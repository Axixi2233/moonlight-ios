//
//  DataManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "DataManager.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@implementation DataManager {
    NSManagedObjectContext *_managedObjectContext;
    AppDelegate *_appDelegate;
}

static NSString *VirtualButtonDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(NSInteger schemeSelection, BOOL portrait) {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    return [NSString stringWithFormat:@"StreamPreferenceVirtualButtonDefinitionsScheme%ld_%@",
            (long)clampedSelection,
            portrait ? @"Portrait" : @"Landscape"];
}

static NSString *VirtualButtonOpacityDefaultsKeyForSchemeSelection(NSInteger schemeSelection) {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    return [NSString stringWithFormat:@"StreamPreferenceVirtualButtonOpacityScheme%ld", (long)clampedSelection];
}

static NSString *VirtualGamepadDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(NSInteger schemeSelection, BOOL portrait) {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    return [NSString stringWithFormat:@"StreamPreferenceVirtualGamepadDefinitionsScheme%ld_%@",
            (long)clampedSelection,
            portrait ? @"Portrait" : @"Landscape"];
}

static NSString *VirtualGamepadOpacityDefaultsKeyForSchemeSelection(NSInteger schemeSelection) {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    return [NSString stringWithFormat:@"StreamPreferenceVirtualGamepadOpacityScheme%ld", (long)clampedSelection];
}

static NSString * const CustomShortcutDefinitionsDefaultsKey = @"StreamPreferenceCustomShortcutDefinitions";

static StreamTouchModeSelection NormalizedTouchModeSelection(NSInteger touchModeSelection) {
    switch (touchModeSelection) {
        case StreamTouchModeSelectionMouse:
        case StreamTouchModeSelectionMultiTouch:
        case StreamTouchModeSelectionDisabled:
            return (StreamTouchModeSelection)touchModeSelection;
        default:
            return StreamTouchModeSelectionTrackpad;
    }
}

static StreamRumbleModeSelection NormalizedRumbleModeSelection(NSInteger rumbleModeSelection) {
    switch (rumbleModeSelection) {
        case StreamRumbleModeSelectionDevice:
        case StreamRumbleModeSelectionDisabled:
            return (StreamRumbleModeSelection)rumbleModeSelection;
        default:
            return StreamRumbleModeSelectionController;
    }
}

static NSInteger NormalizedRelativeMouseSensitivity(NSInteger relativeMouseSensitivity) {
    return MAX(50, MIN(relativeMouseSensitivity, 300));
}

static NSInteger NormalizedRendererSelection(NSInteger rendererSelection) {
    switch (rendererSelection) {
        case 1:
            return 1;
        case 0:
        default:
            return 0;
    }
}

static NSInteger NormalizedLatencyModeSelection(NSInteger latencyModeSelection) {
    switch (latencyModeSelection) {
        case StreamLatencyModeSelectionCompetitive:
        case StreamLatencyModeSelectionSmooth:
            return latencyModeSelection;
        case StreamLatencyModeSelectionBalanced:
        default:
            return StreamLatencyModeSelectionBalanced;
    }
}

static NSInteger NormalizedStreamOrientationSelection(NSInteger streamOrientationSelection) {
    switch (streamOrientationSelection) {
        case StreamOrientationSelectionLandscape:
        case StreamOrientationSelectionPortrait:
            return streamOrientationSelection;
        case StreamOrientationSelectionAutomatic:
        default:
            return StreamOrientationSelectionAutomatic;
    }
}

static NSInteger NormalizedGameMenuShortcutSelection(NSInteger gameMenuShortcutSelection) {
    switch (gameMenuShortcutSelection) {
        case StreamGameMenuShortcutSelectionEscape:
        case StreamGameMenuShortcutSelectionCtrlAltShiftQ:
            return gameMenuShortcutSelection;
        case StreamGameMenuShortcutSelectionNone:
        default:
            return StreamGameMenuShortcutSelectionNone;
    }
}

static NSInteger NormalizedAudioHapticsOutputTarget(NSInteger audioHapticsOutputTarget) {
    switch (audioHapticsOutputTarget) {
        case StreamAudioHapticsOutputTargetController:
            return audioHapticsOutputTarget;
        case StreamAudioHapticsOutputTargetDevice:
        default:
            return StreamAudioHapticsOutputTargetDevice;
    }
}

static NSInteger NormalizedAudioHapticsStrength(NSInteger audioHapticsStrength) {
    return MAX(25, MIN(audioHapticsStrength, 200));
}

static NSInteger NormalizedAudioHapticsVoiceFilterSelection(NSInteger audioHapticsVoiceFilterSelection) {
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

static NSInteger NormalizedMetalFxScalingSelection(NSInteger metalFxScalingSelection) {
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

static NSInteger NormalizedMetalFxSharpenSelection(NSInteger metalFxSharpenSelection) {
    switch (metalFxSharpenSelection) {
        case StreamMetalFxSharpenSelectionDisabled:
        case StreamMetalFxSharpenSelectionStrong:
            return metalFxSharpenSelection;
        case StreamMetalFxSharpenSelectionStandard:
        default:
            return StreamMetalFxSharpenSelectionStandard;
    }
}

static NSInteger NormalizedMetalFxColorModeSelection(NSInteger metalFxColorModeSelection) {
    switch (metalFxColorModeSelection) {
        case StreamMetalFxColorModeSelectionLinear:
        case StreamMetalFxColorModeSelectionHdr:
            return metalFxColorModeSelection;
        case StreamMetalFxColorModeSelectionPerceptual:
        default:
            return StreamMetalFxColorModeSelectionPerceptual;
    }
}

- (id) init {
    self = [super init];
    
    // HACK: Avoid calling [UIApplication delegate] off the UI thread to keep
    // Main Thread Checker happy.
    if ([NSThread isMainThread]) {
        _appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        });
    }
    
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setParentContext:[_appDelegate managedObjectContext]];
    
    return self;
}

- (void) updateUniqueId:(NSString*)uniqueId {
    [_managedObjectContext performBlockAndWait:^{
        [self retrieveSettings].uniqueId = uniqueId;
        [self saveData];
    }];
}

- (NSString*) getUniqueId {
    __block NSString *uid;
    
    [_managedObjectContext performBlockAndWait:^{
        uid = [self retrieveSettings].uniqueId;
    }];

    return uid;
}

- (void) saveSettingsWithBitrate:(NSInteger)bitrate
                       framerate:(NSInteger)framerate
                          height:(NSInteger)height
                           width:(NSInteger)width
                     audioConfig:(NSInteger)audioConfig
                onscreenControls:(NSInteger)onscreenControls
                   optimizeGames:(BOOL)optimizeGames
                 multiController:(BOOL)multiController
                 swapABXYButtons:(BOOL)swapABXYButtons
                       audioOnPC:(BOOL)audioOnPC
                  preferredCodec:(uint32_t)preferredCodec
            latencyModeSelection:(NSInteger)latencyModeSelection
                  useFramePacing:(BOOL)useFramePacing
                       enableHdr:(BOOL)enableHdr
                  btMouseSupport:(BOOL)btMouseSupport
                 remoteMouseMode:(BOOL)remoteMouseMode
              captureMouseCursor:(BOOL)captureMouseCursor
      relativeMouseSensitivity:(NSInteger)relativeMouseSensitivity
               rendererSelection:(NSInteger)rendererSelection
         metalFxScalingSelection:(NSInteger)metalFxScalingSelection
         metalFxSharpenSelection:(NSInteger)metalFxSharpenSelection
       metalFxColorModeSelection:(NSInteger)metalFxColorModeSelection
       pictureInPictureEnabled:(BOOL)pictureInPictureEnabled
     streamOrientationSelection:(NSInteger)streamOrientationSelection
   gameMenuShortcutSelection:(NSInteger)gameMenuShortcutSelection
longPressStartForGameMenuEnabled:(BOOL)longPressStartForGameMenuEnabled
         audioHapticsEnabled:(BOOL)audioHapticsEnabled
    audioHapticsOutputTarget:(NSInteger)audioHapticsOutputTarget
       audioHapticsStrength:(NSInteger)audioHapticsStrength
audioHapticsVoiceFilterSelection:(NSInteger)audioHapticsVoiceFilterSelection
audioHapticsKeepControllerRumble:(BOOL)audioHapticsKeepControllerRumble
audioPlaybackOptimizationEnabled:(BOOL)audioPlaybackOptimizationEnabled
              touchModeSelection:(NSInteger)touchModeSelection
                    statsOverlay:(BOOL)statsOverlay
             rumbleModeSelection:(NSInteger)rumbleModeSelection
                 externalMonitor:(BOOL)externalMonitor
          touchSensitivityGlobal:(BOOL)touchSensitivityGlobal
          enableTouchSensitivity:(BOOL)enableTouchSensitivity
              touchSensitivity:(NSInteger)touchSensitivity
                      motionMode:(NSInteger)motionMode
                virtualDisplayMode:(NSInteger)virtualDisplayMode
           videoAlignmentSelection:(NSInteger)videoAlignmentSelection
              videoAlignmentMargin:(CGFloat)videoAlignmentMargin
performanceOverlayPositionSelection:(NSInteger)performanceOverlayPositionSelection
         performanceOverlayMargin:(CGFloat)performanceOverlayMargin
 performanceOverlayDragEnabled:(BOOL)performanceOverlayDragEnabled
               floatingMenuEnabled:(BOOL)floatingMenuEnabled
             virtualButtonsEnabled:(BOOL)virtualButtonsEnabled
             virtualGamepadEnabled:(BOOL)virtualGamepadEnabled
       virtualButtonSchemeSelection:(NSInteger)virtualButtonSchemeSelection
     virtualGamepadSchemeSelection:(NSInteger)virtualGamepadSchemeSelection
             virtualGamepadOpacity:(CGFloat)virtualGamepadOpacity{
    
    [_managedObjectContext performBlockAndWait:^{
        Settings* settingsToSave = [self retrieveSettings];
        settingsToSave.framerate = [NSNumber numberWithInteger:framerate];
        settingsToSave.bitrate = [NSNumber numberWithInteger:bitrate];
        settingsToSave.height = [NSNumber numberWithInteger:height];
        settingsToSave.width = [NSNumber numberWithInteger:width];
        settingsToSave.audioConfig = [NSNumber numberWithInteger:audioConfig];
        settingsToSave.onscreenControls = [NSNumber numberWithInteger:onscreenControls];
        settingsToSave.optimizeGames = optimizeGames;
        settingsToSave.multiController = multiController;
        settingsToSave.swapABXYButtons = swapABXYButtons;
        settingsToSave.playAudioOnPC = audioOnPC;
        settingsToSave.preferredCodec = preferredCodec;
        NSInteger normalizedLatencyModeSelection = NormalizedLatencyModeSelection(latencyModeSelection);
        settingsToSave.useFramePacing = (normalizedLatencyModeSelection == StreamLatencyModeSelectionSmooth) ? YES : useFramePacing;
        settingsToSave.enableHdr = enableHdr;
        settingsToSave.btMouseSupport = btMouseSupport;
        NSInteger normalizedRelativeMouseSensitivity = NormalizedRelativeMouseSensitivity(relativeMouseSensitivity);
        NSInteger normalizedRendererSelection = NormalizedRendererSelection(rendererSelection);
        NSInteger normalizedMetalFxScalingSelection = NormalizedMetalFxScalingSelection(metalFxScalingSelection);
        NSInteger normalizedMetalFxSharpenSelection = NormalizedMetalFxSharpenSelection(metalFxSharpenSelection);
        NSInteger normalizedMetalFxColorModeSelection = NormalizedMetalFxColorModeSelection(metalFxColorModeSelection);
        NSInteger normalizedStreamOrientationSelection = NormalizedStreamOrientationSelection(streamOrientationSelection);
        NSInteger normalizedGameMenuShortcutSelection = NormalizedGameMenuShortcutSelection(gameMenuShortcutSelection);
        NSInteger normalizedAudioHapticsOutputTarget = NormalizedAudioHapticsOutputTarget(audioHapticsOutputTarget);
        NSInteger normalizedAudioHapticsStrength = NormalizedAudioHapticsStrength(audioHapticsStrength);
        NSInteger normalizedAudioHapticsVoiceFilterSelection = NormalizedAudioHapticsVoiceFilterSelection(audioHapticsVoiceFilterSelection);
        StreamTouchModeSelection normalizedTouchModeSelection = NormalizedTouchModeSelection(touchModeSelection);
        StreamRumbleModeSelection normalizedRumbleModeSelection = NormalizedRumbleModeSelection(rumbleModeSelection);
        settingsToSave.absoluteTouchMode = (normalizedTouchModeSelection == StreamTouchModeSelectionMouse ||
                                            normalizedTouchModeSelection == StreamTouchModeSelectionMultiTouch);
        settingsToSave.statsOverlay = statsOverlay;
        settingsToSave.rumblePhone = (normalizedRumbleModeSelection == StreamRumbleModeSelectionDevice);
        settingsToSave.multiTouchScreen = (normalizedTouchModeSelection == StreamTouchModeSelectionMultiTouch);
        settingsToSave.externalMonitor = externalMonitor;
        settingsToSave.enableTouchSensitivity=enableTouchSensitivity;
        settingsToSave.touchSensitivity=[NSNumber numberWithInteger:touchSensitivity];
        settingsToSave.touchSensitivityGlobal=touchSensitivityGlobal;
        settingsToSave.motionMode = [NSNumber numberWithInteger:motionMode];
        settingsToSave.virtualDisplayMode = [NSNumber numberWithInteger:virtualDisplayMode];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:MAX(0, MIN(videoAlignmentSelection, 2)) forKey:StreamPreferenceVideoAlignmentSelectionKey];
        [defaults setDouble:MAX(0.0, MIN(videoAlignmentMargin, 150.0)) forKey:StreamPreferenceVideoAlignmentMarginKey];
        [defaults setInteger:MAX(0, MIN(performanceOverlayPositionSelection, 5)) forKey:StreamPreferencePerformanceOverlayPositionSelectionKey];
        [defaults setDouble:MAX(0.0, MIN(performanceOverlayMargin, 150.0)) forKey:StreamPreferencePerformanceOverlayMarginKey];
        [defaults setBool:performanceOverlayDragEnabled forKey:StreamPreferencePerformanceOverlayDragEnabledKey];
        [defaults setBool:floatingMenuEnabled forKey:StreamPreferenceFloatingMenuEnabledKey];
        [defaults setBool:virtualButtonsEnabled forKey:StreamPreferenceVirtualButtonsEnabledKey];
        [defaults setBool:virtualGamepadEnabled forKey:StreamPreferenceVirtualGamepadEnabledKey];
        [defaults setBool:remoteMouseMode forKey:StreamPreferenceRemoteMouseModeKey];
        [defaults setBool:captureMouseCursor forKey:StreamPreferenceCaptureMouseCursorKey];
        [defaults setInteger:normalizedRelativeMouseSensitivity forKey:StreamPreferenceRelativeMouseSensitivityKey];
        [defaults setInteger:normalizedRendererSelection forKey:StreamPreferenceRendererSelectionKey];
        [defaults setInteger:normalizedLatencyModeSelection forKey:StreamPreferenceLatencyModeSelectionKey];
        [defaults setInteger:normalizedMetalFxScalingSelection forKey:StreamPreferenceMetalFxScalingSelectionKey];
        [defaults setInteger:normalizedMetalFxSharpenSelection forKey:StreamPreferenceMetalFxSharpenSelectionKey];
        [defaults setInteger:normalizedMetalFxColorModeSelection forKey:StreamPreferenceMetalFxColorModeSelectionKey];
        [defaults setBool:pictureInPictureEnabled forKey:StreamPreferencePictureInPictureEnabledKey];
        [defaults setInteger:normalizedStreamOrientationSelection forKey:StreamPreferenceStreamOrientationSelectionKey];
        [defaults setInteger:normalizedGameMenuShortcutSelection forKey:StreamPreferenceGameMenuShortcutSelectionKey];
        [defaults setBool:longPressStartForGameMenuEnabled forKey:StreamPreferenceLongPressStartForGameMenuEnabledKey];
        [defaults setBool:audioHapticsEnabled forKey:StreamPreferenceAudioHapticsEnabledKey];
        [defaults setInteger:normalizedAudioHapticsOutputTarget forKey:StreamPreferenceAudioHapticsOutputTargetKey];
        [defaults setInteger:normalizedAudioHapticsStrength forKey:StreamPreferenceAudioHapticsStrengthKey];
        [defaults setInteger:normalizedAudioHapticsVoiceFilterSelection forKey:StreamPreferenceAudioHapticsVoiceFilterSelectionKey];
        [defaults setBool:audioHapticsKeepControllerRumble forKey:StreamPreferenceAudioHapticsKeepControllerRumbleKey];
        [defaults setBool:audioPlaybackOptimizationEnabled forKey:StreamPreferenceAudioPlaybackOptimizationEnabledKey];
        [defaults setInteger:normalizedTouchModeSelection forKey:StreamPreferenceTouchModeSelectionKey];
        [defaults setInteger:normalizedRumbleModeSelection forKey:StreamPreferenceRumbleModeSelectionKey];
        [defaults setInteger:MAX(0, MIN(virtualButtonSchemeSelection, 4)) forKey:StreamPreferenceVirtualButtonSchemeSelectionKey];
        [defaults setInteger:MAX(0, MIN(virtualGamepadSchemeSelection, 4)) forKey:StreamPreferenceVirtualGamepadSchemeSelectionKey];
        [defaults setDouble:MAX(0.05f, MIN(virtualGamepadOpacity, 1.0f)) forKey:StreamPreferenceVirtualGamepadOpacityKey];
        [defaults synchronize];
        [self saveData];
    }];
}

- (void) updateHost:(TemporaryHost *)host {
    [_managedObjectContext performBlockAndWait:^{
        // Add a new persistent managed object if one doesn't exist
        Host* parent = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (parent == nil) {
            NSEntityDescription* entity = [NSEntityDescription entityForName:@"Host" inManagedObjectContext:self->_managedObjectContext];
            parent = [[Host alloc] initWithEntity:entity insertIntoManagedObjectContext:self->_managedObjectContext];
        }
        
        // Push changes from the temp host to the persistent one
        [host propagateChangesToParent:parent];
        
        [self saveData];
    }];
}

- (void) updateAppsForExistingHost:(TemporaryHost *)host {
    [_managedObjectContext performBlockAndWait:^{
        Host* parent = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (parent == nil) {
            // The host must exist to be updated
            return;
        }
        
        NSMutableSet *applist = [[NSMutableSet alloc] init];
        NSArray *appRecords = [self fetchRecords:@"App"];
        for (TemporaryApp* app in host.appList) {
            // Add a new persistent managed object if one doesn't exist
            App* parentApp = [self getAppForTemporaryApp:app withAppRecords:appRecords];
            if (parentApp == nil) {
                NSEntityDescription* entity = [NSEntityDescription entityForName:@"App" inManagedObjectContext:self->_managedObjectContext];
                parentApp = [[App alloc] initWithEntity:entity insertIntoManagedObjectContext:self->_managedObjectContext];
            }
            
            [app propagateChangesToParent:parentApp withHost:parent];
            
            [applist addObject:parentApp];
        }
        
        parent.appList = applist;
        
        [self saveData];
    }];
}

- (TemporarySettings*) getSettings {
    __block TemporarySettings *tempSettings;
    
    [_managedObjectContext performBlockAndWait:^{
        tempSettings = [[TemporarySettings alloc] initFromSettings:[self retrieveSettings]];
    }];
    
    return tempSettings;
}

- (NSArray<NSDictionary *> *)virtualButtonDefinitionsForSchemeSelection:(NSInteger)schemeSelection
                                                               portrait:(BOOL)portrait {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *definitions = [defaults arrayForKey:VirtualButtonDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(clampedSelection, portrait)];
    if (![definitions isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return definitions;
}

- (CGFloat)virtualButtonOpacityForSchemeSelection:(NSInteger)schemeSelection {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id storedValue = [defaults objectForKey:VirtualButtonOpacityDefaultsKeyForSchemeSelection(clampedSelection)];
    if (![storedValue isKindOfClass:[NSNumber class]]) {
        return 0.52f;
    }
    return MAX(0.05f, MIN((CGFloat)[storedValue doubleValue], 1.0f));
}

- (void)saveVirtualButtonDefinitions:(NSArray<NSDictionary *> *)definitions
                             opacity:(CGFloat)opacity
                  forSchemeSelection:(NSInteger)schemeSelection
                            portrait:(BOOL)portrait {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(definitions ?: @[]) forKey:VirtualButtonDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(clampedSelection, portrait)];
    [defaults setDouble:MAX(0.05f, MIN(opacity, 1.0f)) forKey:VirtualButtonOpacityDefaultsKeyForSchemeSelection(clampedSelection)];
    [defaults synchronize];
}

- (NSArray<NSDictionary *> *)virtualGamepadDefinitionsForSchemeSelection:(NSInteger)schemeSelection
                                                                portrait:(BOOL)portrait {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *definitions = [defaults arrayForKey:VirtualGamepadDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(clampedSelection, portrait)];
    if (![definitions isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return definitions;
}

- (CGFloat)virtualGamepadOpacityForSchemeSelection:(NSInteger)schemeSelection {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id storedValue = [defaults objectForKey:VirtualGamepadOpacityDefaultsKeyForSchemeSelection(clampedSelection)];
    if (![storedValue isKindOfClass:[NSNumber class]]) {
        return MAX(0.05f, MIN((CGFloat)[defaults doubleForKey:StreamPreferenceVirtualGamepadOpacityKey], 1.0f));
    }
    return MAX(0.05f, MIN((CGFloat)[storedValue doubleValue], 1.0f));
}

- (void)saveVirtualGamepadOpacity:(CGFloat)opacity
                forSchemeSelection:(NSInteger)schemeSelection {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:MAX(0.05f, MIN(opacity, 1.0f)) forKey:VirtualGamepadOpacityDefaultsKeyForSchemeSelection(clampedSelection)];
    [defaults synchronize];
}

- (void)saveVirtualGamepadDefinitions:(NSArray<NSDictionary *> *)definitions
                              opacity:(CGFloat)opacity
                   forSchemeSelection:(NSInteger)schemeSelection
                             portrait:(BOOL)portrait {
    NSInteger clampedSelection = MAX(0, MIN(schemeSelection, 4));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(definitions ?: @[]) forKey:VirtualGamepadDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(clampedSelection, portrait)];
    [defaults setDouble:MAX(0.05f, MIN(opacity, 1.0f)) forKey:VirtualGamepadOpacityDefaultsKeyForSchemeSelection(clampedSelection)];
    [defaults synchronize];
}

- (NSArray<NSDictionary *> *)customShortcutDefinitions {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *definitions = [defaults arrayForKey:CustomShortcutDefinitionsDefaultsKey];
    if (![definitions isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return definitions;
}

- (void)saveTouchModeSelection:(NSInteger)touchModeSelection {
    [_managedObjectContext performBlockAndWait:^{
        StreamTouchModeSelection normalizedTouchModeSelection = NormalizedTouchModeSelection(touchModeSelection);
        Settings *settingsToSave = [self retrieveSettings];
        settingsToSave.absoluteTouchMode = (normalizedTouchModeSelection == StreamTouchModeSelectionMouse ||
                                            normalizedTouchModeSelection == StreamTouchModeSelectionMultiTouch);
        settingsToSave.multiTouchScreen = (normalizedTouchModeSelection == StreamTouchModeSelectionMultiTouch);

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:normalizedTouchModeSelection forKey:StreamPreferenceTouchModeSelectionKey];
        [defaults synchronize];
        [self saveData];
    }];
}

- (void)saveAudioHapticsEnabled:(BOOL)audioHapticsEnabled
                   outputTarget:(NSInteger)audioHapticsOutputTarget
                       strength:(NSInteger)audioHapticsStrength
           voiceFilterSelection:(NSInteger)audioHapticsVoiceFilterSelection
           keepControllerRumble:(BOOL)audioHapticsKeepControllerRumble {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:audioHapticsEnabled forKey:StreamPreferenceAudioHapticsEnabledKey];
    [defaults setInteger:NormalizedAudioHapticsOutputTarget(audioHapticsOutputTarget) forKey:StreamPreferenceAudioHapticsOutputTargetKey];
    [defaults setInteger:NormalizedAudioHapticsStrength(audioHapticsStrength) forKey:StreamPreferenceAudioHapticsStrengthKey];
    [defaults setInteger:NormalizedAudioHapticsVoiceFilterSelection(audioHapticsVoiceFilterSelection) forKey:StreamPreferenceAudioHapticsVoiceFilterSelectionKey];
    [defaults setBool:audioHapticsKeepControllerRumble forKey:StreamPreferenceAudioHapticsKeepControllerRumbleKey];
    [defaults synchronize];
}

- (void)saveCustomShortcutDefinitions:(NSArray<NSDictionary *> *)definitions {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:(definitions ?: @[]) forKey:CustomShortcutDefinitionsDefaultsKey];
    [defaults synchronize];
}

- (void)resetSettingsToDefaultsClearingCustomData:(BOOL)clearCustomData {
    [_managedObjectContext performBlockAndWait:^{
        NSArray<Settings *> *fetchedRecords = [self fetchRecords:@"Settings"];
        NSString *uniqueId = fetchedRecords.firstObject.uniqueId;

        for (Settings *settings in fetchedRecords) {
            [self->_managedObjectContext deleteObject:settings];
        }

        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Settings" inManagedObjectContext:self->_managedObjectContext];
        Settings *settings = [[Settings alloc] initWithEntity:entity insertIntoManagedObjectContext:self->_managedObjectContext];
        settings.uniqueId = uniqueId;
        settings.bitrate = @30000;
        settings.width = @1920;
        settings.height = @1080;
        settings.absoluteTouchMode = NO;
        settings.multiTouchScreen = NO;
        settings.statsOverlay = YES;

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray<NSString *> *preferenceKeys = @[
            StreamPreferenceVideoAlignmentSelectionKey,
            StreamPreferenceVideoAlignmentMarginKey,
            StreamPreferencePerformanceOverlayPositionSelectionKey,
            StreamPreferencePerformanceOverlayMarginKey,
            StreamPreferencePerformanceOverlayDragEnabledKey,
            StreamPreferenceFloatingMenuEnabledKey,
            StreamPreferenceVirtualButtonsEnabledKey,
            StreamPreferenceVirtualGamepadEnabledKey,
            StreamPreferenceRemoteMouseModeKey,
            StreamPreferenceCaptureMouseCursorKey,
            StreamPreferenceRelativeMouseSensitivityKey,
            StreamPreferenceRendererSelectionKey,
            StreamPreferenceLatencyModeSelectionKey,
            StreamPreferenceMetalFxScalingSelectionKey,
            StreamPreferenceMetalFxSharpenSelectionKey,
            StreamPreferencePictureInPictureEnabledKey,
            StreamPreferenceStreamOrientationSelectionKey,
            StreamPreferenceGameMenuShortcutSelectionKey,
            StreamPreferenceLongPressStartForGameMenuEnabledKey,
            StreamPreferenceTouchModeSelectionKey,
            StreamPreferenceRumbleModeSelectionKey,
            StreamPreferenceAudioPlaybackOptimizationEnabledKey,
            StreamPreferenceVirtualButtonSchemeSelectionKey,
            StreamPreferenceVirtualGamepadSchemeSelectionKey,
            StreamPreferenceVirtualGamepadOpacityKey
        ];

        for (NSString *key in preferenceKeys) {
            [defaults removeObjectForKey:key];
        }

        if (clearCustomData) {
            for (NSInteger schemeSelection = 0; schemeSelection < 5; schemeSelection++) {
                [defaults removeObjectForKey:VirtualButtonDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(schemeSelection, NO)];
                [defaults removeObjectForKey:VirtualButtonDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(schemeSelection, YES)];
                [defaults removeObjectForKey:VirtualButtonOpacityDefaultsKeyForSchemeSelection(schemeSelection)];
                [defaults removeObjectForKey:VirtualGamepadDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(schemeSelection, NO)];
                [defaults removeObjectForKey:VirtualGamepadDefinitionsDefaultsKeyForSchemeSelectionAndOrientation(schemeSelection, YES)];
                [defaults removeObjectForKey:VirtualGamepadOpacityDefaultsKeyForSchemeSelection(schemeSelection)];
            }

            [defaults removeObjectForKey:CustomShortcutDefinitionsDefaultsKey];
        }

        [defaults synchronize];
        [self saveData];
    }];
}

- (Settings*) retrieveSettings {
    NSArray* fetchedRecords = [self fetchRecords:@"Settings"];
    if (fetchedRecords.count == 0) {
        // create a new settings object with the default values
        NSEntityDescription* entity = [NSEntityDescription entityForName:@"Settings" inManagedObjectContext:_managedObjectContext];
        Settings* settings = [[Settings alloc] initWithEntity:entity insertIntoManagedObjectContext:_managedObjectContext];
        settings.bitrate = @30000;
        settings.width = @1920;
        settings.height = @1080;
        settings.absoluteTouchMode = NO;
        settings.multiTouchScreen = NO;
        settings.statsOverlay = YES;
        
        return settings;
    } else {
        // we should only ever have 1 settings object stored
        return [fetchedRecords objectAtIndex:0];
    }
}

- (void) removeApp:(TemporaryApp*)app {
    [_managedObjectContext performBlockAndWait:^{
        App* managedApp = [self getAppForTemporaryApp:app withAppRecords:[self fetchRecords:@"App"]];
        if (managedApp != nil) {
            [self->_managedObjectContext deleteObject:managedApp];
            [self saveData];
        }
    }];
}

- (void) removeHost:(TemporaryHost*)host {
    [_managedObjectContext performBlockAndWait:^{
        Host* managedHost = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (managedHost != nil) {
            [self->_managedObjectContext deleteObject:managedHost];
            [self saveData];
        }
    }];
}

- (void) saveData {
    NSError* error;
    if ([_managedObjectContext hasChanges] && ![_managedObjectContext save:&error]) {
        Log(LOG_E, @"Unable to save hosts to database: %@", error);
    }

    [_appDelegate saveContext];
}

- (NSArray*) getHosts {
    __block NSMutableArray *tempHosts = [[NSMutableArray alloc] init];
    
    [_managedObjectContext performBlockAndWait:^{
        NSArray *hosts = [self fetchRecords:@"Host"];
        
        for (Host* host in hosts) {
            [tempHosts addObject:[[TemporaryHost alloc] initFromHost:host]];
        }
    }];
    
    return tempHosts;
}

// Only call from within performBlockAndWait!!!
- (Host*) getHostForTemporaryHost:(TemporaryHost*)tempHost withHostRecords:(NSArray*)hosts {
    for (Host* host in hosts) {
        if ([tempHost.uuid isEqualToString:host.uuid]) {
            return host;
        }
    }
    
    return nil;
}

// Only call from within performBlockAndWait!!!
- (App*) getAppForTemporaryApp:(TemporaryApp*)tempApp withAppRecords:(NSArray*)apps {
    for (App* app in apps) {
        if ([app.id isEqualToString:tempApp.id] &&
            [app.host.uuid isEqualToString:tempApp.host.uuid]) {
            return app;
        }
    }
    
    return nil;
}

- (NSArray*) fetchRecords:(NSString*)entityName {
    NSArray* fetchedRecords;
    
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSError* error;
    fetchedRecords = [_managedObjectContext executeFetchRequest:fetchRequest error:&error];
    //TODO: handle errors
    
    return fetchedRecords;
}

@end
