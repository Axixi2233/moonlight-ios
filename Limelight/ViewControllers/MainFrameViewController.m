//  MainFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

@import ImageIO;

#import "MainFrameViewController.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Connection.h"
#import "StreamManager.h"
#import "Utils.h"
#import "UIComputerView.h"
#import "UIAppView.h"
#import "DataManager.h"
#import "TemporarySettings.h"
#import "WakeOnLanManager.h"
#import "AppListResponse.h"
#import "ServerInfoResponse.h"
#import "StreamFrameViewController.h"
#import "LoadingFrameViewController.h"
#import "ComputerScrollView.h"
#import "TemporaryApp.h"
#import "IdManager.h"
#import "ConnectionHelper.h"
#import "Moonlight-Swift.h"

#if !TARGET_OS_TV
#import "SettingsViewController.h"
#import <objc/runtime.h>
#else
#import <sys/utsname.h>
#endif

#import <VideoToolbox/VideoToolbox.h>

#include <Limelight.h>

#define MainFrameLocalized(key) NSLocalizedString((key), nil)

static NSString * const MainFrameSettingsDidCloseNotification = @"MainFrameSettingsDidCloseNotification";
#if !TARGET_OS_TV
static void *MainFrameAppCellHostingBridgeAssociationKey = &MainFrameAppCellHostingBridgeAssociationKey;
#endif

@implementation MainFrameViewController {
    NSOperationQueue* _opQueue;
    TemporaryHost* _selectedHost;
    BOOL _showHiddenApps;
    NSString* _uniqueId;
    NSData* _clientCert;
    DiscoveryManager* _discMan;
    AppAssetManager* _appManager;
    StreamConfiguration* _streamConfig;
    UIAlertController* _pairAlert;
    LoadingFrameViewController* _loadingFrame;
    UINavigationController* _settingsNavigationController;
    UIView* _backgroundGradientView;
    CAGradientLayer* _backgroundGradientLayer;
    UIScrollView* hostScrollView;
#if !TARGET_OS_TV
    UIView* _hostSelectionContainerView;
    MainFrameHostListHostingViewController* _hostListHostingViewController;
    MainFrameHostActionSheetHostingViewController* _hostActionSheetHostingViewController;
    TemporaryHost* _hostActionSheetHost;
    MainFrameHostActionSheetHostingViewController* _appActionSheetHostingViewController;
    TemporaryApp* _appActionSheetApp;
    NSArray* _sortedHostSelectionList;
#endif
    NSArray* _sortedAppList;
    NSCache* _boxArtCache;
    bool _background;
    CGSize _lastHostScrollViewSize;
    CGSize _lastCollectionViewSize;
#if TARGET_OS_TV
    UITapGestureRecognizer* _menuRecognizer;
#endif
}
static NSMutableSet* hostList;

+ (UICollectionViewFlowLayout *)defaultCollectionViewLayout {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    BOOL isPhone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    layout.minimumLineSpacing = isPhone ? 12.0 : 20.0;
    layout.minimumInteritemSpacing = isPhone ? 12.0 : 20.0;
    layout.sectionInset = UIEdgeInsetsMake(isPhone ? 12.0 : 24.0, isPhone ? 6.0 : 28.0, isPhone ? 12.0 : 24.0, isPhone ? 6.0 : 28.0);
    layout.itemSize = isPhone ? CGSizeMake(110.0, 146.0) : CGSizeMake(182.0, 242.0);
    layout.estimatedItemSize = CGSizeZero;
    return layout;
}

- (void)installBackgroundGradientIfNeeded {
    if (_backgroundGradientView != nil) {
        return;
    }

    _backgroundGradientView = [[UIView alloc] initWithFrame:self.view.bounds];
    _backgroundGradientView.userInteractionEnabled = NO;
    _backgroundGradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _backgroundGradientLayer = [CAGradientLayer layer];
    _backgroundGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:0.95 green:0.89 blue:0.99 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.86 green:0.78 blue:0.98 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.70 green:0.63 blue:0.93 alpha:1.0].CGColor
    ];
    _backgroundGradientLayer.locations = @[@0.0, @0.45, @1.0];
    _backgroundGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _backgroundGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_backgroundGradientView.layer addSublayer:_backgroundGradientLayer];

    [self.view insertSubview:_backgroundGradientView atIndex:0];
}

- (void)updateBackgroundGradientFrame {
    [self installBackgroundGradientIfNeeded];
    _backgroundGradientView.frame = self.view.bounds;
    _backgroundGradientLayer.frame = _backgroundGradientView.bounds;
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

- (void)restorePrimaryNavigationButtons {
#if !TARGET_OS_TV
    if (self.settingsButton == nil) {
        UIImage *settingsImage = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            settingsImage = [[UIImage systemImageNamed:@"gear"] imageByApplyingSymbolConfiguration:symbolConfig];
        }

        if (settingsImage != nil) {
            self.settingsButton = [[UIBarButtonItem alloc] initWithImage:settingsImage
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];
        }
        else {
            self.settingsButton = [[UIBarButtonItem alloc] initWithTitle:MainFrameLocalized(@"settings.title")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];
        }
    }

    if (self.aboutButton == nil) {
        UIImage *aboutImage = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            aboutImage = [[UIImage systemImageNamed:@"info.circle"] imageByApplyingSymbolConfiguration:symbolConfig];
        }

        if (aboutImage != nil) {
            self.aboutButton = [[UIBarButtonItem alloc] initWithImage:aboutImage
                                                                style:UIBarButtonItemStylePlain
                                                               target:nil
                                                               action:nil];
        }
        else {
            self.aboutButton = [[UIBarButtonItem alloc] initWithTitle:MainFrameLocalized(@"about.title")
                                                                style:UIBarButtonItemStylePlain
                                                               target:nil
                                                               action:nil];
        }
    }

    self.navigationItem.leftBarButtonItems = @[self.settingsButton, self.aboutButton];
    self.settingsButton.enabled = YES;
    [self.settingsButton setTarget:self];
    [self.settingsButton setAction:@selector(openSettings:)];
    self.aboutButton.enabled = YES;
    [self.aboutButton setTarget:self];
    [self.aboutButton setAction:@selector(openAbout:)];

    if (self.upButton == nil) {
        self.upButton = [[UIBarButtonItem alloc] initWithTitle:nil
                                                         style:UIBarButtonItemStylePlain
                                                        target:nil
                                                        action:nil];
    }

    self.navigationItem.rightBarButtonItem = self.upButton;
    self.upButton.enabled = YES;
    [self updateRightNavigationButtonForCurrentState];
#endif
}

- (CGRect)hostScrollViewFrameForCurrentBounds {
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = self.view.safeAreaInsets;
    }

    CGRect bounds = self.view.bounds;
    CGFloat topInset = safeAreaInsets.top;
    CGFloat bottomInset = safeAreaInsets.bottom;
    CGFloat availableHeight = MAX(bounds.size.height - topInset - bottomInset, 0.0);

    return CGRectMake(0.0, topInset, bounds.size.width, availableHeight);
}

#if !TARGET_OS_TV
- (void)updateRightNavigationButtonForCurrentState {
    if (self.upButton == nil) {
        return;
    }

    [self.upButton setTarget:self];

    if (_selectedHost == nil) {
        [self.upButton setTitle:nil];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            self.upButton.image = [[UIImage systemImageNamed:@"plus.circle"] imageByApplyingSymbolConfiguration:symbolConfig];
        }
        else {
            [self.upButton setTitle:@"+"];
        }
        [self.upButton setAction:@selector(addHostClicked)];
        if (@available(iOS 26.0, *)) {
            [self.upButton setHidden:NO];
        }
    }
    else {
        self.upButton.image = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
            self.upButton.image = [[UIImage systemImageNamed:@"desktopcomputer"] imageByApplyingSymbolConfiguration:symbolConfig];
        }
        else {
            [self.upButton setTitle:MainFrameLocalized(@"home.device_list")];
        }
        [self.upButton setAction:@selector(showHostSelectionView)];
        if (@available(iOS 26.0, *)) {
            [self.upButton setHidden:NO];
        }
    }
}

- (void)installHostSelectionHostingControllerIfNeeded {
    if (_hostSelectionContainerView == nil) {
        _hostSelectionContainerView = [[UIView alloc] initWithFrame:[self hostScrollViewFrameForCurrentBounds]];
        _hostSelectionContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _hostSelectionContainerView.backgroundColor = [UIColor clearColor];
    }

    if (_hostListHostingViewController != nil) {
        return;
    }

    MainFrameHostListHostingViewController *hostingController = [[MainFrameHostListHostingViewController alloc] init];
    hostingController.delegate = (id<MainFrameHostListHostingViewControllerDelegate>)self;
    [self addChildViewController:hostingController];
    hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    hostingController.view.backgroundColor = [UIColor clearColor];
    [_hostSelectionContainerView addSubview:hostingController.view];
    [NSLayoutConstraint activateConstraints:@[
        [hostingController.view.leadingAnchor constraintEqualToAnchor:_hostSelectionContainerView.leadingAnchor],
        [hostingController.view.trailingAnchor constraintEqualToAnchor:_hostSelectionContainerView.trailingAnchor],
        [hostingController.view.topAnchor constraintEqualToAnchor:_hostSelectionContainerView.topAnchor],
        [hostingController.view.bottomAnchor constraintEqualToAnchor:_hostSelectionContainerView.bottomAnchor]
    ]];
    [hostingController didMoveToParentViewController:self];
    _hostListHostingViewController = hostingController;
}

- (NSString *)statusTextForHost:(TemporaryHost *)host {
    switch (host.state) {
        case StateOnline:
            if (host.pairState == PairStateUnpaired) {
                return MainFrameLocalized(@"home.host_status.online_unpaired");
            }
            return MainFrameLocalized(@"home.host_status.online");

        case StateOffline:
            return MainFrameLocalized(@"home.host_status.offline");

        case StateUnknown:
            return MainFrameLocalized(@"home.host_status.connecting");
    }
}

- (NSInteger)statusStyleForHost:(TemporaryHost *)host {
    switch (host.state) {
        case StateOnline:
            return host.pairState == PairStateUnpaired ? 2 : 1;

        case StateOffline:
            return 2;

        case StateUnknown:
            return 0;
    }
}

- (void)refreshHostSelectionSnapshot {
    [self installHostSelectionHostingControllerIfNeeded];

    NSMutableArray *items = [NSMutableArray array];
    _sortedHostSelectionList = [[hostList allObjects] sortedArrayUsingSelector:@selector(compareName:)];

    for (TemporaryHost *host in _sortedHostSelectionList) {
        MainFrameHostListItemSnapshot *snapshot = [[MainFrameHostListItemSnapshot alloc] init];
        snapshot.title = host.name ?: MainFrameLocalized(@"home.host.default_name");
        snapshot.subtitle = host.activeAddress ?: host.localAddress ?: host.address ?: MainFrameLocalized(@"home.host.waiting_address");
        snapshot.statusText = [self statusTextForHost:host];
        snapshot.statusStyle = [self statusStyleForHost:host];
        snapshot.showsActivity = (host.state == StateUnknown);
        snapshot.addCard = NO;
        [items addObject:snapshot];

        for (TemporaryApp* app in host.appList) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [self updateBoxArtCacheForApp:app];
            });
        }
    }

    [_hostListHostingViewController configureWithItems:items];
}
#endif

- (void)getAppGridMetricsForCollectionView:(UICollectionView *)collectionView
                               sectionInset:(UIEdgeInsets *)sectionInset
                           minimumLineSpacing:(CGFloat *)minimumLineSpacing
                      minimumInteritemSpacing:(CGFloat *)minimumInteritemSpacing
                                     itemSize:(CGSize *)itemSize {
    CGSize boundsSize = collectionView.bounds.size;
    BOOL isPhone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    BOOL isLandscape = boundsSize.width > boundsSize.height;
    CGFloat minimumOuterInset = isPhone ? (isLandscape ? 8.0 : 6.0) : 28.0;
    CGFloat verticalInset = isPhone ? 12.0 : 24.0;
    CGFloat interitemSpacing = isPhone ? (isLandscape ? 8.0 : 12.0) : 20.0;
    CGFloat lineSpacing = isPhone ? 12.0 : 20.0;
    CGSize preferredItemSize = CGSizeZero;

    if (isPhone) {
        preferredItemSize = isLandscape ? CGSizeMake(118.0, 157.0) : CGSizeMake(110.0, 146.0);
    }
    else {
        preferredItemSize = CGSizeMake(182.0, 242.0);
    }

    UIEdgeInsets contentInset = collectionView.contentInset;
    if (@available(iOS 11.0, *)) {
        contentInset = collectionView.adjustedContentInset;
    }

    CGFloat usableWidth = boundsSize.width - contentInset.left - contentInset.right;
    CGFloat contentWidth = MAX(usableWidth - (minimumOuterInset * 2.0), preferredItemSize.width);
    NSInteger columnCount = MAX((NSInteger)floor((contentWidth + interitemSpacing) / (preferredItemSize.width + interitemSpacing)), 1);
    CGFloat usedWidth = (preferredItemSize.width * columnCount) + (interitemSpacing * MAX(columnCount - 1, 0));
    CGFloat horizontalInset = MAX(floor((usableWidth - usedWidth) / 2.0), minimumOuterInset);

    if (sectionInset != NULL) {
        *sectionInset = UIEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);
    }

    if (minimumLineSpacing != NULL) {
        *minimumLineSpacing = lineSpacing;
    }

    if (minimumInteritemSpacing != NULL) {
        *minimumInteritemSpacing = interitemSpacing;
    }

    if (itemSize != NULL) {
        *itemSize = preferredItemSize;
    }
}

- (void)updateCollectionViewLayoutForCurrentBounds {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]]) {
        return;
    }

    CGSize boundsSize = self.collectionView.bounds.size;
    if (CGSizeEqualToSize(boundsSize, CGSizeZero) || CGSizeEqualToSize(boundsSize, _lastCollectionViewSize)) {
        return;
    }

    _lastCollectionViewSize = boundsSize;

    UIEdgeInsets sectionInset = UIEdgeInsetsZero;
    CGFloat lineSpacing = 0.0;
    CGFloat interitemSpacing = 0.0;
    CGSize itemSize = CGSizeZero;
    [self getAppGridMetricsForCollectionView:self.collectionView
                                 sectionInset:&sectionInset
                             minimumLineSpacing:&lineSpacing
                        minimumInteritemSpacing:&interitemSpacing
                                       itemSize:&itemSize];

    layout.sectionInset = sectionInset;
    layout.minimumLineSpacing = lineSpacing;
    layout.minimumInteritemSpacing = interitemSpacing;
    layout.itemSize = itemSize;
    [layout invalidateLayout];
}

- (void)refreshAppListLayoutForCurrentNavigationState {
    if (_selectedHost == nil) {
        return;
    }

    [self adjustScrollViewForSafeArea:self.collectionView];
    [self.navigationController.view setNeedsLayout];
    [self.navigationController.view layoutIfNeeded];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self updateCollectionViewLayoutForCurrentBounds];
    [self.collectionView.collectionViewLayout invalidateLayout];

    if (@available(iOS 11.0, *)) {
        CGFloat minimumOffsetY = -self.collectionView.adjustedContentInset.top;
        if (self.collectionView.contentOffset.y < minimumOffsetY) {
            self.collectionView.contentOffset = CGPointMake(self.collectionView.contentOffset.x, minimumOffsetY);
        }
    }
}

- (instancetype)init {
    return [super initWithCollectionViewLayout:[[self class] defaultCollectionViewLayout]];
}

- (void)openStreamFrame {
    StreamFrameViewController *streamFrame = [[StreamFrameViewController alloc] init];
    streamFrame.streamConfig = _streamConfig;
    [self.navigationController pushViewController:streamFrame animated:YES];
}

- (void)openSettings:(id)sender {
#if !TARGET_OS_TV
    if (_settingsNavigationController != nil && _settingsNavigationController.presentingViewController != nil) {
        return;
    }

    [self restorePrimaryNavigationButtons];

    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    settingsNavigationController.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self presentViewController:settingsNavigationController animated:YES completion:nil];
    _settingsNavigationController = settingsNavigationController;
#endif
}

- (void)openAbout:(id)sender {
#if !TARGET_OS_TV
    if (@available(iOS 13.0, *)) {
        AboutHostingViewController *aboutViewController = [[AboutHostingViewController alloc] init];
        [self.navigationController pushViewController:aboutViewController animated:YES];
    }
#endif
}

- (void)startPairing:(NSString *)PIN {
    // Needs to be synchronous to ensure the alert is shown before any potential
    // failure callback could be invoked.
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->_pairAlert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.pairing.title")
                                                               message:[NSString stringWithFormat:MainFrameLocalized(@"home.pairing.message"), PIN]
                                                        preferredStyle:UIAlertControllerStyleAlert];
        [self->_pairAlert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
            self->_pairAlert = nil;
            [self->_discMan startDiscovery];
            [self hideLoadingFrame: ^{
                [self showHostSelectionView];
            }];
        }]];
        [[self activeViewController] presentViewController:self->_pairAlert animated:YES completion:nil];
    });
}

- (void)displayPairingFailureDialog:(NSString *)message {
    UIAlertController* failedDialog = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.pairing.failed_title")
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:failedDialog];
    [failedDialog addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
    
    [_discMan startDiscovery];
    
    [self hideLoadingFrame: ^{
        [self showHostSelectionView];
        [[self activeViewController] presentViewController:failedDialog animated:YES completion:nil];
    }];
}

- (void)pairFailed:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_pairAlert != nil) {
            [self->_pairAlert dismissViewControllerAnimated:YES completion:^{
                [self displayPairingFailureDialog:message];
            }];
            self->_pairAlert = nil;
        }
    });
}

- (void)pairSuccessful:(NSData*)serverCert {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Store the cert from pairing with the host
        self->_selectedHost.serverCert = serverCert;
        
        [self->_pairAlert dismissViewControllerAnimated:YES completion:nil];
        self->_pairAlert = nil;
        
        [self->_discMan startDiscovery];
        [self alreadyPaired];
    });
}

- (void)disableUpButton {
#if !TARGET_OS_TV
    [self updateRightNavigationButtonForCurrentState];
#endif
}

- (void)enableUpButton {
#if !TARGET_OS_TV
    [self updateRightNavigationButtonForCurrentState];
#endif
}

- (void)updateTitle {
    if (_selectedHost != nil) {
        self.title = _selectedHost.name;
    }
    else {
        NSString *appTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (appTitle.length == 0) {
            appTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        }
        self.title = appTitle.length > 0 ? appTitle : @"Asisi Link";
    }
}

- (void)alreadyPaired {
    BOOL usingCachedAppList = false;
    
    // Capture the host here because it can change once we
    // leave the main thread
    TemporaryHost* host = _selectedHost;
    if (host == nil) {
        [self hideLoadingFrame: nil];
        return;
    }
    
    if ([host.appList count] > 0) {
        usingCachedAppList = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (host != self->_selectedHost) {
                [self hideLoadingFrame: nil];
                return;
            }
            
            [self updateAppsForHost:host];
            [self hideLoadingFrame: nil];
        });
    }
    Log(LOG_I, @"Using cached app list: %d", usingCachedAppList);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Exempt this host from discovery while handling the applist query
        [self->_discMan pauseDiscoveryForHost:host];
        
        AppListResponse* appListResp = [ConnectionHelper getAppListForHost:host];
        
        [self->_discMan resumeDiscoveryForHost:host];

        if (![appListResp isStatusOk] || [appListResp getAppList] == nil) {
            Log(LOG_W, @"Failed to get applist: %@", appListResp.statusMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:@"Connection Interrupted"
                                                                                      message:appListResp.statusMessage
                                                                               preferredStyle:UIAlertControllerStyleAlert];
                [Utils addHelpOptionToDialog:applistAlert];
                [applistAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self hideLoadingFrame: ^{
                    [self showHostSelectionView];
                    [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                }];
                host.state = StateOffline;
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateApplist:[appListResp getAppList] forHost:host];

                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                [self updateAppsForHost:host];
                [self->_appManager stopRetrieving];
                [self->_appManager retrieveAssetsFromHost:host];
                [self hideLoadingFrame: nil];
            });
        }
    });
}

- (void) updateAppEntry:(TemporaryApp*)app forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];

    for (TemporaryApp* savedApp in newHostAppList) {
        if ([app.id isEqualToString:savedApp.id]) {
            savedApp.name = app.name;
            savedApp.hdrSupported = app.hdrSupported;
            savedApp.hidden = app.hidden;
            
            host.appList = newHostAppList;

            [database updateAppsForExistingHost:host];
            return;
        }
    }
}
    
- (void) updateApplist:(NSSet*) newList forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];
    
    for (TemporaryApp* app in newList) {
        BOOL appAlreadyInList = NO;
        for (TemporaryApp* savedApp in newHostAppList) {
            if ([app.id isEqualToString:savedApp.id]) {
                savedApp.name = app.name;
                savedApp.hdrSupported = app.hdrSupported;
                // Don't propagate hidden, because we want the local data to prevail
                appAlreadyInList = YES;
                break;
            }
        }
        if (!appAlreadyInList) {
            app.host = host;
            [newHostAppList addObject:app];
        }
    }
    
    BOOL appWasRemoved;
    do {
        appWasRemoved = NO;
        
        for (TemporaryApp* app in newHostAppList) {
            appWasRemoved = YES;
            for (TemporaryApp* mergedApp in newList) {
                if ([mergedApp.id isEqualToString:app.id]) {
                    appWasRemoved = NO;
                    break;
                }
            }
            if (appWasRemoved) {
                // Removing the app mutates the list we're iterating (which isn't legal).
                // We need to jump out of this loop and restart enumeration.
                
                [newHostAppList removeObject:app];
                
                // It's important to remove the app record from the database
                // since we'll have a constraint violation now that appList
                // doesn't have this app in it.
                [database removeApp:app];
                
                break;
            }
        }
        
        // Keep looping until the list is no longer being mutated
    } while (appWasRemoved);
    
    host.appList = newHostAppList;

    [database updateAppsForExistingHost:host];
    
    // This host may be eligible for a shortcut now that the app list
    // has been populated
    [self updateHostShortcuts];
}

- (void)showHostSelectionView {
#if TARGET_OS_TV
    // Remove the menu button intercept to allow the app to exit
    // when at the host selection view.
    [self.navigationController.view removeGestureRecognizer:_menuRecognizer];
#endif
    
    [_appManager stopRetrieving];
    _showHiddenApps = NO;
    _selectedHost = nil;
    _sortedAppList = nil;
    
    [self updateTitle];
    [self disableUpButton];
    
    [self.collectionView reloadData];
#if !TARGET_OS_TV
    [self installHostSelectionHostingControllerIfNeeded];
    [self refreshHostSelectionSnapshot];
    [self.view addSubview:_hostSelectionContainerView];
#else
    [self.view addSubview:hostScrollView];
#endif
}

- (void) receivedAssetForApp:(TemporaryApp*)app {
    // Update the box art cache now so we don't have to do it
    // on the main thread
    [self updateBoxArtCacheForApp:app];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

- (void)displayDnsFailedDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.network_error.title")
                                                                   message:MainFrameLocalized(@"home.network_error.dns_failed")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:alert];
    [alert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
    [[self activeViewController] presentViewController:alert animated:YES completion:nil];
}

- (void) hostClicked:(TemporaryHost *)host view:(UIView *)view {
    // Treat clicks on offline hosts to be long clicks
    // This shows the context menu with wake, delete, etc. rather
    // than just hanging for a while and failing as we would in this
    // code path.
    if (host.state != StateOnline && view != nil) {
        [self hostLongClicked:host view:view];
        return;
    }
    
    Log(LOG_D, @"Clicked host: %@", host.name);
    _selectedHost = host;
    [self updateTitle];
    [self enableUpButton];
    [self disableNavigation];
    
#if TARGET_OS_TV
    // Intercept the menu key to go back to the host page
    [self.navigationController.view addGestureRecognizer:_menuRecognizer];
#endif
    
    // If we are online, paired, and have a cached app list, skip straight
    // to the app grid without a loading frame. This is the fast path that users
    // should hit most. Check for a valid view because we don't want to hit the fast
    // path after coming back from streaming, since we need to fetch serverinfo too
    // so that our active game data is correct.
    if (host.state == StateOnline && host.pairState == PairStatePaired && host.appList.count > 0 && view != nil) {
        [self alreadyPaired];
        return;
    }
    
    [self showLoadingFrame: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Wait for the PC's status to be known
            while (host.state == StateUnknown) {
                sleep(1);
            }
            
            // Don't bother polling if the server is already offline
            if (host.state == StateOffline) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        [self showHostSelectionView];
                    }];
                });
                return;
            }
            
            HttpManager* hMan = [[HttpManager alloc] initWithHost:host];
            ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
            
            // Exempt this host from discovery while handling the serverinfo request
            [self->_discMan pauseDiscoveryForHost:host];
            [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
            [self->_discMan resumeDiscoveryForHost:host];
            
            if (![serverInfoResp isStatusOk]) {
                Log(LOG_W, @"Failed to get server info: %@", serverInfoResp.statusMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (host != self->_selectedHost) {
                        [self hideLoadingFrame:nil];
                        return;
                    }
                    
                    UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.connection_failed.title")
                                                                            message:serverInfoResp.statusMessage
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [Utils addHelpOptionToDialog:applistAlert];
                    [applistAlert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                    
                    // Only display an alert if this was the result of a real
                    // user action, not just passively entering the foreground again
                    [self hideLoadingFrame: ^{
                        [self showHostSelectionView];
                        if (view != nil) {
                            [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                        }
                    }];
                    
                    host.state = StateOffline;
                });
            } else {
                // Update the host object with this data
                [serverInfoResp populateHost:host];
                if (host.pairState == PairStatePaired) {
                    Log(LOG_I, @"Already Paired");
                    [self alreadyPaired];
                }
                // Only pair when this was the result of explicit user action
                else if (view != nil) {
                    Log(LOG_I, @"Trying to pair");
                    // Polling the server while pairing causes the server to screw up
                    [self->_discMan stopDiscoveryBlocking];
                    PairManager* pMan = [[PairManager alloc] initWithManager:hMan clientCert:self->_clientCert callback:self];
                    [self->_opQueue addOperation:pMan];
                }
                else {
                    // Not user action, so just return to host screen
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoadingFrame:^{
                            [self showHostSelectionView];
                        }];
                    });
                }
            }
        });
    }];
}

- (UIViewController*) activeViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (void)hostLongClicked:(TemporaryHost *)host view:(UIView *)view {
    Log(LOG_D, @"Long clicked host: %@", host.name);
    NSString *message = [self statusMessageForHost:host];
    NSMutableArray<MainFrameHostActionSheetItem *> *items = [NSMutableArray array];

    if (host.state != StateOnline) {
        MainFrameHostActionSheetItem *wakeItem = [[MainFrameHostActionSheetItem alloc] init];
        wakeItem.identifier = @"wake";
        wakeItem.title = MainFrameLocalized(@"home.host_action.wake.title");
        wakeItem.subtitle = MainFrameLocalized(@"home.host_action.wake.subtitle");
        [items addObject:wakeItem];

        MainFrameHostActionSheetItem *eosItem = [[MainFrameHostActionSheetItem alloc] init];
        eosItem.identifier = @"nvidia_eos";
        eosItem.title = MainFrameLocalized(@"home.host_action.eos.title");
        eosItem.subtitle = MainFrameLocalized(@"home.host_action.eos.subtitle");
        [items addObject:eosItem];

        MainFrameHostActionSheetItem *helpItem = [[MainFrameHostActionSheetItem alloc] init];
        helpItem.identifier = @"connection_help";
        helpItem.title = MainFrameLocalized(@"home.host_action.help.title");
        helpItem.subtitle = MainFrameLocalized(@"home.host_action.help.subtitle");
        [items addObject:helpItem];
    }
    else if (host.pairState == PairStatePaired) {
        MainFrameHostActionSheetItem *appsItem = [[MainFrameHostActionSheetItem alloc] init];
        appsItem.identifier = @"view_all_apps";
        appsItem.title = MainFrameLocalized(@"home.host_action.view_all_apps.title");
        appsItem.subtitle = MainFrameLocalized(@"home.host_action.view_all_apps.subtitle");
        [items addObject:appsItem];

        if (host.isNvidiaServerSoftware) {
            MainFrameHostActionSheetItem *eosItem = [[MainFrameHostActionSheetItem alloc] init];
            eosItem.identifier = @"nvidia_eos";
            eosItem.title = MainFrameLocalized(@"home.host_action.eos.title");
            eosItem.subtitle = MainFrameLocalized(@"home.host_action.eos.subtitle");
            [items addObject:eosItem];
        }
    }

    MainFrameHostActionSheetItem *networkItem = [[MainFrameHostActionSheetItem alloc] init];
    networkItem.identifier = @"test_network";
    networkItem.title = MainFrameLocalized(@"home.host_action.test_network.title");
    networkItem.subtitle = MainFrameLocalized(@"home.host_action.test_network.subtitle");
    [items addObject:networkItem];

    MainFrameHostActionSheetItem *removeItem = [[MainFrameHostActionSheetItem alloc] init];
    removeItem.identifier = @"remove_host";
    removeItem.title = MainFrameLocalized(@"home.host_action.remove.title");
    removeItem.subtitle = MainFrameLocalized(@"home.host_action.remove.subtitle");
    removeItem.destructive = YES;
    [items addObject:removeItem];

    MainFrameHostActionSheetHostingViewController *controller = [[MainFrameHostActionSheetHostingViewController alloc] init];
    controller.delegate = (id<MainFrameHostActionSheetHostingViewControllerDelegate>)self;
    [controller configureWithTitle:host.name ?: @"PC" subtitle:message ?: @"" items:items];
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;

    _hostActionSheetHost = host;
    _hostActionSheetHostingViewController = controller;
    [[self activeViewController] presentViewController:controller animated:YES completion:nil];
}

- (NSString *)statusMessageForHost:(TemporaryHost *)host {
    switch (host.state) {
        case StateOffline:
            return @"Offline";

        case StateOnline:
            return host.pairState == PairStatePaired ? MainFrameLocalized(@"home.host_status.online_paired") : MainFrameLocalized(@"home.host_status.online_not_paired");

        case StateUnknown:
            return MainFrameLocalized(@"home.host_status.connecting");
    }
}

- (void)performHostActionWithIdentifier:(NSString *)identifier host:(TemporaryHost *)host {
    if (host == nil || identifier.length == 0) {
        return;
    }

    if ([identifier isEqualToString:@"wake"]) {
        [self presentWakeHostAlertForHost:host];
    }
    else if ([identifier isEqualToString:@"view_all_apps"]) {
        _showHiddenApps = YES;
        [self hostClicked:host view:self.view];
    }
    else if ([identifier isEqualToString:@"nvidia_eos"]) {
        [Utils launchUrl:@"https://github.com/moonlight-stream/moonlight-docs/wiki/NVIDIA-GameStream-End-Of-Service-Announcement-FAQ"];
    }
    else if ([identifier isEqualToString:@"connection_help"]) {
        [Utils launchUrl:@"https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"];
    }
    else if ([identifier isEqualToString:@"test_network"]) {
        [self runNetworkTest];
    }
    else if ([identifier isEqualToString:@"remove_host"]) {
        [self removeHostFromList:host];
    }
}

- (void)presentWakeHostAlertForHost:(TemporaryHost *)host {
    UIAlertController* wolAlert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.wol.title") message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [wolAlert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
    if (host.mac == nil || [host.mac isEqualToString:@"00:00:00:00:00:00"]) {
        wolAlert.message = MainFrameLocalized(@"home.wol.unknown_mac");
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [WakeOnLanManager wakeHost:host];
        });
        wolAlert.message = MainFrameLocalized(@"home.wol.sent");
    }
    [[self activeViewController] presentViewController:wolAlert animated:YES completion:nil];
}

- (void)runNetworkTest {
    [self showLoadingFrame:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            unsigned int portTestResult = LiTestClientConnectivity(CONN_TEST_SERVER, 443, ML_PORT_FLAG_ALL);
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self hideLoadingFrame:^{
                    NSString* message;

                    if (portTestResult == 0) {
                        message = MainFrameLocalized(@"home.network_test.passed");
                    }
                    else if (portTestResult == ML_TEST_RESULT_INCONCLUSIVE) {
                        message = MainFrameLocalized(@"home.network_test.inconclusive");
                    }
                    else {
                        char blockedPorts[512];
                        LiStringifyPortFlags(portTestResult, "\n", blockedPorts, sizeof(blockedPorts));
                        message = [NSString stringWithFormat:MainFrameLocalized(@"home.network_test.blocked"), blockedPorts];
                    }

                    UIAlertController* netTestAlert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.network_test.title") message:message preferredStyle:UIAlertControllerStyleAlert];
                    [netTestAlert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                    [[self activeViewController] presentViewController:netTestAlert animated:YES completion:nil];
                }];
            });
        });
    }];
}

- (void)removeHostFromList:(TemporaryHost *)host {
    [_discMan removeHostFromDiscovery:host];
    DataManager* dataMan = [[DataManager alloc] init];
    [dataMan removeHost:host];
    @synchronized(hostList) {
        [hostList removeObject:host];
        [self updateAllHosts:[hostList allObjects]];
    }
}

- (void) addHostClicked {
    Log(LOG_D, @"Clicked add host");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.manual_add.title")
                                                                   message:MainFrameLocalized(@"home.manual_add.message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = MainFrameLocalized(@"home.manual_add.placeholder");
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.returnKeyType = UIReturnKeyDone;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"home.manual_add.add")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        [weakSelf submitManualHostAddress:[[textField.text ?: @"" trim] copy]];
    }]];

    [[self activeViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)submitManualHostAddress:(NSString *)hostAddress {
    if (hostAddress.length == 0) {
        return;
    }

    [self showLoadingFrame:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self->_discMan discoverHost:hostAddress withCallback:^(TemporaryHost* host, NSString* error){
                if (host != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoadingFrame:^{
                            @synchronized(hostList) {
                                [hostList addObject:host];
                            }
                            [self updateHosts];
                        }];
                    });
                } else {
                    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443,
                                                                            ML_PORT_FLAG_TCP_47984 | ML_PORT_FLAG_TCP_47989);
                    if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
                        error = [error stringByAppendingString:MainFrameLocalized(@"home.host_add.restricted_network_suffix")];
                    }

                    UIAlertController* hostNotFoundAlert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"home.notice.title") message:error preferredStyle:UIAlertControllerStyleAlert];
                    [Utils addHelpOptionToDialog:hostNotFoundAlert];
                    [hostNotFoundAlert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoadingFrame:^{
                            [[self activeViewController] presentViewController:hostNotFoundAlert animated:YES completion:nil];
                        }];
                    });
                }
            }];
        });
    }];
}

- (void) prepareToStreamApp:(TemporaryApp *)app {
    _streamConfig = [[StreamConfiguration alloc] init];
    _streamConfig.host = app.host.activeAddress;
    _streamConfig.httpsPort = app.host.httpsPort;
    _streamConfig.appID = app.id;
    _streamConfig.appName = app.name;
    _streamConfig.serverCert = app.host.serverCert;
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* streamSettings = [dataMan getSettings];
    
    _streamConfig.frameRate = [streamSettings.framerate intValue];
    if (@available(iOS 10.3, *)) {
        // Don't stream more FPS than the display can show
        if (_streamConfig.frameRate > [UIScreen mainScreen].maximumFramesPerSecond) {
            _streamConfig.frameRate = (int)[UIScreen mainScreen].maximumFramesPerSecond;
            Log(LOG_W, @"Clamping FPS to maximum refresh rate: %d", _streamConfig.frameRate);
        }
    }
    
    _streamConfig.height = [streamSettings.height intValue];
    _streamConfig.width = [streamSettings.width intValue];
#if TARGET_OS_TV
    // Don't allow streaming 4K on the Apple TV HD
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "AppleTV5,3") == 0 && _streamConfig.height >= 2160) {
        Log(LOG_W, @"4K streaming not supported on Apple TV HD");
        _streamConfig.width = 1920;
        _streamConfig.height = 1080;
    }
#endif
    
    _streamConfig.bitRate = [streamSettings.bitrate intValue];
    _streamConfig.optimizeGameSettings = streamSettings.optimizeGames;
    _streamConfig.playAudioOnPC = streamSettings.playAudioOnPC;
    _streamConfig.useFramePacing = streamSettings.useFramePacing;
    _streamConfig.swapABXYButtons = streamSettings.swapABXYButtons;
    _streamConfig.motionMode = [streamSettings.motionMode intValue];
    _streamConfig.virtualDisplayMode = [streamSettings.virtualDisplayMode intValue];

    // multiController must be set before calling getConnectedGamepadMask
    _streamConfig.multiController = streamSettings.multiController;
    _streamConfig.gamepadMask = [ControllerSupport getConnectedGamepadMask:_streamConfig];
    
    // Probe for supported channel configurations
    int physicalOutputChannels = (int)[AVAudioSession sharedInstance].maximumOutputNumberOfChannels;
    Log(LOG_I, @"Audio device supports %d channels", physicalOutputChannels);
    
    int requestedChannels = [streamSettings.audioConfig intValue];
    int numberOfChannels = requestedChannels == 0 ? physicalOutputChannels : MIN(requestedChannels, physicalOutputChannels);
    Log(LOG_I, @"Selected number of audio channels %d", numberOfChannels);
    if (numberOfChannels >= 8) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_71_SURROUND;
    }
    else if (numberOfChannels >= 6) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_51_SURROUND;
    }
    else {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    }
    
    _streamConfig.serverCodecModeSupport = app.host.serverCodecModeSupport;
    
    switch (streamSettings.preferredCodec) {
        case CODEC_PREF_AV1:
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN8;
            }
#endif
            // Fall-through
            
        case CODEC_PREF_AUTO:
        case CODEC_PREF_HEVC:
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
            }
            // Fall-through
            
        case CODEC_PREF_H264:
            _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H264;
            break;
    }
    
    // HEVC is supported if the user wants it (or it's required by the chosen resolution) and the SoC supports it
    if ((_streamConfig.width > 4096 || _streamConfig.height > 4096 || streamSettings.enableHdr) && VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
        
        // HEVC Main10 is supported if the user wants it and the display supports it
        if (streamSettings.enableHdr && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
            _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10;
        }
    }
    
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    // Add the AV1 Main10 format if AV1 and HDR are both enabled and supported
    if ((_streamConfig.supportedVideoFormats & VIDEO_FORMAT_MASK_AV1) && streamSettings.enableHdr &&
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
        _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN10;
    }
#endif
}

- (void)appLongClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Long clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
    TemporaryApp* currentApp = [self findRunningApp:app.host];

    NSString *message;
    if (currentApp == nil || [app.id isEqualToString:currentApp.id]) {
        message = app.hidden ? MainFrameLocalized(@"home.app.hidden") : @"";
    }
    else {
        message = [NSString stringWithFormat:MainFrameLocalized(@"home.app.currently_running"), currentApp.name];
    }

    NSMutableArray<MainFrameHostActionSheetItem *> *items = [NSMutableArray array];

    MainFrameHostActionSheetItem *primaryItem = [[MainFrameHostActionSheetItem alloc] init];
    primaryItem.identifier = @"launch_or_resume";
    primaryItem.title = currentApp == nil ? MainFrameLocalized(@"home.app_action.launch.title") : ([app.id isEqualToString:currentApp.id] ? MainFrameLocalized(@"home.app_action.resume.title") : MainFrameLocalized(@"home.app_action.resume_running.title"));
    primaryItem.subtitle = currentApp == nil ? MainFrameLocalized(@"home.app_action.launch.subtitle") : ([app.id isEqualToString:currentApp.id] ? MainFrameLocalized(@"home.app_action.resume.subtitle") : MainFrameLocalized(@"home.app_action.resume_running.subtitle"));
    [items addObject:primaryItem];

    if (currentApp != nil) {
        MainFrameHostActionSheetItem *quitItem = [[MainFrameHostActionSheetItem alloc] init];
        quitItem.identifier = @"quit";
        quitItem.title = [app.id isEqualToString:currentApp.id] ? MainFrameLocalized(@"home.app_action.quit.title") : MainFrameLocalized(@"home.app_action.quit_and_start.title");
        quitItem.subtitle = [app.id isEqualToString:currentApp.id] ? MainFrameLocalized(@"home.app_action.quit.subtitle") : MainFrameLocalized(@"home.app_action.quit_and_start.subtitle");
        quitItem.destructive = YES;
        [items addObject:quitItem];
    }

    if (currentApp == nil || ![app.id isEqualToString:currentApp.id] || app.hidden) {
        MainFrameHostActionSheetItem *visibilityItem = [[MainFrameHostActionSheetItem alloc] init];
        visibilityItem.identifier = @"toggle_visibility";
        visibilityItem.title = app.hidden ? MainFrameLocalized(@"home.app_action.show.title") : MainFrameLocalized(@"home.app_action.hide.title");
        visibilityItem.subtitle = app.hidden ? MainFrameLocalized(@"home.app_action.show.subtitle") : MainFrameLocalized(@"home.app_action.hide.subtitle");
        visibilityItem.destructive = !app.hidden;
        [items addObject:visibilityItem];
    }

    MainFrameHostActionSheetHostingViewController *controller = [[MainFrameHostActionSheetHostingViewController alloc] init];
    controller.delegate = (id<MainFrameHostActionSheetHostingViewControllerDelegate>)self;
    [controller configureWithTitle:app.name ?: MainFrameLocalized(@"home.app.default_name") subtitle:message ?: @"" items:items];
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;

    _appActionSheetApp = app;
    _appActionSheetHostingViewController = controller;
    [[self activeViewController] presentViewController:controller animated:YES completion:nil];
}

- (void) appClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
    if ([self findRunningApp:app.host]) {
        // If there's a running app, display a menu
        [self appLongClicked:app view:view];
    } else {
        [self prepareToStreamApp:app];
        [self openStreamFrame];
    }
}

- (void)performAppActionWithIdentifier:(NSString *)identifier app:(TemporaryApp *)app {
    if (app == nil || identifier.length == 0) {
        return;
    }

    TemporaryApp *currentApp = [self findRunningApp:app.host];

    if ([identifier isEqualToString:@"launch_or_resume"]) {
        if (currentApp != nil) {
            Log(LOG_I, @"Resuming application: %@", currentApp.name);
            [self prepareToStreamApp:currentApp];
        }
        else {
            Log(LOG_I, @"Launching application: %@", app.name);
            [self prepareToStreamApp:app];
        }

        [self openStreamFrame];
        return;
    }

    if ([identifier isEqualToString:@"toggle_visibility"]) {
        app.hidden = !app.hidden;
        [self updateAppEntry:app forHost:app.host];
        [self.collectionView reloadData];
        return;
    }

    if ([identifier isEqualToString:@"quit"] && currentApp != nil) {
        Log(LOG_I, @"Quitting application: %@", currentApp.name);
        [self showLoadingFrame:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                HttpManager* hMan = [[HttpManager alloc] initWithHost:app.host];
                HttpResponse* quitResponse = [[HttpResponse alloc] init];
                HttpRequest* quitRequest = [HttpRequest requestForResponse: quitResponse withUrlRequest:[hMan newQuitAppRequest]];

                [self->_discMan pauseDiscoveryForHost:app.host];
                [hMan executeRequestSynchronously:quitRequest];
                if (quitResponse.statusCode == 200) {
                    ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
                    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                            fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
                    if (![serverInfoResp isStatusOk] || [[serverInfoResp getStringTag:@"state"] hasSuffix:@"_SERVER_BUSY"]) {
                        quitResponse.statusCode = 599;
                    }
                    else if ([serverInfoResp isStatusOk]) {
                        [serverInfoResp populateHost:app.host];
                    }
                }
                [self->_discMan resumeDiscoveryForHost:app.host];

                if (quitResponse.statusCode != 200) {
                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:MainFrameLocalized(@"stream.quit_app.failed_title")
                                                                                   message:MainFrameLocalized(@"stream.quit_app.failed_message")
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:MainFrameLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateAppsForHost:app.host];
                        [self hideLoadingFrame:^{
                            [[self activeViewController] presentViewController:alert animated:YES completion:nil];
                        }];
                    });
                }
                else {
                    app.host.currentGame = @"0";
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateAppsForHost:app.host];
                        if (![app.id isEqualToString:currentApp.id]) {
                            [self prepareToStreamApp:app];
                            [self hideLoadingFrame:^{
                                [self openStreamFrame];
                            }];
                        }
                        else {
                            [self hideLoadingFrame:nil];
                        }
                    });
                }
            });
        }];
    }
}

- (TemporaryApp*) findRunningApp:(TemporaryHost*)host {
    for (TemporaryApp* app in host.appList) {
        if ([app.id isEqualToString:host.currentGame]) {
            return app;
        }
    }
    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    UIView *selectedView = [collectionView cellForItemAtIndexPath:indexPath];
    [self appClicked:_sortedAppList[indexPath.row] view:selectedView];
}

- (void) showLoadingFrame:(void (^)(void))completion {
    [_loadingFrame showLoadingFrame:completion];
}

- (void) hideLoadingFrame:(void (^)(void))completion {
    [self enableNavigation];
    [_loadingFrame dismissLoadingFrame:completion];
}

- (void)adjustScrollViewForSafeArea:(UIScrollView*)view {
    if (@available(iOS 11.0, *)) {
        if (self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20) {
            view.contentInset = UIEdgeInsetsMake(0, 20, 0, 20);
        }
        else {
            view.contentInset = UIEdgeInsetsZero;
        }
    }
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    
    [self adjustScrollViewForSafeArea:self.collectionView];
    [self adjustScrollViewForSafeArea:self->hostScrollView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self updateBackgroundGradientFrame];

    CGSize previousCollectionSize = _lastCollectionViewSize;
    [self updateCollectionViewLayoutForCurrentBounds];
    if (!CGSizeEqualToSize(previousCollectionSize, _lastCollectionViewSize) && _selectedHost != nil) {
        [self.collectionView reloadData];
    }

    CGRect desiredHostScrollFrame = [self hostScrollViewFrameForCurrentBounds];
#if !TARGET_OS_TV
    if (_hostSelectionContainerView != nil && !CGRectEqualToRect(_hostSelectionContainerView.frame, desiredHostScrollFrame)) {
        _hostSelectionContainerView.frame = desiredHostScrollFrame;

        if (!CGSizeEqualToSize(_lastHostScrollViewSize, desiredHostScrollFrame.size)) {
            _lastHostScrollViewSize = desiredHostScrollFrame.size;
            if (_selectedHost == nil) {
                [self refreshHostSelectionSnapshot];
            }
        }
    }
#else
    if (!CGRectEqualToRect(self->hostScrollView.frame, desiredHostScrollFrame)) {
        self->hostScrollView.frame = desiredHostScrollFrame;

        if (!CGSizeEqualToSize(_lastHostScrollViewSize, desiredHostScrollFrame.size)) {
            _lastHostScrollViewSize = desiredHostScrollFrame.size;
            if (_selectedHost == nil) {
                [self updateHosts];
            }
        }
    }
#endif
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    _lastCollectionViewSize = CGSizeZero;
    _lastHostScrollViewSize = CGSizeZero;
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self setNeedsStatusBarAppearanceUpdate];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateCollectionViewLayoutForCurrentBounds];
        [self.collectionView.collectionViewLayout invalidateLayout];

        if (self->_selectedHost != nil) {
            [self.collectionView reloadData];
        }
        else {
            [self updateHosts];
        }

        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self installBackgroundGradientIfNeeded];
    self.view.backgroundColor = [UIColor clearColor];
    [self restorePrimaryNavigationButtons];

    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"AppCell"];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.multipleTouchEnabled = YES;
        
#if !TARGET_OS_TV
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(restorePrimaryNavigationButtons)
                                                 name:MainFrameSettingsDidCloseNotification
                                               object:nil];

    [self disableUpButton];
#else
    // The settings button will direct the user into the Settings app on tvOS
    [_settingsButton setTarget:self];
    [_settingsButton setAction:@selector(openTvSettings:)];
    
    // Restore focus on the selected app on view controller pop navigation
    self.restoresFocusAfterTransition = NO;
    self.collectionView.remembersLastFocusedIndexPath = YES;
    
    _menuRecognizer = [[UITapGestureRecognizer alloc] init];
    [_menuRecognizer addTarget:self action: @selector(showHostSelectionView)];
    _menuRecognizer.allowedPressTypes = [[NSArray alloc] initWithObjects:[NSNumber numberWithLong:UIPressTypeMenu], nil];
    
    self.navigationController.navigationBar.titleTextAttributes = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
#endif
    
    _loadingFrame = [[LoadingFrameViewController alloc] init];
    
    // Set up crypto
    [CryptoManager generateKeyPairUsingSSL];
    _uniqueId = [IdManager getUniqueId];
    _clientCert = [CryptoManager readCertFromFile];

    _appManager = [[AppAssetManager alloc] initWithCallback:self];
    _opQueue = [[NSOperationQueue alloc] init];
    
    // Only initialize the host picker list once
    if (hostList == nil) {
        hostList = [[NSMutableSet alloc] init];
    }
    
    _boxArtCache = [[NSCache alloc] init];
        
    hostScrollView = [[ComputerScrollView alloc] init];
    hostScrollView.frame = [self hostScrollViewFrameForCurrentBounds];
    hostScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [hostScrollView setShowsHorizontalScrollIndicator:NO];
    hostScrollView.delaysContentTouches = NO;
    
    self.collectionView.delaysContentTouches = NO;
    self.collectionView.allowsMultipleSelection = NO;
#if !TARGET_OS_TV
    self.collectionView.multipleTouchEnabled = NO;
    UILongPressGestureRecognizer* cellLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollectionViewLongPress:)];
    cellLongPress.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:cellLongPress];
#else
    // This is the only way to get long press events on a UICollectionViewCell :(
    UILongPressGestureRecognizer* cellLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollectionViewLongPress:)];
    cellLongPress.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:cellLongPress];
#endif
    
    [self retrieveSavedHosts];
    _discMan = [[DiscoveryManager alloc] initWithHosts:[hostList allObjects] andCallback:self];
        
    if ([hostList count] == 1) {
        [self hostClicked:[hostList anyObject] view:nil];
    }
    else {
        [self updateTitle];
#if !TARGET_OS_TV
        [self installHostSelectionHostingControllerIfNeeded];
        [self refreshHostSelectionSnapshot];
        [self.view addSubview:_hostSelectionContainerView];
#else
        [self.view addSubview:hostScrollView];
#endif
    }
}

-(void)handleCollectionViewLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint point = [gestureRecognizer locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (indexPath != nil) {
        UIView *selectedView = [self.collectionView cellForItemAtIndexPath:indexPath];
        [self appLongClicked:_sortedAppList[indexPath.row] view:selectedView];
    }
}

#if TARGET_OS_TV
- (void)openTvSettings:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}
#endif

-(void)beginForegroundRefresh
{
    if (!_background) {
        // This will kick off box art caching
        [self updateHosts];
        
        // Reset state first so we can rediscover hosts that were deleted before
        [_discMan resetDiscoveryState];
        [_discMan startDiscovery];
        
        // This will refresh the applist when a paired host is selected
        if (_selectedHost != nil && _selectedHost.pairState == PairStatePaired) {
            [self hostClicked:_selectedHost view:nil];
        }
    }
}

-(void)handlePendingShortcutAction
{
    // Check if we have a pending shortcut action
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    if (delegate.pcUuidToLoad != nil) {
        // Find the host it corresponds to
        TemporaryHost* matchingHost = nil;
        for (TemporaryHost* host in hostList) {
            if ([host.uuid isEqualToString:delegate.pcUuidToLoad]) {
                matchingHost = host;
                break;
            }
        }
        
        // Clear the pending shortcut action
        delegate.pcUuidToLoad = nil;
        
        // Complete the request
        if (delegate.shortcutCompletionHandler != nil) {
            delegate.shortcutCompletionHandler(matchingHost != nil);
            delegate.shortcutCompletionHandler = nil;
        }
        
        if (matchingHost != nil && _selectedHost != matchingHost) {
            // Navigate to the host page
            [self hostClicked:matchingHost view:nil];
        }
    }
}

-(void)handleReturnToForeground
{
    _background = NO;
    
    [self beginForegroundRefresh];
    
    // Check for a pending shortcut action when returning to foreground
    [self handlePendingShortcutAction];
}

-(void)handleEnterBackground
{
    _background = YES;
    
    [_discMan stopDiscovery];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self restorePrimaryNavigationButtons];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self setNeedsStatusBarAppearanceUpdate];
    [self applyNavigationBarAppearance];
    [self refreshAppListLayoutForCurrentNavigationState];

    // Check for a pending shortcut action when appearing
    [self handlePendingShortcutAction];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleReturnToForeground)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnterBackground)
                                                 name: UIApplicationWillResignActiveNotification
                                               object: nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self restorePrimaryNavigationButtons];
    [self enableNavigation];
    [self applyNavigationBarAppearance];
    [self setNeedsStatusBarAppearanceUpdate];
    [self refreshAppListLayoutForCurrentNavigationState];
    
    // We can get here on home press while streaming
    // since the stream view segues to us just before
    // entering the background. We can't check the app
    // state here (since it's in transition), so we have
    // to use this function that will use our internal
    // state here to determine whether we're foreground.
    //
    // Note that this is neccessary here as we may enter
    // this view via an error dialog from the stream
    // view, so we won't get a return to active notification
    // for that which would normally fire beginForegroundRefresh.
    [self beginForegroundRefresh];
}

- (BOOL)prefersStatusBarHidden
{
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

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (@available(iOS 13.0, *)) {
        return UIStatusBarStyleDarkContent;
    }

    return UIStatusBarStyleDefault;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // when discovery stops, we must create a new instance because
    // you cannot restart an NSOperation when it is finished
    [_discMan stopDiscovery];
    
    // Purge the box art cache
    [_boxArtCache removeAllObjects];
    
    // Remove app lifetime observers to avoid triggering them while streaming.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
}

- (void) retrieveSavedHosts {
    DataManager* dataMan = [[DataManager alloc] init];
    NSArray* hosts = [dataMan getHosts];
    @synchronized(hostList) {
        [hostList addObjectsFromArray:hosts];
        
        // Initialize the non-persistent host state
        for (TemporaryHost* host in hostList) {
            if (host.activeAddress == nil) {
                host.activeAddress = host.localAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.externalAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.address;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.ipv6Address;
            }
        }
    }
}

- (void) updateAllHosts:(NSArray *)hosts {
    // We must copy the array here because it could be modified
    // before our main thread dispatch happens.
    NSArray* hostsCopy = [NSArray arrayWithArray:hosts];
    dispatch_async(dispatch_get_main_queue(), ^{
        Log(LOG_D, @"New host list:");
        for (TemporaryHost* host in hostsCopy) {
            Log(LOG_D, @"Host: \n{\n\t name:%@ \n\t address:%@ \n\t localAddress:%@ \n\t externalAddress:%@ \n\t ipv6Address:%@ \n\t uuid:%@ \n\t mac:%@ \n\t pairState:%d \n\t online:%d \n\t activeAddress:%@ \n}", host.name, host.address, host.localAddress, host.externalAddress, host.ipv6Address, host.uuid, host.mac, host.pairState, host.state, host.activeAddress);
        }
        @synchronized(hostList) {
            [hostList removeAllObjects];
            [hostList addObjectsFromArray:hostsCopy];
        }
        [self updateHosts];
    });
}

- (void)updateHostShortcuts {
#if !TARGET_OS_TV
    NSMutableArray* quickActions = [[NSMutableArray alloc] init];
    
    @synchronized (hostList) {
        for (TemporaryHost* host in hostList) {
            // Pair state may be unknown if we haven't polled it yet, but the app list
            // count will persist from paired PCs
            if ([host.appList count] > 0) {
                UIApplicationShortcutItem* shortcut = [[UIApplicationShortcutItem alloc]
                                                       initWithType:@"PC"
                                                       localizedTitle:host.name
                                                       localizedSubtitle:nil
                                                       icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypePlay]
                                                       userInfo:[NSDictionary dictionaryWithObject:host.uuid forKey:@"UUID"]];
                [quickActions addObject: shortcut];
            }
        }
    }
    
    [UIApplication sharedApplication].shortcutItems = quickActions;
#endif
}

- (void)updateHosts {
    Log(LOG_I, @"Updating hosts...");
#if !TARGET_OS_TV
    [self refreshHostSelectionSnapshot];

    // Create or delete host shortcuts as needed
    [self updateHostShortcuts];

    // Update the title in case we now have a PC
    [self updateTitle];
    return;
#endif

    [[hostScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    UIComputerView* addComp = [[UIComputerView alloc] initForAddWithCallback:self];
    UIComputerView* compView;
    float prevEdge = -1;
    @synchronized (hostList) {
        // Sort the host list in alphabetical order
        NSArray* sortedHostList = [[hostList allObjects] sortedArrayUsingSelector:@selector(compareName:)];
        for (TemporaryHost* comp in sortedHostList) {
            compView = [[UIComputerView alloc] initWithComputer:comp andCallback:self];
            compView.center = CGPointMake([self getCompViewX:compView addComp:addComp prevEdge:prevEdge], hostScrollView.frame.size.height / 2);
            prevEdge = compView.frame.origin.x + compView.frame.size.width;
            [hostScrollView addSubview:compView];
            
            // Start jobs to decode the box art in advance
            for (TemporaryApp* app in comp.appList) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    [self updateBoxArtCacheForApp:app];
                });
            }
        }
    }
    
    // Create or delete host shortcuts as needed
    [self updateHostShortcuts];
    
    // Update the title in case we now have a PC
    [self updateTitle];
    
    prevEdge = [self getCompViewX:addComp addComp:addComp prevEdge:prevEdge];
    addComp.center = CGPointMake(prevEdge, hostScrollView.frame.size.height / 2);
    
    [hostScrollView addSubview:addComp];
    [hostScrollView setContentSize:CGSizeMake(prevEdge + addComp.frame.size.width, hostScrollView.frame.size.height)];
}

- (float) getCompViewX:(UIComputerView*)comp addComp:(UIComputerView*)addComp prevEdge:(float)prevEdge {
    float padding;
    
#if TARGET_OS_TV
    padding = 100;
#else
    padding = addComp.frame.size.width / 2;
#endif
    
    if (prevEdge == -1) {
        return hostScrollView.frame.origin.x + comp.frame.size.width / 2 + padding;
    } else {
        return prevEdge + comp.frame.size.width / 2 + padding;
    }
}

// This function forces immediate decoding of the UIImage, rather
// than the default lazy decoding that results in janky scrolling.
+ (UIImage*) loadBoxArtForCaching:(TemporaryApp*)app {
    UIImage* boxArt;
    
    NSData* imageData = [NSData dataWithContentsOfFile:[AppAssetManager boxArtPathForApp:app]];
    if (imageData == nil) {
        // No box art on disk
        return nil;
    }
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil);
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef imageContext =  CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace,
                                                       kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(imageContext, CGRectMake(0, 0, width, height), cgImage);
    
    CGImageRef outputImage = CGBitmapContextCreateImage(imageContext);

    boxArt = [UIImage imageWithCGImage:outputImage];
    
    CGImageRelease(outputImage);
    CGContextRelease(imageContext);
    
    CGImageRelease(cgImage);
    CFRelease(source);
    
    return boxArt;
}

- (void) updateBoxArtCacheForApp:(TemporaryApp*)app {
    if ([_boxArtCache objectForKey:app] == nil) {
        UIImage* image = [MainFrameViewController loadBoxArtForCaching:app];
        if (image != nil) {
            // Add the image to our cache if it was present
            [_boxArtCache setObject:image forKey:app];
        }
    }
}

- (UIImage*)cachedBoxArtForApp:(TemporaryApp*)app {
    UIImage* image = [_boxArtCache objectForKey:app];
    if (image == nil) {
        image = [MainFrameViewController loadBoxArtForCaching:app];
        if (image != nil) {
            [_boxArtCache setObject:image forKey:app];
        }
    }

    return image;
}

- (void) updateAppsForHost:(TemporaryHost*)host {
    if (host != _selectedHost) {
        Log(LOG_W, @"Mismatched host during app update");
        return;
    }
    
    _sortedAppList = [host.appList allObjects];
    _sortedAppList = [_sortedAppList sortedArrayUsingSelector:@selector(compareName:)];
    
    if (!_showHiddenApps) {
        NSMutableArray* visibleAppList = [NSMutableArray array];
        for (TemporaryApp* app in _sortedAppList) {
            if (!app.hidden) {
                [visibleAppList addObject:app];
            }
        }
        _sortedAppList = visibleAppList;
    }
    
#if !TARGET_OS_TV
    [_hostSelectionContainerView removeFromSuperview];
#else
    [hostScrollView removeFromSuperview];
#endif
    [self.collectionView reloadData];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];
    
    TemporaryApp* app = _sortedAppList[indexPath.row];
#if !TARGET_OS_TV
    MainFrameAppCellHostingBridge *bridge = objc_getAssociatedObject(cell, MainFrameAppCellHostingBridgeAssociationKey);
    if (bridge == nil) {
        bridge = [[MainFrameAppCellHostingBridge alloc] init];
        objc_setAssociatedObject(cell, MainFrameAppCellHostingBridgeAssociationKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    TemporaryApp* runningApp = [self findRunningApp:app.host];
    BOOL isRunning = runningApp != nil && [runningApp.id isEqualToString:app.id];
    [bridge renderInView:cell.contentView
                   title:app.name ?: @""
                  boxArt:[self cachedBoxArtForApp:app]
                  hidden:app.hidden
                 running:isRunning];
#else
    UIAppView* appView = [[UIAppView alloc] initWithApp:app cache:_boxArtCache andCallback:self];
    [appView applyDisplaySize:cell.contentView.bounds.size];
    appView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [[cell.contentView.subviews copy] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [cell.contentView addSubview:appView];
#endif
    
    // Shadow opacity is controlled inside UIAppView based on whether the app
    // is hidden or not during the update cycle.
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:cell.bounds];
    cell.layer.masksToBounds = NO;
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOffset = CGSizeMake(1.0f, 5.0f);
    cell.layer.shadowPath = shadowPath.CGPath;
    
#if !TARGET_OS_TV
    cell.exclusiveTouch = YES;
#endif

    cell.contentView.backgroundColor = [UIColor clearColor];

    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize itemSize = CGSizeZero;
    [self getAppGridMetricsForCollectionView:collectionView
                                 sectionInset:NULL
                             minimumLineSpacing:NULL
                        minimumInteritemSpacing:NULL
                                       itemSize:&itemSize];
    return itemSize;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    CGFloat lineSpacing = 0.0;
    [self getAppGridMetricsForCollectionView:collectionView
                                 sectionInset:NULL
                             minimumLineSpacing:&lineSpacing
                        minimumInteritemSpacing:NULL
                                       itemSize:NULL];
    return lineSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    CGFloat interitemSpacing = 0.0;
    [self getAppGridMetricsForCollectionView:collectionView
                                 sectionInset:NULL
                             minimumLineSpacing:NULL
                        minimumInteritemSpacing:&interitemSpacing
                                       itemSize:NULL];
    return interitemSpacing;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    UIEdgeInsets sectionInset = UIEdgeInsetsZero;
    [self getAppGridMetricsForCollectionView:collectionView
                                 sectionInset:&sectionInset
                             minimumLineSpacing:NULL
                        minimumInteritemSpacing:NULL
                                       itemSize:NULL];
    return sectionInset;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1; // App collection only
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_selectedHost != nil && _sortedAppList != nil) {
        return _sortedAppList.count;
    }
    else {
        return 0;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Purge the box art cache on low memory
    [_boxArtCache removeAllObjects];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#if !TARGET_OS_TV
- (void)mainFrameHostListHostingViewController:(MainFrameHostListHostingViewController *)controller didSelectItemAt:(NSInteger)index {
    if (_sortedHostSelectionList != nil && index >= 0 && index < _sortedHostSelectionList.count) {
        [self hostClicked:_sortedHostSelectionList[index] view:self.view];
    }
}

- (void)mainFrameHostListHostingViewController:(MainFrameHostListHostingViewController *)controller didLongPressItemAt:(NSInteger)index {
    if (_sortedHostSelectionList != nil && index >= 0 && index < _sortedHostSelectionList.count) {
        [self hostLongClicked:_sortedHostSelectionList[index] view:self.view];
    }
}

- (void)mainFrameHostActionSheetHostingViewController:(MainFrameHostActionSheetHostingViewController *)controller didSelectActionWithIdentifier:(NSString *)identifier {
    if (controller == _hostActionSheetHostingViewController) {
        TemporaryHost *host = _hostActionSheetHost;
        _hostActionSheetHost = nil;
        _hostActionSheetHostingViewController = nil;

        [controller dismissViewControllerAnimated:YES completion:^{
            [self performHostActionWithIdentifier:identifier host:host];
        }];
        return;
    }

    if (controller == _appActionSheetHostingViewController) {
        TemporaryApp *app = _appActionSheetApp;
        _appActionSheetApp = nil;
        _appActionSheetHostingViewController = nil;

        [controller dismissViewControllerAnimated:YES completion:^{
            [self performAppActionWithIdentifier:identifier app:app];
        }];
    }
}

- (void)mainFrameHostActionSheetHostingViewControllerDidCancel:(MainFrameHostActionSheetHostingViewController *)controller {
    if (controller == _hostActionSheetHostingViewController) {
        _hostActionSheetHost = nil;
        _hostActionSheetHostingViewController = nil;
    }
    else if (controller == _appActionSheetHostingViewController) {
        _appActionSheetApp = nil;
        _appActionSheetHostingViewController = nil;
    }

    [controller dismissViewControllerAnimated:YES completion:nil];
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
#endif

- (void) disableNavigation {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem.enabled = NO;
    for (UIBarButtonItem *item in self.navigationItem.leftBarButtonItems) {
        item.enabled = NO;
    }
}

- (void) enableNavigation {
    self.navigationItem.rightBarButtonItem.enabled = YES;
    self.navigationItem.leftBarButtonItem.enabled = YES;
    for (UIBarButtonItem *item in self.navigationItem.leftBarButtonItems) {
        item.enabled = YES;
    }
}

#if TARGET_OS_TV
- (BOOL)canBecomeFocused {
    return YES;
}
#endif

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    
#if !TARGET_OS_TV
    if (context.nextFocusedView != nil) {
        [context.nextFocusedView setAlpha:0.8];
    }
    [context.previouslyFocusedView setAlpha:1.0];
#endif
}

@end
