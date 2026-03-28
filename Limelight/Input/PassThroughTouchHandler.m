//
//  PassThroughTouchHandler.m
//  Moonlight
//
//  Created by OpenAI Codex.
//

#import "PassThroughTouchHandler.h"
#import "DataManager.h"
#import "TouchScreenManager.h"
#import "SensitivityBean.h"

#include <float.h>
#include <Limelight.h>

@implementation PassThroughTouchHandler {
    StreamView *view;
    TemporarySettings *settings;
    TouchScreenManager *touchManager;
    NSMutableDictionary<NSNumber *, SensitivityBean *> *sensitivityMap;
}

- (id)initWithView:(StreamView *)view {
    return [self initWithView:view settings:[[[DataManager alloc] init] getSettings]];
}

- (id)initWithView:(StreamView *)view settings:(TemporarySettings *)settings {
    self = [self init];
    if (self != nil) {
        self->view = view;
        self->settings = settings ?: [[[DataManager alloc] init] getSettings];
        self->touchManager = [[TouchScreenManager alloc] init];
        self->sensitivityMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    (void)event;
    [self sendTouchEventsForTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    (void)event;
    [self sendTouchEventsForTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    (void)event;
    [self sendTouchEventsForTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    (void)event;
    [self sendTouchEventsForTouches:touches];
}

- (void)sendTouchEventsForTouches:(NSSet<UITouch *> *)touches {
    for (UITouch *touch in touches) {
        [self sendTouchEventForTouch:touch];
    }
}

- (void)sendTouchEventForTouch:(UITouch *)touch {
    uint8_t type;
    uint32_t touchID = [touchManager identifierForTouch:touch];

    switch (touch.phase) {
        case UITouchPhaseBegan:
            type = LI_TOUCH_EVENT_DOWN;
            break;
        case UITouchPhaseMoved:
            type = LI_TOUCH_EVENT_MOVE;
            break;
        case UITouchPhaseEnded:
            type = LI_TOUCH_EVENT_UP;
            break;
        case UITouchPhaseCancelled:
            type = LI_TOUCH_EVENT_CANCEL;
            break;
        default:
            return;
    }

    CGPoint location = [self resolvedLocationForTouch:touch touchID:touchID];
    CGSize videoSize = [view getVideoAreaSize];
    CGFloat altitudeSine = sin(touch.altitudeAngle);
    CGFloat pressure = 0.0f;
    if (touch.maximumPossibleForce > 0.0f && fabs(altitudeSine) > FLT_EPSILON) {
        pressure = (touch.force / touch.maximumPossibleForce) / altitudeSine;
    }

    LiSendTouchEvent(type,
                     touchID,
                     location.x / videoSize.width,
                     location.y / videoSize.height,
                     pressure,
                     0.0f,
                     0.0f,
                     [view getRotationFromAzimuthAngle:[touch azimuthAngleInView:view]]);

    if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
        [touchManager removeTouch:touch];
        [sensitivityMap removeObjectForKey:@(touchID)];
    }
}

- (CGPoint)resolvedLocationForTouch:(UITouch *)touch touchID:(uint32_t)touchID {
    CGPoint location = [view adjustCoordinatesForVideoArea:[touch locationInView:view]];

    if (!settings.enableTouchSensitivity || settings.touchSensitivity.floatValue == 100.0f) {
        return location;
    }

    CGFloat normalizedX = location.x;
    CGFloat normalizedY = location.y;
    if (!settings.touchSensitivityGlobal && normalizedX < [UIScreen mainScreen].bounds.size.width / 2.0f) {
        return location;
    }

    NSNumber *key = @(touchID);
    if (touch.phase == UITouchPhaseMoved) {
        SensitivityBean *bean = [sensitivityMap objectForKey:key];
        if (bean == nil) {
            bean = [[SensitivityBean alloc] init];
        }

        if (bean.lastAbsoluteX != -1) {
            CGFloat dx = normalizedX - bean.lastAbsoluteX;
            CGFloat dy = normalizedY - bean.lastAbsoluteY;
            CGFloat sensitivityMultiplier = 0.01f * settings.touchSensitivity.floatValue;
            dx *= sensitivityMultiplier;
            dy *= sensitivityMultiplier;
            normalizedX = bean.lastRelativelyX + dx;
            normalizedY = bean.lastRelativelyY + dy;
        }

        bean.lastAbsoluteX = location.x;
        bean.lastAbsoluteY = location.y;
        bean.lastRelativelyX = normalizedX;
        bean.lastRelativelyY = normalizedY;
        [sensitivityMap setObject:bean forKey:key];
    }

    location.x = normalizedX;
    location.y = normalizedY;
    return location;
}

@end
