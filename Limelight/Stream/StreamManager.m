//
//  StreamManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "StreamManager.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Utils.h"
#import "DataManager.h"

#import "StreamView.h"
#import "MetalVideoRenderer.h"
#import "ServerInfoResponse.h"
#import "HttpResponse.h"
#import "HttpRequest.h"
#import "IdManager.h"

#include <Limelight.h>

#define StreamManagerLocalized(key) NSLocalizedString((key), nil)

static NSString *MetalFxOverlayStringForSettings(TemporarySettings *settings, CGFloat activeScale)
{
    if (settings.rendererSelection != StreamVideoRendererSelectionMetal) {
        return @"";
    }

    if (settings.metalFxScalingSelection == StreamMetalFxScalingSelectionDisabled) {
        return StreamManagerLocalized(@"stream.stats.metal");
    }

    if (activeScale > 1.0f) {
        return [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.mfx"), activeScale];
    }

    switch ((StreamMetalFxScalingSelection)settings.metalFxScalingSelection) {
        case StreamMetalFxScalingSelectionOnePointFiveX:
            return [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.mfx"), 1.5f];
        case StreamMetalFxScalingSelectionTwoX:
            return [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.mfx"), 2.0f];
        case StreamMetalFxScalingSelectionAutomatic:
            return StreamManagerLocalized(@"stream.stats.mfx_auto");
        case StreamMetalFxScalingSelectionDisabled:
        default:
            return @"";
    }
}

@implementation StreamManager {
    StreamConfiguration* _config;

    UIView* _renderView;
    id<ConnectionCallbacks> _callbacks;
    Connection* _connection;
    id<VideoRendering> _renderer;
}

- (NSString *)getBandwidthOverlayText
{
    video_stats_t stats;

    if (!_connection) {
        return @"";
    }

    if (![_connection getVideoStats:&stats]) {
        return @"";
    }

    double interval = stats.endTime - stats.startTime;
    if (interval <= 0.0) {
        interval = 1.0;
    }

    double kbPerSecond = ((double)stats.totalVideoBytes / 1024.0) / interval;
    if (kbPerSecond > 1000.0) {
        double mbPerSecond = kbPerSecond / 1024.0;
        return [NSString stringWithFormat:StreamManagerLocalized(@"stream.bandwidth.mb"), mbPerSecond];
    }

    return [NSString stringWithFormat:StreamManagerLocalized(@"stream.bandwidth.kb"), kbPerSecond];
}

- (id<VideoRendering>)makeRendererForCurrentSettings
{
    TemporarySettings *settings = [[[DataManager alloc] init] getSettings];
    StreamVideoRendererSelection selection = (StreamVideoRendererSelection)settings.rendererSelection;
    float aspectRatio = (float)self->_config.width / (float)self->_config.height;

    switch (selection) {
        case StreamVideoRendererSelectionMetal:
            return [[MetalVideoRenderer alloc] initWithView:self->_renderView
                                                  callbacks:self->_callbacks
                                          streamAspectRatio:aspectRatio
                                             useFramePacing:self->_config.useFramePacing];
        case StreamVideoRendererSelectionSystem:
        default:
            return [[VideoDecoderRenderer alloc] initWithView:self->_renderView
                                                    callbacks:self->_callbacks
                                            streamAspectRatio:aspectRatio
                                               useFramePacing:self->_config.useFramePacing];
    }
}

- (id<VideoRendering>)currentRenderer
{
    return _renderer;
}

- (id) initWithConfig:(StreamConfiguration*)config renderView:(UIView*)view connectionCallbacks:(id<ConnectionCallbacks>)callbacks {
    self = [super init];
    _config = config;
    _renderView = view;
    _callbacks = callbacks;
    _config.riKey = [Utils randomBytes:16];
    _config.riKeyId = arc4random();
    return self;
}

- (void)main {
    [CryptoManager generateKeyPairUsingSSL];
    
    HttpManager* hMan = [[HttpManager alloc] initWithAddress:_config.host httpsPort:_config.httpsPort
                                                     serverCert:_config.serverCert];
    
    ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                       fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
    NSString* pairStatus = [serverInfoResp getStringTag:@"PairStatus"];
    NSString* appversion = [serverInfoResp getStringTag:@"appversion"];
    NSString* gfeVersion = [serverInfoResp getStringTag:@"GfeVersion"];
    NSString* serverState = [serverInfoResp getStringTag:@"state"];
    if (![serverInfoResp isStatusOk]) {
        [_callbacks launchFailed:serverInfoResp.statusMessage];
        return;
    }
    else if (pairStatus == NULL || appversion == NULL || serverState == NULL) {
        [_callbacks launchFailed:StreamManagerLocalized(@"stream.launch.failed_connect_pc")];
        return;
    }
    
    if (![pairStatus isEqualToString:@"1"]) {
        // Not paired
        [_callbacks launchFailed:StreamManagerLocalized(@"stream.launch.not_paired")];
        return;
    }
    
    // Only perform this check on GFE (as indicated by MJOLNIR in state value)
    if ((_config.width > 4096 || _config.height > 4096) && [serverState containsString:@"MJOLNIR"]) {
        // Pascal added support for 8K HEVC encoding support. Maxwell 2 could encode HEVC but only up to 4K.
        // We can't directly identify Pascal, but we can look for HEVC Main10 which was added in the same generation.
        NSString* codecSupport = [serverInfoResp getStringTag:@"ServerCodecModeSupport"];
        if (codecSupport == nil || !([codecSupport intValue] & 0x200)) {
            [_callbacks launchFailed:StreamManagerLocalized(@"stream.launch.gpu_no_4k")];
            return;
        }
    }
    
    // Populate the config's version fields from serverinfo
    _config.appVersion = appversion;
    _config.gfeVersion = gfeVersion;
    
    // resumeApp and launchApp handle calling launchFailed
    NSString* sessionUrl;
    if ([serverState hasSuffix:@"_SERVER_BUSY"]) {
        // App already running, resume it
        if (![self resumeApp:hMan receiveSessionUrl:&sessionUrl]) {
            return;
        }
    } else {
        // Start app
        if (![self launchApp:hMan receiveSessionUrl:&sessionUrl]) {
            return;
        }
    }
    
    // Populate RTSP session URL from launch/resume response
    _config.rtspSessionUrl = sessionUrl;
    
    // Initializing the renderer must be done on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_renderer = [self makeRendererForCurrentSettings];
        self->_connection = [[Connection alloc] initWithConfig:self->_config renderer:self->_renderer connectionCallbacks:self->_callbacks];
        NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
        [opQueue addOperation:self->_connection];
    });
}

- (void) stopStream
{
    [_connection terminate];
    _connection = nil;
    _renderer = nil;
}

- (BOOL) launchApp:(HttpManager*)hMan receiveSessionUrl:(NSString**)sessionUrl {
    HttpResponse* launchResp = [[HttpResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:launchResp withUrlRequest:[hMan newLaunchOrResumeRequest:@"launch" config:_config]]];
    NSString *gameSession = [launchResp getStringTag:@"gamesession"];
    if (![launchResp isStatusOk]) {
        [_callbacks launchFailed:launchResp.statusMessage];
        Log(LOG_E, @"Failed Launch Response: %@", launchResp.statusMessage);
        return FALSE;
    } else if (gameSession == NULL || [gameSession isEqualToString:@"0"]) {
        [_callbacks launchFailed:StreamManagerLocalized(@"stream.launch.failed_launch_app")];
        Log(LOG_E, @"Failed to parse game session");
        return FALSE;
    }
    
    *sessionUrl = [launchResp getStringTag:@"sessionUrl0"];
    return TRUE;
}

- (BOOL) resumeApp:(HttpManager*)hMan receiveSessionUrl:(NSString**)sessionUrl {
    HttpResponse* resumeResp = [[HttpResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:resumeResp withUrlRequest:[hMan newLaunchOrResumeRequest:@"resume" config:_config]]];
    NSString* resume = [resumeResp getStringTag:@"resume"];
    if (![resumeResp isStatusOk]) {
        [_callbacks launchFailed:resumeResp.statusMessage];
        Log(LOG_E, @"Failed Resume Response: %@", resumeResp.statusMessage);
        return FALSE;
    } else if (resume == NULL || [resume isEqualToString:@"0"]) {
        [_callbacks launchFailed:StreamManagerLocalized(@"stream.launch.failed_resume_app")];
        Log(LOG_E, @"Failed to parse resume response");
        return FALSE;
    }
    
    *sessionUrl = [resumeResp getStringTag:@"sessionUrl0"];
    return TRUE;
}

- (NSString*) getStatsOverlayText {
    return [self getStatsOverlayTextWithExtendedMetrics:NO];
}

- (NSString*) getStatsOverlayTextWithExtendedMetrics:(BOOL)showsExtendedMetrics {
    video_stats_t stats;
    
    if (!_connection) {
        return @"";
    }
    
    if (![_connection getVideoStats:&stats]) {
        return @"";
    }


    TemporarySettings *settings = [[[DataManager alloc] init] getSettings];
    BOOL shouldShowDecoderLatency = settings.rendererSelection == StreamVideoRendererSelectionMetal;
    
    uint32_t rtt, variance;
    NSString* latencyStringLite;
    NSString* jitterStringLite;
    if (LiGetEstimatedRttInfo(&rtt, &variance)) {
        latencyStringLite= [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.latency"), rtt];
        jitterStringLite = showsExtendedMetrics ? [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.jitter"), variance] : @"";
    }
    else {
        latencyStringLite= @"";
        jitterStringLite = @"";
    }

    CGFloat metalFxScale = [_connection getActiveMetalFxScale];
    NSString *metalFxStringLite = MetalFxOverlayStringForSettings(settings, metalFxScale);
    
    NSString* hostProcessingStringLite;
    if (showsExtendedMetrics && stats.framesWithHostProcessingLatency != 0) {
        hostProcessingStringLite = [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.encoding"),
                                    (float)stats.totalHostProcessingLatency / stats.framesWithHostProcessingLatency / 10.f];
    }
    else {
        hostProcessingStringLite = @"";
    }

    NSString* clientLatencyStringLite;
    if (showsExtendedMetrics && stats.framesWithClientQueueLatency != 0) {
        clientLatencyStringLite = [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.client"),
                                   (double)stats.totalClientQueueLatency / (double)stats.framesWithClientQueueLatency];
    }
    else {
        clientLatencyStringLite = @"";
    }

    NSString* decoderLatencyStringLite;
    if (shouldShowDecoderLatency && stats.framesWithDecoderLatency != 0) {
        decoderLatencyStringLite = [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.decode"),
                                    (double)stats.totalDecoderLatency / (double)stats.framesWithDecoderLatency];
    }
    else {
        decoderLatencyStringLite = @"";
    }

    double interval = stats.endTime - stats.startTime;
    double safeInterval = interval > 0.0 ? interval : 1.0;
    double droppedFramesPerSecond = (double)stats.networkDroppedFrames / safeInterval;
    double fps = (double)stats.totalFrames / safeInterval;

    NSString* droppedFramesStringLite;
    if (showsExtendedMetrics) {
        droppedFramesStringLite = [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.dropped"),
                                   droppedFramesPerSecond];
    }
    else {
        droppedFramesStringLite = @"";
    }

    return [NSString stringWithFormat:StreamManagerLocalized(@"stream.stats.overlay"),
            _config.width,
            _config.height,
            [_connection getActiveCodecNameLite],
            metalFxStringLite,
            latencyStringLite,
            decoderLatencyStringLite,
            hostProcessingStringLite,
            clientLatencyStringLite,
            jitterStringLite,
            droppedFramesStringLite,
            fps];
    
//    return [NSString stringWithFormat:@"Video stream: %dx%d %.2f FPS (Codec: %@)\nFrames dropped by your network connection: %.2f%%\nAverage network latency: %@%@",
//            _config.width,
//            _config.height,
//            stats.totalFrames / interval,
//            [_connection getActiveCodecName],
//            stats.networkDroppedFrames / interval,
//            latencyString,
//            hostProcessingString];
    
}

@end
