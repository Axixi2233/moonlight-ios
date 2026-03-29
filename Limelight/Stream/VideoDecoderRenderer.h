//
//  VideoDecoderRenderer.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/18/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

@import AVFoundation;

#import "ConnectionCallbacks.h"
#include "Limelight.h"

typedef NS_ENUM(NSInteger, StreamVideoRendererSelection) {
    StreamVideoRendererSelectionSystem = 0,
    StreamVideoRendererSelectionMetal = 1
};

@protocol VideoRendering <NSObject>

- (id)initWithView:(UIView*)view callbacks:(id<ConnectionCallbacks>)callbacks streamAspectRatio:(float)aspectRatio useFramePacing:(BOOL)useFramePacing;
- (void)setupWithVideoFormat:(int)videoFormat width:(int)videoWidth height:(int)videoHeight frameRate:(int)frameRate;
- (void)start;
- (void)stop;
- (void)setHdrMode:(BOOL)enabled;
- (int)submitDecodeBuffer:(unsigned char *)data length:(int)length bufferType:(int)bufferType decodeUnit:(PDECODE_UNIT)du;
@optional
- (BOOL)consumeCompletedDecoderLatencyTotal:(uint64_t *)total
                                     frames:(int *)frames
                                        min:(uint64_t *)min
                                        max:(uint64_t *)max;

@end

@interface VideoDecoderRenderer : NSObject <VideoRendering>

@end
