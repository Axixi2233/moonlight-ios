//
//  Connection.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "Connection.h"
#import "Utils.h"

#import <VideoToolbox/VideoToolbox.h>

#define SDL_MAIN_HANDLED
#import <SDL.h>

#include "Limelight.h"
#include "opus_multistream.h"

@implementation Connection {
    SERVER_INFORMATION _serverInfo;
    STREAM_CONFIGURATION _streamConfig;
    CONNECTION_LISTENER_CALLBACKS _clCallbacks;
    DECODER_RENDERER_CALLBACKS _drCallbacks;
    AUDIO_RENDERER_CALLBACKS _arCallbacks;
    char _hostString[256];
    char _appVersionString[32];
    char _gfeVersionString[32];
    char _rtspSessionUrl[128];
    id<VideoRendering> _rendererTarget;
    id<ConnectionCallbacks> _callbackTarget;
}

static NSLock* initLock;
static OpusMSDecoder* opusDecoder;
static id<ConnectionCallbacks> _callbacks;
static int lastFrameNumber;
static int activeVideoFormat;
static video_stats_t currentVideoStats;
static video_stats_t lastVideoStats;
static NSLock* videoStatsLock;
static audio_stats_t currentAudioStats;
static audio_stats_t lastAudioStats;
static NSLock* audioStatsLock;

static SDL_AudioDeviceID audioDevice;
static OPUS_MULTISTREAM_CONFIGURATION audioConfig;
static void* audioBuffer;
static void* audioSilenceBuffer;
static int audioFrameSize;
static int audioBytesPerSampleFrame;
static const int kMaxPendingAudioDurationMs = 80;
static const int kPreferredSDLBufferSamples = 1024;

static id<VideoRendering> renderer;

static void QueueAudioSilenceFrames(int frameCount)
{
    if (audioDevice == 0 || audioSilenceBuffer == NULL || audioConfig.channelCount <= 0 || frameCount <= 0) {
        return;
    }

    int bytes = sizeof(short) * frameCount * audioConfig.channelCount;
    if (bytes <= 0 || bytes > audioFrameSize) {
        bytes = audioFrameSize;
    }

    if (SDL_QueueAudio(audioDevice, audioSilenceBuffer, bytes) < 0) {
        Log(LOG_E, @"Failed to queue silence sample: %s\n", SDL_GetError());
    }
}

static void RotateAudioStatsWindowIfNeeded(CFTimeInterval now)
{
    if (currentAudioStats.startTime == 0) {
        currentAudioStats.startTime = now;
        return;
    }

    if (now - currentAudioStats.startTime < 1.0f) {
        return;
    }

    currentAudioStats.endTime = now;
    lastAudioStats = currentAudioStats;
    memset(&currentAudioStats, 0, sizeof(currentAudioStats));
    currentAudioStats.startTime = now;
}

static void DrainCompletedRendererDecoderStats(void)
{
    if (renderer == nil || ![renderer respondsToSelector:@selector(consumeCompletedDecoderLatencyTotal:frames:min:max:)]) {
        return;
    }

    uint64_t total = 0;
    int frames = 0;
    uint64_t min = 0;
    uint64_t max = 0;
    if (![renderer consumeCompletedDecoderLatencyTotal:&total frames:&frames min:&min max:&max]) {
        return;
    }

    currentVideoStats.totalDecoderLatency += total;
    currentVideoStats.framesWithDecoderLatency += frames;
    if (currentVideoStats.minDecoderLatency == 0 || (min != 0 && min < currentVideoStats.minDecoderLatency)) {
        currentVideoStats.minDecoderLatency = min;
    }
    if (max > currentVideoStats.maxDecoderLatency) {
        currentVideoStats.maxDecoderLatency = max;
    }
}

int DrDecoderSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags)
{
    [renderer setupWithVideoFormat:videoFormat width:width height:height frameRate:redrawRate];
    lastFrameNumber = 0;
    activeVideoFormat = videoFormat;
    memset(&currentVideoStats, 0, sizeof(currentVideoStats));
    memset(&lastVideoStats, 0, sizeof(lastVideoStats));
    return 0;
}

void DrStart(void)
{
    [renderer start];
}

void DrStop(void)
{
    [renderer stop];
}

-(BOOL) getVideoStats:(video_stats_t*)stats
{
    [videoStatsLock lock];
    DrainCompletedRendererDecoderStats();

    if (lastVideoStats.endTime != 0) {
        memcpy(stats, &lastVideoStats, sizeof(*stats));

        // Metal decode latency is produced asynchronously by VideoToolbox callbacks.
        // If the last completed 1-second window hasn't picked it up yet, surface the
        // most recent in-flight decode stats so the overlay doesn't appear blank.
        if (stats->framesWithDecoderLatency == 0 && currentVideoStats.framesWithDecoderLatency != 0) {
            stats->totalDecoderLatency = currentVideoStats.totalDecoderLatency;
            stats->framesWithDecoderLatency = currentVideoStats.framesWithDecoderLatency;
            stats->maxDecoderLatency = currentVideoStats.maxDecoderLatency;
            stats->minDecoderLatency = currentVideoStats.minDecoderLatency;
        }

        [videoStatsLock unlock];
        return YES;
    }
    
    // No stats yet
    [videoStatsLock unlock];
    return NO;
}

-(BOOL) getAudioStats:(audio_stats_t*)stats
{
    [audioStatsLock lock];

    if (lastAudioStats.endTime != 0) {
        memcpy(stats, &lastAudioStats, sizeof(*stats));
        [audioStatsLock unlock];
        return YES;
    }

    if (currentAudioStats.startTime != 0 &&
        (currentAudioStats.receivedPackets != 0 ||
         currentAudioStats.droppedPackets != 0 ||
         currentAudioStats.decodeErrors != 0)) {
        memcpy(stats, &currentAudioStats, sizeof(*stats));
        [audioStatsLock unlock];
        return YES;
    }

    [audioStatsLock unlock];
    return NO;
}

-(NSString*) getActiveCodecName
{
    switch (activeVideoFormat)
    {
        case VIDEO_FORMAT_H264:
            return @"H.264";
        case VIDEO_FORMAT_H265:
            return @"HEVC";
        case VIDEO_FORMAT_H265_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"HEVC Main 10 HDR";
            }
            else {
                return @"HEVC Main 10 SDR";
            }
        case VIDEO_FORMAT_AV1_MAIN8:
            return @"AV1";
        case VIDEO_FORMAT_AV1_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"AV1 10-bit HDR";
            }
            else {
                return @"AV1 10-bit SDR";
            }
        default:
            return @"UNKNOWN";
    }
}

-(NSString*) getActiveCodecNameLite
{
    switch (activeVideoFormat)
    {
        case VIDEO_FORMAT_H264:
            return @"H.264";
        case VIDEO_FORMAT_H265:
            return @"HEVC";
        case VIDEO_FORMAT_H265_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"HEVC HDR";
            }
            else {
                return @"HEVC";
            }
        case VIDEO_FORMAT_AV1_MAIN8:
            return @"AV1";
        case VIDEO_FORMAT_AV1_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"AV1 HDR";
            }
            else {
                return @"AV1";
            }
        default:
            return @"";
    }
}

-(CGFloat) getActiveMetalFxScale
{
    if (renderer == nil ||
        ![renderer respondsToSelector:@selector(isMetalFxActive)] ||
        ![renderer respondsToSelector:@selector(currentMetalFxScale)] ||
        ![renderer isMetalFxActive]) {
        return 0.0;
    }

    return [renderer currentMetalFxScale];
}

int DrSubmitDecodeUnit(PDECODE_UNIT decodeUnit)
{
    int offset = 0;
    int ret;
    unsigned char* data = (unsigned char*) malloc(decodeUnit->fullLength);
    if (data == NULL) {
        // A frame was lost due to OOM condition
        return DR_NEED_IDR;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (!lastFrameNumber) {
        currentVideoStats.startTime = now;
        lastFrameNumber = decodeUnit->frameNumber;
    }
    else {
        // Flip stats roughly every second
        if (now - currentVideoStats.startTime >= 1.0f) {
            DrainCompletedRendererDecoderStats();
            currentVideoStats.endTime = now;
            
            [videoStatsLock lock];
            lastVideoStats = currentVideoStats;
            [videoStatsLock unlock];
            
            memset(&currentVideoStats, 0, sizeof(currentVideoStats));
            currentVideoStats.startTime = now;
        }
        
        // Any frame number greater than m_LastFrameNumber + 1 represents a dropped frame
        currentVideoStats.networkDroppedFrames += decodeUnit->frameNumber - (lastFrameNumber + 1);
        currentVideoStats.totalFrames += decodeUnit->frameNumber - (lastFrameNumber + 1);
        lastFrameNumber = decodeUnit->frameNumber;
    }
    
    if (decodeUnit->frameHostProcessingLatency != 0) {
        if (currentVideoStats.minHostProcessingLatency == 0 || decodeUnit->frameHostProcessingLatency < currentVideoStats.minHostProcessingLatency) {
            currentVideoStats.minHostProcessingLatency = decodeUnit->frameHostProcessingLatency;
        }
        
        if (decodeUnit->frameHostProcessingLatency > currentVideoStats.maxHostProcessingLatency) {
            currentVideoStats.maxHostProcessingLatency = decodeUnit->frameHostProcessingLatency;
        }
        
        currentVideoStats.framesWithHostProcessingLatency++;
        currentVideoStats.totalHostProcessingLatency += decodeUnit->frameHostProcessingLatency;
    }

    uint64_t nowMs = LiGetMillis();
    if (decodeUnit->enqueueTimeMs != 0 && nowMs >= decodeUnit->enqueueTimeMs) {
        uint64_t clientQueueLatency = nowMs - decodeUnit->enqueueTimeMs;

        if (currentVideoStats.minClientQueueLatency == 0 || clientQueueLatency < currentVideoStats.minClientQueueLatency) {
            currentVideoStats.minClientQueueLatency = clientQueueLatency;
        }

        if (clientQueueLatency > currentVideoStats.maxClientQueueLatency) {
            currentVideoStats.maxClientQueueLatency = clientQueueLatency;
        }

        currentVideoStats.framesWithClientQueueLatency++;
        currentVideoStats.totalClientQueueLatency += clientQueueLatency;
    }
    
    currentVideoStats.receivedFrames++;
    currentVideoStats.totalFrames++;
    currentVideoStats.totalVideoBytes += (uint64_t)decodeUnit->fullLength;

    PLENTRY entry = decodeUnit->bufferList;
    while (entry != NULL) {
        // Submit parameter set NALUs directly since no copy is required by the decoder
        if (entry->bufferType != BUFFER_TYPE_PICDATA) {
            ret = [renderer submitDecodeBuffer:(unsigned char*)entry->data
                                        length:entry->length
                                    bufferType:entry->bufferType
                                     decodeUnit:decodeUnit];
            if (ret != DR_OK) {
                free(data);
                return ret;
            }
        }
        else {
            memcpy(&data[offset], entry->data, entry->length);
            offset += entry->length;
        }

        entry = entry->next;
    }

    // This function will take our picture data buffer
    return [renderer submitDecodeBuffer:data
                                 length:offset
                             bufferType:BUFFER_TYPE_PICDATA
                              decodeUnit:decodeUnit];
}

int ArInit(int audioConfiguration, POPUS_MULTISTREAM_CONFIGURATION opusConfig, void* context, int flags)
{
    int err;
    SDL_AudioSpec want, have;
    
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0) {
        Log(LOG_E, @"Failed to initialize audio subsystem: %s\n", SDL_GetError());
        return -1;
    }
        
    SDL_zero(want);
    want.freq = opusConfig->sampleRate;
    want.format = AUDIO_S16;
    want.channels = opusConfig->channelCount;
    want.samples = MAX(opusConfig->samplesPerFrame, kPreferredSDLBufferSamples);

    audioDevice = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (audioDevice == 0) {
        Log(LOG_E, @"Failed to open audio device: %s\n", SDL_GetError());
        ArCleanup();
        return -1;
    }
    
    audioConfig = *opusConfig;
    audioFrameSize = opusConfig->samplesPerFrame * sizeof(short) * opusConfig->channelCount;
    audioBytesPerSampleFrame = sizeof(short) * opusConfig->channelCount;
    audioBuffer = SDL_malloc(audioFrameSize);
    if (audioBuffer == NULL) {
        Log(LOG_E, @"Failed to allocate audio frame buffer");
        ArCleanup();
        return -1;
    }

    audioSilenceBuffer = SDL_calloc(1, audioFrameSize);
    if (audioSilenceBuffer == NULL) {
        Log(LOG_E, @"Failed to allocate audio silence buffer");
        ArCleanup();
        return -1;
    }
    
    opusDecoder = opus_multistream_decoder_create(opusConfig->sampleRate,
                                                  opusConfig->channelCount,
                                                  opusConfig->streams,
                                                  opusConfig->coupledStreams,
                                                  opusConfig->mapping,
                                                  &err);
    if (opusDecoder == NULL) {
        Log(LOG_E, @"Failed to create Opus decoder");
        ArCleanup();
        return -1;
    }
    
    // Start playback
    SDL_PauseAudioDevice(audioDevice, 0);

    [audioStatsLock lock];
    memset(&currentAudioStats, 0, sizeof(currentAudioStats));
    memset(&lastAudioStats, 0, sizeof(lastAudioStats));
    [audioStatsLock unlock];
    
    // Disable lowering volume of other audio streams (SDL sets AVAudioSessionCategoryOptionDuckOthers by default)
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    return 0;
}

void ArCleanup(void)
{
    if ([_callbacks respondsToSelector:@selector(stopAudioHaptics)]) {
        [_callbacks stopAudioHaptics];
    }

    if (opusDecoder != NULL) {
        opus_multistream_decoder_destroy(opusDecoder);
        opusDecoder = NULL;
    }
    
    if (audioDevice != 0) {
        SDL_CloseAudioDevice(audioDevice);
        audioDevice = 0;
    }
    
    if (audioBuffer != NULL) {
        SDL_free(audioBuffer);
        audioBuffer = NULL;
    }

    if (audioSilenceBuffer != NULL) {
        SDL_free(audioSilenceBuffer);
        audioSilenceBuffer = NULL;
    }

    audioBytesPerSampleFrame = 0;
    
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

void ArDecodeAndPlaySample(char* sampleData, int sampleLength)
{
    int decodeLen;
    double pendingDurationMs = LiGetPendingAudioDuration();
    double queuedDurationMs = 0.0;
    Uint32 queuedBytes = audioDevice != 0 ? SDL_GetQueuedAudioSize(audioDevice) : 0;
    CFTimeInterval processStartTime = CACurrentMediaTime();

    if (audioDevice != 0 && audioBytesPerSampleFrame > 0 && audioConfig.sampleRate > 0) {
        double queuedFrames = (double)queuedBytes / (double)audioBytesPerSampleFrame;
        queuedDurationMs = (queuedFrames / (double)audioConfig.sampleRate) * 1000.0;
    }

    [audioStatsLock lock];
    RotateAudioStatsWindowIfNeeded(processStartTime);
    currentAudioStats.receivedPackets++;
    currentAudioStats.totalPendingDurationMs += pendingDurationMs;
    currentAudioStats.pendingSamples++;
    if (pendingDurationMs > currentAudioStats.maxPendingDurationMs) {
        currentAudioStats.maxPendingDurationMs = pendingDurationMs;
    }
    currentAudioStats.totalQueuedDurationMs += queuedDurationMs;
    currentAudioStats.queuedSamples++;
    if (queuedDurationMs > currentAudioStats.maxQueuedDurationMs) {
        currentAudioStats.maxQueuedDurationMs = queuedDurationMs;
    }
    [audioStatsLock unlock];
    
    // A small amount of extra audio headroom is preferable to aggressive
    // dropping on iOS, which tends to sound like periodic stutter.
    if (pendingDurationMs > kMaxPendingAudioDurationMs) {
        CFTimeInterval processEndTime = CACurrentMediaTime();
        [audioStatsLock lock];
        currentAudioStats.droppedPackets++;
        currentAudioStats.processedPackets++;
        currentAudioStats.totalProcessTimeMs += (processEndTime - processStartTime) * 1000.0;
        if ((processEndTime - processStartTime) * 1000.0 > currentAudioStats.maxProcessTimeMs) {
            currentAudioStats.maxProcessTimeMs = (processEndTime - processStartTime) * 1000.0;
        }
        [audioStatsLock unlock];
        return;
    }
    
    decodeLen = opus_multistream_decode(opusDecoder, (unsigned char *)sampleData, sampleLength,
                                        (short*)audioBuffer, audioConfig.samplesPerFrame, 0);
    if (decodeLen > 0) {
        if ([_callbacks respondsToSelector:@selector(processAudioHapticsSamples:frameCount:channelCount:sampleRate:)]) {
            [_callbacks processAudioHapticsSamples:(const short *)audioBuffer
                                        frameCount:decodeLen
                                      channelCount:audioConfig.channelCount
                                        sampleRate:audioConfig.sampleRate];
        }

        if (SDL_QueueAudio(audioDevice,
                           audioBuffer,
                           sizeof(short) * decodeLen * audioConfig.channelCount) < 0) {
            Log(LOG_E, @"Failed to queue audio sample: %s\n", SDL_GetError());
        }
    }
    else {
        [audioStatsLock lock];
        currentAudioStats.decodeErrors++;
        [audioStatsLock unlock];

        // Feed a short silence bridge on decode failure to reduce audible pop/static.
        QueueAudioSilenceFrames(audioConfig.samplesPerFrame / 2);
    }

    CFTimeInterval processEndTime = CACurrentMediaTime();
    double processTimeMs = (processEndTime - processStartTime) * 1000.0;
    [audioStatsLock lock];
    currentAudioStats.processedPackets++;
    currentAudioStats.totalProcessTimeMs += processTimeMs;
    if (processTimeMs > currentAudioStats.maxProcessTimeMs) {
        currentAudioStats.maxProcessTimeMs = processTimeMs;
    }
    [audioStatsLock unlock];
}

void ClStageStarting(int stage)
{
    [_callbacks stageStarting:LiGetStageName(stage)];
}

void ClStageComplete(int stage)
{
    [_callbacks stageComplete:LiGetStageName(stage)];
}

void ClStageFailed(int stage, int errorCode)
{
    [_callbacks stageFailed:LiGetStageName(stage) withError:errorCode portTestFlags:LiGetPortFlagsFromStage(stage)];
}

void ClConnectionStarted(void)
{
    [_callbacks connectionStarted];
}

void ClConnectionTerminated(int errorCode)
{
    [_callbacks connectionTerminated: errorCode];
}

void ClLogMessage(const char* format, ...)
{
    va_list va;
    va_start(va, format);
    vfprintf(stderr, format, va);
    va_end(va);
}

void ClRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor)
{
    [_callbacks rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
}

void ClConnectionStatusUpdate(int status)
{
    [_callbacks connectionStatusUpdate:status];
}

void ClSetHdrMode(bool enabled)
{
    [renderer setHdrMode:enabled];
    [_callbacks setHdrMode:enabled];
}

void ClRumbleTriggers(uint16_t controllerNumber, uint16_t leftTriggerMotor, uint16_t rightTriggerMotor)
{
    [_callbacks rumbleTriggers:controllerNumber leftTrigger:leftTriggerMotor rightTrigger:rightTriggerMotor];
}

void ClSetMotionEventState(uint16_t controllerNumber, uint8_t motionType, uint16_t reportRateHz)
{
    [_callbacks setMotionEventState:controllerNumber motionType:motionType reportRateHz:reportRateHz];
}

void ClSetControllerLED(uint16_t controllerNumber, uint8_t r, uint8_t g, uint8_t b)
{
    [_callbacks setControllerLed:controllerNumber r:r g:g b:b];
}

-(void) terminate
{
    // Interrupt any action blocking LiStartConnection(). This is
    // thread-safe and done outside initLock on purpose, since we
    // won't be able to acquire it if LiStartConnection is in
    // progress.
    LiInterruptConnection();
    
    // We dispatch this async to get out because this can be invoked
    // on a thread inside common and we don't want to deadlock. It also avoids
    // blocking on the caller's thread waiting to acquire initLock.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [initLock lock];
        LiStopConnection();
        if (renderer == self->_rendererTarget) {
            renderer = nil;
        }
        if (_callbacks == self->_callbackTarget) {
            _callbacks = nil;
        }
        [initLock unlock];
    });
}

-(id) initWithConfig:(StreamConfiguration*)config renderer:(id<VideoRendering>)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks
{
    self = [super init];

    // Use a lock to ensure that only one thread is initializing
    // or deinitializing a connection at a time.
    if (initLock == nil) {
        initLock = [[NSLock alloc] init];
    }
    
    if (videoStatsLock == nil) {
        videoStatsLock = [[NSLock alloc] init];
    }
    if (audioStatsLock == nil) {
        audioStatsLock = [[NSLock alloc] init];
    }
    
    NSString *rawAddress = [Utils addressPortStringToAddress:config.host];
    strncpy(_hostString,
            [rawAddress cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_hostString) - 1);
    strncpy(_appVersionString,
            [config.appVersion cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_appVersionString) - 1);
    if (config.gfeVersion != nil) {
        strncpy(_gfeVersionString,
                [config.gfeVersion cStringUsingEncoding:NSUTF8StringEncoding],
                sizeof(_gfeVersionString) - 1);
    }
    if (config.rtspSessionUrl != nil) {
        strncpy(_rtspSessionUrl,
                [config.rtspSessionUrl cStringUsingEncoding:NSUTF8StringEncoding],
                sizeof(_rtspSessionUrl) - 1);
    }

    LiInitializeServerInformation(&_serverInfo);
    _serverInfo.address = _hostString;
    _serverInfo.serverInfoAppVersion = _appVersionString;
    if (config.gfeVersion != nil) {
        _serverInfo.serverInfoGfeVersion = _gfeVersionString;
    }
    if (config.rtspSessionUrl != nil) {
        _serverInfo.rtspSessionUrl = _rtspSessionUrl;
    }
    _serverInfo.serverCodecModeSupport = config.serverCodecModeSupport;

    _rendererTarget = myRenderer;
    _callbackTarget = callbacks;
    renderer = myRenderer;
    _callbacks = callbacks;

    LiInitializeStreamConfiguration(&_streamConfig);
    _streamConfig.width = config.width;
    _streamConfig.height = config.height;
    _streamConfig.fps = config.frameRate;
    _streamConfig.bitrate = config.bitRate;
    _streamConfig.supportedVideoFormats = config.supportedVideoFormats;
    _streamConfig.audioConfiguration = config.audioConfiguration;
    
    // Since we require iOS 12 or above, we're guaranteed to be running
    // on a 64-bit device with ARMv8 crypto instructions, so we don't
    // need to check for that here.
    _streamConfig.encryptionFlags = ENCFLG_ALL;
    
    if ([Utils isActiveNetworkVPN]) {
        // Force remote streaming mode when a VPN is connected
        _streamConfig.streamingRemotely = STREAM_CFG_REMOTE;
        _streamConfig.packetSize = 1024;
    }
    else {
        // Detect remote streaming automatically based on the IP address of the target
        _streamConfig.streamingRemotely = STREAM_CFG_AUTO;
        _streamConfig.packetSize = 1392;
    }

    memcpy(_streamConfig.remoteInputAesKey, [config.riKey bytes], [config.riKey length]);
    memset(_streamConfig.remoteInputAesIv, 0, 16);
    int riKeyId = htonl(config.riKeyId);
    memcpy(_streamConfig.remoteInputAesIv, &riKeyId, sizeof(riKeyId));

    LiInitializeVideoCallbacks(&_drCallbacks);
    _drCallbacks.setup = DrDecoderSetup;
    _drCallbacks.start = DrStart;
    _drCallbacks.stop = DrStop;
    _drCallbacks.capabilities = CAPABILITY_PULL_RENDERER |
                                CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC |
                                CAPABILITY_REFERENCE_FRAME_INVALIDATION_AV1;

    LiInitializeAudioCallbacks(&_arCallbacks);
    _arCallbacks.init = ArInit;
    _arCallbacks.cleanup = ArCleanup;
    _arCallbacks.decodeAndPlaySample = ArDecodeAndPlaySample;
    _arCallbacks.capabilities = CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION;

    LiInitializeConnectionCallbacks(&_clCallbacks);
    _clCallbacks.stageStarting = ClStageStarting;
    _clCallbacks.stageComplete = ClStageComplete;
    _clCallbacks.stageFailed = ClStageFailed;
    _clCallbacks.connectionStarted = ClConnectionStarted;
    _clCallbacks.connectionTerminated = ClConnectionTerminated;
    _clCallbacks.logMessage = ClLogMessage;
    _clCallbacks.rumble = ClRumble;
    _clCallbacks.connectionStatusUpdate = ClConnectionStatusUpdate;
    _clCallbacks.setHdrMode = ClSetHdrMode;
    _clCallbacks.rumbleTriggers = ClRumbleTriggers;
    _clCallbacks.setMotionEventState = ClSetMotionEventState;
    _clCallbacks.setControllerLED = ClSetControllerLED;

    return self;
}

-(void) main
{
    [initLock lock];
    LiStartConnection(&_serverInfo,
                      &_streamConfig,
                      &_clCallbacks,
                      &_drCallbacks,
                      &_arCallbacks,
                      NULL, 0,
                      NULL, 0);
    [initLock unlock];
}

@end
