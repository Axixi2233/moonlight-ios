//
//  AppDelegate.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_TV
#import "MainFrameViewController.h"
#endif

#if !TARGET_OS_TV
@interface AppLaunchOverlayView : UIView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title;
- (void)playIntroAnimationWithCompletion:(dispatch_block_t)completion;

@end

@implementation AppLaunchOverlayView {
    CAGradientLayer *_backgroundLayer;
    UIView *_glowView;
    UIView *_iconBackgroundView;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIView *_progressTrackView;
    UIView *_progressFillView;
    NSLayoutConstraint *_progressFillWidthConstraint;
}

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];

    _backgroundLayer = [CAGradientLayer layer];
    _backgroundLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:0.95 green:0.89 blue:0.99 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.86 green:0.78 blue:0.98 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.70 green:0.63 blue:0.93 alpha:1.0].CGColor
    ];
    _backgroundLayer.startPoint = CGPointMake(0.0, 0.0);
    _backgroundLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.layer addSublayer:_backgroundLayer];

    _glowView = [[UIView alloc] init];
    _glowView.translatesAutoresizingMaskIntoConstraints = NO;
    _glowView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    _glowView.layer.cornerRadius = 76.0;
    [self addSubview:_glowView];

    UIImage* launchImage = [UIImage imageNamed:@"LaunchIcon"];
    if (launchImage == nil) {
        launchImage = [UIImage imageNamed:@"Computer"];
    }

    _iconBackgroundView = [[UIView alloc] init];
    _iconBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconBackgroundView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
    _iconBackgroundView.layer.cornerRadius = 28.0;
    _iconBackgroundView.layer.shadowColor = [UIColor colorWithRed:0.36 green:0.24 blue:0.55 alpha:1.0].CGColor;
    _iconBackgroundView.layer.shadowOpacity = 0.14;
    _iconBackgroundView.layer.shadowRadius = 20.0;
    _iconBackgroundView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self addSubview:_iconBackgroundView];

    _iconView = [[UIImageView alloc] initWithImage:launchImage];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = title;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = [UIColor colorWithRed:0.29 green:0.21 blue:0.45 alpha:1.0];
    _titleLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightSemibold];
    [self addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.text = @"随时随地，畅联你的电脑！";
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.textColor = [UIColor colorWithRed:0.43 green:0.35 blue:0.60 alpha:0.92];
    _subtitleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [self addSubview:_subtitleLabel];

    _progressTrackView = [[UIView alloc] init];
    _progressTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressTrackView.backgroundColor = [UIColor colorWithRed:0.79 green:0.72 blue:0.91 alpha:0.45];
    _progressTrackView.layer.cornerRadius = 3.0;
    _progressTrackView.clipsToBounds = YES;
    [self addSubview:_progressTrackView];

    _progressFillView = [[UIView alloc] init];
    _progressFillView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressFillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    _progressFillView.layer.cornerRadius = 3.0;
    [_progressTrackView addSubview:_progressFillView];

    _progressFillWidthConstraint = [_progressFillView.widthAnchor constraintEqualToConstant:40.0];
    _progressFillWidthConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [_glowView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_glowView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-92.0],
        [_glowView.widthAnchor constraintEqualToConstant:152.0],
        [_glowView.heightAnchor constraintEqualToConstant:152.0],

        [_iconBackgroundView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_iconBackgroundView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-92.0],
        [_iconBackgroundView.widthAnchor constraintEqualToConstant:108.0],
        [_iconBackgroundView.heightAnchor constraintEqualToConstant:108.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-90.0],
        [_iconView.widthAnchor constraintEqualToConstant:96.0],
        [_iconView.heightAnchor constraintEqualToConstant:96.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:20.0],
        [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:24.0],
        [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:_titleLabel.trailingAnchor constant:24.0],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
        [_subtitleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_subtitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:32.0],
        [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:_subtitleLabel.trailingAnchor constant:32.0],

        [_progressTrackView.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:18.0],
        [_progressTrackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_progressTrackView.widthAnchor constraintEqualToConstant:150.0],
        [_progressTrackView.heightAnchor constraintEqualToConstant:6.0],

        [_progressFillView.leadingAnchor constraintEqualToAnchor:_progressTrackView.leadingAnchor],
        [_progressFillView.topAnchor constraintEqualToAnchor:_progressTrackView.topAnchor],
        [_progressFillView.bottomAnchor constraintEqualToAnchor:_progressTrackView.bottomAnchor]
    ]];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _backgroundLayer.frame = self.bounds;
}

- (void)playIntroAnimationWithCompletion:(dispatch_block_t)completion {
    CABasicAnimation* pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.fromValue = @1.0;
    pulseAnimation.toValue = @1.06;
    pulseAnimation.duration = 0.72;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = HUGE_VALF;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_iconView.layer addAnimation:pulseAnimation forKey:@"launchPulse"];

    CABasicAnimation* floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    floatAnimation.fromValue = @0.0;
    floatAnimation.toValue = @-4.0;
    floatAnimation.duration = 0.90;
    floatAnimation.autoreverses = YES;
    floatAnimation.repeatCount = HUGE_VALF;
    floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_glowView.layer addAnimation:floatAnimation forKey:@"launchFloat"];
    [_iconView.layer addAnimation:floatAnimation forKey:@"launchFloat"];

    [self layoutIfNeeded];
    [UIView animateWithDuration:0.95
                          delay:0.10
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self->_progressFillWidthConstraint.constant = 150.0;
        [self layoutIfNeeded];
    } completion:nil];

    [UIView animateWithDuration:0.45
                          delay:1.05
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeScale(1.02, 1.02);
    } completion:^(BOOL finished) {
        [self->_iconView.layer removeAllAnimations];
        [self->_glowView.layer removeAllAnimations];
        if (completion != nil) {
            completion();
        }
    }];
}

@end
#endif

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

static NSOperationQueue* mainQueue;

#if TARGET_OS_TV
static NSString* DB_NAME = @"Moonlight_tvOS.bin";
#else
static NSString* DB_NAME = @"Limelight_iOS.sqlite";
#endif

#if !TARGET_OS_TV
- (NSString *)launchOverlayTitle {
    NSString* displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (displayName.length == 0) {
        displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    }
    if (displayName.length == 0) {
        displayName = @"Moonlight";
    }
    return displayName;
}

- (void)installAnimatedLaunchOverlay {
    if (self.window == nil) {
        return;
    }

    AppLaunchOverlayView* overlayView = [[AppLaunchOverlayView alloc] initWithFrame:self.window.bounds title:[self launchOverlayTitle]];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.window addSubview:overlayView];
    [overlayView playIntroAnimationWithCompletion:^{
        [overlayView removeFromSuperview];
    }];
}
#endif

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if !TARGET_OS_TV
    UIApplicationShortcutItem* shortcut = [launchOptions valueForKey:UIApplicationLaunchOptionsShortcutItemKey];
    if (shortcut != nil) {
        _pcUuidToLoad = (NSString*)[shortcut.userInfo objectForKey:@"UUID"];
    }

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    MainFrameViewController *mainFrameViewController = [[MainFrameViewController alloc] init];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:mainFrameViewController];
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installAnimatedLaunchOverlay];
    });
#endif
    return YES;
}

#if !TARGET_OS_TV
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }

    return UIInterfaceOrientationMaskAllButUpsideDown;
}
#endif

#if !TARGET_OS_TV
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler {
    _pcUuidToLoad = (NSString*)[shortcutItem.userInfo objectForKey:@"UUID"];
    _shortcutCompletionHandler = completionHandler;
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    if (managedObjectContext != nil) {
        [managedObjectContext performBlock:^{
            if (![managedObjectContext hasChanges]) {
                return;
            }
            NSError *error = nil;
            if (![managedObjectContext save:&error]) {
                Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
            }
            
#if TARGET_OS_TV
            NSData* dbData = [NSData dataWithContentsOfURL:[[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:DB_NAME]];
            [[NSUserDefaults standardUserDefaults] setObject:dbData forKey:DB_NAME];
#endif
        }];
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    NSString* storeType;
    
#if TARGET_OS_TV
    // Use a binary store for tvOS since we will need exclusive access to the file
    // to serialize into NSUserDefaults.
    storeType = NSBinaryStoreType;
#else
    storeType = NSSQLiteStoreType;
#endif
    
    // We must ensure the persistent store is ready to opened
    [self preparePersistentStore];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:storeType configuration:nil URL:[self getStoreURL] options:options error:&error]) {
        // Log the error
        Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
        
        // Drop the database
        [self dropDatabase];
        
        // Try again
        return [self persistentStoreCoordinator];
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void) dropDatabase
{
    // Delete the file on disk
    [[NSFileManager defaultManager] removeItemAtURL:[self getStoreURL] error:nil];
    
#if TARGET_OS_TV
    // Also delete the copy in the NSUserDefaults on tvOS
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:DB_NAME];
#endif
}

- (void) preparePersistentStore
{
#if TARGET_OS_TV
    // On tvOS, we may need to inflate the DB from NSUserDefaults
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [paths objectAtIndex:0];
    NSString *dbPath = [cacheDirectory stringByAppendingPathComponent:DB_NAME];
    
    // Always prefer the on disk version
    if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
        // If that is unavailable, inflate it from NSUserDefaults
        NSData* data = [[NSUserDefaults standardUserDefaults] dataForKey:DB_NAME];
        if (data != nil) {
            Log(LOG_I, @"Inflating database from NSUserDefaults");
            [data writeToFile:dbPath atomically:YES];
        }
        else {
            Log(LOG_I, @"No database on disk or in NSUserDefaults");
        }
    }
    else {
        Log(LOG_I, @"Using cached database");
    }
#endif
}

- (NSURL*) getStoreURL {
#if TARGET_OS_TV
    // We use the cache folder to store our database on tvOS
    return [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:DB_NAME];
#else
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:DB_NAME];
#endif
}

@end
