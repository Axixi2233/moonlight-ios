//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "SettingsViewController.h"
#import "TemporarySettings.h"
#import "DataManager.h"
#import "Moonlight-Swift.h"

#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

static NSString * const MainFrameSettingsDidCloseNotification = @"MainFrameSettingsDidCloseNotification";
#define SettingsLocalized(key) NSLocalizedString((key), nil)

@implementation SettingsViewController {
    SettingsHostingViewController *_settingsHostingViewController;
}

@dynamic overrideUserInterfaceStyle;

static const NSInteger minimumBitrateKbps = 10000;
static const NSInteger maximumBitrateKbps = 500000;

const int RESOLUTION_TABLE_SIZE = 9;
const int RESOLUTION_TABLE_CUSTOM_INDEX = RESOLUTION_TABLE_SIZE - 1;
CGSize resolutionTable[RESOLUTION_TABLE_SIZE];

BOOL isCustomResolution(CGSize res) {
    if (res.width == 0 && res.height == 0) {
        return NO;
    }
    
    for (int i = 0; i < RESOLUTION_TABLE_CUSTOM_INDEX; i++) {
        if (res.width == resolutionTable[i].width && res.height == resolutionTable[i].height) {
            return NO;
        }
    }
    
    return YES;
}

static NSInteger AudioConfigSelectionFromChannelCount(NSInteger channelCount) {
    switch (channelCount) {
        case 6:
            return 1;
        case 8:
            return 2;
        case 2:
        default:
            return 0;
    }
}

static NSInteger ChannelCountFromAudioConfigSelection(NSInteger selection) {
    switch (selection) {
        case 1:
            return 6;
        case 2:
            return 8;
        case 0:
        default:
            return 2;
    }
}

- (UIColor *)navigationAccentColor {
    return [UIColor colorWithRed:0.31 green:0.23 blue:0.46 alpha:1.0];
}

- (NSDictionary<NSAttributedStringKey, id> *)navigationTitleAttributes {
    return @{
        NSForegroundColorAttributeName: [self navigationAccentColor],
        NSFontAttributeName: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };
}

- (void)applyNavigationBarAppearance {
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (navigationBar == nil) {
        return;
    }

    UIColor *accentColor = [self navigationAccentColor];
    navigationBar.tintColor = accentColor;
    navigationBar.titleTextAttributes = [self navigationTitleAttributes];

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        appearance.titleTextAttributes = [self navigationTitleAttributes];

        if (@available(iOS 26.0, *)) {
            [appearance configureWithTransparentBackground];
            appearance.backgroundColor = [UIColor clearColor];
            appearance.shadowColor = [UIColor clearColor];
        }
        else {
            [appearance configureWithOpaqueBackground];
            appearance.backgroundColor = [UIColor colorWithRed:0.98 green:0.96 blue:1.0 alpha:0.96];
            appearance.shadowColor = [UIColor colorWithRed:0.73 green:0.69 blue:0.82 alpha:0.22];
        }

        navigationBar.standardAppearance = appearance;
        navigationBar.compactAppearance = appearance;
        navigationBar.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            navigationBar.compactScrollEdgeAppearance = appearance;
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor clearColor];
    self.title = SettingsLocalized(@"settings.title");
    UIImage *backImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        backImage = [[UIImage systemImageNamed:@"chevron.left"] imageByApplyingSymbolConfiguration:symbolConfig];
    }

    if (backImage != nil) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backImage
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(closeSettings:)];
    }
    else {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:SettingsLocalized(@"common.back")
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(closeSettings:)];
    }
    UIImage *resetImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        resetImage = [[UIImage systemImageNamed:@"arrow.trianglehead.counterclockwise"] imageByApplyingSymbolConfiguration:symbolConfig];
    }

    if (resetImage != nil) {
        UIBarButtonItem *resetButtonItem = [[UIBarButtonItem alloc] initWithImage:resetImage
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(promptResetToDefaults:)];
        resetButtonItem.accessibilityLabel = SettingsLocalized(@"settings.reset.title");
        resetButtonItem.accessibilityHint = SettingsLocalized(@"settings.reset.hint");
        self.navigationItem.rightBarButtonItem = resetButtonItem;
    }
    else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:SettingsLocalized(@"settings.reset.button")
                                                                                   style:UIBarButtonItemStylePlain
                                                                                  target:self
                                                                                  action:@selector(promptResetToDefaults:)];
    }
    [self applyNavigationBarAppearance];
    [self installSwiftUISettingsIfPossible];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self applyNavigationBarAppearance];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isBeingDismissed || self.isMovingFromParentViewController) {
        [self saveSettings];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [self setNeedsStatusBarAppearanceUpdate];

    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (BOOL)prefersStatusBarHidden {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return NO;
    }

    UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationUnknown;
    if (@available(iOS 13.0, *)) {
        interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
    }

    if (interfaceOrientation != UIInterfaceOrientationUnknown) {
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);
    }

    return CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (@available(iOS 13.0, *)) {
        return UIStatusBarStyleDarkContent;
    }

    return UIStatusBarStyleDefault;
}

- (void) saveSettings {
    [self loadViewIfNeeded];
    if (_settingsHostingViewController == nil) {
        return;
    }

    [self saveSettingsUsingSnapshot:[_settingsHostingViewController currentSnapshot]];
}

- (void)promptResetToDefaults:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SettingsLocalized(@"settings.reset.title")
                                                                             message:SettingsLocalized(@"settings.reset.message")
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:SettingsLocalized(@"settings.reset.settings_only")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self resetSettingsToDefaultsClearingCustomData:NO];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:SettingsLocalized(@"settings.reset.clear_custom_data")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
        [self resetSettingsToDefaultsClearingCustomData:YES];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:SettingsLocalized(@"common.cancel")
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)resetSettingsToDefaultsClearingCustomData:(BOOL)clearCustomData {
    DataManager *dataManager = [[DataManager alloc] init];
    [dataManager resetSettingsToDefaultsClearingCustomData:clearCustomData];
    [self reloadSettingsUIFromCurrentSettings];
}

- (void)reloadSettingsUIFromCurrentSettings {
    TemporarySettings *currentSettings = [self currentSettingsForSettingsUI];
    [self configureResolutionTableForSettings:currentSettings];

    SettingsFormSnapshot *snapshot = [self makeSnapshotFromSettings:currentSettings];
    [_settingsHostingViewController configureWith:snapshot];
}


- (void)installSwiftUISettingsIfPossible {
    TemporarySettings *currentSettings = [self currentSettingsForSettingsUI];
    [self configureResolutionTableForSettings:currentSettings];

    SettingsFormSnapshot *snapshot = [self makeSnapshotFromSettings:currentSettings];
    SettingsHostingViewController *hostingController = [[SettingsHostingViewController alloc] init];
    hostingController.delegate = (id<SettingsHostingViewControllerDelegate>)self;
    [hostingController configureWith:snapshot];

    [self addChildViewController:hostingController];
    hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hostingController.view];
    [NSLayoutConstraint activateConstraints:@[
        [hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [hostingController didMoveToParentViewController:self];

    _settingsHostingViewController = hostingController;
}

- (TemporarySettings *)currentSettingsForSettingsUI {
    DataManager *dataManager = [[DataManager alloc] init];
    return [dataManager getSettings];
}

- (void)configureResolutionTableForSettings:(TemporarySettings *)currentSettings {
    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    CGFloat screenScale = window.screen.scale;
    CGFloat safeAreaWidth = (window.frame.size.width - window.safeAreaInsets.left - window.safeAreaInsets.right) * screenScale;
    CGFloat fullScreenWidth = window.frame.size.width * screenScale;
    CGFloat fullScreenHeight = window.frame.size.height * screenScale;

    resolutionTable[0] = CGSizeMake(640, 360);
    resolutionTable[1] = CGSizeMake(1280, 720);
    resolutionTable[2] = CGSizeMake(1920, 1080);
    resolutionTable[3] = CGSizeMake(2560, 1440);
    resolutionTable[4] = CGSizeMake(2560, 1600);
    resolutionTable[5] = CGSizeMake(3840, 2160);
    resolutionTable[6] = CGSizeMake(safeAreaWidth, fullScreenHeight);
    resolutionTable[7] = CGSizeMake(fullScreenWidth, fullScreenHeight);
    resolutionTable[8] = CGSizeMake([currentSettings.width integerValue], [currentSettings.height integerValue]);

    if (!isCustomResolution(resolutionTable[8])) {
        resolutionTable[8] = CGSizeMake(0, 0);
    }
}

- (SettingsFormSnapshot *)makeSnapshotFromSettings:(TemporarySettings *)currentSettings {
    SettingsFormSnapshot *snapshot = [[SettingsFormSnapshot alloc] init];

    snapshot.bitrateValues = @[ @(minimumBitrateKbps), @(maximumBitrateKbps) ];
    snapshot.bitrateMinimumKbps = minimumBitrateKbps;
    snapshot.bitrateMaximumKbps = maximumBitrateKbps;
    NSInteger savedBitrate = [currentSettings.bitrate intValue];
    if (savedBitrate <= 0) {
        savedBitrate = 30000;
    }
    snapshot.bitrateKbps = MAX(minimumBitrateKbps, MIN(savedBitrate, maximumBitrateKbps));

    BOOL enable120Fps = NO;
    if (@available(iOS 10.3, tvOS 10.3, *)) {
        if ([UIScreen mainScreen].maximumFramesPerSecond > 62) {
            enable120Fps = YES;
        }
    }
    snapshot.framerateOptions = enable120Fps ? @[ @30, @60, @120 ] : @[ @30, @60 ];
    snapshot.framerate = [currentSettings.framerate intValue];
    if (!enable120Fps && snapshot.framerate > 60) {
        snapshot.framerate = 60;
    }

    snapshot.resolutionTitles = @[
        @"360p",
        @"720p",
        @"1080p",
        @"2K",
        @"2K 16:10",
        @"4K",
        SettingsLocalized(@"settings.resolution.safe_area"),
        SettingsLocalized(@"settings.resolution.full_screen"),
        SettingsLocalized(@"settings.resolution.custom")
    ];
    NSMutableArray<NSString *> *resolutionDetailTitles = [[NSMutableArray alloc] init];
    for (int i = 0; i < RESOLUTION_TABLE_SIZE; i++) {
        NSInteger width = (NSInteger)resolutionTable[i].width;
        NSInteger height = (NSInteger)resolutionTable[i].height;
        if (i == RESOLUTION_TABLE_CUSTOM_INDEX && (width == 0 || height == 0)) {
            [resolutionDetailTitles addObject:SettingsLocalized(@"common.not_set")];
        }
        else {
            [resolutionDetailTitles addObject:[NSString stringWithFormat:@"%ld x %ld", (long)width, (long)height]];
        }
    }
    snapshot.resolutionDetailTitles = resolutionDetailTitles;

    NSInteger resolution = 2;
    for (int i = 0; i < RESOLUTION_TABLE_SIZE; i++) {
        if ((int)resolutionTable[i].height == [currentSettings.height intValue] &&
            (int)resolutionTable[i].width == [currentSettings.width intValue]) {
            resolution = i;
            break;
        }
    }
    snapshot.selectedResolutionIndex = resolution;
    snapshot.customResolutionWidth = (NSInteger)resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width;
    snapshot.customResolutionHeight = (NSInteger)resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height;
    snapshot.isFourKResolutionEnabled = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
    if (!snapshot.isFourKResolutionEnabled && snapshot.selectedResolutionIndex == 5) {
        snapshot.selectedResolutionIndex = 4;
    }

    NSMutableArray<NSString *> *codecTitles = [NSMutableArray arrayWithObject:@"H.264"];
    NSMutableArray<NSNumber *> *codecValues = [NSMutableArray arrayWithObject:@(CODEC_PREF_H264)];
    if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        [codecTitles addObject:@"HEVC"];
        [codecValues addObject:@(CODEC_PREF_HEVC)];
    }
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
        [codecTitles addObject:@"AV1"];
        [codecValues addObject:@(CODEC_PREF_AV1)];
    }
#endif
    [codecTitles addObject:SettingsLocalized(@"common.auto")];
    [codecValues addObject:@(CODEC_PREF_AUTO)];
    snapshot.codecTitles = codecTitles;
    snapshot.codecValues = codecValues;
    snapshot.preferredCodecValue = currentSettings.preferredCodec;
    if (![codecValues containsObject:@(snapshot.preferredCodecValue)]) {
        snapshot.preferredCodecValue = CODEC_PREF_AUTO;
    }

    snapshot.hdrSupported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10);
    snapshot.enableHdr = snapshot.hdrSupported ? currentSettings.enableHdr : NO;
    snapshot.useFramePacing = currentSettings.useFramePacing;
    snapshot.audioConfigSelection = AudioConfigSelectionFromChannelCount([currentSettings.audioConfig intValue]);

    snapshot.touchModeSelection = currentSettings.touchModeSelection;
    snapshot.optimizeGames = currentSettings.optimizeGames;
    snapshot.multiController = currentSettings.multiController;
    snapshot.swapABXYButtons = currentSettings.swapABXYButtons;
    snapshot.playAudioOnPC = currentSettings.playAudioOnPC;
    snapshot.btMouseSupport = currentSettings.btMouseSupport;
    snapshot.remoteMouseMode = currentSettings.remoteMouseMode;
    snapshot.captureMouseCursor = currentSettings.captureMouseCursor;
    snapshot.relativeMouseSensitivity = currentSettings.relativeMouseSensitivity;
    snapshot.statsOverlay = currentSettings.statsOverlay;
    snapshot.rumbleModeSelection = currentSettings.rumbleModeSelection;
    snapshot.externalMonitor = currentSettings.externalMonitor;
    snapshot.motionMode = [currentSettings.motionMode intValue];
    snapshot.virtualDisplayMode = [currentSettings.virtualDisplayMode intValue];
    snapshot.enableTouchSensitivity = currentSettings.enableTouchSensitivity;
    snapshot.touchSensitivityGlobal = currentSettings.touchSensitivityGlobal;
    snapshot.touchSensitivity = [currentSettings.touchSensitivity intValue];
    snapshot.videoAlignmentSelection = currentSettings.videoAlignmentSelection;
    snapshot.videoAlignmentMargin = (NSInteger)currentSettings.videoAlignmentMargin;
    snapshot.performanceOverlayPositionSelection = currentSettings.performanceOverlayPositionSelection;
    snapshot.performanceOverlayMargin = (NSInteger)currentSettings.performanceOverlayMargin;
    snapshot.floatingMenuEnabled = currentSettings.floatingMenuEnabled;
    snapshot.virtualButtonsEnabled = currentSettings.virtualButtonsEnabled;
    snapshot.virtualGamepadEnabled = currentSettings.virtualGamepadEnabled;
    snapshot.virtualButtonSchemeSelection = currentSettings.virtualButtonSchemeSelection;
    snapshot.virtualGamepadSchemeSelection = currentSettings.virtualGamepadSchemeSelection;
    snapshot.virtualGamepadOpacity = (NSInteger)lrint(currentSettings.virtualGamepadOpacity * 100.0);

    return snapshot;
}

- (NSInteger)chosenStreamWidthFromSnapshot:(SettingsFormSnapshot *)snapshot {
    BOOL lastSegmentSelected = snapshot.selectedResolutionIndex + 1 == snapshot.resolutionTitles.count;
    if (lastSegmentSelected) {
        return snapshot.customResolutionWidth;
    }

    return resolutionTable[snapshot.selectedResolutionIndex].width;
}

- (NSInteger)chosenStreamHeightFromSnapshot:(SettingsFormSnapshot *)snapshot {
    BOOL lastSegmentSelected = snapshot.selectedResolutionIndex + 1 == snapshot.resolutionTitles.count;
    if (lastSegmentSelected) {
        return snapshot.customResolutionHeight;
    }

    return resolutionTable[snapshot.selectedResolutionIndex].height;
}

- (void)saveSettingsUsingSnapshot:(SettingsFormSnapshot *)snapshot {
    DataManager *dataMan = [[DataManager alloc] init];
    NSInteger framerate = snapshot.framerate;
    NSInteger height = [self chosenStreamHeightFromSnapshot:snapshot];
    NSInteger width = [self chosenStreamWidthFromSnapshot:snapshot];
    NSInteger audioConfig = ChannelCountFromAudioConfigSelection(snapshot.audioConfigSelection);
    CGFloat virtualGamepadOpacity = MAX(0.05, MIN(snapshot.virtualGamepadOpacity / 100.0, 1.0));

    [dataMan saveSettingsWithBitrate:snapshot.bitrateKbps
                           framerate:framerate
                              height:height
                               width:width
                         audioConfig:audioConfig
                    onscreenControls:0
                       optimizeGames:snapshot.optimizeGames
                     multiController:snapshot.multiController
                     swapABXYButtons:snapshot.swapABXYButtons
                           audioOnPC:snapshot.playAudioOnPC
                      preferredCodec:(uint32_t)snapshot.preferredCodecValue
                      useFramePacing:snapshot.useFramePacing
                           enableHdr:snapshot.enableHdr
                      btMouseSupport:snapshot.btMouseSupport
                     remoteMouseMode:snapshot.remoteMouseMode
                  captureMouseCursor:snapshot.captureMouseCursor
            relativeMouseSensitivity:snapshot.relativeMouseSensitivity
                  touchModeSelection:snapshot.touchModeSelection
                        statsOverlay:snapshot.statsOverlay
                 rumbleModeSelection:snapshot.rumbleModeSelection
                     externalMonitor:snapshot.externalMonitor
              touchSensitivityGlobal:snapshot.touchSensitivityGlobal
              enableTouchSensitivity:snapshot.enableTouchSensitivity
                    touchSensitivity:snapshot.touchSensitivity
                          motionMode:snapshot.motionMode
                  virtualDisplayMode:snapshot.virtualDisplayMode
             videoAlignmentSelection:snapshot.videoAlignmentSelection
                videoAlignmentMargin:snapshot.videoAlignmentMargin
performanceOverlayPositionSelection:snapshot.performanceOverlayPositionSelection
         performanceOverlayMargin:snapshot.performanceOverlayMargin
              floatingMenuEnabled:snapshot.floatingMenuEnabled
             virtualButtonsEnabled:snapshot.virtualButtonsEnabled
             virtualGamepadEnabled:snapshot.virtualGamepadEnabled
       virtualButtonSchemeSelection:snapshot.virtualButtonSchemeSelection
     virtualGamepadSchemeSelection:snapshot.virtualGamepadSchemeSelection
             virtualGamepadOpacity:virtualGamepadOpacity];

    [dataMan saveVirtualGamepadOpacity:virtualGamepadOpacity
                     forSchemeSelection:snapshot.virtualGamepadSchemeSelection];
}

- (void)settingsHostingViewControllerDidRequestCustomResolution:(SettingsHostingViewController *)controller {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:SettingsLocalized(@"settings.custom_resolution.alert_title") message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = SettingsLocalized(@"settings.custom_resolution.width_placeholder");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width == 0 ? @"" : [NSString stringWithFormat:@"%d", (int)resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width];
    }];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = SettingsLocalized(@"settings.custom_resolution.height_placeholder");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height == 0 ? @"" : [NSString stringWithFormat:@"%d", (int)resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height];
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:SettingsLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray *textfields = alertController.textFields;
        UITextField *widthField = textfields[0];
        UITextField *heightField = textfields[1];

        long width = [widthField.text integerValue];
        long height = [heightField.text integerValue];
        if (width <= 0 || height <= 0) {
            return;
        }

        int maxResolutionDimension = 4096;
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                maxResolutionDimension = 8192;
            }
        }

        width = MIN(width, maxResolutionDimension);
        height = MIN(height, maxResolutionDimension);
        width = MAX(width, 256);
        height = MAX(height, 256);

        resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX] = CGSizeMake(width, height);
        [controller updateCustomResolutionWidth:(NSInteger)width height:(NSInteger)height];

        UIAlertController *infoAlert = [UIAlertController alertControllerWithTitle:@"Custom Resolution Selected"
                                                                           message:@"Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.\n\nResolutions that are not supported by your client or host PC may cause streaming errors."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [infoAlert addAction:[UIAlertAction actionWithTitle:SettingsLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:infoAlert animated:YES completion:nil];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)settingsHostingViewController:(SettingsHostingViewController *)controller didRequestOpenExternalURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return;
    }

    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }

    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)closeSettings:(id)sender {
    [self saveSettings];
    [self dismissViewControllerAnimated:YES completion:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MainFrameSettingsDidCloseNotification object:nil];
    }];
}

@end
