//
//  TemporarySettings.h
//  Moonlight
//
//  Created by Cameron Gutman on 12/1/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//

#import "Settings+CoreDataClass.h"

FOUNDATION_EXTERN NSString * const StreamPreferenceVideoAlignmentSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVideoAlignmentMarginKey;
FOUNDATION_EXTERN NSString * const StreamPreferencePerformanceOverlayPositionSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferencePerformanceOverlayMarginKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceFloatingMenuEnabledKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceTouchModeSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVirtualButtonSchemeSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVirtualGamepadSchemeSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVirtualGamepadOpacityKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVirtualButtonsEnabledKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceVirtualGamepadEnabledKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceCaptureMouseCursorKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceRumbleModeSelectionKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceRemoteMouseModeKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceRelativeMouseSensitivityKey;
FOUNDATION_EXTERN NSString * const StreamPreferenceRendererSelectionKey;

typedef NS_ENUM(NSInteger, StreamTouchModeSelection) {
    StreamTouchModeSelectionTrackpad = 0,
    StreamTouchModeSelectionMouse = 1,
    StreamTouchModeSelectionMultiTouch = 2,
    StreamTouchModeSelectionDisabled = 3
};

typedef NS_ENUM(NSInteger, StreamRumbleModeSelection) {
    StreamRumbleModeSelectionController = 0,
    StreamRumbleModeSelectionDevice = 1,
    StreamRumbleModeSelectionDisabled = 2
};

@interface TemporarySettings : NSObject

@property (nonatomic, retain) Settings * parent;

@property (nonatomic, retain) NSNumber * bitrate;
@property (nonatomic, retain) NSNumber * framerate;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSNumber * width;
@property (nonatomic, retain) NSNumber * audioConfig;
@property (nonatomic, retain) NSNumber * onscreenControls;
@property (nonatomic, retain) NSString * uniqueId;
@property (nonatomic) enum {
    CODEC_PREF_AUTO,
    CODEC_PREF_H264,
    CODEC_PREF_HEVC,
    CODEC_PREF_AV1,
} preferredCodec;
@property (nonatomic) BOOL useFramePacing;
@property (nonatomic) BOOL multiController;
@property (nonatomic) BOOL swapABXYButtons;
@property (nonatomic) BOOL playAudioOnPC;
@property (nonatomic) BOOL optimizeGames;
@property (nonatomic) BOOL enableHdr;
@property (nonatomic) BOOL btMouseSupport;
@property (nonatomic) BOOL remoteMouseMode;
@property (nonatomic) BOOL captureMouseCursor;
@property (nonatomic) BOOL absoluteTouchMode;
@property (nonatomic) BOOL statsOverlay;
@property (nonatomic) BOOL rumblePhone;
@property (nonatomic) NSInteger rumbleModeSelection;
@property (nonatomic, retain) NSNumber * motionMode;
@property (nonatomic, retain) NSNumber * virtualDisplayMode;
@property (nonatomic) BOOL multiTouchScreen;
@property (nonatomic) BOOL externalMonitor;
@property (nonatomic) BOOL enableTouchSensitivity;
@property (nonatomic) BOOL touchSensitivityGlobal;
@property (nonatomic, retain) NSNumber * touchSensitivity;
@property (nonatomic) NSInteger touchModeSelection;
@property (nonatomic) NSInteger videoAlignmentSelection;
@property (nonatomic) CGFloat videoAlignmentMargin;
@property (nonatomic) NSInteger performanceOverlayPositionSelection;
@property (nonatomic) CGFloat performanceOverlayMargin;
@property (nonatomic) BOOL floatingMenuEnabled;
@property (nonatomic) BOOL virtualButtonsEnabled;
@property (nonatomic) BOOL virtualGamepadEnabled;
@property (nonatomic) NSInteger virtualButtonSchemeSelection;
@property (nonatomic) NSInteger virtualGamepadSchemeSelection;
@property (nonatomic) CGFloat virtualGamepadOpacity;
@property (nonatomic) NSInteger relativeMouseSensitivity;
@property (nonatomic) NSInteger rendererSelection;

- (id) initFromSettings:(Settings*)settings;
- (BOOL)usesAbsoluteTouchMode;
- (BOOL)usesMultiTouchScreen;
- (BOOL)disablesDirectScreenTouchInput;
- (BOOL)usesControllerRumble;
- (BOOL)usesDeviceRumble;

@end
