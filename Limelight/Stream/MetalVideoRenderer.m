//
//  MetalVideoRenderer.m
//  Moonlight
//
//  Created by OpenAI Codex on 2026/3/29.
//

#import "MetalVideoRenderer.h"

@import CoreImage;
@import MetalKit;

#import <VideoToolbox/VideoToolbox.h>
#include <libavcodec/avcodec.h>
#include <libavcodec/cbs.h>
#include <libavcodec/cbs_av1.h>
#include <libavformat/avio.h>
#include <libavutil/mem.h>
#include <float.h>

#import "StreamView.h"

static const size_t kMetalRendererNaluStartPrefixSize = 3;
static const size_t kMetalRendererNalLengthPrefixSize = 4;
static const NSUInteger kMetalRendererMaxOutstandingDecodeFrames = 2;

extern int ff_isom_write_av1c(AVIOContext *pb, const uint8_t *buf, int size,
                              int write_seq_header);

typedef struct {
    CFTimeInterval submitTime;
} MetalDecodeFrameContext;

static void MetalVideoRendererDecompressionOutputCallback(void *decompressionOutputRefCon,
                                                          void *sourceFrameRefCon,
                                                          OSStatus status,
                                                          VTDecodeInfoFlags infoFlags,
                                                          CVImageBufferRef imageBuffer,
                                                          CMTime presentationTimeStamp,
                                                          CMTime presentationDuration);

@interface MetalVideoRenderer () <MTKViewDelegate>

@property (nonatomic, strong) VideoDecoderRenderer *fallbackRenderer;

@end

@implementation MetalVideoRenderer {
    UIView *_hostView;
    StreamView *_streamView;
    id<ConnectionCallbacks> _callbacks;
    float _streamAspectRatio;

    id<MTLDevice> _metalDevice;
    id<MTLCommandQueue> _commandQueue;
    MTKView *_metalView;
    CIContext *_ciContext;
    CGColorSpaceRef _colorSpace;

    NSLock *_decodedFrameLock;
    CVPixelBufferRef _latestPixelBuffer;
    CVPixelBufferRef _lastPresentedPixelBuffer;
    NSLock *_decoderLatencyLock;
    dispatch_queue_t _decodeSubmissionQueue;
    BOOL _decodeSubmissionScheduled;
    NSUInteger _outstandingDecodeFrames;

    NSMutableArray<NSData *> *parameterSetBuffers;
    NSData *masteringDisplayColorVolume;
    NSData *contentLightLevelInfo;
    CMVideoFormatDescriptionRef formatDesc;
    VTDecompressionSessionRef decompressionSession;

    int videoFormat;
    int frameRate;
    BOOL framePacing;
    CADisplayLink *_displayLink;
    BOOL _metalEnabled;
    BOOL _usingFallbackRenderer;
    BOOL _videoContentShown;
    BOOL _hdrModeRequested;
    BOOL _hdrOutputEnabled;
    uint64_t _completedDecoderLatencyTotal;
    int _completedDecoderLatencyFrames;
    uint64_t _completedDecoderLatencyMin;
    uint64_t _completedDecoderLatencyMax;
    CGSize _cachedHostBoundsSize;
    CGSize _cachedDrawableSize;
    CGRect _cachedImageExtent;
    CGAffineTransform _cachedPresentationTransform;
    CGRect _cachedDrawableBounds;
    BOOL _hasCachedPresentationTransform;
}

int DrSubmitDecodeUnit(PDECODE_UNIT decodeUnit);

- (id)initWithView:(UIView *)view callbacks:(id<ConnectionCallbacks>)callbacks streamAspectRatio:(float)aspectRatio useFramePacing:(BOOL)useFramePacing
{
    self = [super init];
    if (self) {
        _hostView = view;
        if ([view isKindOfClass:[StreamView class]]) {
            _streamView = (StreamView *)view;
        }
        _callbacks = callbacks;
        _streamAspectRatio = aspectRatio;
        framePacing = useFramePacing;
        _decodedFrameLock = [[NSLock alloc] init];
        _decoderLatencyLock = [[NSLock alloc] init];
        _decodeSubmissionQueue = dispatch_queue_create("cn.axi.moonlight.metal.decode-submit", DISPATCH_QUEUE_SERIAL);
        _decodeSubmissionScheduled = NO;
        _outstandingDecodeFrames = 0;
        parameterSetBuffers = [[NSMutableArray alloc] init];

        _metalDevice = MTLCreateSystemDefaultDevice();
        _commandQueue = [_metalDevice newCommandQueue];
        _metalEnabled = (_metalDevice != nil && _commandQueue != nil);

        if (_metalEnabled) {
            [self installMetalView];
            [self applyMetalDisplayConfiguration];

            if (_streamView != nil) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(updateMetalViewLayout)
                                                             name:StreamViewBoundsDidChangeNotification
                                                           object:_streamView];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self teardownDecompressionSession];
    [self clearLatestPixelBuffer];

    if (formatDesc != NULL) {
        CFRelease(formatDesc);
        formatDesc = NULL;
    }

    if (_colorSpace != NULL) {
        CGColorSpaceRelease(_colorSpace);
        _colorSpace = NULL;
    }
}

- (void)installMetalView
{
    if (!_metalEnabled || _hostView == nil || _metalView != nil) {
        return;
    }

    _metalView = [[MTKView alloc] initWithFrame:_hostView.bounds device:_metalDevice];
    _metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _metalView.enableSetNeedsDisplay = NO;
    _metalView.paused = YES;
    _metalView.framebufferOnly = NO;
    _metalView.autoResizeDrawable = YES;
    _metalView.opaque = YES;
    _metalView.backgroundColor = [UIColor blackColor];
    _metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    _metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalView.userInteractionEnabled = NO;
    _metalView.multipleTouchEnabled = NO;
    _metalView.delegate = self;
    _metalView.hidden = YES;
    [_hostView insertSubview:_metalView atIndex:0];
}

- (void)invalidateCachedPresentationTransform
{
    _cachedHostBoundsSize = CGSizeZero;
    _cachedDrawableSize = CGSizeZero;
    _cachedImageExtent = CGRectZero;
    _cachedDrawableBounds = CGRectZero;
    _cachedPresentationTransform = CGAffineTransformIdentity;
    _hasCachedPresentationTransform = NO;

    [_decodedFrameLock lock];
    if (_lastPresentedPixelBuffer != NULL) {
        CFRelease(_lastPresentedPixelBuffer);
        _lastPresentedPixelBuffer = NULL;
    }
    [_decodedFrameLock unlock];
}

- (BOOL)screenSupportsExtendedDynamicRange
{
    if (@available(iOS 16.0, *)) {
        UIScreen *screen = _hostView.window.screen ?: UIScreen.mainScreen;
        return screen != nil && MAX(screen.currentEDRHeadroom, screen.potentialEDRHeadroom) > 1.0f;
    }

    return NO;
}

- (CAEDRMetadata *)currentEdrMetadata API_AVAILABLE(ios(16.0))
{
    if (!CAEDRMetadata.isAvailable) {
        return nil;
    }

    if (masteringDisplayColorVolume != nil || contentLightLevelInfo != nil) {
        return [CAEDRMetadata HDR10MetadataWithDisplayInfo:masteringDisplayColorVolume
                                              contentInfo:contentLightLevelInfo
                                       opticalOutputScale:100.0f];
    }

    return [CAEDRMetadata HDR10MetadataWithMinLuminance:0.0001f
                                           maxLuminance:1000.0f
                                     opticalOutputScale:100.0f];
}

- (CGColorSpaceRef)createTargetColorSpaceForHdrOutput:(BOOL)hdrOutput
{
    if (hdrOutput) {
        CGColorSpaceRef extendedDisplayP3 = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
        if (extendedDisplayP3 != NULL) {
            return extendedDisplayP3;
        }
    }

    return CGColorSpaceCreateDeviceRGB();
}

- (void)rebuildCiContextForColorSpace:(CGColorSpaceRef)targetColorSpace
{
    NSDictionary *contextOptions = @{
        kCIContextWorkingColorSpace : (__bridge id)targetColorSpace,
        kCIContextOutputColorSpace : (__bridge id)targetColorSpace
    };
    _ciContext = [CIContext contextWithMTLDevice:_metalDevice options:contextOptions];
}

- (void)applyMetalDisplayConfiguration
{
    if (!_metalEnabled || _metalView == nil) {
        return;
    }

    BOOL shouldEnableHdrOutput = _hdrModeRequested && [self screenSupportsExtendedDynamicRange];
    MTLPixelFormat targetPixelFormat = shouldEnableHdrOutput ? MTLPixelFormatRGBA16Float : MTLPixelFormatBGRA8Unorm;
    CAMetalLayer *metalLayer = (CAMetalLayer *)_metalView.layer;

    if (_colorSpace != NULL) {
        CGColorSpaceRelease(_colorSpace);
        _colorSpace = NULL;
    }
    _colorSpace = [self createTargetColorSpaceForHdrOutput:shouldEnableHdrOutput];

    _hdrOutputEnabled = shouldEnableHdrOutput;
    _metalView.colorPixelFormat = targetPixelFormat;
    metalLayer.colorspace = _colorSpace;
    metalLayer.contentsFormat = shouldEnableHdrOutput ? kCAContentsFormatRGBA16Float : kCAContentsFormatRGBA8Uint;

    if (@available(iOS 16.0, *)) {
        metalLayer.wantsExtendedDynamicRangeContent = shouldEnableHdrOutput;
        metalLayer.EDRMetadata = shouldEnableHdrOutput ? [self currentEdrMetadata] : nil;
    }

    [self rebuildCiContextForColorSpace:_colorSpace];
    [self invalidateCachedPresentationTransform];
    [_metalView releaseDrawables];
}

- (void)updateMetalViewLayout
{
    if (_metalView == nil || _hostView == nil) {
        return;
    }

    _metalView.frame = _hostView.bounds;
    [self invalidateCachedPresentationTransform];
}

- (VideoDecoderRenderer *)fallbackRenderer
{
    if (_fallbackRenderer == nil && _hostView != nil) {
        _fallbackRenderer = [[VideoDecoderRenderer alloc] initWithView:_hostView
                                                             callbacks:_callbacks
                                                     streamAspectRatio:_streamAspectRatio
                                                        useFramePacing:NO];
    }

    return _fallbackRenderer;
}

- (BOOL)shouldUseFallbackRendererForFormat:(int)selectedVideoFormat
{
    if (!_metalEnabled) {
        return YES;
    }

    if (selectedVideoFormat & VIDEO_FORMAT_MASK_AV1) {
        return !VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1);
    }

    return !(selectedVideoFormat & (VIDEO_FORMAT_MASK_H264 | VIDEO_FORMAT_MASK_H265));
}

- (void)setupWithVideoFormat:(int)selectedVideoFormat width:(int)videoWidth height:(int)videoHeight frameRate:(int)selectedFrameRate
{
    videoFormat = selectedVideoFormat;
    frameRate = selectedFrameRate;
    _streamAspectRatio = videoHeight == 0 ? _streamAspectRatio : (float)videoWidth / (float)videoHeight;
    _usingFallbackRenderer = [self shouldUseFallbackRendererForFormat:selectedVideoFormat];
    _videoContentShown = NO;
    [self invalidateCachedPresentationTransform];

    if (_metalView != nil) {
        _metalView.hidden = YES;
        UIScreen *screen = _hostView.window.screen ?: UIScreen.mainScreen;
        NSInteger screenMaximumFramesPerSecond = MAX(screen.maximumFramesPerSecond, 1);
        _metalView.preferredFramesPerSecond = MAX(MIN(selectedFrameRate, (int)screenMaximumFramesPerSecond), 1);
    }
    _hdrOutputEnabled = NO;
    _decodeSubmissionScheduled = NO;
    _outstandingDecodeFrames = 0;
    [_decoderLatencyLock lock];
    _completedDecoderLatencyTotal = 0;
    _completedDecoderLatencyFrames = 0;
    _completedDecoderLatencyMin = 0;
    _completedDecoderLatencyMax = 0;
    [_decoderLatencyLock unlock];

    [parameterSetBuffers removeAllObjects];
    [self teardownDecompressionSession];
    [self clearLatestPixelBuffer];

    if (formatDesc != NULL) {
        CFRelease(formatDesc);
        formatDesc = NULL;
    }

    if (_usingFallbackRenderer) {
        [[self fallbackRenderer] setupWithVideoFormat:selectedVideoFormat
                                                width:videoWidth
                                               height:videoHeight
                                            frameRate:selectedFrameRate];
    }
}

- (void)start
{
    if (_usingFallbackRenderer) {
        [[self fallbackRenderer] start];
        return;
    }

    [self applyMetalDisplayConfiguration];

    if (_metalView != nil) {
        _metalView.paused = NO;
        UIScreen *screen = _hostView.window.screen ?: UIScreen.mainScreen;
        NSInteger screenMaximumFramesPerSecond = MAX(screen.maximumFramesPerSecond, 1);
        _metalView.preferredFramesPerSecond = MAX(MIN(frameRate, (int)screenMaximumFramesPerSecond), 1);
    }
}

- (void)stop
{
    [_displayLink invalidate];
    _displayLink = nil;

    if (_usingFallbackRenderer) {
        [[self fallbackRenderer] stop];
    }

    _decodeSubmissionScheduled = NO;
    _outstandingDecodeFrames = 0;

    [self teardownDecompressionSession];
    [self clearLatestPixelBuffer];

    if (_metalView != nil) {
        _metalView.paused = YES;
        _metalView.hidden = YES;
    }
}

- (void)setHdrMode:(BOOL)enabled
{
    if (_usingFallbackRenderer) {
        [[self fallbackRenderer] setHdrMode:enabled];
        return;
    }

    _hdrModeRequested = enabled;

    SS_HDR_METADATA hdrMetadata;
    BOOL hasMetadata = enabled && LiGetHdrMetadata(&hdrMetadata);
    BOOL metadataChanged = NO;

    if (hasMetadata && hdrMetadata.displayPrimaries[0].x != 0 && hdrMetadata.maxDisplayLuminance != 0) {
        struct {
            vector_ushort2 primaries[3];
            vector_ushort2 white_point;
            uint32_t luminance_max;
            uint32_t luminance_min;
        } __attribute__((packed, aligned(4))) mdcv;

        mdcv.primaries[0].x = __builtin_bswap16(hdrMetadata.displayPrimaries[1].x);
        mdcv.primaries[0].y = __builtin_bswap16(hdrMetadata.displayPrimaries[1].y);
        mdcv.primaries[1].x = __builtin_bswap16(hdrMetadata.displayPrimaries[2].x);
        mdcv.primaries[1].y = __builtin_bswap16(hdrMetadata.displayPrimaries[2].y);
        mdcv.primaries[2].x = __builtin_bswap16(hdrMetadata.displayPrimaries[0].x);
        mdcv.primaries[2].y = __builtin_bswap16(hdrMetadata.displayPrimaries[0].y);
        mdcv.white_point.x = __builtin_bswap16(hdrMetadata.whitePoint.x);
        mdcv.white_point.y = __builtin_bswap16(hdrMetadata.whitePoint.y);
        mdcv.luminance_max = __builtin_bswap32((uint32_t)hdrMetadata.maxDisplayLuminance * 10000);
        mdcv.luminance_min = __builtin_bswap32(hdrMetadata.minDisplayLuminance);

        NSData *newMdcv = [NSData dataWithBytes:&mdcv length:sizeof(mdcv)];
        if (masteringDisplayColorVolume == nil || ![newMdcv isEqualToData:masteringDisplayColorVolume]) {
            masteringDisplayColorVolume = newMdcv;
            metadataChanged = YES;
        }
    }
    else if (masteringDisplayColorVolume != nil) {
        masteringDisplayColorVolume = nil;
        metadataChanged = YES;
    }

    if (hasMetadata && hdrMetadata.maxContentLightLevel != 0 && hdrMetadata.maxFrameAverageLightLevel != 0) {
        struct {
            uint16_t max_content_light_level;
            uint16_t max_frame_average_light_level;
        } __attribute__((packed, aligned(2))) cll;

        cll.max_content_light_level = __builtin_bswap16(hdrMetadata.maxContentLightLevel);
        cll.max_frame_average_light_level = __builtin_bswap16(hdrMetadata.maxFrameAverageLightLevel);

        NSData *newCll = [NSData dataWithBytes:&cll length:sizeof(cll)];
        if (contentLightLevelInfo == nil || ![newCll isEqualToData:contentLightLevelInfo]) {
            contentLightLevelInfo = newCll;
            metadataChanged = YES;
        }
    }
    else if (contentLightLevelInfo != nil) {
        contentLightLevelInfo = nil;
        metadataChanged = YES;
    }

    if (metadataChanged) {
        LiRequestIdrFrame();
    }

    [self applyMetalDisplayConfiguration];
}

- (void)updateAnnexBBufferForRange:(CMBlockBufferRef)frameBuffer dataBlock:(CMBlockBufferRef)dataBuffer offset:(int)offset length:(int)nalLength
{
    OSStatus status;
    size_t oldOffset = CMBlockBufferGetDataLength(frameBuffer);

    status = CMBlockBufferAppendMemoryBlock(frameBuffer, NULL,
                                            kMetalRendererNalLengthPrefixSize,
                                            kCFAllocatorDefault, NULL, 0,
                                            kMetalRendererNalLengthPrefixSize, 0);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferAppendMemoryBlock failed: %d", (int)status);
        return;
    }

    const int dataLength = nalLength - (int)kMetalRendererNaluStartPrefixSize;
    const uint8_t lengthBytes[] = {
        (uint8_t)(dataLength >> 24),
        (uint8_t)(dataLength >> 16),
        (uint8_t)(dataLength >> 8),
        (uint8_t)dataLength
    };
    status = CMBlockBufferReplaceDataBytes(lengthBytes, frameBuffer,
                                           oldOffset, kMetalRendererNalLengthPrefixSize);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferReplaceDataBytes failed: %d", (int)status);
        return;
    }

    status = CMBlockBufferAppendBufferReference(frameBuffer,
                                                dataBuffer,
                                                offset + (int)kMetalRendererNaluStartPrefixSize,
                                                dataLength,
                                                0);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferAppendBufferReference failed: %d", (int)status);
    }
}

- (NSData *)getAv1CodecConfigurationBox:(NSData *)frameData
{
    AVIOContext *ioctx = NULL;
    int err = avio_open_dyn_buf(&ioctx);
    if (err < 0) {
        Log(LOG_E, @"avio_open_dyn_buf() failed: %d", err);
        return nil;
    }

    err = ff_isom_write_av1c(ioctx, (uint8_t *)frameData.bytes, (int)frameData.length, 1);
    if (err < 0) {
        Log(LOG_E, @"ff_isom_write_av1c() failed: %d", err);
    }

    uint8_t *av1cBuf = NULL;
    int av1cBufLen = avio_close_dyn_buf(ioctx, &av1cBuf);
    NSData *data = nil;
    if (err >= 0 && av1cBufLen > 0) {
        data = [NSData dataWithBytes:av1cBuf length:av1cBufLen];
    }
    av_free(av1cBuf);
    return data;
}

- (CMVideoFormatDescriptionRef)createAV1FormatDescriptionForIDRFrame:(NSData *)frameData
{
    NSMutableDictionary *extensions = [[NSMutableDictionary alloc] init];

    CodedBitstreamContext *cbsCtx = NULL;
    int err = ff_cbs_init(&cbsCtx, AV_CODEC_ID_AV1, NULL);
    if (err < 0) {
        Log(LOG_E, @"ff_cbs_init() failed: %d", err);
        return nil;
    }

    AVPacket avPacket = {};
    avPacket.data = (uint8_t *)frameData.bytes;
    avPacket.size = (int)frameData.length;

    CodedBitstreamFragment cbsFrag = {};
    err = ff_cbs_read_packet(cbsCtx, &cbsFrag, &avPacket);
    if (err < 0) {
        Log(LOG_E, @"ff_cbs_read_packet() failed: %d", err);
        ff_cbs_close(&cbsCtx);
        return nil;
    }

#define SET_CFSTR_EXTENSION(key, value) extensions[(__bridge NSString *)key] = (__bridge NSString *)(value)
#define SET_EXTENSION(key, value) extensions[(__bridge NSString *)key] = (value)

    SET_EXTENSION(kCMFormatDescriptionExtension_FormatName, @"av01");
    SET_EXTENSION(kCMFormatDescriptionExtension_Depth, @24);

    CodedBitstreamAV1Context *bitstreamCtx = (CodedBitstreamAV1Context *)cbsCtx->priv_data;
    AV1RawSequenceHeader *seqHeader = bitstreamCtx->sequence_header;
    if (seqHeader == NULL) {
        Log(LOG_E, @"AV1 sequence header not found in IDR frame!");
        ff_cbs_fragment_free(&cbsFrag);
        ff_cbs_close(&cbsCtx);
        return nil;
    }

    switch (seqHeader->color_config.color_primaries) {
        case 1:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_ITU_R_709_2);
            break;
        case 6:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_SMPTE_C);
            break;
        case 9:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_ITU_R_2020);
            break;
        default:
            break;
    }

    switch (seqHeader->color_config.transfer_characteristics) {
        case 1:
        case 6:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_709_2);
            break;
        case 7:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_SMPTE_240M_1995);
            break;
        case 8:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_Linear);
            break;
        case 14:
        case 15:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_2020);
            break;
        case 16:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ);
            break;
        case 17:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG);
            break;
        default:
            break;
    }

    switch (seqHeader->color_config.matrix_coefficients) {
        case 1:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2);
            break;
        case 6:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4);
            break;
        case 7:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_SMPTE_240M_1995);
            break;
        case 9:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_2020);
            break;
        default:
            break;
    }

    SET_EXTENSION(kCMFormatDescriptionExtension_FullRangeVideo, @(seqHeader->color_config.color_range == 1));
    SET_EXTENSION(kCMFormatDescriptionExtension_FieldCount, @(1));

    switch (seqHeader->color_config.chroma_sample_position) {
        case 1:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ChromaLocationTopField,
                                kCMFormatDescriptionChromaLocation_Left);
            break;
        case 2:
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ChromaLocationTopField,
                                kCMFormatDescriptionChromaLocation_TopLeft);
            break;
        default:
            break;
    }

    if (contentLightLevelInfo != nil) {
        SET_EXTENSION(kCMFormatDescriptionExtension_ContentLightLevelInfo, contentLightLevelInfo);
    }

    if (masteringDisplayColorVolume != nil) {
        SET_EXTENSION(kCMFormatDescriptionExtension_MasteringDisplayColorVolume, masteringDisplayColorVolume);
    }

    NSData *av1Config = [self getAv1CodecConfigurationBox:frameData];
    if (av1Config != nil) {
        extensions[(__bridge NSString *)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] = @{
            @"av1C" : av1Config,
        };
    }
    extensions[@"BitsPerComponent"] = @(bitstreamCtx->bit_depth);

#undef SET_EXTENSION
#undef SET_CFSTR_EXTENSION

    CMVideoFormatDescriptionRef av1FormatDesc = NULL;
    OSStatus status = CMVideoFormatDescriptionCreate(kCFAllocatorDefault,
                                                     kCMVideoCodecType_AV1,
                                                     bitstreamCtx->frame_width,
                                                     bitstreamCtx->frame_height,
                                                     (__bridge CFDictionaryRef)extensions,
                                                     &av1FormatDesc);
    if (status != noErr) {
        Log(LOG_E, @"Failed to create AV1 format description: %d", (int)status);
        av1FormatDesc = NULL;
    }

    ff_cbs_fragment_free(&cbsFrag);
    ff_cbs_close(&cbsCtx);
    return av1FormatDesc;
}

- (BOOL)rebuildFormatDescriptionForCurrentParameterSetsWithFrameData:(unsigned char *)data length:(int)length
{
    if (formatDesc != NULL) {
        CFRelease(formatDesc);
        formatDesc = NULL;
    }

    if (videoFormat & VIDEO_FORMAT_MASK_H264) {
        size_t parameterSetCount = [parameterSetBuffers count];
        if (parameterSetCount == 0) {
            return NO;
        }

        const uint8_t *parameterSetPointers[parameterSetCount];
        size_t parameterSetSizes[parameterSetCount];
        for (NSUInteger index = 0; index < parameterSetCount; index++) {
            NSData *parameterSet = parameterSetBuffers[index];
            parameterSetPointers[index] = parameterSet.bytes;
            parameterSetSizes[index] = parameterSet.length;
        }

        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              parameterSetCount,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              kMetalRendererNalLengthPrefixSize,
                                                                              &formatDesc);
        [parameterSetBuffers removeAllObjects];
        if (status != noErr) {
            Log(LOG_E, @"Failed to create H264 format description for Metal renderer: %d", (int)status);
            formatDesc = NULL;
        }
    }
    else if (videoFormat & VIDEO_FORMAT_MASK_H265) {
        size_t parameterSetCount = [parameterSetBuffers count];
        if (parameterSetCount == 0) {
            return NO;
        }

        const uint8_t *parameterSetPointers[parameterSetCount];
        size_t parameterSetSizes[parameterSetCount];
        for (NSUInteger index = 0; index < parameterSetCount; index++) {
            NSData *parameterSet = parameterSetBuffers[index];
            parameterSetPointers[index] = parameterSet.bytes;
            parameterSetSizes[index] = parameterSet.length;
        }

        NSMutableDictionary *videoFormatParams = [[NSMutableDictionary alloc] init];
        if (contentLightLevelInfo != nil) {
            videoFormatParams[(__bridge NSString *)kCMFormatDescriptionExtension_ContentLightLevelInfo] = contentLightLevelInfo;
        }
        if (masteringDisplayColorVolume != nil) {
            videoFormatParams[(__bridge NSString *)kCMFormatDescriptionExtension_MasteringDisplayColorVolume] = masteringDisplayColorVolume;
        }

        OSStatus status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                              parameterSetCount,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              kMetalRendererNalLengthPrefixSize,
                                                                              (__bridge CFDictionaryRef)videoFormatParams,
                                                                              &formatDesc);
        [parameterSetBuffers removeAllObjects];
        if (status != noErr) {
            Log(LOG_E, @"Failed to create HEVC format description for Metal renderer: %d", (int)status);
            formatDesc = NULL;
        }
    }
    else if (videoFormat & VIDEO_FORMAT_MASK_AV1) {
        NSData *fullFrameData = [NSData dataWithBytesNoCopy:data length:length freeWhenDone:NO];
        formatDesc = [self createAV1FormatDescriptionForIDRFrame:fullFrameData];
    }
    else {
        return NO;
    }

    if (formatDesc == NULL) {
        return NO;
    }

    [self teardownDecompressionSession];
    return [self ensureDecompressionSession];
}

- (BOOL)ensureDecompressionSession
{
    if (decompressionSession != NULL) {
        return YES;
    }

    if (formatDesc == NULL) {
        return NO;
    }

    NSDictionary *destinationAttributes = @{
        (__bridge NSString *)kCVPixelBufferMetalCompatibilityKey : @YES
    };

    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = MetalVideoRendererDecompressionOutputCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void *)self;

    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   formatDesc,
                                                   NULL,
                                                   (__bridge CFDictionaryRef)destinationAttributes,
                                                   &callbackRecord,
                                                   &decompressionSession);
    if (status != noErr) {
        Log(LOG_E, @"Failed to create VideoToolbox decompression session for Metal renderer: %d", (int)status);
        decompressionSession = NULL;
        return NO;
    }

    VTSessionSetProperty(decompressionSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    return YES;
}

- (void)teardownDecompressionSession
{
    if (decompressionSession == NULL) {
        return;
    }

    VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession);
    VTDecompressionSessionInvalidate(decompressionSession);
    CFRelease(decompressionSession);
    decompressionSession = NULL;
}

- (void)clearLatestPixelBuffer
{
    [_decodedFrameLock lock];
    if (_latestPixelBuffer != NULL) {
        CFRelease(_latestPixelBuffer);
        _latestPixelBuffer = NULL;
    }
    if (_lastPresentedPixelBuffer != NULL) {
        CFRelease(_lastPresentedPixelBuffer);
        _lastPresentedPixelBuffer = NULL;
    }
    [_decodedFrameLock unlock];
}

- (void)presentDecodedFrame:(CVPixelBufferRef)pixelBuffer
{
    [_decodedFrameLock lock];
    if (_latestPixelBuffer != NULL) {
        CFRelease(_latestPixelBuffer);
    }
    _latestPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    [_decodedFrameLock unlock];

    if (!_videoContentShown || _hdrModeRequested != _hdrOutputEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_usingFallbackRenderer || self->_metalView == nil) {
                return;
            }

            if (self->_hdrModeRequested != self->_hdrOutputEnabled) {
                [self applyMetalDisplayConfiguration];
            }

            if (!self->_videoContentShown) {
                self->_videoContentShown = YES;
                self->_metalView.hidden = NO;
                [self->_callbacks videoContentShown];
            }
        });
    }
}

- (void)recordCompletedDecoderLatency:(uint64_t)latencyMs
{
    [_decoderLatencyLock lock];
    _completedDecoderLatencyTotal += latencyMs;
    _completedDecoderLatencyFrames++;
    if (_completedDecoderLatencyMin == 0 || latencyMs < _completedDecoderLatencyMin) {
        _completedDecoderLatencyMin = latencyMs;
    }
    if (latencyMs > _completedDecoderLatencyMax) {
        _completedDecoderLatencyMax = latencyMs;
    }
    [_decoderLatencyLock unlock];
}

- (BOOL)consumeCompletedDecoderLatencyTotal:(uint64_t *)total
                                     frames:(int *)frames
                                        min:(uint64_t *)min
                                        max:(uint64_t *)max
{
    [_decoderLatencyLock lock];
    BOOL hasStats = _completedDecoderLatencyFrames > 0;
    if (hasStats) {
        if (total != NULL) {
            *total = _completedDecoderLatencyTotal;
        }
        if (frames != NULL) {
            *frames = _completedDecoderLatencyFrames;
        }
        if (min != NULL) {
            *min = _completedDecoderLatencyMin;
        }
        if (max != NULL) {
            *max = _completedDecoderLatencyMax;
        }

        _completedDecoderLatencyTotal = 0;
        _completedDecoderLatencyFrames = 0;
        _completedDecoderLatencyMin = 0;
        _completedDecoderLatencyMax = 0;
    }
    [_decoderLatencyLock unlock];
    return hasStats;
}

- (CGRect)targetRectForDrawableSize:(CGSize)drawableSize
{
    CGSize boundsSize = _hostView.bounds.size;
    if (boundsSize.width <= 0.0 || boundsSize.height <= 0.0 || drawableSize.width <= 0.0 || drawableSize.height <= 0.0) {
        return CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    }

    CGFloat videoWidth;
    CGFloat videoHeight;
    if (boundsSize.width > boundsSize.height * _streamAspectRatio) {
        videoWidth = boundsSize.height * _streamAspectRatio;
        videoHeight = boundsSize.height;
    }
    else {
        videoWidth = boundsSize.width;
        videoHeight = boundsSize.width / _streamAspectRatio;
    }

    CGFloat originX = boundsSize.width / 2.0 - videoWidth / 2.0;
    CGFloat originY = boundsSize.height / 2.0 - videoHeight / 2.0;

    if (_streamView != nil && videoHeight < boundsSize.height) {
        CGFloat availableVerticalPadding = MAX(boundsSize.height - videoHeight, 0.0f);
        CGFloat clampedMargin = MIN([_streamView videoAlignmentMargin], availableVerticalPadding);
        switch ([_streamView videoAlignmentMode]) {
            case StreamViewVideoAlignmentModeTop:
                originY = clampedMargin;
                break;
            case StreamViewVideoAlignmentModeBottom:
                originY = boundsSize.height - videoHeight - clampedMargin;
                break;
            case StreamViewVideoAlignmentModeCenter:
            default:
                break;
        }
    }

    CGFloat scaleX = drawableSize.width / boundsSize.width;
    CGFloat scaleY = drawableSize.height / boundsSize.height;
    return CGRectMake(originX * scaleX, originY * scaleY, videoWidth * scaleX, videoHeight * scaleY);
}

- (CGAffineTransform)presentationTransformForImageExtent:(CGRect)imageExtent drawableSize:(CGSize)drawableSize
{
    CGSize hostBoundsSize = _hostView.bounds.size;
    if (_hasCachedPresentationTransform &&
        CGSizeEqualToSize(_cachedHostBoundsSize, hostBoundsSize) &&
        CGSizeEqualToSize(_cachedDrawableSize, drawableSize) &&
        CGRectEqualToRect(_cachedImageExtent, imageExtent)) {
        return _cachedPresentationTransform;
    }

    CGRect targetRect = [self targetRectForDrawableSize:drawableSize];
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, CGRectGetMinX(targetRect), CGRectGetMinY(targetRect));
    transform = CGAffineTransformScale(transform,
                                       CGRectGetWidth(targetRect) / CGRectGetWidth(imageExtent),
                                       CGRectGetHeight(targetRect) / CGRectGetHeight(imageExtent));
    transform = CGAffineTransformTranslate(transform, -CGRectGetMinX(imageExtent), -CGRectGetMinY(imageExtent));

    _cachedHostBoundsSize = hostBoundsSize;
    _cachedDrawableSize = drawableSize;
    _cachedImageExtent = imageExtent;
    _cachedDrawableBounds = CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    _cachedPresentationTransform = transform;
    _hasCachedPresentationTransform = YES;

    return transform;
}

- (void)handleDecodedImageBuffer:(CVImageBufferRef)imageBuffer
{
    if (imageBuffer == NULL) {
        return;
    }

    [self presentDecodedFrame:(CVPixelBufferRef)imageBuffer];
}

- (void)noteDecodeFrameCompleted
{
    @synchronized (self) {
        if (_outstandingDecodeFrames > 0) {
            _outstandingDecodeFrames--;
        }
    }
}

- (void)scheduleDecodeSubmissionIfNeeded
{
    if (_usingFallbackRenderer || _decodeSubmissionQueue == nil) {
        return;
    }

    @synchronized (self) {
        if (_decodeSubmissionScheduled ||
            _outstandingDecodeFrames >= kMetalRendererMaxOutstandingDecodeFrames) {
            return;
        }
        _decodeSubmissionScheduled = YES;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(_decodeSubmissionQueue, ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        if (!strongSelf->_usingFallbackRenderer) {
            while (1) {
                BOOL canSubmitMore = NO;
                @synchronized (strongSelf) {
                    canSubmitMore = strongSelf->_outstandingDecodeFrames < kMetalRendererMaxOutstandingDecodeFrames;
                }
                if (!canSubmitMore) {
                    break;
                }

                VIDEO_FRAME_HANDLE handle;
                PDECODE_UNIT du;
                if (!LiPollNextVideoFrame(&handle, &du)) {
                    break;
                }

                int submitResult = DrSubmitDecodeUnit(du);
                LiCompleteVideoFrame(handle, submitResult);

                if (submitResult == DR_OK) {
                    @synchronized (strongSelf) {
                        strongSelf->_outstandingDecodeFrames++;
                    }
                }
            }
        }

        @synchronized (strongSelf) {
            strongSelf->_decodeSubmissionScheduled = NO;
        }
    });
}

- (int)submitDecodeBuffer:(unsigned char *)data length:(int)length bufferType:(int)bufferType decodeUnit:(PDECODE_UNIT)du
{
    if (_usingFallbackRenderer) {
        return [[self fallbackRenderer] submitDecodeBuffer:data length:length bufferType:bufferType decodeUnit:du];
    }

    if (du->frameType == FRAME_TYPE_IDR) {
        if (bufferType != BUFFER_TYPE_PICDATA) {
            if (bufferType == BUFFER_TYPE_VPS || bufferType == BUFFER_TYPE_SPS || bufferType == BUFFER_TYPE_PPS) {
                int startLen = data[2] == 0x01 ? 3 : 4;
                [parameterSetBuffers addObject:[NSData dataWithBytes:&data[startLen] length:length - startLen]];
            }
            return DR_OK;
        }

        if (![self rebuildFormatDescriptionForCurrentParameterSetsWithFrameData:data length:length]) {
            free(data);
            return DR_NEED_IDR;
        }
    }

    if (formatDesc == NULL || ![self ensureDecompressionSession]) {
        free(data);
        return DR_NEED_IDR;
    }

    CMBlockBufferRef dataBlockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                         data,
                                                         length,
                                                         kCFAllocatorDefault,
                                                         NULL,
                                                         0,
                                                         length,
                                                         0,
                                                         &dataBlockBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferCreateWithMemoryBlock failed: %d", (int)status);
        free(data);
        return DR_NEED_IDR;
    }

    CMBlockBufferRef frameBlockBuffer = NULL;
    status = CMBlockBufferCreateEmpty(NULL, 0, 0, &frameBlockBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferCreateEmpty failed: %d", (int)status);
        CFRelease(dataBlockBuffer);
        return DR_NEED_IDR;
    }

    if (videoFormat & (VIDEO_FORMAT_MASK_H264 | VIDEO_FORMAT_MASK_H265)) {
        int lastOffset = -1;
        for (int index = 0; index < length - (int)kMetalRendererNaluStartPrefixSize; index++) {
            if (data[index] == 0 && data[index + 1] == 0 && data[index + 2] == 1) {
                if (lastOffset != -1) {
                    [self updateAnnexBBufferForRange:frameBlockBuffer
                                           dataBlock:dataBlockBuffer
                                              offset:lastOffset
                                              length:index - lastOffset];
                }
                lastOffset = index;
            }
        }

        if (lastOffset != -1) {
            [self updateAnnexBBufferForRange:frameBlockBuffer
                                   dataBlock:dataBlockBuffer
                                      offset:lastOffset
                                      length:length - lastOffset];
        }
    }
    else {
        status = CMBlockBufferAppendBufferReference(frameBlockBuffer, dataBlockBuffer, 0, length, 0);
        if (status != noErr) {
            Log(LOG_E, @"CMBlockBufferAppendBufferReference failed: %d", (int)status);
            CFRelease(dataBlockBuffer);
            CFRelease(frameBlockBuffer);
            return DR_NEED_IDR;
        }
    }

    CMSampleTimingInfo sampleTiming = {
        .duration = kCMTimeInvalid,
        .presentationTimeStamp = CMTimeMake(du->presentationTimeMs, 1000),
        .decodeTimeStamp = kCMTimeInvalid
    };

    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                       frameBlockBuffer,
                                       formatDesc,
                                       1,
                                       1,
                                       &sampleTiming,
                                       0,
                                       NULL,
                                       &sampleBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMSampleBufferCreateReady failed for Metal renderer: %d", (int)status);
        CFRelease(dataBlockBuffer);
        CFRelease(frameBlockBuffer);
        return DR_NEED_IDR;
    }

    MetalDecodeFrameContext *decodeContext = malloc(sizeof(MetalDecodeFrameContext));
    if (decodeContext != NULL) {
        decodeContext->submitTime = CACurrentMediaTime();
    }

    VTDecodeInfoFlags infoFlags = 0;
    status = VTDecompressionSessionDecodeFrame(decompressionSession,
                                               sampleBuffer,
                                               kVTDecodeFrame_EnableAsynchronousDecompression | kVTDecodeFrame_1xRealTimePlayback,
                                               decodeContext,
                                               &infoFlags);

    CFRelease(sampleBuffer);
    CFRelease(frameBlockBuffer);
    CFRelease(dataBlockBuffer);

    if (status != noErr) {
        if (decodeContext != NULL) {
            free(decodeContext);
        }
        Log(LOG_E, @"VTDecompressionSessionDecodeFrame failed for Metal renderer: %d", (int)status);
        [self teardownDecompressionSession];
        return DR_NEED_IDR;
    }

    return DR_OK;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

- (void)drawInMTKView:(MTKView *)view
{
    if (_usingFallbackRenderer) {
        return;
    }

    [self scheduleDecodeSubmissionIfNeeded];

    CVPixelBufferRef pixelBuffer = NULL;
    [_decodedFrameLock lock];
    if (_latestPixelBuffer != NULL) {
        pixelBuffer = CVPixelBufferRetain(_latestPixelBuffer);
    }
    [_decodedFrameLock unlock];

    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (pixelBuffer == NULL || drawable == nil || renderPassDescriptor == nil) {
        if (pixelBuffer != NULL) {
            CFRelease(pixelBuffer);
        }
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    if (commandBuffer == nil) {
        CFRelease(pixelBuffer);
        return;
    }

    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [encoder endEncoding];

    CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CGRect imageExtent = image.extent;
    CGAffineTransform transform = [self presentationTransformForImageExtent:imageExtent drawableSize:view.drawableSize];
    CIImage *transformedImage = [image imageByApplyingTransform:transform];
    [_ciContext render:transformedImage
          toMTLTexture:drawable.texture
         commandBuffer:commandBuffer
                bounds:_cachedDrawableBounds
            colorSpace:_colorSpace];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];

    CFRelease(pixelBuffer);
}

@end

static void MetalVideoRendererDecompressionOutputCallback(void *decompressionOutputRefCon,
                                                          void *sourceFrameRefCon,
                                                          OSStatus status,
                                                          VTDecodeInfoFlags infoFlags,
                                                          CVImageBufferRef imageBuffer,
                                                          CMTime presentationTimeStamp,
                                                          CMTime presentationDuration)
{
    MetalVideoRenderer *renderer = (__bridge MetalVideoRenderer *)decompressionOutputRefCon;
    [renderer noteDecodeFrameCompleted];

    MetalDecodeFrameContext *decodeContext = (MetalDecodeFrameContext *)sourceFrameRefCon;
    if (status != noErr || imageBuffer == NULL) {
        if (decodeContext != NULL) {
            free(decodeContext);
        }
        [renderer scheduleDecodeSubmissionIfNeeded];
        return;
    }

    if (decodeContext != NULL) {
        uint64_t decoderLatencyMs = (uint64_t)((CACurrentMediaTime() - decodeContext->submitTime) * 1000.0);
        [renderer recordCompletedDecoderLatency:decoderLatencyMs];
        free(decodeContext);
    }
    [renderer handleDecodedImageBuffer:imageBuffer];
    [renderer scheduleDecodeSubmissionIfNeeded];
}
