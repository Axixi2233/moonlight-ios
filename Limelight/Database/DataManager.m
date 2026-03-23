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
                  useFramePacing:(BOOL)useFramePacing
                       enableHdr:(BOOL)enableHdr
                  btMouseSupport:(BOOL)btMouseSupport
               absoluteTouchMode:(BOOL)absoluteTouchMode
                    statsOverlay:(BOOL)statsOverlay
                     rumblePhone:(BOOL)rumblePhone
                multiTouchScreen:(BOOL)multiTouchScreen
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
               floatingMenuEnabled:(BOOL)floatingMenuEnabled
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
        settingsToSave.useFramePacing = useFramePacing;
        settingsToSave.enableHdr = enableHdr;
        settingsToSave.btMouseSupport = btMouseSupport;
        settingsToSave.absoluteTouchMode = absoluteTouchMode;
        settingsToSave.statsOverlay = statsOverlay;
        settingsToSave.rumblePhone = rumblePhone;
        settingsToSave.multiTouchScreen = multiTouchScreen;
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
        [defaults setBool:floatingMenuEnabled forKey:StreamPreferenceFloatingMenuEnabledKey];
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

- (Settings*) retrieveSettings {
    NSArray* fetchedRecords = [self fetchRecords:@"Settings"];
    if (fetchedRecords.count == 0) {
        // create a new settings object with the default values
        NSEntityDescription* entity = [NSEntityDescription entityForName:@"Settings" inManagedObjectContext:_managedObjectContext];
        Settings* settings = [[Settings alloc] initWithEntity:entity insertIntoManagedObjectContext:_managedObjectContext];
        
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
