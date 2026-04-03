//
//  TemporarySettings.m
//  Moonlight
//
//  Created by Cameron Gutman on 12/1/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//

#import "TemporarySettings.h"

NSString * const StreamPreferenceVideoAlignmentSelectionKey = @"StreamPreferenceVideoAlignmentSelection";
NSString * const StreamPreferenceVideoAlignmentMarginKey = @"StreamPreferenceVideoAlignmentMargin";
NSString * const StreamPreferencePerformanceOverlayPositionSelectionKey = @"StreamPreferencePerformanceOverlayPositionSelection";
NSString * const StreamPreferencePerformanceOverlayMarginKey = @"StreamPreferencePerformanceOverlayMargin";
NSString * const StreamPreferenceFloatingMenuEnabledKey = @"StreamPreferenceFloatingMenuEnabled";
NSString * const StreamPreferenceTouchModeSelectionKey = @"StreamPreferenceTouchModeSelection";
NSString * const StreamPreferenceVirtualButtonSchemeSelectionKey = @"StreamPreferenceVirtualButtonSchemeSelection";
NSString * const StreamPreferenceVirtualGamepadSchemeSelectionKey = @"StreamPreferenceVirtualGamepadSchemeSelection";
NSString * const StreamPreferenceVirtualGamepadOpacityKey = @"StreamPreferenceVirtualGamepadOpacity";
NSString * const StreamPreferenceVirtualButtonsEnabledKey = @"StreamPreferenceVirtualButtonsEnabled";
NSString * const StreamPreferenceVirtualGamepadEnabledKey = @"StreamPreferenceVirtualGamepadEnabled";
NSString * const StreamPreferenceCaptureMouseCursorKey = @"StreamPreferenceCaptureMouseCursor";
NSString * const StreamPreferenceRumbleModeSelectionKey = @"StreamPreferenceRumbleModeSelection";
NSString * const StreamPreferenceRemoteMouseModeKey = @"StreamPreferenceRemoteMouseMode";
NSString * const StreamPreferenceRelativeMouseSensitivityKey = @"StreamPreferenceRelativeMouseSensitivity";
NSString * const StreamPreferenceRendererSelectionKey = @"StreamPreferenceRendererSelection";
NSString * const StreamPreferenceMetalFxScalingSelectionKey = @"StreamPreferenceMetalFxScalingSelection";
NSString * const StreamPreferenceMetalFxSharpenSelectionKey = @"StreamPreferenceMetalFxSharpenSelection";
NSString * const StreamPreferenceMetalFxColorModeSelectionKey = @"StreamPreferenceMetalFxColorModeSelection";
NSString * const StreamPreferencePictureInPictureEnabledKey = @"StreamPreferencePictureInPictureEnabled";
NSString * const StreamPreferenceStreamOrientationSelectionKey = @"StreamPreferenceStreamOrientationSelection";
NSString * const StreamPreferenceGameMenuShortcutSelectionKey = @"StreamPreferenceGameMenuShortcutSelection";
NSString * const StreamPreferenceLongPressStartForGameMenuEnabledKey = @"StreamPreferenceLongPressStartForGameMenuEnabled";
NSString * const StreamPreferenceAudioHapticsEnabledKey = @"StreamPreferenceAudioHapticsEnabled";
NSString * const StreamPreferenceAudioHapticsOutputTargetKey = @"StreamPreferenceAudioHapticsOutputTarget";
NSString * const StreamPreferenceAudioHapticsStrengthKey = @"StreamPreferenceAudioHapticsStrength";
NSString * const StreamPreferenceAudioHapticsVoiceFilterSelectionKey = @"StreamPreferenceAudioHapticsVoiceFilterSelection";
NSString * const StreamPreferenceAudioHapticsKeepControllerRumbleKey = @"StreamPreferenceAudioHapticsKeepControllerRumble";

@implementation TemporarySettings

@synthesize touchModeSelection = _touchModeSelection;
@synthesize rumbleModeSelection = _rumbleModeSelection;

- (StreamTouchModeSelection)normalizedTouchModeSelection:(NSInteger)touchModeSelection {
    switch (touchModeSelection) {
        case StreamTouchModeSelectionMouse:
        case StreamTouchModeSelectionMultiTouch:
        case StreamTouchModeSelectionDisabled:
            return (StreamTouchModeSelection)touchModeSelection;
        default:
            return StreamTouchModeSelectionTrackpad;
    }
}

- (void)setTouchModeSelection:(NSInteger)touchModeSelection {
    StreamTouchModeSelection normalizedSelection = [self normalizedTouchModeSelection:touchModeSelection];
    _touchModeSelection = normalizedSelection;
    self.absoluteTouchMode = (normalizedSelection == StreamTouchModeSelectionMouse ||
                              normalizedSelection == StreamTouchModeSelectionMultiTouch);
    self.multiTouchScreen = (normalizedSelection == StreamTouchModeSelectionMultiTouch);
}

- (StreamRumbleModeSelection)normalizedRumbleModeSelection:(NSInteger)rumbleModeSelection {
    switch (rumbleModeSelection) {
        case StreamRumbleModeSelectionDevice:
        case StreamRumbleModeSelectionDisabled:
            return (StreamRumbleModeSelection)rumbleModeSelection;
        default:
            return StreamRumbleModeSelectionController;
    }
}

- (void)setRumbleModeSelection:(NSInteger)rumbleModeSelection {
    StreamRumbleModeSelection normalizedSelection = [self normalizedRumbleModeSelection:rumbleModeSelection];
    _rumbleModeSelection = normalizedSelection;
    self.rumblePhone = (normalizedSelection == StreamRumbleModeSelectionDevice);
}

- (BOOL)usesAbsoluteTouchMode {
    return self.touchModeSelection == StreamTouchModeSelectionMouse ||
           self.touchModeSelection == StreamTouchModeSelectionMultiTouch;
}

- (BOOL)usesMultiTouchScreen {
    return self.touchModeSelection == StreamTouchModeSelectionMultiTouch;
}

- (BOOL)disablesDirectScreenTouchInput {
    return self.touchModeSelection == StreamTouchModeSelectionDisabled;
}

- (BOOL)usesControllerRumble {
    return self.rumbleModeSelection == StreamRumbleModeSelectionController;
}

- (BOOL)usesDeviceRumble {
    return self.rumbleModeSelection == StreamRumbleModeSelectionDevice;
}

- (NSInteger)normalizedRelativeMouseSensitivity:(NSInteger)relativeMouseSensitivity {
    return MAX(50, MIN(relativeMouseSensitivity, 300));
}

- (NSInteger)normalizedRendererSelection:(NSInteger)rendererSelection {
    switch (rendererSelection) {
        case 1:
            return 1;
        case 0:
        default:
            return 0;
    }
}

- (NSInteger)normalizedMetalFxScalingSelection:(NSInteger)metalFxScalingSelection {
    switch (metalFxScalingSelection) {
        case StreamMetalFxScalingSelectionOnePointFiveX:
        case StreamMetalFxScalingSelectionTwoX:
        case StreamMetalFxScalingSelectionDisabled:
            return metalFxScalingSelection;
        case StreamMetalFxScalingSelectionAutomatic:
        default:
            return StreamMetalFxScalingSelectionAutomatic;
    }
}

- (NSInteger)normalizedMetalFxSharpenSelection:(NSInteger)metalFxSharpenSelection {
    switch (metalFxSharpenSelection) {
        case StreamMetalFxSharpenSelectionDisabled:
        case StreamMetalFxSharpenSelectionStrong:
            return metalFxSharpenSelection;
        case StreamMetalFxSharpenSelectionStandard:
        default:
            return StreamMetalFxSharpenSelectionStandard;
    }
}

- (NSInteger)normalizedMetalFxColorModeSelection:(NSInteger)metalFxColorModeSelection {
    switch (metalFxColorModeSelection) {
        case StreamMetalFxColorModeSelectionLinear:
        case StreamMetalFxColorModeSelectionHdr:
            return metalFxColorModeSelection;
        case StreamMetalFxColorModeSelectionPerceptual:
        default:
            return StreamMetalFxColorModeSelectionPerceptual;
    }
}

- (NSInteger)normalizedStreamOrientationSelection:(NSInteger)streamOrientationSelection {
    switch (streamOrientationSelection) {
        case StreamOrientationSelectionLandscape:
        case StreamOrientationSelectionPortrait:
            return streamOrientationSelection;
        case StreamOrientationSelectionAutomatic:
        default:
            return StreamOrientationSelectionAutomatic;
    }
}

- (NSInteger)normalizedGameMenuShortcutSelection:(NSInteger)gameMenuShortcutSelection {
    switch (gameMenuShortcutSelection) {
        case StreamGameMenuShortcutSelectionEscape:
        case StreamGameMenuShortcutSelectionCtrlAltShiftQ:
            return gameMenuShortcutSelection;
        case StreamGameMenuShortcutSelectionNone:
        default:
            return StreamGameMenuShortcutSelectionNone;
    }
}

- (NSInteger)normalizedAudioHapticsOutputTarget:(NSInteger)audioHapticsOutputTarget {
    switch (audioHapticsOutputTarget) {
        case StreamAudioHapticsOutputTargetController:
            return audioHapticsOutputTarget;
        case StreamAudioHapticsOutputTargetDevice:
        default:
            return StreamAudioHapticsOutputTargetDevice;
    }
}

- (NSInteger)normalizedAudioHapticsStrength:(NSInteger)audioHapticsStrength {
    return MAX(25, MIN(audioHapticsStrength, 200));
}

- (NSInteger)normalizedAudioHapticsVoiceFilterSelection:(NSInteger)audioHapticsVoiceFilterSelection {
    switch (audioHapticsVoiceFilterSelection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
        case StreamAudioHapticsVoiceFilterSelectionMedium:
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return audioHapticsVoiceFilterSelection;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return StreamAudioHapticsVoiceFilterSelectionOff;
    }
}

- (id) initFromSettings:(Settings*)settings {
    self = [self init];
    
    self.parent = settings;

    NSDictionary *streamPreferenceDefaults = @{
        StreamPreferenceVideoAlignmentSelectionKey: @(0),
        StreamPreferenceVideoAlignmentMarginKey: @(0.0),
        StreamPreferencePerformanceOverlayPositionSelectionKey: @(0),
        StreamPreferencePerformanceOverlayMarginKey: @(6.0),
        StreamPreferenceFloatingMenuEnabledKey: @(YES),
        StreamPreferenceTouchModeSelectionKey: @(StreamTouchModeSelectionTrackpad),
        StreamPreferenceVirtualButtonsEnabledKey: @(NO),
        StreamPreferenceVirtualGamepadEnabledKey: @(NO),
        StreamPreferenceVirtualButtonSchemeSelectionKey: @(0),
        StreamPreferenceVirtualGamepadSchemeSelectionKey: @(0),
        StreamPreferenceVirtualGamepadOpacityKey: @(0.52),
        StreamPreferenceCaptureMouseCursorKey: @(YES),
        StreamPreferenceRumbleModeSelectionKey: @(StreamRumbleModeSelectionController),
        StreamPreferenceRemoteMouseModeKey: @(NO),
        StreamPreferenceRelativeMouseSensitivityKey: @(100),
        StreamPreferenceRendererSelectionKey: @(0),
        StreamPreferenceMetalFxScalingSelectionKey: @(StreamMetalFxScalingSelectionAutomatic),
        StreamPreferenceMetalFxSharpenSelectionKey: @(StreamMetalFxSharpenSelectionStandard),
        StreamPreferenceMetalFxColorModeSelectionKey: @(StreamMetalFxColorModeSelectionPerceptual),
        StreamPreferencePictureInPictureEnabledKey: @(NO),
        StreamPreferenceStreamOrientationSelectionKey: @(StreamOrientationSelectionAutomatic),
        StreamPreferenceGameMenuShortcutSelectionKey: @(StreamGameMenuShortcutSelectionNone),
        StreamPreferenceLongPressStartForGameMenuEnabledKey: @(NO),
        StreamPreferenceAudioHapticsEnabledKey: @(NO),
        StreamPreferenceAudioHapticsOutputTargetKey: @(StreamAudioHapticsOutputTargetDevice),
        StreamPreferenceAudioHapticsStrengthKey: @(100),
        StreamPreferenceAudioHapticsVoiceFilterSelectionKey: @(StreamAudioHapticsVoiceFilterSelectionOff),
        StreamPreferenceAudioHapticsKeepControllerRumbleKey: @(NO)
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:streamPreferenceDefaults];
    
#if TARGET_OS_TV
    // Apply default values from our Root.plist
    NSString* settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    NSDictionary* settingsData = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray* preferences = [settingsData objectForKey:@"PreferenceSpecifiers"];
    NSMutableDictionary* defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for (NSDictionary* prefSpecification in preferences) {
        NSString* key = [prefSpecification objectForKey:@"Key"];
        if (key != nil) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
    
    self.bitrate = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"bitrate"]];
    assert([self.bitrate intValue] != 0);
    self.framerate = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"framerate"]];
    assert([self.framerate intValue] != 0);
    self.audioConfig = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"audioConfig"]];
    assert([self.audioConfig intValue] != 0);
    self.preferredCodec = (typeof(self.preferredCodec))[[NSUserDefaults standardUserDefaults] integerForKey:@"preferredCodec"];
    self.useFramePacing = [[NSUserDefaults standardUserDefaults] integerForKey:@"useFramePacing"] != 0;
    self.playAudioOnPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"audioOnPC"];
    self.enableHdr = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableHdr"];
    self.optimizeGames = [[NSUserDefaults standardUserDefaults] boolForKey:@"optimizeGames"];
    self.multiController = [[NSUserDefaults standardUserDefaults] boolForKey:@"multipleControllers"];
    self.swapABXYButtons = [[NSUserDefaults standardUserDefaults] boolForKey:@"swapABXYButtons"];
    self.btMouseSupport = [[NSUserDefaults standardUserDefaults] boolForKey:@"btMouseSupport"];
    self.statsOverlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"statsOverlay"];
    
    NSInteger _screenSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"streamResolution"];
    switch (_screenSize) {
        case 0:
            self.height = [NSNumber numberWithInteger:720];
            self.width = [NSNumber numberWithInteger:1280];
            break;
        case 1:
            self.height = [NSNumber numberWithInteger:1080];
            self.width = [NSNumber numberWithInteger:1920];
            break;
        case 2:
            self.height = [NSNumber numberWithInteger:2160];
            self.width = [NSNumber numberWithInteger:3840];
            break;
        case 3:
            self.height = [NSNumber numberWithInteger:1440];
            self.width = [NSNumber numberWithInteger:2560];
            break;
        default:
            abort();
    }
    self.onscreenControls = [NSNumber numberWithInteger:0];
#else
    self.bitrate = settings.bitrate;
    self.framerate = settings.framerate;
    self.height = settings.height;
    self.width = settings.width;
    self.audioConfig = settings.audioConfig;
    self.preferredCodec = settings.preferredCodec;
    self.useFramePacing = settings.useFramePacing;
    self.playAudioOnPC = settings.playAudioOnPC;
    self.enableHdr = settings.enableHdr;
    self.optimizeGames = settings.optimizeGames;
    self.multiController = settings.multiController;
    self.swapABXYButtons = settings.swapABXYButtons;
    self.onscreenControls = settings.onscreenControls;
    self.btMouseSupport = settings.btMouseSupport;
    self.statsOverlay = settings.statsOverlay;
    self.rumblePhone=settings.rumblePhone;
    self.externalMonitor=settings.externalMonitor;
    self.touchSensitivity=settings.touchSensitivity;
    self.enableTouchSensitivity=settings.enableTouchSensitivity;
    self.touchSensitivityGlobal=settings.touchSensitivityGlobal;
    self.motionMode = settings.motionMode;
    self.virtualDisplayMode=settings.virtualDisplayMode;
#endif
    self.uniqueId = settings.uniqueId;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.remoteMouseMode = [defaults boolForKey:StreamPreferenceRemoteMouseModeKey];
    self.captureMouseCursor = [defaults boolForKey:StreamPreferenceCaptureMouseCursorKey];
    self.relativeMouseSensitivity = [self normalizedRelativeMouseSensitivity:[defaults integerForKey:StreamPreferenceRelativeMouseSensitivityKey]];
    self.rendererSelection = [self normalizedRendererSelection:[defaults integerForKey:StreamPreferenceRendererSelectionKey]];
    self.metalFxScalingSelection = [self normalizedMetalFxScalingSelection:[defaults integerForKey:StreamPreferenceMetalFxScalingSelectionKey]];
    self.metalFxSharpenSelection = [self normalizedMetalFxSharpenSelection:[defaults integerForKey:StreamPreferenceMetalFxSharpenSelectionKey]];
    self.metalFxColorModeSelection = [self normalizedMetalFxColorModeSelection:[defaults integerForKey:StreamPreferenceMetalFxColorModeSelectionKey]];
    self.pictureInPictureEnabled = [defaults boolForKey:StreamPreferencePictureInPictureEnabledKey];
    self.streamOrientationSelection = [self normalizedStreamOrientationSelection:[defaults integerForKey:StreamPreferenceStreamOrientationSelectionKey]];
    self.gameMenuShortcutSelection = [self normalizedGameMenuShortcutSelection:[defaults integerForKey:StreamPreferenceGameMenuShortcutSelectionKey]];
    self.longPressStartForGameMenuEnabled = [defaults boolForKey:StreamPreferenceLongPressStartForGameMenuEnabledKey];
    self.audioHapticsEnabled = [defaults boolForKey:StreamPreferenceAudioHapticsEnabledKey];
    self.audioHapticsOutputTarget = [self normalizedAudioHapticsOutputTarget:[defaults integerForKey:StreamPreferenceAudioHapticsOutputTargetKey]];
    self.audioHapticsStrength = [self normalizedAudioHapticsStrength:[defaults integerForKey:StreamPreferenceAudioHapticsStrengthKey]];
    self.audioHapticsVoiceFilterSelection = [self normalizedAudioHapticsVoiceFilterSelection:[defaults integerForKey:StreamPreferenceAudioHapticsVoiceFilterSelectionKey]];
    self.audioHapticsKeepControllerRumble = [defaults boolForKey:StreamPreferenceAudioHapticsKeepControllerRumbleKey];
    id storedRumbleMode = [defaults objectForKey:StreamPreferenceRumbleModeSelectionKey];
    if ([storedRumbleMode isKindOfClass:[NSNumber class]]) {
        self.rumbleModeSelection = [storedRumbleMode integerValue];
    } else {
        self.rumbleModeSelection = settings.rumblePhone ? StreamRumbleModeSelectionDevice : StreamRumbleModeSelectionController;
    }
    id storedTouchMode = [defaults objectForKey:StreamPreferenceTouchModeSelectionKey];
    if ([storedTouchMode isKindOfClass:[NSNumber class]]) {
        self.touchModeSelection = [storedTouchMode integerValue];
    } else if (settings.absoluteTouchMode) {
        self.touchModeSelection = settings.multiTouchScreen ? StreamTouchModeSelectionMultiTouch : StreamTouchModeSelectionMouse;
    } else {
        self.touchModeSelection = StreamTouchModeSelectionTrackpad;
    }
    self.videoAlignmentSelection = [[NSUserDefaults standardUserDefaults] integerForKey:StreamPreferenceVideoAlignmentSelectionKey];
    self.videoAlignmentMargin = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:StreamPreferenceVideoAlignmentMarginKey];
    self.performanceOverlayPositionSelection = [[NSUserDefaults standardUserDefaults] integerForKey:StreamPreferencePerformanceOverlayPositionSelectionKey];
    self.performanceOverlayMargin = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:StreamPreferencePerformanceOverlayMarginKey];
    self.floatingMenuEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:StreamPreferenceFloatingMenuEnabledKey];
    self.virtualButtonsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:StreamPreferenceVirtualButtonsEnabledKey];
    self.virtualGamepadEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:StreamPreferenceVirtualGamepadEnabledKey];
    self.virtualButtonSchemeSelection = [[NSUserDefaults standardUserDefaults] integerForKey:StreamPreferenceVirtualButtonSchemeSelectionKey];
    self.virtualGamepadSchemeSelection = [[NSUserDefaults standardUserDefaults] integerForKey:StreamPreferenceVirtualGamepadSchemeSelectionKey];
    self.virtualGamepadOpacity = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:StreamPreferenceVirtualGamepadOpacityKey];
    
    return self;
}

@end
