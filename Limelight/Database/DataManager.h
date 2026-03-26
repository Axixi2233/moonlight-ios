//
//  DataManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@interface DataManager : NSObject

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
             virtualGamepadOpacity:(CGFloat)virtualGamepadOpacity;

- (NSArray*) getHosts;
- (void) updateHost:(TemporaryHost*)host;
- (void) updateAppsForExistingHost:(TemporaryHost *)host;
- (void) removeHost:(TemporaryHost*)host;
- (void) removeApp:(TemporaryApp*)app;

- (TemporarySettings*) getSettings;
- (NSArray<NSDictionary *> *)virtualButtonDefinitionsForSchemeSelection:(NSInteger)schemeSelection
                                                               portrait:(BOOL)portrait;
- (CGFloat)virtualButtonOpacityForSchemeSelection:(NSInteger)schemeSelection;
- (void)saveVirtualButtonDefinitions:(NSArray<NSDictionary *> *)definitions
                             opacity:(CGFloat)opacity
                  forSchemeSelection:(NSInteger)schemeSelection
                            portrait:(BOOL)portrait;
- (NSArray<NSDictionary *> *)virtualGamepadDefinitionsForSchemeSelection:(NSInteger)schemeSelection
                                                                portrait:(BOOL)portrait;
- (CGFloat)virtualGamepadOpacityForSchemeSelection:(NSInteger)schemeSelection;
- (void)saveVirtualGamepadOpacity:(CGFloat)opacity
                forSchemeSelection:(NSInteger)schemeSelection;
- (void)saveVirtualGamepadDefinitions:(NSArray<NSDictionary *> *)definitions
                              opacity:(CGFloat)opacity
                   forSchemeSelection:(NSInteger)schemeSelection
                             portrait:(BOOL)portrait;

- (void) updateUniqueId:(NSString*)uniqueId;
- (NSString*) getUniqueId;

@end
