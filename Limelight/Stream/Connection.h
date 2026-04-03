//
//  Connection.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "VideoDecoderRenderer.h"
#import "StreamConfiguration.h"

#define CONN_TEST_SERVER "ios.conntest.moonlight-stream.org"

typedef struct {
    CFTimeInterval startTime;
    CFTimeInterval endTime;
    int totalFrames;
    int receivedFrames;
    int networkDroppedFrames;
    uint64_t totalVideoBytes;
    int totalHostProcessingLatency;
    int framesWithHostProcessingLatency;
    int maxHostProcessingLatency;
    int minHostProcessingLatency;
    uint64_t totalClientQueueLatency;
    int framesWithClientQueueLatency;
    uint64_t maxClientQueueLatency;
    uint64_t minClientQueueLatency;
    uint64_t totalDecoderLatency;
    int framesWithDecoderLatency;
    uint64_t maxDecoderLatency;
    uint64_t minDecoderLatency;
} video_stats_t;

typedef struct {
    CFTimeInterval startTime;
    CFTimeInterval endTime;
    int receivedPackets;
    int droppedPackets;
    int decodeErrors;
    double totalPendingDurationMs;
    int pendingSamples;
    double maxPendingDurationMs;
    double totalQueuedDurationMs;
    int queuedSamples;
    double maxQueuedDurationMs;
    double totalProcessTimeMs;
    int processedPackets;
    double maxProcessTimeMs;
} audio_stats_t;

@interface Connection : NSOperation <NSStreamDelegate>

-(id) initWithConfig:(StreamConfiguration*)config renderer:(id<VideoRendering>)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks;
-(void) terminate;
-(void) main;
-(BOOL) getVideoStats:(video_stats_t*)stats;
-(BOOL) getAudioStats:(audio_stats_t*)stats;
-(NSString*) getActiveCodecName;
-(NSString*) getActiveCodecNameLite;
-(CGFloat) getActiveMetalFxScale;
@end
