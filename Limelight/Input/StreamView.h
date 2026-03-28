//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "ControllerSupport.h"
#import "Moonlight-Swift.h"
#import "StreamConfiguration.h"
#import "TouchScreenManager.h"
#import "SensitivityBean.h"

extern NSString * const StreamViewBoundsDidChangeNotification;
extern NSString * const StreamViewVirtualButtonsDidChangeNotification;
extern NSString * const StreamViewVirtualButtonSelectionDidChangeNotification;
extern NSString * const StreamViewVirtualGamepadDidChangeNotification;
extern NSString * const StreamViewVirtualGamepadSelectionDidChangeNotification;

typedef NS_ENUM(NSInteger, StreamViewVideoAlignmentMode) {
    StreamViewVideoAlignmentModeCenter = 0,
    StreamViewVideoAlignmentModeTop = 1,
    StreamViewVideoAlignmentModeBottom = 2
};

@protocol UserInteractionDelegate <NSObject>

- (void) userInteractionBegan;
- (void) userInteractionEnded;

@end

#if TARGET_OS_TV
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate>
#else
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate, UIPointerInteractionDelegate>
#endif

- (void) setupStreamView:(ControllerSupport*)controllerSupport
     interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                  config:(StreamConfiguration*)streamConfig;
- (void) setTemporaryVirtualGamepadVisible:(BOOL)visible;
- (BOOL) isTemporaryVirtualGamepadVisible;
- (void) setTemporaryVirtualGamepadDescriptors:(NSArray<NSDictionary<NSString *, id> *> *)descriptors;
- (NSArray<NSDictionary<NSString *, id> *> *)currentTemporaryVirtualGamepadDescriptors;
- (void) setTemporaryVirtualGamepadEditingEnabled:(BOOL)enabled;
- (BOOL) isTemporaryVirtualGamepadEditingEnabled;
- (void) setTemporaryVirtualButtonDescriptors:(NSArray<NSDictionary<NSString *, id> *> *)descriptors;
- (NSArray<NSDictionary<NSString *, id> *> *)currentTemporaryVirtualButtonDescriptors;
- (void) setTemporaryVirtualButtonsVisible:(BOOL)visible;
- (BOOL) isTemporaryVirtualButtonsVisible;
- (void) setTemporaryVirtualButtonsEditingEnabled:(BOOL)enabled;
- (BOOL) isTemporaryVirtualButtonsEditingEnabled;
- (void) setVideoAlignmentMode:(StreamViewVideoAlignmentMode)alignmentMode;
- (StreamViewVideoAlignmentMode) videoAlignmentMode;
- (void) setVideoAlignmentMargin:(CGFloat)alignmentMargin;
- (CGFloat) videoAlignmentMargin;
- (void) setViewOnlyModeEnabled:(BOOL)enabled;
- (BOOL) isViewOnlyModeEnabled;
- (void) showKeyInputBoard;
- (void) sendShortcutPrimaryKeyCodes:(NSArray<NSNumber *> *)primaryKeyCodes
                   secondaryKeyCodes:(NSArray<NSNumber *> *)secondaryKeyCodes;
- (void) applyTemporaryTouchModeSelection:(NSInteger)selection;
- (void) resetAfterTemporaryTouchModeChange;

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse;
- (CGSize) getVideoAreaSize;
- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point;
- (uint16_t) getRotationFromAzimuthAngle:(float)azimuthAngle;
#endif

@end
