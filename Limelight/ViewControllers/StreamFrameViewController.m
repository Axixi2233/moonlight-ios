//
//  StreamFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "StreamFrameViewController.h"
#import "MainFrameViewController.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "MicUplinkManager.h"
#import "ControllerSupport.h"
#import "DataManager.h"
#import "Moonlight-Swift.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <Limelight.h>

#define StreamMenuLocalized(key) NSLocalizedString((key), nil)

#if !TARGET_OS_TV
#import <AVKit/AVKit.h>
#endif

#if TARGET_OS_TV
#import <AVFoundation/AVDisplayCriteria.h>
#import <AVKit/AVDisplayManager.h>
#import <AVKit/UIWindow.h>
#endif

@interface AVDisplayCriteria()
@property(readonly) int videoDynamicRange;
@property(readonly, nonatomic) float refreshRate;
- (id)initWithRefreshRate:(float)arg1 videoDynamicRange:(int)arg2;
@end

@interface StreamFrameViewController () <StreamActionSheetHostingViewControllerDelegate, StreamShortcutPanelHostingViewControllerDelegate, StreamVirtualKeyboardPanelHostingViewControllerDelegate, StreamVirtualButtonsPanelHostingViewControllerDelegate, UIGestureRecognizerDelegate
#if !TARGET_OS_TV
, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate
#endif
>
@end

static const CGFloat kStreamFloatingMenuPhoneButtonSize = 44.0f;
static const CGFloat kStreamFloatingMenuPadButtonSize = 48.0f;
static const CGFloat kStreamFloatingMenuExpandedMargin = 6.0f;
static const CGFloat kStreamFloatingMenuAutoCollapseDelay = 3.0f;
static const CGFloat kStreamFloatingMenuCollapsedAlpha = 0.42f;
static const CGFloat kStreamFloatingMenuExpandedAlpha = 0.96f;
static const NSInteger kStreamPerformanceOverlayPositionCustom = 6;

@implementation StreamFrameViewController {
    ControllerSupport *_controllerSupport;
    StreamManager *_streamMan;
    TemporarySettings *_settings;
    NSTimer *_inactivityTimer;
    NSTimer *_statsUpdateTimer;
    UITapGestureRecognizer *_menuTapGestureRecognizer;
    UITapGestureRecognizer *_menuDoubleTapGestureRecognizer;
    UITapGestureRecognizer *_playPauseTapGestureRecognizer;
    UITextView *_overlayView;
    UILabel *_stageLabel;
    UILabel *_tipLabel;
    UIActivityIndicatorView *_spinner;
    StreamView *_streamView;
    UIScrollView *_scrollView;
    BOOL _userIsInteracting;
    CGSize _keyboardSize;
    StreamActionSheetHostingViewController *_streamActionSheetHostingViewController;
    StreamShortcutPanelHostingViewController *_streamShortcutPanelHostingViewController;
    StreamVirtualKeyboardPanelHostingViewController *_streamVirtualKeyboardPanelHostingViewController;
    StreamVirtualButtonsPanelHostingViewController *_streamVirtualButtonsPanelHostingViewController;
    BOOL _streamOverlayMouseInputSuppressed;
    NSInteger _currentSessionTouchModeSelection;
    NSInteger _currentSessionVideoAlignmentSelection;
    CGFloat _currentSessionVideoAlignmentMargin;
    BOOL _extendedPerformanceMetricsEnabled;
    BOOL _microphoneEnabled;
    BOOL _microphoneStartRequested;
    MicUplinkManager *_micUplinkManager;
    NSInteger _currentSessionPerformanceOverlayPositionSelection;
    CGFloat _currentSessionPerformanceOverlayMargin;
    BOOL _currentSessionPerformanceOverlayDragEnabled;
    CGFloat _currentSessionPerformanceOverlayCustomXRatio;
    CGFloat _currentSessionPerformanceOverlayCustomYRatio;
    UIPanGestureRecognizer *_overlayPanGestureRecognizer;
    CGPoint _overlayPanTouchOffset;
    BOOL _viewOnlyModeEnabled;
    CGFloat _viewOnlyRestoreZoomScale;
    CGPoint _viewOnlyRestoreContentOffset;
    BOOL _viewOnlyHadScrollViewBeforeEntering;
    BOOL _suppressTerminationAlertForManualExit;
    UIControl *_floatingMenuButton;
    UIImageView *_floatingMenuIconView;
    NSTimer *_floatingMenuDormancyTimer;
    UILongPressGestureRecognizer *_floatingMenuLongPressRecognizer;
    BOOL _floatingMenuCollapsed;
    BOOL _floatingMenuAnchoredRight;
    CGFloat _floatingMenuCenterY;
    CGPoint _floatingMenuPanStartCenter;
    CGPoint _floatingMenuTouchOffset;
    BOOL _floatingMenuDragMoved;
    BOOL _floatingMenuHasCustomPosition;
    NSMutableArray<NSDictionary *> *_virtualButtonDefinitions;
    NSMutableArray<NSDictionary *> *_virtualGamepadDefinitions;
    NSMutableArray<NSDictionary *> *_customShortcutDefinitions;
    UIView *_virtualButtonEditorView;
    UILabel *_virtualButtonEditorTitleLabel;
    UISegmentedControl *_virtualButtonEditorShapeControl;
    UILabel *_virtualButtonEditorScaleValueLabel;
    UISlider *_virtualButtonEditorScaleSlider;
    UILabel *_virtualButtonEditorWidthValueLabel;
    UISlider *_virtualButtonEditorWidthSlider;
    UILabel *_virtualButtonEditorHeightValueLabel;
    UISlider *_virtualButtonEditorHeightSlider;
    UILabel *_virtualButtonEditorTouchSensitivityXValueLabel;
    UISlider *_virtualButtonEditorTouchSensitivityXSlider;
    UILabel *_virtualButtonEditorTouchSensitivityYValueLabel;
    UISlider *_virtualButtonEditorTouchSensitivityYSlider;
    UIButton *_virtualButtonEditorCloseButton;
    UIButton *_virtualButtonEditorDeleteButton;
    UIButton *_virtualButtonEditorSaveButton;
    UIView *_virtualControlsEditingToolbarView;
    UIButton *_virtualControlsEditingCollapseButton;
    UIButton *_virtualControlsEditingExitButton;
    UIButton *_virtualControlsEditingResetButton;
    UIButton *_virtualControlsEditingDoneButton;
    NSString *_selectedVirtualButtonIdentifier;
    NSString *_selectedVirtualGamepadIdentifier;
    CGFloat _currentSessionVirtualButtonOpacity;
    CGFloat _currentSessionVirtualGamepadOpacity;
    NSInteger _currentSessionVirtualButtonSchemeSelection;
    NSInteger _currentSessionVirtualGamepadSchemeSelection;
    BOOL _currentSessionVirtualButtonLayoutPortrait;
    BOOL _currentSessionVirtualGamepadLayoutPortrait;
    BOOL _virtualButtonsEditingSessionActive;
    BOOL _virtualButtonsEditingPreviousVisibility;
    BOOL _virtualGamepadEditingSessionActive;
    BOOL _virtualGamepadEditingPreviousVisibility;
    BOOL _virtualControlsEditingToolbarCollapsed;
    
#if !TARGET_OS_TV
    UIScreenEdgePanGestureRecognizer *_exitSwipeRecognizer;
#endif
    //外接显示器-----------start
    UIWindow *_extWindow;
    StreamView *_renderView;
    UIWindow *_deviceWindow;
    //外接显示器-----------end
#if !TARGET_OS_TV
    AVPictureInPictureController *_pictureInPictureController;
    AVPictureInPictureController *_observedPictureInPictureController;
    BOOL _pictureInPictureActive;
    BOOL _pictureInPictureStartingForBackground;
#endif
    BOOL _manualExitInProgress;
}

- (NSAttributedString *)statsOverlayAttributedTextForText:(NSString *)text {
    if (text.length == 0) {
        return [[NSAttributedString alloc] initWithString:@""];
    }

    UIFont *font = _overlayView.font ?: [UIFont systemFontOfSize:10.0];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];
    NSString *symbolName = [self currentNetworkSymbolName];
    UIImage *symbolImage = nil;

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:font.pointSize weight:UIImageSymbolWeightSemibold];
        symbolImage = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
        if (symbolImage != nil) {
            symbolImage = [symbolImage imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    if (symbolImage != nil) {
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = symbolImage;
        CGFloat iconSide = ceil(font.lineHeight);
        CGFloat yOffset = floor((font.capHeight - iconSide) / 2.0);
        attachment.bounds = CGRectMake(0, yOffset, iconSide, iconSide);
        [attributedText appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    }

    NSDictionary *attributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: font
    };
    NSMutableAttributedString *textAttributes = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    NSRange micRange = [text rangeOfString:@"Mic" options:NSBackwardsSearch];
    if (micRange.location != NSNotFound && NSMaxRange(micRange) == text.length) {
        [textAttributes addAttributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithRed:0.28 green:1.0 blue:0.55 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:font.pointSize]
        } range:micRange];
    }
    [attributedText appendAttributedString:textAttributes];
    return attributedText;
}

- (NSString *)currentNetworkSymbolName {
    struct ifaddrs *ifaList = NULL;
    struct ifaddrs *ifa = NULL;
    BOOL hasWiFi = NO;
    BOOL hasCellular = NO;

    if (getifaddrs(&ifaList) == -1) {
        return @"wifi.circle";
    }

    for (ifa = ifaList; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) {
            continue;
        }

        if (!(ifa->ifa_flags & IFF_UP) || !(ifa->ifa_flags & IFF_RUNNING)) {
            continue;
        }

        if (ifa->ifa_flags & IFF_LOOPBACK) {
            continue;
        }

        sa_family_t family = ifa->ifa_addr->sa_family;
        if (family != AF_INET && family != AF_INET6) {
            continue;
        }

        NSString *interfaceName = [NSString stringWithUTF8String:ifa->ifa_name ?: ""];
        if ([interfaceName hasPrefix:@"en"]) {
            hasWiFi = YES;
            break;
        }

        if ([interfaceName hasPrefix:@"pdp_ip"]) {
            hasCellular = YES;
        }
    }

    freeifaddrs(ifaList);
    if (hasWiFi) {
        return @"wifi.circle";
    }

    if (hasCellular) {
        return @"cellularbars.circle";
    }

    return @"wifi.circle";
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#if !TARGET_OS_TV
- (void)stopObservingPictureInPictureController
{
    if (_observedPictureInPictureController == nil) {
        return;
    }

    @try {
        [_observedPictureInPictureController removeObserver:self forKeyPath:@"pictureInPicturePossible"];
    }
    @catch (__unused NSException *exception) {
    }

    _observedPictureInPictureController = nil;
}

- (void)startObservingPictureInPictureControllerIfNeeded
{
    if (_pictureInPictureController == nil || _observedPictureInPictureController == _pictureInPictureController) {
        return;
    }

    [self stopObservingPictureInPictureController];
    [_pictureInPictureController addObserver:self
                                  forKeyPath:@"pictureInPicturePossible"
                                     options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                     context:NULL];
    _observedPictureInPictureController = _pictureInPictureController;
}

- (BOOL)supportsPictureInPictureForCurrentSession
{
    if (!_settings.pictureInPictureEnabled) {
        return NO;
    }

    if (_settings.externalMonitor) {
        return NO;
    }

    if (_settings.rendererSelection != StreamVideoRendererSelectionSystem) {
        return NO;
    }

    if (@available(iOS 15.0, *)) {
        return [AVPictureInPictureController isPictureInPictureSupported];
    }

    return NO;
}

- (void)prepareAudioSessionForPictureInPicture
{
    if (@available(iOS 15.0, *)) {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSError *audioError = nil;
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioError];
        if (audioError != nil) {
            Log(LOG_W, @"Failed to set AVAudioSession category for Picture in Picture: %@", audioError);
        }

        audioError = nil;
        [audioSession setActive:YES error:&audioError];
        if (audioError != nil) {
            Log(LOG_W, @"Failed to activate AVAudioSession for Picture in Picture: %@", audioError);
        }
    }
}

- (void)configurePictureInPictureIfNeeded
{
    if (![self supportsPictureInPictureForCurrentSession]) {
        [self stopObservingPictureInPictureController];
        _pictureInPictureController = nil;
        return;
    }

    if (@available(iOS 15.0, *)) {
        AVSampleBufferDisplayLayer *displayLayer = nil;
        id<VideoRendering> renderer = [_streamMan currentRenderer];
        if ([renderer respondsToSelector:@selector(pictureInPictureDisplayLayer)]) {
            displayLayer = [renderer pictureInPictureDisplayLayer];
        }

        if (displayLayer == nil) {
            return;
        }

        if (_pictureInPictureController != nil) {
            if (_pictureInPictureController.isPictureInPictureActive) {
                return;
            }
            [self stopObservingPictureInPictureController];
            _pictureInPictureController.delegate = nil;
            _pictureInPictureController = nil;
        }

        AVPictureInPictureControllerContentSource *contentSource =
            [[AVPictureInPictureControllerContentSource alloc] initWithSampleBufferDisplayLayer:displayLayer
                                                                               playbackDelegate:self];
        _pictureInPictureController = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
        _pictureInPictureController.delegate = self;
        if ([_pictureInPictureController respondsToSelector:@selector(setCanStartPictureInPictureAutomaticallyFromInline:)]) {
            _pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = YES;
        }
        [self startObservingPictureInPictureControllerIfNeeded];
    }
}

- (BOOL)shouldKeepStreamAliveForPictureInPicture
{
    return _pictureInPictureActive || _pictureInPictureStartingForBackground;
}

- (void)resetPictureInPictureState
{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self resetPictureInPictureState];
        });
        return;
    }

    if (@available(iOS 15.0, *)) {
        if (_pictureInPictureController.isPictureInPictureActive) {
            [_pictureInPictureController stopPictureInPicture];
        }
    }

    [self stopObservingPictureInPictureController];
    _pictureInPictureController.delegate = nil;
    _pictureInPictureController = nil;
    _pictureInPictureActive = NO;
    _pictureInPictureStartingForBackground = NO;
}
#endif

- (void)layoutOverlayViewForCurrentBounds {
    if (_overlayView == nil || _overlayView.hidden) {
        return;
    }

    CGRect bounds = self.view.bounds;
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = self.view.safeAreaInsets;
    }

    CGFloat horizontalPadding = 0.0;
    CGFloat verticalPadding = 0.0;
    CGFloat availableWidth = MAX(bounds.size.width - safeAreaInsets.left - safeAreaInsets.right, 0.0);
    CGFloat maxWidth = MAX(availableWidth - horizontalPadding * 2.0, 120.0);
    CGFloat linePadding = _overlayView.textContainer.lineFragmentPadding * 2.0;
    UIEdgeInsets textInsets = _overlayView.textContainerInset;
    CGFloat maxTextWidth = MAX(maxWidth - textInsets.left - textInsets.right - linePadding, 1.0);

    CGRect textRect = CGRectZero;
    if (_overlayView.attributedText.length > 0) {
        textRect = [_overlayView.attributedText boundingRectWithSize:CGSizeMake(maxTextWidth, CGFLOAT_MAX)
                                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                                             context:nil];
    }
    else {
        NSDictionary *attributes = @{
            NSFontAttributeName: _overlayView.font ?: [UIFont systemFontOfSize:10.0]
        };
        NSString *overlayText = _overlayView.text ?: @"";
        textRect = [overlayText boundingRectWithSize:CGSizeMake(maxTextWidth, CGFLOAT_MAX)
                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                          attributes:attributes
                                             context:nil];
    }

    CGFloat contentWidth = ceil(textRect.size.width) + textInsets.left + textInsets.right + linePadding;
    CGFloat contentHeight = ceil(textRect.size.height) + textInsets.top + textInsets.bottom;
    CGFloat overlayWidth = MIN(MAX(contentWidth, 44.0), maxWidth);
    CGFloat overlayHeight = MAX(contentHeight, _overlayView.font.lineHeight + textInsets.top + textInsets.bottom);
    CGFloat clampedMargin = MIN(MAX(_currentSessionPerformanceOverlayMargin, 0.0f), 150.0f);
    CGFloat minX = safeAreaInsets.left + horizontalPadding;
    CGFloat maxX = CGRectGetMaxX(bounds) - safeAreaInsets.right - horizontalPadding - overlayWidth;
    CGFloat minY = safeAreaInsets.top + verticalPadding;
    CGFloat maxY = CGRectGetMaxY(bounds) - safeAreaInsets.bottom - verticalPadding - overlayHeight;
    CGFloat originX = safeAreaInsets.left + floor((availableWidth - overlayWidth) / 2.0);
    CGFloat originY = minY + clampedMargin;

    if (_currentSessionPerformanceOverlayPositionSelection == kStreamPerformanceOverlayPositionCustom) {
        originX = minX + (maxX - minX) * _currentSessionPerformanceOverlayCustomXRatio;
        originY = minY + (maxY - minY) * _currentSessionPerformanceOverlayCustomYRatio;
    }
    else {
        switch (_currentSessionPerformanceOverlayPositionSelection) {
            case 1:
                originX = minX;
                originY = minY + clampedMargin;
                break;
            case 2:
                originX = maxX;
                originY = minY + clampedMargin;
                break;
            case 3:
                originX = safeAreaInsets.left + floor((availableWidth - overlayWidth) / 2.0);
                originY = maxY - clampedMargin;
                break;
            case 4:
                originX = minX;
                originY = maxY - clampedMargin;
                break;
            case 5:
                originX = maxX;
                originY = maxY - clampedMargin;
                break;
            case 0:
            default:
                break;
        }
    }

    if (maxX <= minX) {
        originX = minX;
    }
    if (maxY <= minY) {
        originY = minY;
    }

    originX = MIN(MAX(originX, minX), maxX);
    originY = MIN(MAX(originY, minY), maxY);

    CGRect frame = CGRectMake(originX,
                              originY,
                              overlayWidth,
                              overlayHeight);
    _overlayView.frame = frame;
}

- (void)updateCustomPerformanceOverlayRatiosForFrame:(CGRect)frame {
    CGRect bounds = self.view.bounds;
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = self.view.safeAreaInsets;
    }

    CGFloat minX = safeAreaInsets.left;
    CGFloat maxX = CGRectGetMaxX(bounds) - safeAreaInsets.right - CGRectGetWidth(frame);
    CGFloat minY = safeAreaInsets.top;
    CGFloat maxY = CGRectGetMaxY(bounds) - safeAreaInsets.bottom - CGRectGetHeight(frame);

    if (maxX <= minX) {
        _currentSessionPerformanceOverlayCustomXRatio = 0.0f;
    }
    else {
        _currentSessionPerformanceOverlayCustomXRatio = (CGRectGetMinX(frame) - minX) / (maxX - minX);
    }

    if (maxY <= minY) {
        _currentSessionPerformanceOverlayCustomYRatio = 0.0f;
    }
    else {
        _currentSessionPerformanceOverlayCustomYRatio = (CGRectGetMinY(frame) - minY) / (maxY - minY);
    }

    _currentSessionPerformanceOverlayCustomXRatio = MIN(MAX(_currentSessionPerformanceOverlayCustomXRatio, 0.0f), 1.0f);
    _currentSessionPerformanceOverlayCustomYRatio = MIN(MAX(_currentSessionPerformanceOverlayCustomYRatio, 0.0f), 1.0f);
}

- (void)handlePerformanceOverlayPan:(UIPanGestureRecognizer *)gestureRecognizer {
    if (_overlayView == nil || _overlayView.hidden || !_currentSessionPerformanceOverlayDragEnabled) {
        return;
    }

    CGPoint location = [gestureRecognizer locationInView:self.view];
    CGRect bounds = self.view.bounds;
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = self.view.safeAreaInsets;
    }

    CGFloat minX = safeAreaInsets.left;
    CGFloat maxX = CGRectGetMaxX(bounds) - safeAreaInsets.right - CGRectGetWidth(_overlayView.bounds);
    CGFloat minY = safeAreaInsets.top;
    CGFloat maxY = CGRectGetMaxY(bounds) - safeAreaInsets.bottom - CGRectGetHeight(_overlayView.bounds);

    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            _overlayPanTouchOffset = CGPointMake(location.x - CGRectGetMinX(_overlayView.frame),
                                                 location.y - CGRectGetMinY(_overlayView.frame));
            break;
        }
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat originX = location.x - _overlayPanTouchOffset.x;
            CGFloat originY = location.y - _overlayPanTouchOffset.y;
            if (maxX <= minX) {
                originX = minX;
            }
            else {
                originX = MIN(MAX(originX, minX), maxX);
            }
            if (maxY <= minY) {
                originY = minY;
            }
            else {
                originY = MIN(MAX(originY, minY), maxY);
            }

            CGRect frame = _overlayView.frame;
            frame.origin = CGPointMake(originX, originY);
            _overlayView.frame = frame;
            _currentSessionPerformanceOverlayPositionSelection = kStreamPerformanceOverlayPositionCustom;
            [self updateCustomPerformanceOverlayRatiosForFrame:frame];
            break;
        }
        default:
            break;
    }
}

- (void)layoutStreamingSubviewsForCurrentBounds {
    CGRect bounds = self.view.bounds;
    BOOL preserveZoomedStreamFrame = (_scrollView != nil &&
                                      _streamView.superview == _scrollView &&
                                      _viewOnlyModeEnabled &&
                                      _scrollView.zoomScale > 1.0f);
    if (!preserveZoomedStreamFrame) {
        _streamView.frame = bounds;
    }

    if (_renderView != nil && _extWindow == nil) {
        _renderView.frame = bounds;
        _renderView.bounds = bounds;
    }

    if (_scrollView != nil) {
        _scrollView.frame = bounds;
        if (!preserveZoomedStreamFrame) {
            _scrollView.contentSize = _streamView.bounds.size;
        }
    }

    [_stageLabel sizeToFit];
    _stageLabel.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));

    [_spinner sizeToFit];
    _spinner.center = CGPointMake(CGRectGetMidX(bounds),
                                  CGRectGetMidY(bounds) - _stageLabel.frame.size.height - _spinner.frame.size.height);

    if (_tipLabel.text.length > 0) {
        CGSize tipTextSize = [_tipLabel sizeThatFits:CGSizeMake(CGRectGetWidth(bounds) - 40.0, CGFLOAT_MAX)];
        CGFloat tipHorizontalPadding = 20.0;
        CGFloat tipVerticalPadding = 10.0;
        _tipLabel.frame = CGRectMake(0,
                                     0,
                                     ceil(tipTextSize.width + tipHorizontalPadding * 2.0),
                                     ceil(tipTextSize.height + tipVerticalPadding * 2.0));
    }

    CGFloat tipTopInset = 18.0;
    if (@available(iOS 11.0, *)) {
        tipTopInset += self.view.safeAreaInsets.top;
    }
    _tipLabel.center = CGPointMake(CGRectGetMidX(bounds),
                                   tipTopInset + CGRectGetHeight(_tipLabel.bounds) * 0.5);

    [self layoutOverlayViewForCurrentBounds];
    [self layoutVirtualButtonEditorForCurrentBounds];
    [self layoutVirtualControlsEditingToolbarForCurrentBounds];
    [self layoutFloatingMenuButtonForCurrentBounds];
}

- (CGFloat)floatingMenuMinimumCenterYForBounds:(CGRect)bounds {
    CGFloat safeTop = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
    }
    return safeTop + kStreamFloatingMenuExpandedMargin + [self floatingMenuButtonSize] * 0.5f;
}

- (CGFloat)floatingMenuMaximumCenterYForBounds:(CGRect)bounds {
    CGFloat safeBottom = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    return CGRectGetHeight(bounds) - safeBottom - kStreamFloatingMenuExpandedMargin - [self floatingMenuButtonSize] * 0.5f;
}

- (CGFloat)floatingMenuButtonSize {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone ? kStreamFloatingMenuPhoneButtonSize : kStreamFloatingMenuPadButtonSize;
}

- (CGFloat)floatingMenuExpandedCenterXForBounds:(CGRect)bounds anchoredRight:(BOOL)anchoredRight {
    if (anchoredRight) {
        return CGRectGetWidth(bounds) - kStreamFloatingMenuExpandedMargin - [self floatingMenuButtonSize] * 0.5f;
    }

    return kStreamFloatingMenuExpandedMargin + [self floatingMenuButtonSize] * 0.5f;
}

- (CGFloat)floatingMenuCollapsedCenterXForBounds:(CGRect)bounds anchoredRight:(BOOL)anchoredRight {
    if (anchoredRight) {
        return CGRectGetWidth(bounds);
    }

    return 0.0f;
}

- (void)invalidateFloatingMenuDormancyTimer {
    [_floatingMenuDormancyTimer invalidate];
    _floatingMenuDormancyTimer = nil;
}

- (void)handleFloatingMenuButtonTouchUpInside:(id)sender {
    [self invalidateFloatingMenuDormancyTimer];

    if (_floatingMenuCollapsed) {
        [self setFloatingMenuCollapsed:NO animated:YES];
        [self scheduleFloatingMenuAutoCollapse];
        return;
    }

    [self showActionSheetWithTitle:StreamMenuLocalized(@"stream.menu.title") options:nil];
    [self scheduleFloatingMenuAutoCollapse];
}

- (void)installFloatingMenuButtonIfNeeded {
    if (_floatingMenuButton != nil) {
        return;
    }

    CGFloat buttonSize = [self floatingMenuButtonSize];
    _floatingMenuButton = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
    _floatingMenuButton.backgroundColor = [UIColor clearColor];
    _floatingMenuButton.layer.cornerRadius = buttonSize * 0.5f;
    _floatingMenuButton.layer.borderWidth = 1.0f;
    _floatingMenuButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92].CGColor;
    _floatingMenuButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _floatingMenuButton.layer.shadowOpacity = 0.24f;
    _floatingMenuButton.layer.shadowRadius = 10.0f;
    _floatingMenuButton.layer.shadowOffset = CGSizeMake(0, 6);
    _floatingMenuButton.alpha = kStreamFloatingMenuExpandedAlpha;
    _floatingMenuButton.clipsToBounds = NO;
    _floatingMenuButton.exclusiveTouch = YES;
    [_floatingMenuButton addTarget:self action:@selector(handleFloatingMenuButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];

    _floatingMenuIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _floatingMenuIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _floatingMenuIconView.contentMode = UIViewContentModeScaleAspectFill;
    _floatingMenuIconView.clipsToBounds = YES;
    _floatingMenuIconView.layer.cornerRadius = buttonSize * 0.5f;
    _floatingMenuIconView.image = [UIImage imageNamed:@"AppIconRound"];
    [_floatingMenuButton addSubview:_floatingMenuIconView];
    [NSLayoutConstraint activateConstraints:@[
        [_floatingMenuIconView.centerXAnchor constraintEqualToAnchor:_floatingMenuButton.centerXAnchor],
        [_floatingMenuIconView.centerYAnchor constraintEqualToAnchor:_floatingMenuButton.centerYAnchor],
        [_floatingMenuIconView.widthAnchor constraintEqualToAnchor:_floatingMenuButton.widthAnchor],
        [_floatingMenuIconView.heightAnchor constraintEqualToAnchor:_floatingMenuButton.heightAnchor]
    ]];

    _floatingMenuLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingMenuPan:)];
    _floatingMenuLongPressRecognizer.minimumPressDuration = 0.18;
    _floatingMenuLongPressRecognizer.allowableMovement = CGFLOAT_MAX;
    _floatingMenuLongPressRecognizer.cancelsTouchesInView = YES;
    _floatingMenuLongPressRecognizer.delegate = self;
    [self.view addGestureRecognizer:_floatingMenuLongPressRecognizer];

    CGRect bounds = self.view.bounds;
    _floatingMenuAnchoredRight = NO;
    _floatingMenuCollapsed = NO;
    _floatingMenuHasCustomPosition = NO;
    _floatingMenuCenterY = CGRectGetHeight(bounds) * 0.25f;
    _floatingMenuCenterY = MIN(MAX(_floatingMenuCenterY, [self floatingMenuMinimumCenterYForBounds:bounds]),
                               [self floatingMenuMaximumCenterYForBounds:bounds]);
    _floatingMenuButton.center = CGPointMake([self floatingMenuExpandedCenterXForBounds:bounds anchoredRight:NO],
                                             _floatingMenuCenterY);

    [self.view addSubview:_floatingMenuButton];
    [self.view bringSubviewToFront:_floatingMenuButton];
    [self scheduleFloatingMenuAutoCollapse];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == _floatingMenuLongPressRecognizer) {
        if (_floatingMenuButton == nil) {
            return NO;
        }

        CGPoint location = [gestureRecognizer locationInView:self.view];
        return CGRectContainsPoint(_floatingMenuButton.frame, location);
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == _floatingMenuLongPressRecognizer || otherGestureRecognizer == _floatingMenuLongPressRecognizer) {
        return YES;
    }

    return NO;
}

- (void)layoutFloatingMenuButtonForCurrentBounds {
    if (_floatingMenuButton == nil) {
        return;
    }

    CGRect bounds = self.view.bounds;
    CGFloat minCenterY = [self floatingMenuMinimumCenterYForBounds:bounds];
    CGFloat maxCenterY = [self floatingMenuMaximumCenterYForBounds:bounds];
    if (!_floatingMenuHasCustomPosition || _floatingMenuCenterY <= 0.0f) {
        _floatingMenuCenterY = CGRectGetHeight(bounds) * 0.25f;
    }
    _floatingMenuCenterY = MIN(MAX(_floatingMenuCenterY, minCenterY), maxCenterY);

    CGFloat centerX = _floatingMenuCollapsed ?
        [self floatingMenuCollapsedCenterXForBounds:bounds anchoredRight:_floatingMenuAnchoredRight] :
        [self floatingMenuExpandedCenterXForBounds:bounds anchoredRight:_floatingMenuAnchoredRight];

    CGFloat buttonSize = [self floatingMenuButtonSize];
    _floatingMenuButton.bounds = CGRectMake(0, 0, buttonSize, buttonSize);
    _floatingMenuButton.center = CGPointMake(centerX, _floatingMenuCenterY);
    [self.view bringSubviewToFront:_floatingMenuButton];
}

- (void)setFloatingMenuCollapsed:(BOOL)collapsed animated:(BOOL)animated {
    if (_floatingMenuButton == nil) {
        return;
    }

    _floatingMenuCollapsed = collapsed;
    CGRect bounds = self.view.bounds;
    CGFloat centerX = collapsed ?
        [self floatingMenuCollapsedCenterXForBounds:bounds anchoredRight:_floatingMenuAnchoredRight] :
        [self floatingMenuExpandedCenterXForBounds:bounds anchoredRight:_floatingMenuAnchoredRight];
    CGFloat alpha = collapsed ? kStreamFloatingMenuCollapsedAlpha : kStreamFloatingMenuExpandedAlpha;
    CGAffineTransform transform = collapsed ? CGAffineTransformMakeScale(0.92f, 0.92f) : CGAffineTransformIdentity;

    void (^changes)(void) = ^{
        self->_floatingMenuButton.center = CGPointMake(centerX, self->_floatingMenuCenterY);
        self->_floatingMenuButton.alpha = alpha;
        self->_floatingMenuButton.transform = transform;
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    }
    else {
        changes();
    }
}

- (void)scheduleFloatingMenuAutoCollapse {
    [self invalidateFloatingMenuDormancyTimer];
    _floatingMenuDormancyTimer = [NSTimer scheduledTimerWithTimeInterval:kStreamFloatingMenuAutoCollapseDelay
                                                                  target:self
                                                                selector:@selector(handleFloatingMenuDormancyTimer:)
                                                                userInfo:nil
                                                                 repeats:NO];
}

- (void)handleFloatingMenuDormancyTimer:(NSTimer *)timer {
    [self setFloatingMenuCollapsed:YES animated:YES];
}

- (void)handleFloatingMenuPan:(UILongPressGestureRecognizer *)recognizer {
    if (_floatingMenuButton == nil) {
        return;
    }

    CGRect bounds = self.view.bounds;
    CGFloat minCenterY = [self floatingMenuMinimumCenterYForBounds:bounds];
    CGFloat maxCenterY = [self floatingMenuMaximumCenterYForBounds:bounds];
    CGFloat minCenterX = [self floatingMenuExpandedCenterXForBounds:bounds anchoredRight:NO];
    CGFloat maxCenterX = [self floatingMenuExpandedCenterXForBounds:bounds anchoredRight:YES];

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            _floatingMenuDragMoved = NO;
            [_floatingMenuButton.layer removeAllAnimations];
            _floatingMenuPanStartCenter = _floatingMenuButton.center;
            [self invalidateFloatingMenuDormancyTimer];
            if (_floatingMenuCollapsed) {
                [self setFloatingMenuCollapsed:NO animated:NO];
                _floatingMenuPanStartCenter = _floatingMenuButton.center;
            }
            else {
                [self setFloatingMenuCollapsed:NO animated:NO];
            }
            {
                CGPoint location = [recognizer locationInView:self.view];
                _floatingMenuTouchOffset = CGPointMake(location.x - _floatingMenuButton.center.x,
                                                       location.y - _floatingMenuButton.center.y);
            }
            break;

        case UIGestureRecognizerStateChanged: {
            CGPoint location = [recognizer locationInView:self.view];
            CGPoint translation = CGPointMake(location.x - (_floatingMenuPanStartCenter.x + _floatingMenuTouchOffset.x),
                                             location.y - (_floatingMenuPanStartCenter.y + _floatingMenuTouchOffset.y));
            if (!_floatingMenuDragMoved && hypot(translation.x, translation.y) > 4.0f) {
                _floatingMenuDragMoved = YES;
            }
            if (!_floatingMenuDragMoved) {
                break;
            }
            CGPoint newCenter = CGPointMake(location.x - _floatingMenuTouchOffset.x,
                                            location.y - _floatingMenuTouchOffset.y);
            newCenter.x = MIN(MAX(newCenter.x, minCenterX), maxCenterX);
            newCenter.y = MIN(MAX(newCenter.y, minCenterY), maxCenterY);
            _floatingMenuButton.center = newCenter;
            _floatingMenuCenterY = newCenter.y;
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!_floatingMenuDragMoved) {
                break;
            }

            CGPoint location = [recognizer locationInView:self.view];
            CGFloat midpointX = CGRectGetMidX(bounds);
            _floatingMenuAnchoredRight = location.x >= midpointX;
            _floatingMenuCenterY = MIN(MAX(_floatingMenuButton.center.y, minCenterY), maxCenterY);
            _floatingMenuHasCustomPosition = YES;
            [self setFloatingMenuCollapsed:NO animated:YES];
            [self scheduleFloatingMenuAutoCollapse];
            break;
        }

        default:
            break;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self applyPreferredOrientationIfNeeded];
    [self reloadVirtualControlSchemesFromSavedSettingsIfNeeded];
#if defined(__IPHONE_14_0)
    if (@available(iOS 14.0, *)) {
        [self setNeedsUpdateOfPrefersPointerLocked];
    }
#endif
    //外接显示器
    if(_settings.externalMonitor){
        _deviceWindow = self.view.window;
        if (UIScreen.screens.count > 1) {
            [self prepExtScreen:UIScreen.screens.lastObject];
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.view insertSubview:self->_renderView atIndex:0];
            });
        }
        // check to see if external screen is connected/disconnected
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(extScreenDidConnect:)
                                                     name: UIScreenDidConnectNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(extScreenDidDisconnect:)
                                                     name: UIScreenDidDisconnectNotification
                                                   object: nil];
    }
    
}

#if TARGET_OS_TV
- (void)controllerPauseButtonPressed:(id)sender { }
- (void)controllerPauseButtonDoublePressed:(id)sender {
    Log(LOG_I, @"Menu double-pressed -- backing out of stream");
    [self returnToMainFrame];
}
- (void)controllerPlayPauseButtonPressed:(id)sender {
    Log(LOG_I, @"Play/Pause button pressed -- backing out of stream");
    [self returnToMainFrame];
}
#endif


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    _settings = [[[DataManager alloc] init] getSettings];
    _currentSessionVirtualButtonSchemeSelection = _settings.virtualButtonSchemeSelection;
    _currentSessionVirtualGamepadSchemeSelection = _settings.virtualGamepadSchemeSelection;
    _currentSessionVirtualButtonLayoutPortrait = [self isVirtualButtonLayoutPortraitForSize:self.view.bounds.size];
    _currentSessionVirtualGamepadLayoutPortrait = _currentSessionVirtualButtonLayoutPortrait;
    [self loadVirtualButtonDefinitionsFromCurrentScheme];
    [self loadVirtualGamepadDefinitionsFromCurrentScheme];
    [self loadCustomShortcutDefinitions];
    _currentSessionTouchModeSelection = MAX(StreamTouchModeSelectionTrackpad,
                                            MIN(_settings.touchModeSelection, StreamTouchModeSelectionDisabled));
    _currentSessionVideoAlignmentSelection = MAX(0, MIN(_settings.videoAlignmentSelection, 2));
    _currentSessionVideoAlignmentMargin = MAX(0.0f, MIN(_settings.videoAlignmentMargin, 150.0f));
    NSInteger savedPerformanceOverlayPositionSelection = _settings.performanceOverlayPositionSelection;
    if (savedPerformanceOverlayPositionSelection == kStreamPerformanceOverlayPositionCustom) {
        _currentSessionPerformanceOverlayPositionSelection = kStreamPerformanceOverlayPositionCustom;
    }
    else {
        _currentSessionPerformanceOverlayPositionSelection = MAX(0, MIN(savedPerformanceOverlayPositionSelection, 5));
    }
    _currentSessionPerformanceOverlayMargin = MAX(0.0f, MIN(_settings.performanceOverlayMargin, 150.0f));
    _currentSessionPerformanceOverlayDragEnabled = _settings.performanceOverlayDragEnabled;
    _currentSessionPerformanceOverlayCustomXRatio = 0.5f;
    _currentSessionPerformanceOverlayCustomYRatio = 0.0f;
    
    _stageLabel = [[UILabel alloc] init];
    [_stageLabel setUserInteractionEnabled:NO];
    [_stageLabel setText:[NSString stringWithFormat:@"Starting %@...", self.streamConfig.appName]];
    [_stageLabel sizeToFit];
    _stageLabel.textAlignment = NSTextAlignmentCenter;
    _stageLabel.textColor = [UIColor whiteColor];
    _stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    
    _spinner = [[UIActivityIndicatorView alloc] init];
    [_spinner setUserInteractionEnabled:NO];
#if TARGET_OS_TV
    [_spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
#else
    [_spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
#endif
    [_spinner sizeToFit];
    [_spinner startAnimating];
    _spinner.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2 - _stageLabel.frame.size.height - _spinner.frame.size.height);
    
    _controllerSupport = [[ControllerSupport alloc] initWithConfig:self.streamConfig delegate:self];
    _inactivityTimer = nil;
    
    _streamView = [[StreamView alloc] initWithFrame:self.view.frame];
    [_streamView setVideoAlignmentMode:_currentSessionVideoAlignmentSelection];
    [_streamView setVideoAlignmentMargin:_currentSessionVideoAlignmentMargin];
    
    //外接显示器
    if(_settings.externalMonitor){
        _renderView = [[StreamView alloc] initWithFrame:self.view.frame];
        _renderView.bounds = _streamView.bounds;
        [_renderView setVideoAlignmentMode:_currentSessionVideoAlignmentSelection];
        [_renderView setVideoAlignmentMargin:_currentSessionVideoAlignmentMargin];
    }
    
    [_streamView setupStreamView:_controllerSupport interactionDelegate:self config:self.streamConfig];
    [_streamView setVideoAlignmentMode:_currentSessionVideoAlignmentSelection];
    [_streamView setVideoAlignmentMargin:_currentSessionVideoAlignmentMargin];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self applyVirtualGamepadDefinitionsToStreamView];
    
#if TARGET_OS_TV
    if (!_menuTapGestureRecognizer || !_menuDoubleTapGestureRecognizer || !_playPauseTapGestureRecognizer) {
        _menuTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPauseButtonPressed:)];
        _menuTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypeMenu)];
        
        _playPauseTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPlayPauseButtonPressed:)];
        _playPauseTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypePlayPause)];
        
        _menuDoubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPauseButtonDoublePressed:)];
        _menuDoubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [_menuTapGestureRecognizer requireGestureRecognizerToFail:_menuDoubleTapGestureRecognizer];
        _menuDoubleTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypeMenu)];
    }
    
    [self.view addGestureRecognizer:_menuTapGestureRecognizer];
    [self.view addGestureRecognizer:_menuDoubleTapGestureRecognizer];
    [self.view addGestureRecognizer:_playPauseTapGestureRecognizer];
    
#else
    _exitSwipeRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
    _exitSwipeRecognizer.edges = UIRectEdgeLeft;
    _exitSwipeRecognizer.delaysTouchesBegan = NO;
    _exitSwipeRecognizer.delaysTouchesEnded = NO;
    
    [self.view addGestureRecognizer:_exitSwipeRecognizer];
#endif
    
    _tipLabel = [[UILabel alloc] init];
    [_tipLabel setUserInteractionEnabled:NO];
    
#if TARGET_OS_TV
    [_tipLabel setText:@"Tip: Tap the Play/Pause button on the Apple TV Remote to disconnect from your PC"];
#else
    [_tipLabel setText:StreamMenuLocalized(@"stream.menu.edge_swipe_hint")];
#endif
    
    _tipLabel.textColor = [UIColor whiteColor];
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.numberOfLines = 1;
    _tipLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.62];
    _tipLabel.layer.cornerRadius = 16.0;
    _tipLabel.layer.masksToBounds = YES;
    _tipLabel.layer.borderWidth = 1.0;
    _tipLabel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
    _tipLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height * 0.9);
    
    //外接显示器
    if(_settings.externalMonitor){
        _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                                renderView:_renderView
                                       connectionCallbacks:self];
    }else{
        _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                                renderView:_streamView
                                       connectionCallbacks:self];
    }
    
    NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperation:_streamMan];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(applicationDidBecomeActive:)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(applicationDidEnterBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(streamVirtualButtonsDidChange:)
                                                 name:StreamViewVirtualButtonsDidChangeNotification
                                               object:_streamView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVirtualButtonSelectionDidChange:)
                                                 name:StreamViewVirtualButtonSelectionDidChangeNotification
                                               object:_streamView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(streamVirtualGamepadDidChange:)
                                                 name:StreamViewVirtualGamepadDidChangeNotification
                                               object:_streamView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVirtualGamepadSelectionDidChange:)
                                                 name:StreamViewVirtualGamepadSelectionDidChangeNotification
                                               object:_streamView];
    
#if 0
    // FIXME: This doesn't work reliably on iPad for some reason. Showing and hiding the keyboard
    // several times in a row will not correctly restore the state of the UIScrollView.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillShow:)
                                                 name: UIKeyboardWillShowNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillHide:)
                                                 name: UIKeyboardWillHideNotification
                                               object: nil];
#endif
    
    // Only wrap the stream in a scroll view for temporary view-only mode.
    if (_viewOnlyModeEnabled) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
#if !TARGET_OS_TV
        [_scrollView.panGestureRecognizer setMinimumNumberOfTouches:1];
#endif
        [_scrollView setShowsHorizontalScrollIndicator:NO];
        [_scrollView setShowsVerticalScrollIndicator:NO];
        [_scrollView setDelegate:self];
        [_scrollView setMinimumZoomScale:1.0f];
        [_scrollView setMaximumZoomScale:10.0f];
        [_scrollView setScrollEnabled:YES];
        [_scrollView.pinchGestureRecognizer setEnabled:YES];
        
        // Add StreamView inside a UIScrollView for view-only mode
        [_scrollView addSubview:_streamView];
        [self.view addSubview:_scrollView];
    }
    else {
        // Add StreamView directly during normal streaming interaction
        [self.view addSubview:_streamView];
    }
    
    [self.view addSubview:_stageLabel];
    [self.view addSubview:_spinner];
    [self.view addSubview:_tipLabel];
    [self installVirtualButtonEditorIfNeeded];
    if (_settings.floatingMenuEnabled) {
        [self installFloatingMenuButtonIfNeeded];
    }

    [self layoutStreamingSubviewsForCurrentBounds];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _streamView;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    // Only cleanup when we're being destroyed
    if (parent == nil) {
        [_controllerSupport cleanup];
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        if (!_manualExitInProgress) {
            [_streamMan stopStream];
        }
        if (_inactivityTimer != nil) {
            [_inactivityTimer invalidate];
            _inactivityTimer = nil;
        }
        [self invalidateFloatingMenuDormancyTimer];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

#if 0
- (void)keyboardWillShow:(NSNotification *)notification {
    _keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self->_scrollView.frame;
        frame.size.height -= self->_keyboardSize.height;
        self->_scrollView.frame = frame;
    }];
}

-(void)keyboardWillHide:(NSNotification *)notification {
    // NOTE: UIKeyboardFrameEndUserInfoKey returns a different keyboard size
    // than UIKeyboardFrameBeginUserInfoKey, so it's unsuitable for use here
    // to undo the changes made by keyboardWillShow.
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self->_scrollView.frame;
        frame.size.height += self->_keyboardSize.height;
        self->_scrollView.frame = frame;
    }];
}
#endif


//外接显示器----start
// External Screen connected
- (void)extScreenDidConnect:(NSNotification *)notification {
    Log(LOG_I, @"External Screen Connected");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self prepExtScreen:notification.object];
    });
}

// External Screen disconnected
- (void)extScreenDidDisconnect:(NSNotification *)notification {
    Log(LOG_I, @"External Screen Disconnected");
    if(UIScreen.screens.count < 2)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeExtScreen];
        });
    }
}

// Prepare Screen
- (void)prepExtScreen:(UIScreen*)extScreen {
    Log(LOG_I, @"Preparing External Screen");
    CGRect frame = extScreen.bounds;
    extScreen.overscanCompensation = 3;
    _extWindow = [[UIWindow alloc] initWithFrame:frame];
    _extWindow.screen = extScreen;
    _renderView.bounds = frame;
    _renderView.frame = frame;
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:@"ScreenConnected" object:self];
    [_extWindow addSubview:_renderView];
    _extWindow.hidden = NO;
}

- (void)removeExtScreen {
    Log(LOG_I, @"Removing External Screen");
    _extWindow.hidden = YES;
    _renderView.bounds = _deviceWindow.bounds;
    _renderView.frame = _deviceWindow.frame;
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:@"ScreenDisconnected" object:self];
    [self.view insertSubview:_renderView atIndex:0];
}
//外接显示器----end


- (void)updateStatsOverlay {
    //    NSString* overlayText = [self->_streamMan getStatsOverlayText];
    NSString* overlayText = [NSString stringWithFormat:@"%@ %@%@",
                             [self->_streamMan getBandwidthOverlayText],
                             [self->_streamMan getStatsOverlayTextWithExtendedMetrics:_extendedPerformanceMetricsEnabled],
                             _microphoneEnabled ? @" Mic" : @""];
    NSAttributedString *attributedText = [self statsOverlayAttributedTextForText:overlayText];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_overlayView == nil) {
            [self updateOverlayText:overlayText];
        }
        [self->_overlayView setAttributedText:attributedText];
        [self->_overlayView setHidden:NO];
        [self layoutOverlayViewForCurrentBounds];
    });
}

- (void)updateOverlayText:(NSString*)text {
    if (_overlayView == nil) {
        _overlayView = [[UITextView alloc] init];
#if !TARGET_OS_TV
        [_overlayView setEditable:NO];
#endif
        [_overlayView setUserInteractionEnabled:_currentSessionPerformanceOverlayDragEnabled];
        [_overlayView setSelectable:NO];
        [_overlayView setScrollEnabled:NO];
        
        // HACK: If not using stats overlay, center the text
        if (_statsUpdateTimer == nil) {
            [_overlayView setTextAlignment:NSTextAlignmentCenter];
        }
        
        _overlayView.layer.cornerRadius = 2.0;  // 设置圆角半径
        _overlayView.layer.masksToBounds = YES;  // 确保圆角生效
        
        [_overlayView setTextColor:[UIColor whiteColor]];
        //        [_overlayView setBackgroundColor:[UIColor blackColor]];
        UIColor *colorWithAlpha = [[UIColor blackColor] colorWithAlphaComponent:0.35];
        [_overlayView setBackgroundColor:colorWithAlpha];
        _overlayView.textContainerInset = UIEdgeInsetsMake(3, 2, 2, 3);  // 设置内边距
        
#if TARGET_OS_TV
        [_overlayView setFont:[UIFont systemFontOfSize:24]];
#else
        [_overlayView setFont:[UIFont systemFontOfSize:10]];
#endif
        _overlayPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePerformanceOverlayPan:)];
        [_overlayView addGestureRecognizer:_overlayPanGestureRecognizer];
        //        [_overlayView setAlpha:0.35];
        [self.view addSubview:_overlayView];
    }
    
    if (text != nil) {
        [_overlayView setAttributedText:nil];
        [_overlayView setText:text];
        [_overlayView setHidden:NO];
        [self layoutOverlayViewForCurrentBounds];
    }
    else {
        [_overlayView setHidden:YES];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutStreamingSubviewsForCurrentBounds];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    BOOL nextPortrait = [self isVirtualButtonLayoutPortraitForSize:size];
    BOOL virtualButtonOrientationChanged = nextPortrait != _currentSessionVirtualButtonLayoutPortrait;
    BOOL virtualGamepadOrientationChanged = nextPortrait != _currentSessionVirtualGamepadLayoutPortrait;

    if (virtualButtonOrientationChanged) {
        [self persistCurrentVirtualButtonScheme];
    }
    if (virtualGamepadOrientationChanged) {
        [self persistCurrentVirtualGamepadScheme];
    }

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        [self layoutStreamingSubviewsForCurrentBounds];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        if (virtualButtonOrientationChanged) {
            [self switchVirtualButtonLayoutToPortrait:nextPortrait preserveCurrentLayoutAsFallback:YES];
            [self applyVirtualButtonDefinitionsToStreamView];
            [self refreshVirtualButtonsPanelIfNeeded];
            [self refreshVirtualButtonEditorForCurrentSelection];
        }
        if (virtualGamepadOrientationChanged) {
            [self switchVirtualGamepadLayoutToPortrait:nextPortrait preserveCurrentLayoutAsFallback:YES];
            [self applyVirtualGamepadDefinitionsToStreamView];
            [self refreshVirtualButtonEditorForCurrentSelection];
        }
        [self layoutStreamingSubviewsForCurrentBounds];
    }];
}

- (void) returnToMainFrame {
#if !TARGET_OS_TV
    [self resetPictureInPictureState];
#endif
    // Reset display mode back to default
    [self updatePreferredDisplayMode:NO];
    
    [_statsUpdateTimer invalidate];
    _statsUpdateTimer = nil;
    [_micUplinkManager stop];
    _micUplinkManager = nil;
    _microphoneStartRequested = NO;
    _microphoneEnabled = NO;
    [self invalidateFloatingMenuDormancyTimer];
    
    _suppressTerminationAlertForManualExit = YES;
    _manualExitInProgress = YES;

    void (^stopStreamAfterNavigation)(void) = ^{
        [self->_streamMan stopStream];
    };

    [self.navigationController popToRootViewControllerAnimated:YES];
    id<UIViewControllerTransitionCoordinator> coordinator = self.navigationController.transitionCoordinator;
    if (coordinator != nil) {
        [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
            stopStreamAfterNavigation();
        }];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            stopStreamAfterNavigation();
        });
    }
    _extWindow = nil;
    
}

- (void)presentConnectionAlertWithTitle:(NSString *)title message:(NSString *)message {
    if (title.length == 0 && message.length == 0) {
        [self returnToMainFrame];
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^showAlert)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        UIViewController *presenter = strongSelf.navigationController ?: strongSelf;
        if (presenter.view.window == nil) {
            [strongSelf returnToMainFrame];
            return;
        }

        UIAlertController* conTermAlert = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:conTermAlert];
        [conTermAlert addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"common.ok")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction* action){
            [strongSelf returnToMainFrame];
        }]];
        [presenter presentViewController:conTermAlert animated:YES completion:nil];
    };

    UIViewController *presenter = self.navigationController ?: self;
    UIViewController *presentedController = presenter.presentedViewController;
    if (presentedController != nil && !presentedController.isBeingDismissed) {
        [self clearPresentedStreamOverlayControllerIfNeeded:presentedController];
        [presentedController dismissViewControllerAnimated:NO completion:showAlert];
    }
    else {
        showAlert();
    }
}

// This will fire if the user opens control center or gets a low battery message
- (void)applicationWillResignActive:(NSNotification *)notification {
    if (_inactivityTimer != nil) {
        [_inactivityTimer invalidate];
    }
    
#if !TARGET_OS_TV
    // Terminate the stream if the app is inactive for 60 seconds
    Log(LOG_I, @"Starting inactivity termination timer");
    _inactivityTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                        target:self
                                                      selector:@selector(inactiveTimerExpired:)
                                                      userInfo:nil
                                                       repeats:NO];
#endif
}

- (void)inactiveTimerExpired:(NSTimer*)timer {
    Log(LOG_I, @"Terminating stream after inactivity");
    
    [self returnToMainFrame];
    
    _inactivityTimer = nil;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
#if !TARGET_OS_TV
    _pictureInPictureStartingForBackground = NO;
#endif
    [self reloadVirtualControlSchemesFromSavedSettingsIfNeeded];
    // Stop the background timer, since we're foregrounded again
    if (_inactivityTimer != nil) {
        Log(LOG_I, @"Stopping inactivity timer after becoming active again");
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
}

// This fires when the home button is pressed
- (void)applicationDidEnterBackground:(UIApplication *)application {
#if !TARGET_OS_TV
    if ([self shouldKeepStreamAliveForPictureInPicture]) {
        Log(LOG_I, @"Keeping stream alive for Picture in Picture");
        if (_inactivityTimer != nil) {
            [_inactivityTimer invalidate];
            _inactivityTimer = nil;
        }
        return;
    }
#endif
    Log(LOG_I, @"Terminating stream immediately for backgrounding");
    
    if (_inactivityTimer != nil) {
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
    
    [self returnToMainFrame];
}

- (void)edgeSwiped {
    Log(LOG_I, @"User swiped to end stream");
    [self showActionSheetWithTitle:StreamMenuLocalized(@"stream.menu.title") options:nil];
}

- (BOOL)streamOverlayWantsMouseInputSuppressed {
    return _streamActionSheetHostingViewController != nil ||
           _streamShortcutPanelHostingViewController != nil ||
           _streamVirtualKeyboardPanelHostingViewController != nil ||
           _streamVirtualButtonsPanelHostingViewController != nil ||
           (_virtualButtonEditorView != nil && !_virtualButtonEditorView.hidden) ||
           [_streamView isTemporaryVirtualButtonsEditingEnabled] ||
           [_streamView isTemporaryVirtualGamepadEditingEnabled];
}

- (void)setStreamOverlayMouseInputSuppressed:(BOOL)suppressed {
    if (_streamOverlayMouseInputSuppressed == suppressed) {
        return;
    }

    _streamOverlayMouseInputSuppressed = suppressed;
    [_streamView setMouseInputSuppressed:suppressed];
    [_controllerSupport setMouseInputSuppressed:suppressed];
}

- (void)updateStreamOverlayMouseInputSuppression {
    [self setStreamOverlayMouseInputSuppressed:[self streamOverlayWantsMouseInputSuppressed]];
}

- (void)clearPresentedStreamOverlayControllerIfNeeded:(UIViewController *)presentedController {
    if (presentedController == _streamActionSheetHostingViewController) {
        _streamActionSheetHostingViewController = nil;
    }
    if (presentedController == _streamShortcutPanelHostingViewController) {
        _streamShortcutPanelHostingViewController = nil;
    }
    if (presentedController == _streamVirtualKeyboardPanelHostingViewController) {
        _streamVirtualKeyboardPanelHostingViewController = nil;
    }
    if (presentedController == _streamVirtualButtonsPanelHostingViewController) {
        _streamVirtualButtonsPanelHostingViewController = nil;
    }
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)showActionSheetWithTitle:(NSString *)title options:(NSArray<NSString *> *)options {
    if (@available(iOS 13.0, *)) {
        NSMutableArray<StreamActionSheetItem *> *items = [NSMutableArray array];

        StreamActionSheetItem *disconnectItem = [[StreamActionSheetItem alloc] init];
        disconnectItem.identifier = @"disconnect";
        disconnectItem.title = StreamMenuLocalized(@"stream.menu.disconnect.title");
        disconnectItem.subtitle = StreamMenuLocalized(@"stream.menu.disconnect.subtitle");
        disconnectItem.symbolName = @"xmark.circle";
        disconnectItem.destructive = YES;
        disconnectItem.accentColor = [UIColor systemRedColor];
        [items addObject:disconnectItem];

        StreamActionSheetItem *quitStreamItem = [[StreamActionSheetItem alloc] init];
        quitStreamItem.identifier = @"quit_app";
        quitStreamItem.title = StreamMenuLocalized(@"stream.menu.quit_stream.title");
        quitStreamItem.subtitle = StreamMenuLocalized(@"stream.menu.quit_stream.subtitle");
        quitStreamItem.symbolName = @"rectangle.portrait.and.arrow.right";
        quitStreamItem.destructive = YES;
        quitStreamItem.accentColor = [UIColor systemOrangeColor];
        [items addObject:quitStreamItem];

        StreamActionSheetItem *statsItem = [[StreamActionSheetItem alloc] init];
        statsItem.identifier = @"open_performance";
        statsItem.title = StreamMenuLocalized(@"stream.menu.stats.title");
        statsItem.subtitle = StreamMenuLocalized(@"stream.menu.stats.subtitle");
        statsItem.symbolName = @"chart.bar.xaxis";
        statsItem.active = [self isPerformanceOverlayVisible];
        statsItem.accentColor = [UIColor systemTealColor];
        [items addObject:statsItem];

        StreamActionSheetItem *microphoneItem = [[StreamActionSheetItem alloc] init];
        microphoneItem.identifier = @"toggle_microphone";
        microphoneItem.title = StreamMenuLocalized(@"stream.menu.microphone.title");
        microphoneItem.subtitle = StreamMenuLocalized(_microphoneEnabled ? @"stream.menu.microphone.subtitle_on" : @"stream.menu.microphone.subtitle_off");
        microphoneItem.symbolName = _microphoneEnabled ? @"mic.fill" : @"mic.slash";
        microphoneItem.active = _microphoneEnabled;
        microphoneItem.accentColor = [UIColor systemPinkColor];
        [items addObject:microphoneItem];

        StreamActionSheetItem *keyboardItem = [[StreamActionSheetItem alloc] init];
        keyboardItem.identifier = @"keyboard";
        keyboardItem.title = StreamMenuLocalized(@"stream.menu.phone_keyboard.title");
        keyboardItem.subtitle = StreamMenuLocalized(@"stream.menu.phone_keyboard.subtitle");
        keyboardItem.symbolName = @"keyboard";
        keyboardItem.accentColor = [UIColor systemBlueColor];
        [items addObject:keyboardItem];

        StreamActionSheetItem *virtualGamepadItem = [[StreamActionSheetItem alloc] init];
        virtualGamepadItem.identifier = @"virtual_gamepad";
        virtualGamepadItem.title = StreamMenuLocalized(@"stream.menu.virtual_gamepad.title");
        virtualGamepadItem.subtitle = StreamMenuLocalized(@"stream.menu.virtual_gamepad.subtitle");
        virtualGamepadItem.symbolName = @"gamecontroller";
        virtualGamepadItem.active = [_streamView isTemporaryVirtualGamepadVisible];
        virtualGamepadItem.accentColor = [UIColor systemIndigoColor];
        [items addObject:virtualGamepadItem];

        StreamActionSheetItem *manageVirtualGamepadItem = [[StreamActionSheetItem alloc] init];
        manageVirtualGamepadItem.identifier = @"manage_virtual_gamepad";
        manageVirtualGamepadItem.title = StreamMenuLocalized(@"stream.menu.manage_virtual_gamepad.title");
        manageVirtualGamepadItem.subtitle = StreamMenuLocalized(@"stream.menu.manage_virtual_gamepad.subtitle");
        manageVirtualGamepadItem.symbolName = @"gamecontroller.fill";
        manageVirtualGamepadItem.active = [_streamView isTemporaryVirtualGamepadEditingEnabled];
        manageVirtualGamepadItem.accentColor = [UIColor systemPurpleColor];

        StreamActionSheetItem *virtualButtonsItem = [[StreamActionSheetItem alloc] init];
        virtualButtonsItem.identifier = @"virtual_buttons";
        virtualButtonsItem.title = StreamMenuLocalized(@"stream.menu.virtual_buttons.title");
        virtualButtonsItem.subtitle = StreamMenuLocalized(@"stream.menu.virtual_buttons.subtitle");
        virtualButtonsItem.symbolName = @"square.grid.2x2";
        virtualButtonsItem.active = [_streamView isTemporaryVirtualButtonsVisible];
        virtualButtonsItem.accentColor = [UIColor colorWithRed:0.36 green:0.88 blue:0.79 alpha:1.0];
        [items addObject:virtualButtonsItem];

        StreamActionSheetItem *manageVirtualButtonsItem = [[StreamActionSheetItem alloc] init];
        manageVirtualButtonsItem.identifier = @"manage_virtual_buttons";
        manageVirtualButtonsItem.title = StreamMenuLocalized(@"stream.menu.manage_virtual_buttons.title");
        manageVirtualButtonsItem.subtitle = StreamMenuLocalized(@"stream.menu.manage_virtual_buttons.subtitle");
        manageVirtualButtonsItem.symbolName = @"square.and.pencil";
        manageVirtualButtonsItem.accentColor = [UIColor systemTealColor];

        StreamActionSheetItem *shortcutItem = [[StreamActionSheetItem alloc] init];
        shortcutItem.identifier = @"shortcuts";
        shortcutItem.title = StreamMenuLocalized(@"stream.menu.shortcuts.title");
        shortcutItem.subtitle = StreamMenuLocalized(@"stream.menu.shortcuts.subtitle");
        shortcutItem.symbolName = @"command.square";
        shortcutItem.accentColor = [UIColor systemBlueColor];
        [items addObject:shortcutItem];

        StreamActionSheetItem *fullKeyboardItem = [[StreamActionSheetItem alloc] init];
        fullKeyboardItem.identifier = @"full_keyboard";
        fullKeyboardItem.title = StreamMenuLocalized(@"stream.menu.full_keyboard.title");
        fullKeyboardItem.subtitle = StreamMenuLocalized(@"stream.menu.full_keyboard.subtitle");
        fullKeyboardItem.symbolName = @"keyboard.badge.ellipsis";
        fullKeyboardItem.accentColor = [UIColor systemOrangeColor];
        [items addObject:fullKeyboardItem];

        StreamActionSheetItem *viewOnlyItem = [[StreamActionSheetItem alloc] init];
        viewOnlyItem.identifier = @"view_only";
        viewOnlyItem.title = StreamMenuLocalized(@"stream.menu.view_only.title");
        viewOnlyItem.subtitle = StreamMenuLocalized(@"stream.menu.view_only.subtitle");
        viewOnlyItem.symbolName = @"eye";
        viewOnlyItem.active = _viewOnlyModeEnabled;
        viewOnlyItem.accentColor = [UIColor systemGreenColor];
        [items addObject:viewOnlyItem];

        StreamActionSheetItem *audioHapticsItem = [[StreamActionSheetItem alloc] init];
        audioHapticsItem.identifier = @"open_audio_haptics";
        audioHapticsItem.title = StreamMenuLocalized(@"stream.audio_haptics.title");
        audioHapticsItem.subtitle = StreamMenuLocalized(@"stream.audio_haptics.title");
        audioHapticsItem.symbolName = @"waveform.path";
        audioHapticsItem.active = _settings.audioHapticsEnabled;
        audioHapticsItem.accentColor = [UIColor colorWithRed:0.38 green:0.84 blue:0.98 alpha:1.0];
        [items addObject:audioHapticsItem];

        StreamActionSheetItem *videoAlignmentItem = [[StreamActionSheetItem alloc] init];
        videoAlignmentItem.identifier = @"open_video_alignment";
        videoAlignmentItem.title = StreamMenuLocalized(@"stream.video_alignment.title");
        videoAlignmentItem.subtitle = StreamMenuLocalized(@"stream.video_alignment.title");
        videoAlignmentItem.symbolName = @"rectangle.center.inset.filled";
        videoAlignmentItem.active = ([self currentVideoAlignmentSelection] != 0 || _currentSessionVideoAlignmentMargin > 0.5f);
        videoAlignmentItem.accentColor = [UIColor colorWithRed:0.38 green:0.84 blue:0.98 alpha:1.0];
        [items addObject:videoAlignmentItem];

        [items addObject:manageVirtualGamepadItem];
        [items addObject:manageVirtualButtonsItem];

        StreamActionSheetHostingViewController *controller = [[StreamActionSheetHostingViewController alloc] init];
        controller.delegate = (id<StreamActionSheetHostingViewControllerDelegate>)self;
        controller.touchModeSelection = @([self currentTouchModeSelection]);
        controller.videoAlignmentSelection = @([self currentVideoAlignmentSelection]);
        controller.videoAlignmentMargin = @(_currentSessionVideoAlignmentMargin);
        controller.statsOverlayEnabled = [self isPerformanceOverlayVisible];
        controller.extendedPerformanceMetricsEnabled = _extendedPerformanceMetricsEnabled;
        controller.performanceOverlayDragEnabled = _currentSessionPerformanceOverlayDragEnabled;
        controller.audioHapticsEnabled = _settings.audioHapticsEnabled;
        controller.audioHapticsOutputTargetSelection = @(_settings.audioHapticsOutputTarget);
        controller.audioHapticsStrength = @(_settings.audioHapticsStrength);
        controller.audioHapticsVoiceFilterSelection = @(_settings.audioHapticsVoiceFilterSelection);
        controller.audioHapticsKeepControllerRumble = _settings.audioHapticsKeepControllerRumble;
        [controller configureWithTitle:title subtitle:StreamMenuLocalized(@"stream.menu.subtitle") items:items];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;

        _streamActionSheetHostingViewController = controller;
        [self updateStreamOverlayMouseInputSuppression];
        [self presentViewController:controller animated:YES completion:nil];
        return;
    }

    [self setStreamOverlayMouseInputSuppressed:YES];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"stream.menu.disconnect_fallback")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self updateStreamOverlayMouseInputSuppression];
        [self returnToMainFrame];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"stream.menu.toggle_stats_fallback")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self updateStreamOverlayMouseInputSuppression];
        [self handleStreamMenuActionWithIdentifier:@"toggle_stats"];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"stream.menu.toggle_microphone_fallback")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self updateStreamOverlayMouseInputSuppression];
        [self handleStreamMenuActionWithIdentifier:@"toggle_microphone"];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"stream.menu.open_keyboard_fallback")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self updateStreamOverlayMouseInputSuppression];
        [self handleStreamMenuActionWithIdentifier:@"keyboard"];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"common.cancel")
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self updateStreamOverlayMouseInputSuppression];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSInteger)currentTouchModeSelection {
    return _currentSessionTouchModeSelection;
}

- (NSInteger)currentVideoAlignmentSelection {
    return _currentSessionVideoAlignmentSelection;
}

- (CGFloat)currentVideoAlignmentMargin {
    return _currentSessionVideoAlignmentMargin;
}

- (void)applyTouchModeSelectionToCurrentSession:(NSInteger)selection {
    NSInteger normalizedSelection = MAX(StreamTouchModeSelectionTrackpad,
                                        MIN(selection, StreamTouchModeSelectionDisabled));
    _currentSessionTouchModeSelection = normalizedSelection;
    _settings.touchModeSelection = normalizedSelection;
    [[[DataManager alloc] init] saveTouchModeSelection:normalizedSelection];

    [_streamView applyTemporaryTouchModeSelection:normalizedSelection];
    [self updateStreamingTouchModeLayout];
    [_streamView resetAfterTemporaryTouchModeChange];
}

- (void)updateStreamingTouchModeLayout {
    BOOL needsScrollView = _viewOnlyModeEnabled;

        if (needsScrollView) {
            if (_scrollView == nil) {
                _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
            [_scrollView setShowsHorizontalScrollIndicator:NO];
            [_scrollView setShowsVerticalScrollIndicator:NO];
            [_scrollView setDelegate:self];
            [_scrollView setMinimumZoomScale:1.0f];
            [_scrollView setMaximumZoomScale:10.0f];
            [_scrollView setMultipleTouchEnabled:YES];
            [_scrollView setBackgroundColor:[UIColor clearColor]];
        }

#if !TARGET_OS_TV
        [_scrollView.panGestureRecognizer setMinimumNumberOfTouches:(_viewOnlyModeEnabled ? 1 : 2)];
#endif
        [_scrollView setDelaysContentTouches:_viewOnlyModeEnabled];
        [_scrollView setCanCancelContentTouches:_viewOnlyModeEnabled];
        [_scrollView setScrollEnabled:_viewOnlyModeEnabled];
        [_scrollView.pinchGestureRecognizer setEnabled:_viewOnlyModeEnabled];
        if (!_viewOnlyModeEnabled) {
            [_scrollView setZoomScale:1.0f animated:NO];
            [_scrollView setContentOffset:CGPointZero animated:NO];
        }

        if (_scrollView.superview != self.view) {
            [self.view insertSubview:_scrollView atIndex:0];
        }

        if (_streamView.superview != _scrollView) {
            [_streamView removeFromSuperview];
            [_scrollView addSubview:_streamView];
        }
    }
    else {
        if (_streamView.superview != self.view) {
            [_streamView removeFromSuperview];
            [self.view insertSubview:_streamView atIndex:0];
        }

        if (_scrollView != nil && _scrollView.superview == self.view) {
            [_scrollView removeFromSuperview];
        }
    }

    if (_stageLabel.superview == self.view) {
        [self.view bringSubviewToFront:_stageLabel];
    }
    if (_spinner.superview == self.view) {
        [self.view bringSubviewToFront:_spinner];
    }
    if (_tipLabel.superview == self.view) {
        [self.view bringSubviewToFront:_tipLabel];
    }
    if (_overlayView != nil && _overlayView.superview == self.view) {
        [self.view bringSubviewToFront:_overlayView];
    }
    if (_virtualButtonEditorView != nil && _virtualButtonEditorView.superview == self.view) {
        [self.view bringSubviewToFront:_virtualButtonEditorView];
    }
    if (_virtualControlsEditingToolbarView != nil && _virtualControlsEditingToolbarView.superview == self.view) {
        [self.view bringSubviewToFront:_virtualControlsEditingToolbarView];
    }

    [self layoutStreamingSubviewsForCurrentBounds];
}

- (void)applyVideoAlignmentSelectionToCurrentSession:(NSInteger)selection {
    _currentSessionVideoAlignmentSelection = selection;
    [_streamView setVideoAlignmentMode:(StreamViewVideoAlignmentMode)selection];
    [self layoutStreamingSubviewsForCurrentBounds];
}

- (void)applyVideoAlignmentMarginToCurrentSession:(CGFloat)margin {
    _currentSessionVideoAlignmentMargin = MAX(0.0f, MIN(margin, 150.0f));
    [_streamView setVideoAlignmentMargin:_currentSessionVideoAlignmentMargin];
    [self layoutStreamingSubviewsForCurrentBounds];
}

- (void)applyExtendedPerformanceMetricsEnabled:(BOOL)enabled {
    _extendedPerformanceMetricsEnabled = enabled;

    if (_overlayView != nil && !_overlayView.hidden) {
        [self updateStatsOverlay];
    }
}

- (BOOL)isPerformanceOverlayVisible {
    return _statsUpdateTimer != nil && (_overlayView == nil || !_overlayView.hidden);
}

- (void)applyPerformanceOverlayEnabledToCurrentSession:(BOOL)enabled {
    if (enabled) {
        if (_overlayView != nil) {
            [_overlayView setHidden:NO];
        }

        if (_statsUpdateTimer == nil) {
            [self startHUD];
        }

        [self updateStatsOverlay];
        return;
    }

    if (_statsUpdateTimer != nil) {
        [_statsUpdateTimer invalidate];
        _statsUpdateTimer = nil;
    }

    if (_overlayView != nil) {
        [_overlayView setHidden:YES];
    }
}

- (void)applyMicrophoneEnabledToCurrentSession:(BOOL)enabled {
    if (enabled) {
        _microphoneStartRequested = YES;
        if (_micUplinkManager == nil) {
            _micUplinkManager = [[MicUplinkManager alloc] initWithStreamConfig:self.streamConfig];
        }

        [self showTemporaryTipText:StreamMenuLocalized(@"stream.menu.microphone.starting")];
        [_micUplinkManager startWithCompletion:^(BOOL started, NSString *message) {
            if (!self->_microphoneStartRequested) {
                [self->_micUplinkManager stop];
                self->_micUplinkManager = nil;
                self->_microphoneEnabled = NO;
                return;
            }

            self->_microphoneEnabled = started;
            [self showTemporaryTipText:(started ? StreamMenuLocalized(@"stream.menu.microphone.enabled") :
                                        (message.length > 0 ? message : StreamMenuLocalized(@"stream.menu.microphone.unavailable")))];

            if (self->_overlayView != nil && !self->_overlayView.hidden) {
                [self updateStatsOverlay];
            }
        }];
        return;
    }

    [_micUplinkManager stop];
    _micUplinkManager = nil;
    _microphoneStartRequested = NO;
    _microphoneEnabled = NO;
    [self showTemporaryTipText:StreamMenuLocalized(@"stream.menu.microphone.disabled")];

    if (_overlayView != nil && !_overlayView.hidden) {
        [self updateStatsOverlay];
    }
}

- (void)applyPerformanceOverlayDragEnabledToCurrentSession:(BOOL)enabled {
    _currentSessionPerformanceOverlayDragEnabled = enabled;
    if (_overlayView != nil) {
        [_overlayView setUserInteractionEnabled:enabled];
    }
}

- (void)applyPerformanceOverlayPositionSelectionToCurrentSession:(NSInteger)selection {
    _currentSessionPerformanceOverlayPositionSelection = MAX(0, MIN(selection, 5));
    [self layoutOverlayViewForCurrentBounds];
}

- (void)applyPerformanceOverlayMarginToCurrentSession:(CGFloat)margin {
    _currentSessionPerformanceOverlayMargin = MAX(0.0f, MIN(margin, 150.0f));
    [self layoutOverlayViewForCurrentBounds];
}

- (void)persistCurrentAudioHapticsSettings {
    DataManager *dataManager = [[DataManager alloc] init];
    [dataManager saveAudioHapticsEnabled:_settings.audioHapticsEnabled
                            outputTarget:_settings.audioHapticsOutputTarget
                                strength:_settings.audioHapticsStrength
                    voiceFilterSelection:_settings.audioHapticsVoiceFilterSelection
                    keepControllerRumble:_settings.audioHapticsKeepControllerRumble];
}

- (void)applyCurrentAudioHapticsSettingsToSession {
    [_controllerSupport updateAudioHapticsEnabled:_settings.audioHapticsEnabled
                                     outputTarget:_settings.audioHapticsOutputTarget
                                         strength:_settings.audioHapticsStrength
                             voiceFilterSelection:_settings.audioHapticsVoiceFilterSelection
                         keepControllerRumble:_settings.audioHapticsKeepControllerRumble];
}

- (NSString *)touchModeTitleForSelection:(NSInteger)selection {
    switch (selection) {
        case 1:
            return StreamMenuLocalized(@"stream.touch_mode.mouse");
        case 2:
            return StreamMenuLocalized(@"stream.touch_mode.multitouch");
        case 3:
            return StreamMenuLocalized(@"stream.touch_mode.disabled");
        default:
            return StreamMenuLocalized(@"stream.touch_mode.trackpad");
    }
}

- (void)showTemporaryTouchModeOverlayForSelection:(NSInteger)selection {
    NSString *title = [self touchModeTitleForSelection:selection];
    [self showTemporaryTipText:[NSString stringWithFormat:StreamMenuLocalized(@"stream.touch_mode.toast"), title]];
}

- (void)showTemporaryTipText:(NSString *)text {
    if (@available(iOS 13.0, *)) {
        if (_streamActionSheetHostingViewController != nil &&
            _streamActionSheetHostingViewController.presentingViewController != nil) {
            [_streamActionSheetHostingViewController showToastWithText:text];
            return;
        }
    }

    _tipLabel.text = text;
    CGSize labelSize = [_tipLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    CGFloat horizontalPadding = 20.0;
    CGFloat verticalPadding = 10.0;
    _tipLabel.frame = CGRectMake(0,
                                 0,
                                 ceil(labelSize.width + horizontalPadding * 2.0),
                                 ceil(labelSize.height + verticalPadding * 2.0));
    _tipLabel.hidden = NO;
    [self layoutStreamingSubviewsForCurrentBounds];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_tipLabel.hidden = YES;
    });
}

- (BOOL)isTemporaryVirtualGamepadVisible {
    return [_streamView isTemporaryVirtualGamepadVisible];
}

- (void)toggleTemporaryVirtualGamepad {
    BOOL shouldShowVirtualGamepad = ![self isTemporaryVirtualGamepadVisible];
    [_streamView setTemporaryVirtualGamepadVisible:shouldShowVirtualGamepad];

#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)setViewOnlyModeEnabled:(BOOL)enabled {
    if (_viewOnlyModeEnabled == enabled) {
        return;
    }

    if (enabled) {
        _viewOnlyModeEnabled = YES;
        _viewOnlyHadScrollViewBeforeEntering = (_scrollView != nil && _scrollView.superview == self.view);
        _viewOnlyRestoreZoomScale = (_scrollView != nil) ? _scrollView.zoomScale : 1.0f;
        _viewOnlyRestoreContentOffset = (_scrollView != nil) ? _scrollView.contentOffset : CGPointZero;
        [_streamView setViewOnlyModeEnabled:YES];
        [self updateStreamingTouchModeLayout];
        if (_scrollView != nil) {
            [_scrollView setZoomScale:MAX(_viewOnlyRestoreZoomScale, 1.0f) animated:NO];
            [_scrollView setContentOffset:_viewOnlyRestoreContentOffset animated:NO];
        }
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.menu.view_only.enabled")];
        return;
    }

    _viewOnlyModeEnabled = NO;
    [_streamView setViewOnlyModeEnabled:NO];
    [self updateStreamingTouchModeLayout];

    if (_scrollView != nil) {
        if (_viewOnlyHadScrollViewBeforeEntering) {
            [_scrollView setZoomScale:MAX(_viewOnlyRestoreZoomScale, 1.0f) animated:NO];
            [_scrollView setContentOffset:_viewOnlyRestoreContentOffset animated:NO];
        } else {
            [_scrollView setZoomScale:1.0f animated:NO];
            [_scrollView setContentOffset:CGPointZero animated:NO];
        }
    }
    [self showTemporaryTipText:StreamMenuLocalized(@"stream.menu.view_only.disabled")];
}

- (void)toggleViewOnlyMode {
    [self setViewOnlyModeEnabled:!_viewOnlyModeEnabled];
}

- (NSArray<NSDictionary *> *)defaultVirtualButtonDefinitions {
    return @[
        @{@"id": @"virtual_button_escape", @"title": @"ESC", @"subtitle": @"ESC", @"primary": @[@0x1B], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0},
        @{@"id": @"virtual_button_tab", @"title": @"Tab", @"subtitle": @"Tab", @"primary": @[@0x09], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0},
        @{@"id": @"virtual_button_enter", @"title": @"Enter", @"subtitle": @"Enter", @"primary": @[@0x0D], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0},
        @{@"id": @"virtual_button_win", @"title": @"Win", @"subtitle": @"Win", @"primary": @[@0x5B], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0},
        @{@"id": @"virtual_button_alt_tab", @"title": @"Alt+Tab", @"subtitle": @"Alt + Tab", @"primary": @[@0x12, @0x09], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0},
        @{@"id": @"virtual_button_ctrl_shift_esc", @"title": StreamMenuLocalized(@"stream.shortcuts.default.task_manager"), @"subtitle": @"Ctrl + Shift + ESC", @"primary": @[@0x11, @0x10, @0x1B], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0}
    ];
}

- (NSArray<NSDictionary *> *)legacyDefaultVirtualGamepadDefinitionsForPortrait:(BOOL)portrait {
    if (portrait) {
        return @[
            @{@"id": @"gamepad_left_stick", @"title": @"LS", @"controlAction": @"gamepad_left_stick", @"shape": @"circle", @"scale": @0.96, @"xRatio": @0.24, @"yRatio": @0.80},
            @{@"id": @"gamepad_dpad", @"title": @"DPad", @"controlAction": @"gamepad_dpad", @"shape": @"circle", @"scale": @0.90, @"xRatio": @0.24, @"yRatio": @0.60},
            @{@"id": @"gamepad_right_stick", @"title": @"RS", @"controlAction": @"gamepad_right_stick", @"shape": @"circle", @"scale": @0.96, @"xRatio": @0.76, @"yRatio": @0.80},
            @{@"id": @"gamepad_l3", @"title": @"L3", @"role": @"l3", @"shape": @"circle", @"scale": @0.74, @"xRatio": @0.44, @"yRatio": @0.36},
            @{@"id": @"gamepad_r3", @"title": @"R3", @"role": @"r3", @"shape": @"circle", @"scale": @0.74, @"xRatio": @0.56, @"yRatio": @0.36},
            @{@"id": @"gamepad_face_buttons", @"title": @"ABXY", @"controlAction": @"gamepad_face_buttons", @"shape": @"circle", @"scale": @0.90, @"xRatio": @0.78, @"yRatio": @0.54},
            @{@"id": @"gamepad_l1", @"title": @"L1", @"role": @"l1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.22, @"yRatio": @0.18},
            @{@"id": @"gamepad_r1", @"title": @"R1", @"role": @"r1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.78, @"yRatio": @0.18},
            @{@"id": @"gamepad_l2", @"title": @"L2", @"role": @"l2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.22, @"yRatio": @0.10},
            @{@"id": @"gamepad_r2", @"title": @"R2", @"role": @"r2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.78, @"yRatio": @0.10},
            @{@"id": @"gamepad_select", @"title": @"Select", @"role": @"select", @"shape": @"roundedRect", @"widthScale": @0.84, @"heightScale": @0.88, @"xRatio": @0.44, @"yRatio": @0.26},
            @{@"id": @"gamepad_start", @"title": @"Start", @"role": @"start", @"shape": @"roundedRect", @"widthScale": @0.84, @"heightScale": @0.88, @"xRatio": @0.56, @"yRatio": @0.26}
        ];
    }

    return @[
        @{@"id": @"gamepad_left_stick", @"title": @"LS", @"controlAction": @"gamepad_left_stick", @"shape": @"circle", @"scale": @0.96, @"xRatio": @0.20, @"yRatio": @0.76},
        @{@"id": @"gamepad_dpad", @"title": @"DPad", @"controlAction": @"gamepad_dpad", @"shape": @"circle", @"scale": @0.88, @"xRatio": @0.18, @"yRatio": @0.48},
        @{@"id": @"gamepad_right_stick", @"title": @"RS", @"controlAction": @"gamepad_right_stick", @"shape": @"circle", @"scale": @0.96, @"xRatio": @0.80, @"yRatio": @0.76},
        @{@"id": @"gamepad_l3", @"title": @"L3", @"role": @"l3", @"shape": @"circle", @"scale": @0.72, @"xRatio": @0.47, @"yRatio": @0.28},
        @{@"id": @"gamepad_r3", @"title": @"R3", @"role": @"r3", @"shape": @"circle", @"scale": @0.72, @"xRatio": @0.53, @"yRatio": @0.28},
        @{@"id": @"gamepad_face_buttons", @"title": @"ABXY", @"controlAction": @"gamepad_face_buttons", @"shape": @"circle", @"scale": @0.88, @"xRatio": @0.82, @"yRatio": @0.40},
        @{@"id": @"gamepad_l1", @"title": @"L1", @"role": @"l1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.20, @"yRatio": @0.15},
        @{@"id": @"gamepad_r1", @"title": @"R1", @"role": @"r1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.80, @"yRatio": @0.15},
        @{@"id": @"gamepad_l2", @"title": @"L2", @"role": @"l2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.20, @"yRatio": @0.06},
        @{@"id": @"gamepad_r2", @"title": @"R2", @"role": @"r2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": @0.80, @"yRatio": @0.06},
        @{@"id": @"gamepad_select", @"title": @"Select", @"role": @"select", @"shape": @"roundedRect", @"widthScale": @0.82, @"heightScale": @0.88, @"xRatio": @0.47, @"yRatio": @0.18},
        @{@"id": @"gamepad_start", @"title": @"Start", @"role": @"start", @"shape": @"roundedRect", @"widthScale": @0.82, @"heightScale": @0.88, @"xRatio": @0.53, @"yRatio": @0.18}
    ];
}

- (BOOL)virtualGamepadDefinitions:(NSArray<NSDictionary *> *)definitions matchesTemplate:(NSArray<NSDictionary *> *)templateDefinitions {
    if (definitions.count != templateDefinitions.count) {
        return NO;
    }

    NSArray<NSString *> *stringKeys = @[@"id", @"title", @"role", @"controlAction", @"shape"];
    NSArray<NSString *> *numericKeys = @[@"scale", @"widthScale", @"heightScale", @"xRatio", @"yRatio"];

    for (NSUInteger index = 0; index < definitions.count; index++) {
        NSDictionary *definition = definitions[index];
        NSDictionary *templateDefinition = templateDefinitions[index];

        for (NSString *key in stringKeys) {
            id value = definition[key];
            id templateValue = templateDefinition[key];
            if (value == nil && templateValue == nil) {
                continue;
            }
            if (![value isEqual:templateValue]) {
                return NO;
            }
        }

        for (NSString *key in numericKeys) {
            NSNumber *value = definition[key];
            NSNumber *templateValue = templateDefinition[key];
            if (value == nil && templateValue == nil) {
                continue;
            }
            if (value == nil || templateValue == nil) {
                return NO;
            }
            if (fabs(value.doubleValue - templateValue.doubleValue) > 0.0001) {
                return NO;
            }
        }
    }

    return YES;
}

- (NSDictionary *)virtualGamepadStyleDefaultsForRole:(NSString *)role portrait:(BOOL)portrait {
    CGFloat defaultScale = portrait ? 0.66f : 0.64f;

    if ([role isEqualToString:@"select"]) {
        return @{
            @"title": @"Select",
            @"systemImage": @"square.on.circle",
            @"shape": @"circle",
            @"scale": @(defaultScale)
        };
    }
    if ([role isEqualToString:@"start"]) {
        return @{
            @"title": @"Start",
            @"systemImage": @"line.3.horizontal.circle",
            @"shape": @"circle",
            @"scale": @(defaultScale)
        };
    }
    if ([role isEqualToString:@"special"] || [role isEqualToString:@"guide"] || [role isEqualToString:@"xbox"]) {
        return @{
            @"title": @"Xbox",
            @"systemImage": @"xbox.logo",
            @"shape": @"circle",
            @"scale": @(defaultScale)
        };
    }

    return nil;
}

- (NSArray<NSDictionary *> *)normalizedVirtualGamepadDefinitions:(NSArray<NSDictionary *> *)definitions
                                                        portrait:(BOOL)portrait
                                                       didMutate:(BOOL *)didMutate {
    NSMutableArray<NSMutableDictionary *> *normalizedDefinitions = [NSMutableArray arrayWithCapacity:definitions.count + 1];
    NSMutableDictionary *selectDefinition = nil;
    NSMutableDictionary *startDefinition = nil;
    BOOL hasSpecialDefinition = NO;
    BOOL mutated = NO;

    for (NSDictionary *definition in definitions) {
        if (![definition isKindOfClass:[NSDictionary class]]) {
            mutated = YES;
            continue;
        }

        NSMutableDictionary *updatedDefinition = [definition mutableCopy];
        NSString *role = updatedDefinition[@"role"];
        NSDictionary *styleDefaults = [self virtualGamepadStyleDefaultsForRole:role portrait:portrait];
        if (styleDefaults != nil) {
            NSString *shape = updatedDefinition[@"shape"];
            NSNumber *scale = updatedDefinition[@"scale"];
            NSString *systemImage = updatedDefinition[@"systemImage"];

            updatedDefinition[@"title"] = styleDefaults[@"title"];
            updatedDefinition[@"shape"] = styleDefaults[@"shape"];
            if (![shape isEqual:styleDefaults[@"shape"]] ||
                ![updatedDefinition[@"title"] isEqual:styleDefaults[@"title"]]) {
                mutated = YES;
            }
            if (scale == nil) {
                updatedDefinition[@"scale"] = styleDefaults[@"scale"];
                mutated = YES;
            }
            if (![systemImage isKindOfClass:[NSString class]] || systemImage.length == 0) {
                updatedDefinition[@"systemImage"] = styleDefaults[@"systemImage"];
                mutated = YES;
            }
            [updatedDefinition removeObjectForKey:@"widthScale"];
            [updatedDefinition removeObjectForKey:@"heightScale"];
        }

        if ([role isEqualToString:@"select"]) {
            selectDefinition = updatedDefinition;
        }
        else if ([role isEqualToString:@"start"]) {
            startDefinition = updatedDefinition;
        }
        else if ([role isEqualToString:@"special"] || [role isEqualToString:@"guide"] || [role isEqualToString:@"xbox"]) {
            hasSpecialDefinition = YES;
            updatedDefinition[@"id"] = @"gamepad_special";
            updatedDefinition[@"role"] = @"special";
            updatedDefinition[@"title"] = @"Xbox";
            updatedDefinition[@"systemImage"] = @"xbox.logo";
            updatedDefinition[@"shape"] = @"circle";
        }

        [normalizedDefinitions addObject:updatedDefinition];
    }

    if (!hasSpecialDefinition) {
        NSArray<NSDictionary *> *defaultDefinitions = [self defaultVirtualGamepadDefinitionsForPortrait:portrait];
        NSDictionary *defaultSpecialDefinition = [defaultDefinitions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id == %@", @"gamepad_special"]].firstObject;
        if (defaultSpecialDefinition != nil) {
            NSMutableDictionary *specialDefinition = [defaultSpecialDefinition mutableCopy];
            CGFloat specialX = [defaultSpecialDefinition[@"xRatio"] doubleValue];
            CGFloat specialY = [defaultSpecialDefinition[@"yRatio"] doubleValue];

            if (selectDefinition != nil || startDefinition != nil) {
                CGFloat selectX = [selectDefinition[@"xRatio"] doubleValue];
                CGFloat startX = [startDefinition[@"xRatio"] doubleValue];
                CGFloat selectY = [selectDefinition[@"yRatio"] doubleValue];
                CGFloat startY = [startDefinition[@"yRatio"] doubleValue];

                if (selectDefinition != nil && startDefinition != nil) {
                    specialX = (selectX + startX) * 0.5f;
                    specialY = (selectY + startY) * 0.5f;
                    CGFloat minimumGap = portrait ? 0.12f : 0.14f;
                    CGFloat currentGap = fabs(startX - selectX);
                    if (currentGap < minimumGap) {
                        CGFloat halfGap = minimumGap * 0.5f;
                        selectDefinition[@"xRatio"] = @(MAX(0.0f, specialX - halfGap));
                        startDefinition[@"xRatio"] = @(MIN(1.0f, specialX + halfGap));
                    }
                }
                else if (selectDefinition != nil) {
                    specialX = MIN(1.0f, selectX + (portrait ? 0.08f : 0.07f));
                    specialY = selectY;
                }
                else if (startDefinition != nil) {
                    specialX = MAX(0.0f, startX - (portrait ? 0.08f : 0.07f));
                    specialY = startY;
                }
            }

            specialDefinition[@"xRatio"] = @(specialX);
            specialDefinition[@"yRatio"] = @(specialY);

            NSUInteger insertIndex = [normalizedDefinitions indexOfObjectPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
                return [definition[@"role"] isEqualToString:@"start"];
            }];
            if (insertIndex == NSNotFound) {
                [normalizedDefinitions addObject:specialDefinition];
            }
            else {
                [normalizedDefinitions insertObject:specialDefinition atIndex:insertIndex];
            }
            mutated = YES;
        }
    }

    if (didMutate != NULL) {
        *didMutate = mutated;
    }

    return normalizedDefinitions;
}

- (NSArray<NSDictionary *> *)defaultVirtualGamepadDefinitionsForPortrait:(BOOL)portrait {
    BOOL isPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if (portrait) {
        return @[
            @{@"id": @"gamepad_left_stick", @"title": @"LS", @"controlAction": @"gamepad_left_stick", @"shape": @"circle", @"scale": isPad ? @0.96 : @0.94, @"xRatio": isPad ? @0.24 : @0.22, @"yRatio": isPad ? @0.84 : @0.86},
            @{@"id": @"gamepad_dpad", @"title": @"DPad", @"controlAction": @"gamepad_dpad", @"shape": @"circle", @"scale": isPad ? @0.90 : @0.86, @"xRatio": isPad ? @0.20 : @0.20, @"yRatio": isPad ? @0.58 : @0.60},
            @{@"id": @"gamepad_right_stick", @"title": @"RS", @"controlAction": @"gamepad_right_stick", @"shape": @"circle", @"scale": isPad ? @0.96 : @0.94, @"xRatio": isPad ? @0.76 : @0.78, @"yRatio": isPad ? @0.84 : @0.86},
            @{@"id": @"gamepad_l3", @"title": @"L3", @"role": @"l3", @"shape": @"circle", @"scale": isPad ? @0.72 : @0.68, @"xRatio": isPad ? @0.34 : @0.34, @"yRatio": isPad ? @0.46 : @0.48},
            @{@"id": @"gamepad_select", @"title": @"Select", @"role": @"select", @"systemImage": @"square.on.circle", @"shape": @"circle", @"scale": isPad ? @0.70 : @0.66, @"xRatio": @0.42, @"yRatio": isPad ? @0.34 : @0.36},
            @{@"id": @"gamepad_special", @"title": @"Xbox", @"role": @"special", @"systemImage": @"xbox.logo", @"shape": @"circle", @"scale": isPad ? @0.70 : @0.66, @"xRatio": @0.50, @"yRatio": isPad ? @0.32 : @0.34},
            @{@"id": @"gamepad_start", @"title": @"Start", @"role": @"start", @"systemImage": @"line.3.horizontal.circle", @"shape": @"circle", @"scale": isPad ? @0.70 : @0.66, @"xRatio": @0.58, @"yRatio": isPad ? @0.34 : @0.36},
            @{@"id": @"gamepad_r3", @"title": @"R3", @"role": @"r3", @"shape": @"circle", @"scale": isPad ? @0.72 : @0.68, @"xRatio": isPad ? @0.66 : @0.66, @"yRatio": isPad ? @0.46 : @0.48},
            @{@"id": @"gamepad_face_buttons", @"title": @"ABXY", @"controlAction": @"gamepad_face_buttons", @"shape": @"circle", @"scale": isPad ? @0.90 : @0.86, @"xRatio": isPad ? @0.80 : @0.80, @"yRatio": isPad ? @0.58 : @0.60},
            @{@"id": @"gamepad_l1", @"title": @"L1", @"role": @"l1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.22 : @0.18, @"yRatio": isPad ? @0.18 : @0.18},
            @{@"id": @"gamepad_r1", @"title": @"R1", @"role": @"r1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.78 : @0.82, @"yRatio": isPad ? @0.18 : @0.18},
            @{@"id": @"gamepad_l2", @"title": @"L2", @"role": @"l2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.22 : @0.18, @"yRatio": isPad ? @0.10 : @0.08},
            @{@"id": @"gamepad_r2", @"title": @"R2", @"role": @"r2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.78 : @0.82, @"yRatio": isPad ? @0.10 : @0.08}
        ];
    }

    return @[
        @{@"id": @"gamepad_left_stick", @"title": @"LS", @"controlAction": @"gamepad_left_stick", @"shape": @"circle", @"scale": isPad ? @0.96 : @0.96, @"xRatio": isPad ? @0.16 : @0.14, @"yRatio": isPad ? @0.86 : @0.88},
        @{@"id": @"gamepad_dpad", @"title": @"DPad", @"controlAction": @"gamepad_dpad", @"shape": @"circle", @"scale": isPad ? @0.88 : @0.86, @"xRatio": isPad ? @0.14 : @0.14, @"yRatio": isPad ? @0.44 : @0.46},
        @{@"id": @"gamepad_right_stick", @"title": @"RS", @"controlAction": @"gamepad_right_stick", @"shape": @"circle", @"scale": isPad ? @0.96 : @0.96, @"xRatio": isPad ? @0.84 : @0.86, @"yRatio": isPad ? @0.86 : @0.88},
        @{@"id": @"gamepad_l3", @"title": @"L3", @"role": @"l3", @"shape": @"circle", @"scale": isPad ? @0.70 : @0.68, @"xRatio": isPad ? @0.32 : @0.30, @"yRatio": isPad ? @0.64 : @0.66},
        @{@"id": @"gamepad_select", @"title": @"Select", @"role": @"select", @"systemImage": @"square.on.circle", @"shape": @"circle", @"scale": isPad ? @0.68 : @0.64, @"xRatio": @0.42, @"yRatio": isPad ? @0.58 : @0.60},
        @{@"id": @"gamepad_special", @"title": @"Xbox", @"role": @"special", @"systemImage": @"xbox.logo", @"shape": @"circle", @"scale": isPad ? @0.68 : @0.64, @"xRatio": @0.50, @"yRatio": isPad ? @0.56 : @0.58},
        @{@"id": @"gamepad_start", @"title": @"Start", @"role": @"start", @"systemImage": @"line.3.horizontal.circle", @"shape": @"circle", @"scale": isPad ? @0.68 : @0.64, @"xRatio": @0.58, @"yRatio": isPad ? @0.58 : @0.60},
        @{@"id": @"gamepad_r3", @"title": @"R3", @"role": @"r3", @"shape": @"circle", @"scale": isPad ? @0.70 : @0.68, @"xRatio": isPad ? @0.68 : @0.70, @"yRatio": isPad ? @0.64 : @0.66},
        @{@"id": @"gamepad_face_buttons", @"title": @"ABXY", @"controlAction": @"gamepad_face_buttons", @"shape": @"circle", @"scale": isPad ? @0.88 : @0.86, @"xRatio": isPad ? @0.86 : @0.86, @"yRatio": isPad ? @0.46 : @0.48},
        @{@"id": @"gamepad_l1", @"title": @"L1", @"role": @"l1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.12 : @0.10, @"yRatio": @0.13},
        @{@"id": @"gamepad_l2", @"title": @"L2", @"role": @"l2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.24 : @0.24, @"yRatio": @0.13},
        @{@"id": @"gamepad_r1", @"title": @"R1", @"role": @"r1", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.76 : @0.76, @"yRatio": @0.13},
        @{@"id": @"gamepad_r2", @"title": @"R2", @"role": @"r2", @"shape": @"roundedRect", @"widthScale": @0.92, @"heightScale": @0.92, @"xRatio": isPad ? @0.88 : @0.90, @"yRatio": @0.13}
    ];
}

- (void)loadDefaultVirtualGamepadDefinitionsForCurrentOrientation {
    _virtualGamepadDefinitions = [[self defaultVirtualGamepadDefinitionsForPortrait:_currentSessionVirtualGamepadLayoutPortrait] mutableCopy];
}

- (NSInteger)currentVirtualButtonSchemeSelection {
    return MAX(0, MIN(_currentSessionVirtualButtonSchemeSelection, 4));
}

- (NSInteger)currentVirtualGamepadSchemeSelection {
    return MAX(0, MIN(_currentSessionVirtualGamepadSchemeSelection, 4));
}

- (void)reloadVirtualControlSchemesFromSavedSettingsIfNeeded {
    DataManager *dataManager = [[DataManager alloc] init];
    TemporarySettings *latestSettings = [dataManager getSettings];

    NSInteger latestVirtualButtonSchemeSelection = MAX(0, MIN(latestSettings.virtualButtonSchemeSelection, 4));
    NSInteger latestVirtualGamepadSchemeSelection = MAX(0, MIN(latestSettings.virtualGamepadSchemeSelection, 4));
    BOOL virtualButtonsReloaded = NO;
    BOOL virtualGamepadReloaded = NO;

    if (_currentSessionVirtualButtonSchemeSelection != latestVirtualButtonSchemeSelection) {
        _currentSessionVirtualButtonSchemeSelection = latestVirtualButtonSchemeSelection;
        _settings.virtualButtonSchemeSelection = latestVirtualButtonSchemeSelection;
        [self loadVirtualButtonDefinitionsFromCurrentScheme];
        [self applyVirtualButtonDefinitionsToStreamView];
        virtualButtonsReloaded = YES;
    }

    if (_currentSessionVirtualGamepadSchemeSelection != latestVirtualGamepadSchemeSelection) {
        _currentSessionVirtualGamepadSchemeSelection = latestVirtualGamepadSchemeSelection;
        _settings.virtualGamepadSchemeSelection = latestVirtualGamepadSchemeSelection;
        [self loadVirtualGamepadDefinitionsFromCurrentScheme];
        [self applyVirtualGamepadDefinitionsToStreamView];
        virtualGamepadReloaded = YES;
    }

    if (virtualButtonsReloaded) {
        [self refreshVirtualButtonsPanelIfNeeded];
    }

    if (virtualButtonsReloaded || virtualGamepadReloaded) {
        [self refreshVirtualButtonEditorForCurrentSelection];
    }
}

- (BOOL)isVirtualButtonLayoutPortraitForSize:(CGSize)size {
    if (size.width <= 0.0f || size.height <= 0.0f) {
        CGSize fallbackSize = UIScreen.mainScreen.bounds.size;
        return fallbackSize.height >= fallbackSize.width;
    }

    return size.height >= size.width;
}

- (void)switchVirtualButtonLayoutToPortrait:(BOOL)portrait preserveCurrentLayoutAsFallback:(BOOL)preserveCurrentLayoutAsFallback {
    NSArray<NSDictionary *> *fallbackDefinitions = preserveCurrentLayoutAsFallback ? [[self virtualButtonDefinitions] copy] : nil;
    CGFloat fallbackOpacity = [self currentVirtualButtonOpacity];
    DataManager *dataManager = [[DataManager alloc] init];
    NSInteger schemeSelection = [self currentVirtualButtonSchemeSelection];
    NSArray<NSDictionary *> *savedDefinitions = [dataManager virtualButtonDefinitionsForSchemeSelection:schemeSelection
                                                                                              portrait:portrait];

    _currentSessionVirtualButtonLayoutPortrait = portrait;
    if (savedDefinitions != nil) {
        _virtualButtonDefinitions = [savedDefinitions mutableCopy];
    }
    else if (fallbackDefinitions.count > 0) {
        _virtualButtonDefinitions = [fallbackDefinitions mutableCopy];
    }
    else {
        _virtualButtonDefinitions = [[self defaultVirtualButtonDefinitions] mutableCopy];
    }

    _currentSessionVirtualButtonOpacity = [dataManager virtualButtonOpacityForSchemeSelection:schemeSelection];
    if (_currentSessionVirtualButtonOpacity <= 0.0f) {
        _currentSessionVirtualButtonOpacity = fallbackOpacity;
    }
}

- (void)persistCurrentVirtualButtonScheme {
    DataManager *dataManager = [[DataManager alloc] init];
    [dataManager saveVirtualButtonDefinitions:[self virtualButtonDefinitions]
                                     opacity:[self currentVirtualButtonOpacity]
                          forSchemeSelection:[self currentVirtualButtonSchemeSelection]
                                    portrait:_currentSessionVirtualButtonLayoutPortrait];
}

- (void)loadVirtualButtonDefinitionsFromCurrentScheme {
    [self switchVirtualButtonLayoutToPortrait:_currentSessionVirtualButtonLayoutPortrait preserveCurrentLayoutAsFallback:NO];
}

- (void)switchVirtualGamepadLayoutToPortrait:(BOOL)portrait preserveCurrentLayoutAsFallback:(BOOL)preserveCurrentLayoutAsFallback {
    NSArray<NSDictionary *> *fallbackDefinitions = preserveCurrentLayoutAsFallback ? [[self virtualGamepadDefinitions] copy] : nil;
    CGFloat fallbackOpacity = [self currentVirtualGamepadOpacity];
    DataManager *dataManager = [[DataManager alloc] init];
    NSInteger schemeSelection = [self currentVirtualGamepadSchemeSelection];
    NSArray<NSDictionary *> *savedDefinitions = [dataManager virtualGamepadDefinitionsForSchemeSelection:schemeSelection
                                                                                               portrait:portrait];
    NSArray<NSDictionary *> *legacyDefaultDefinitions = [self legacyDefaultVirtualGamepadDefinitionsForPortrait:portrait];
    BOOL shouldMigrateSavedDefinitions = (savedDefinitions.count > 0 &&
                                          [self virtualGamepadDefinitions:savedDefinitions matchesTemplate:legacyDefaultDefinitions]);
    NSArray<NSDictionary *> *effectiveSavedDefinitions = shouldMigrateSavedDefinitions ? [self defaultVirtualGamepadDefinitionsForPortrait:portrait] : savedDefinitions;
    BOOL didNormalizeDefinitions = NO;

    _currentSessionVirtualGamepadLayoutPortrait = portrait;
    if (effectiveSavedDefinitions != nil && effectiveSavedDefinitions.count > 0) {
        _virtualGamepadDefinitions = [[self normalizedVirtualGamepadDefinitions:effectiveSavedDefinitions
                                                                       portrait:portrait
                                                                      didMutate:&didNormalizeDefinitions] mutableCopy];
    }
    else if (fallbackDefinitions.count > 0) {
        _virtualGamepadDefinitions = [[self normalizedVirtualGamepadDefinitions:fallbackDefinitions
                                                                       portrait:portrait
                                                                      didMutate:&didNormalizeDefinitions] mutableCopy];
    }
    else {
        _virtualGamepadDefinitions = [[self defaultVirtualGamepadDefinitionsForPortrait:portrait] mutableCopy];
    }

    _currentSessionVirtualGamepadOpacity = [dataManager virtualGamepadOpacityForSchemeSelection:schemeSelection];
    if (_currentSessionVirtualGamepadOpacity <= 0.0f) {
        _currentSessionVirtualGamepadOpacity = fallbackOpacity;
    }

    if (shouldMigrateSavedDefinitions || didNormalizeDefinitions) {
        [dataManager saveVirtualGamepadDefinitions:[self virtualGamepadDefinitions]
                                           opacity:[self currentVirtualGamepadOpacity]
                                forSchemeSelection:schemeSelection
                                          portrait:portrait];
    }
}

- (void)persistCurrentVirtualGamepadScheme {
    DataManager *dataManager = [[DataManager alloc] init];
    [dataManager saveVirtualGamepadDefinitions:[self virtualGamepadDefinitions]
                                       opacity:[self currentVirtualGamepadOpacity]
                            forSchemeSelection:[self currentVirtualGamepadSchemeSelection]
                                      portrait:_currentSessionVirtualGamepadLayoutPortrait];
}

- (void)loadVirtualGamepadDefinitionsFromCurrentScheme {
    [self switchVirtualGamepadLayoutToPortrait:_currentSessionVirtualGamepadLayoutPortrait preserveCurrentLayoutAsFallback:NO];
}

- (NSMutableArray<NSDictionary *> *)virtualGamepadDefinitions {
    if (_virtualGamepadDefinitions == nil) {
        [self loadDefaultVirtualGamepadDefinitionsForCurrentOrientation];
    }

    return _virtualGamepadDefinitions;
}

- (NSMutableArray<NSDictionary *> *)virtualButtonDefinitions {
    if (_virtualButtonDefinitions == nil) {
        [self loadVirtualButtonDefinitionsFromCurrentScheme];
    }

    return _virtualButtonDefinitions;
}

- (NSArray<StreamVirtualButtonPanelItem *> *)virtualButtonPanelItems {
    NSArray<NSDictionary *> *definitions = [self virtualButtonDefinitions];
    NSMutableArray<StreamVirtualButtonPanelItem *> *items = [NSMutableArray arrayWithCapacity:definitions.count];
    for (NSDictionary *definition in definitions) {
        StreamVirtualButtonPanelItem *item = [[StreamVirtualButtonPanelItem alloc] init];
        item.identifier = definition[@"id"] ?: @"";
        item.title = definition[@"title"] ?: @"";
        item.subtitle = definition[@"subtitle"] ?: @"";
        item.shape = definition[@"shape"] ?: @"roundedRect";
        item.scale = definition[@"scale"] ?: @1.0;
        item.widthScale = definition[@"widthScale"] ?: @1.0;
        item.heightScale = definition[@"heightScale"] ?: @1.0;
        [items addObject:item];
    }
    return items;
}

- (CGFloat)currentVirtualButtonOpacity {
    if (_currentSessionVirtualButtonOpacity <= 0.0f) {
        _currentSessionVirtualButtonOpacity = 0.52f;
    }
    return _currentSessionVirtualButtonOpacity;
}

- (CGFloat)currentVirtualGamepadOpacity {
    if (_currentSessionVirtualGamepadOpacity <= 0.0f) {
        _currentSessionVirtualGamepadOpacity = 0.52f;
    }
    return _currentSessionVirtualGamepadOpacity;
}

- (void)applyVirtualButtonDefinitionsToStreamView {
    if (_streamView == nil) {
        return;
    }

    CGFloat opacity = [self currentVirtualButtonOpacity];
    NSMutableArray<NSDictionary *> *descriptors = [NSMutableArray arrayWithCapacity:[self virtualButtonDefinitions].count];
    for (NSDictionary *definition in [self virtualButtonDefinitions]) {
        NSMutableDictionary *updatedDefinition = [definition mutableCopy];
        updatedDefinition[@"opacity"] = @(opacity);
        [descriptors addObject:updatedDefinition];
    }

    [_streamView setTemporaryVirtualButtonDescriptors:descriptors];
}

- (void)applyVirtualGamepadDefinitionsToStreamView {
    if (_streamView == nil) {
        return;
    }

    CGFloat opacity = [self currentVirtualGamepadOpacity];
    NSMutableArray<NSDictionary *> *descriptors = [NSMutableArray arrayWithCapacity:[self virtualGamepadDefinitions].count];
    for (NSDictionary *definition in [self virtualGamepadDefinitions]) {
        NSMutableDictionary *updatedDefinition = [definition mutableCopy];
        updatedDefinition[@"opacity"] = @(opacity);
        [descriptors addObject:updatedDefinition];
    }

    [_streamView setTemporaryVirtualGamepadDescriptors:descriptors];
}

- (NSDictionary *)selectedVirtualButtonDefinition {
    if (_selectedVirtualButtonIdentifier.length == 0) {
        return nil;
    }

    NSUInteger index = [[self virtualButtonDefinitions] indexOfObjectPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:self->_selectedVirtualButtonIdentifier];
    }];
    if (index == NSNotFound) {
        return nil;
    }

    return [[self virtualButtonDefinitions] objectAtIndex:index];
}

- (NSDictionary *)selectedVirtualGamepadDefinition {
    if (_selectedVirtualGamepadIdentifier.length == 0) {
        return nil;
    }

    NSUInteger index = [[self virtualGamepadDefinitions] indexOfObjectPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:self->_selectedVirtualGamepadIdentifier];
    }];
    if (index == NSNotFound) {
        return nil;
    }

    return [[self virtualGamepadDefinitions] objectAtIndex:index];
}

- (BOOL)isVirtualButtonsEditingActive {
    return _streamView != nil && [_streamView isTemporaryVirtualButtonsEditingEnabled];
}

- (BOOL)isVirtualGamepadEditingActive {
    return _streamView != nil && [_streamView isTemporaryVirtualGamepadEditingEnabled];
}

- (BOOL)isAnyVirtualControlsEditingActive {
    return [self isVirtualButtonsEditingActive] || [self isVirtualGamepadEditingActive];
}

- (void)installVirtualControlsEditingToolbarIfNeeded {
    if (_virtualControlsEditingToolbarView != nil) {
        return;
    }

    _virtualControlsEditingToolbarView = [[UIView alloc] initWithFrame:CGRectZero];
    _virtualControlsEditingToolbarView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72f];
    _virtualControlsEditingToolbarView.layer.cornerRadius = 14.0f;
    _virtualControlsEditingToolbarView.layer.masksToBounds = YES;
    _virtualControlsEditingToolbarView.layer.borderWidth = 1.0f;
    _virtualControlsEditingToolbarView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14f].CGColor;
    _virtualControlsEditingToolbarView.hidden = YES;

    _virtualControlsEditingCollapseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        [_virtualControlsEditingCollapseButton setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    }
    [_virtualControlsEditingCollapseButton setTintColor:[UIColor whiteColor]];
    _virtualControlsEditingCollapseButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    _virtualControlsEditingCollapseButton.layer.cornerRadius = 11.0f;
    _virtualControlsEditingCollapseButton.layer.borderWidth = 1.0f;
    _virtualControlsEditingCollapseButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12f].CGColor;
    [_virtualControlsEditingCollapseButton addTarget:self action:@selector(handleVirtualControlsCollapseToolbarTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualControlsEditingToolbarView addSubview:_virtualControlsEditingCollapseButton];

    _virtualControlsEditingExitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualControlsEditingExitButton setTitle:StreamMenuLocalized(@"stream.virtual_controls.exit") forState:UIControlStateNormal];
    _virtualControlsEditingExitButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualControlsEditingExitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualControlsEditingExitButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    _virtualControlsEditingExitButton.layer.cornerRadius = 11.0f;
    _virtualControlsEditingExitButton.layer.borderWidth = 1.0f;
    _virtualControlsEditingExitButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12f].CGColor;
    [_virtualControlsEditingExitButton addTarget:self action:@selector(handleVirtualControlsExitEditingTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualControlsEditingToolbarView addSubview:_virtualControlsEditingExitButton];

    _virtualControlsEditingResetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualControlsEditingResetButton setTitle:StreamMenuLocalized(@"settings.reset.button") forState:UIControlStateNormal];
    _virtualControlsEditingResetButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualControlsEditingResetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualControlsEditingResetButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    _virtualControlsEditingResetButton.layer.cornerRadius = 11.0f;
    _virtualControlsEditingResetButton.layer.borderWidth = 1.0f;
    _virtualControlsEditingResetButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12f].CGColor;
    [_virtualControlsEditingResetButton addTarget:self action:@selector(handleVirtualControlsResetEditingTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualControlsEditingToolbarView addSubview:_virtualControlsEditingResetButton];

    _virtualControlsEditingDoneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualControlsEditingDoneButton setTitle:StreamMenuLocalized(@"stream.virtual_buttons.save") forState:UIControlStateNormal];
    _virtualControlsEditingDoneButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualControlsEditingDoneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualControlsEditingDoneButton.backgroundColor = [[UIColor colorWithRed:0.50f green:0.45f blue:0.94f alpha:1.0f] colorWithAlphaComponent:0.92f];
    _virtualControlsEditingDoneButton.layer.cornerRadius = 11.0f;
    [_virtualControlsEditingDoneButton addTarget:self action:@selector(handleVirtualControlsDoneEditingTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualControlsEditingToolbarView addSubview:_virtualControlsEditingDoneButton];

    [self.view addSubview:_virtualControlsEditingToolbarView];
}

- (void)layoutVirtualControlsEditingToolbarForCurrentBounds {
    if (_virtualControlsEditingToolbarView == nil || _virtualControlsEditingToolbarView.hidden) {
        return;
    }

    CGRect bounds = self.view.bounds;
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = self.view.safeAreaInsets;
    }

    CGFloat buttonHeight = 32.0f;
    CGFloat collapseButtonWidth = 32.0f;
    CGFloat horizontalPadding = 10.0f;
    CGFloat verticalPadding = 10.0f;
    CGFloat spacing = 8.0f;
    CGFloat exitWidth = MAX(72.0f, ceil([_virtualControlsEditingExitButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, buttonHeight)].width) + 28.0f);
    CGFloat resetWidth = MAX(72.0f, ceil([_virtualControlsEditingResetButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, buttonHeight)].width) + 28.0f);
    CGFloat doneWidth = MAX(72.0f, ceil([_virtualControlsEditingDoneButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, buttonHeight)].width) + 28.0f);
    CGFloat toolbarWidth = 0.0f;
    CGFloat toolbarHeight = verticalPadding * 2.0f + buttonHeight;
    if (_virtualControlsEditingToolbarCollapsed) {
        toolbarWidth = horizontalPadding * 2.0f + collapseButtonWidth;
    }
    else {
        toolbarWidth = horizontalPadding * 2.0f + collapseButtonWidth + spacing + exitWidth + spacing + resetWidth + spacing + doneWidth;
    }
    CGFloat x = CGRectGetWidth(bounds) - safeInsets.right - toolbarWidth - 12.0f;
    CGFloat y = safeInsets.top + 12.0f;

    _virtualControlsEditingToolbarView.frame = CGRectMake(MAX(x, 12.0f),
                                                          y,
                                                          toolbarWidth,
                                                          toolbarHeight);
    _virtualControlsEditingCollapseButton.frame = CGRectMake(horizontalPadding,
                                                             verticalPadding,
                                                             collapseButtonWidth,
                                                             buttonHeight);
    if (@available(iOS 13.0, *)) {
        NSString *symbolName = _virtualControlsEditingToolbarCollapsed ? @"chevron.left" : @"chevron.right";
        [_virtualControlsEditingCollapseButton setImage:[UIImage systemImageNamed:symbolName] forState:UIControlStateNormal];
    }

    BOOL expanded = !_virtualControlsEditingToolbarCollapsed;
    _virtualControlsEditingExitButton.hidden = !expanded;
    _virtualControlsEditingResetButton.hidden = !expanded;
    _virtualControlsEditingDoneButton.hidden = !expanded;
    if (!expanded) {
        return;
    }

    CGFloat cursorX = CGRectGetMaxX(_virtualControlsEditingCollapseButton.frame) + spacing;
    _virtualControlsEditingExitButton.frame = CGRectMake(cursorX,
                                                         verticalPadding,
                                                         exitWidth,
                                                         buttonHeight);
    cursorX = CGRectGetMaxX(_virtualControlsEditingExitButton.frame) + spacing;
    _virtualControlsEditingResetButton.frame = CGRectMake(cursorX,
                                                          verticalPadding,
                                                          resetWidth,
                                                          buttonHeight);
    cursorX = CGRectGetMaxX(_virtualControlsEditingResetButton.frame) + spacing;
    _virtualControlsEditingDoneButton.frame = CGRectMake(cursorX,
                                                         verticalPadding,
                                                         doneWidth,
                                                         buttonHeight);
}

- (void)refreshVirtualControlsEditingToolbarIfNeeded {
    [self installVirtualControlsEditingToolbarIfNeeded];

    BOOL shouldShow = [self isAnyVirtualControlsEditingActive];
    _virtualControlsEditingToolbarView.hidden = !shouldShow;
    if (!shouldShow) {
        return;
    }

    [self.view bringSubviewToFront:_virtualControlsEditingToolbarView];
    [self layoutVirtualControlsEditingToolbarForCurrentBounds];
}

- (void)beginVirtualButtonsEditingSessionIfNeeded {
    if (_virtualButtonsEditingSessionActive || _streamView == nil) {
        return;
    }

    _virtualButtonsEditingSessionActive = YES;
    _virtualButtonsEditingPreviousVisibility = [_streamView isTemporaryVirtualButtonsVisible];
    _virtualControlsEditingToolbarCollapsed = NO;
}

- (void)beginVirtualGamepadEditingSessionIfNeeded {
    if (_virtualGamepadEditingSessionActive || _streamView == nil) {
        return;
    }

    _virtualGamepadEditingSessionActive = YES;
    _virtualGamepadEditingPreviousVisibility = [_streamView isTemporaryVirtualGamepadVisible];
    _virtualControlsEditingToolbarCollapsed = NO;
}

- (void)enterVirtualButtonsEditingMode {
    if (_streamView == nil) {
        return;
    }

    [self beginVirtualButtonsEditingSessionIfNeeded];
    [_streamView setTemporaryVirtualButtonsEditingEnabled:YES];
    [_streamView setTemporaryVirtualButtonsVisible:YES];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)enterVirtualGamepadEditingMode {
    if (_streamView == nil) {
        return;
    }

    [self beginVirtualGamepadEditingSessionIfNeeded];
    [_streamView setTemporaryVirtualGamepadEditingEnabled:YES];
    [_streamView setTemporaryVirtualGamepadVisible:YES];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)finishVirtualButtonsEditingModeRestoringPreviousVisibility:(BOOL)restorePreviousVisibility {
    if (_streamView == nil) {
        _virtualButtonsEditingSessionActive = NO;
        return;
    }

    BOOL targetVisible = restorePreviousVisibility ? _virtualButtonsEditingPreviousVisibility : [_streamView isTemporaryVirtualButtonsVisible];
    [_streamView setTemporaryVirtualButtonsEditingEnabled:NO];
    [_streamView setTemporaryVirtualButtonsVisible:targetVisible];
    _selectedVirtualButtonIdentifier = nil;
    _virtualButtonEditorView.hidden = YES;
    _virtualButtonsEditingSessionActive = NO;
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)finishVirtualGamepadEditingModeRestoringPreviousVisibility:(BOOL)restorePreviousVisibility {
    if (_streamView == nil) {
        _virtualGamepadEditingSessionActive = NO;
        return;
    }

    BOOL targetVisible = restorePreviousVisibility ? _virtualGamepadEditingPreviousVisibility : [_streamView isTemporaryVirtualGamepadVisible];
    [_streamView setTemporaryVirtualGamepadEditingEnabled:NO];
    [_streamView setTemporaryVirtualGamepadVisible:targetVisible];
    _selectedVirtualGamepadIdentifier = nil;
    _virtualButtonEditorView.hidden = YES;
    _virtualGamepadEditingSessionActive = NO;
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)handleVirtualControlsDoneEditingTapped:(UIButton *)sender {
    (void)sender;

    [self applyVirtualButtonEditorValuesToSelectedItem];

    BOOL handled = NO;
    if ([self isVirtualButtonsEditingActive]) {
        [self finishVirtualButtonsEditingModeRestoringPreviousVisibility:NO];
        handled = YES;
    }
    if ([self isVirtualGamepadEditingActive]) {
        [self finishVirtualGamepadEditingModeRestoringPreviousVisibility:NO];
        handled = YES;
    }
    if (handled) {
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.virtual_buttons.save")];
    }
}

- (void)handleVirtualControlsExitEditingTapped:(UIButton *)sender {
    (void)sender;

    BOOL handled = NO;
    if ([self isVirtualButtonsEditingActive]) {
        [self finishVirtualButtonsEditingModeRestoringPreviousVisibility:YES];
        handled = YES;
    }
    if ([self isVirtualGamepadEditingActive]) {
        [self finishVirtualGamepadEditingModeRestoringPreviousVisibility:YES];
        handled = YES;
    }
    if (handled) {
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.virtual_controls.exit")];
    }
}

- (void)handleVirtualControlsCollapseToolbarTapped:(UIButton *)sender {
    (void)sender;

    _virtualControlsEditingToolbarCollapsed = !_virtualControlsEditingToolbarCollapsed;
    [self layoutVirtualControlsEditingToolbarForCurrentBounds];
}

- (void)resetCurrentVirtualButtonsLayoutToDefaults {
    _virtualButtonDefinitions = [[self defaultVirtualButtonDefinitions] mutableCopy];
    _selectedVirtualButtonIdentifier = nil;
    _virtualButtonEditorView.hidden = YES;
    [self applyVirtualButtonDefinitionsToStreamView];
    [self persistCurrentVirtualButtonScheme];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
}

- (void)resetCurrentVirtualGamepadLayoutToDefaults {
    _virtualGamepadDefinitions = [[self defaultVirtualGamepadDefinitionsForPortrait:_currentSessionVirtualGamepadLayoutPortrait] mutableCopy];
    _selectedVirtualGamepadIdentifier = nil;
    _virtualButtonEditorView.hidden = YES;
    [self applyVirtualGamepadDefinitionsToStreamView];
    [self persistCurrentVirtualGamepadScheme];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
}

- (void)handleVirtualControlsResetEditingTapped:(UIButton *)sender {
    (void)sender;

    BOOL handled = NO;
    if ([self isVirtualButtonsEditingActive]) {
        [self resetCurrentVirtualButtonsLayoutToDefaults];
        handled = YES;
    }
    if ([self isVirtualGamepadEditingActive]) {
        [self resetCurrentVirtualGamepadLayoutToDefaults];
        handled = YES;
    }
    if (handled) {
        [self showTemporaryTipText:StreamMenuLocalized(@"settings.reset.button")];
    }
}

- (void)installVirtualButtonEditorIfNeeded {
    if (_virtualButtonEditorView != nil) {
        return;
    }

    _virtualButtonEditorView = [[UIView alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
    _virtualButtonEditorView.layer.cornerRadius = 18.0f;
    _virtualButtonEditorView.layer.masksToBounds = YES;
    _virtualButtonEditorView.layer.borderWidth = 1.0f;
    _virtualButtonEditorView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    _virtualButtonEditorView.hidden = YES;

    _virtualButtonEditorTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorTitleLabel.textColor = [UIColor whiteColor];
    _virtualButtonEditorTitleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorTitleLabel];

    _virtualButtonEditorShapeControl = [[UISegmentedControl alloc] initWithItems:@[StreamMenuLocalized(@"stream.virtual_button_editor.shape.rounded_rect"), StreamMenuLocalized(@"stream.virtual_button_editor.shape.circle")]];
    [_virtualButtonEditorShapeControl addTarget:self action:@selector(handleVirtualButtonEditorShapeChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorShapeControl];

    UILabel *scaleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    scaleLabel.tag = 9101;
    scaleLabel.text = StreamMenuLocalized(@"stream.virtual_button_editor.scale");
    scaleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    scaleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [_virtualButtonEditorView addSubview:scaleLabel];

    _virtualButtonEditorScaleValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorScaleValueLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    _virtualButtonEditorScaleValueLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightSemibold];
    _virtualButtonEditorScaleValueLabel.textAlignment = NSTextAlignmentRight;
    [_virtualButtonEditorView addSubview:_virtualButtonEditorScaleValueLabel];

    _virtualButtonEditorScaleSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorScaleSlider.minimumValue = 0.5f;
    _virtualButtonEditorScaleSlider.maximumValue = 2.0f;
    [_virtualButtonEditorScaleSlider addTarget:self action:@selector(handleVirtualButtonEditorScaleChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorScaleSlider];

    UILabel *widthLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    widthLabel.tag = 9102;
    widthLabel.text = StreamMenuLocalized(@"stream.virtual_button_editor.width");
    widthLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    widthLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [_virtualButtonEditorView addSubview:widthLabel];

    _virtualButtonEditorWidthValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorWidthValueLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    _virtualButtonEditorWidthValueLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightSemibold];
    _virtualButtonEditorWidthValueLabel.textAlignment = NSTextAlignmentRight;
    [_virtualButtonEditorView addSubview:_virtualButtonEditorWidthValueLabel];

    _virtualButtonEditorWidthSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorWidthSlider.minimumValue = 0.5f;
    _virtualButtonEditorWidthSlider.maximumValue = 2.0f;
    [_virtualButtonEditorWidthSlider addTarget:self action:@selector(handleVirtualButtonEditorWidthChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorWidthSlider];

    UILabel *heightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    heightLabel.tag = 9103;
    heightLabel.text = StreamMenuLocalized(@"stream.virtual_button_editor.height");
    heightLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    heightLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [_virtualButtonEditorView addSubview:heightLabel];

    _virtualButtonEditorHeightValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorHeightValueLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    _virtualButtonEditorHeightValueLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightSemibold];
    _virtualButtonEditorHeightValueLabel.textAlignment = NSTextAlignmentRight;
    [_virtualButtonEditorView addSubview:_virtualButtonEditorHeightValueLabel];

    _virtualButtonEditorHeightSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorHeightSlider.minimumValue = 0.5f;
    _virtualButtonEditorHeightSlider.maximumValue = 2.0f;
    [_virtualButtonEditorHeightSlider addTarget:self action:@selector(handleVirtualButtonEditorHeightChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorHeightSlider];

    UILabel *touchSensitivityXLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    touchSensitivityXLabel.tag = 9104;
    touchSensitivityXLabel.text = StreamMenuLocalized(@"stream.virtual_button_editor.sensitivity_x");
    touchSensitivityXLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    touchSensitivityXLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [_virtualButtonEditorView addSubview:touchSensitivityXLabel];

    _virtualButtonEditorTouchSensitivityXValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorTouchSensitivityXValueLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    _virtualButtonEditorTouchSensitivityXValueLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightSemibold];
    _virtualButtonEditorTouchSensitivityXValueLabel.textAlignment = NSTextAlignmentRight;
    [_virtualButtonEditorView addSubview:_virtualButtonEditorTouchSensitivityXValueLabel];

    _virtualButtonEditorTouchSensitivityXSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorTouchSensitivityXSlider.minimumValue = 0.5f;
    _virtualButtonEditorTouchSensitivityXSlider.maximumValue = 3.0f;
    [_virtualButtonEditorTouchSensitivityXSlider addTarget:self action:@selector(handleVirtualButtonEditorTouchSensitivityXChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorTouchSensitivityXSlider];

    UILabel *touchSensitivityYLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    touchSensitivityYLabel.tag = 9105;
    touchSensitivityYLabel.text = StreamMenuLocalized(@"stream.virtual_button_editor.sensitivity_y");
    touchSensitivityYLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    touchSensitivityYLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [_virtualButtonEditorView addSubview:touchSensitivityYLabel];

    _virtualButtonEditorTouchSensitivityYValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorTouchSensitivityYValueLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    _virtualButtonEditorTouchSensitivityYValueLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightSemibold];
    _virtualButtonEditorTouchSensitivityYValueLabel.textAlignment = NSTextAlignmentRight;
    [_virtualButtonEditorView addSubview:_virtualButtonEditorTouchSensitivityYValueLabel];

    _virtualButtonEditorTouchSensitivityYSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    _virtualButtonEditorTouchSensitivityYSlider.minimumValue = 0.5f;
    _virtualButtonEditorTouchSensitivityYSlider.maximumValue = 3.0f;
    [_virtualButtonEditorTouchSensitivityYSlider addTarget:self action:@selector(handleVirtualButtonEditorTouchSensitivityYChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorTouchSensitivityYSlider];

    _virtualButtonEditorSaveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualButtonEditorSaveButton setTitle:StreamMenuLocalized(@"stream.virtual_buttons.save") forState:UIControlStateNormal];
    _virtualButtonEditorSaveButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorSaveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualButtonEditorSaveButton.backgroundColor = [[UIColor colorWithRed:0.50f green:0.45f blue:0.94f alpha:1.0f] colorWithAlphaComponent:0.92f];
    _virtualButtonEditorSaveButton.layer.cornerRadius = 11.0f;
    [_virtualButtonEditorSaveButton addTarget:self action:@selector(handleVirtualButtonEditorSaveTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorSaveButton];

    _virtualButtonEditorCloseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualButtonEditorCloseButton setTitle:StreamMenuLocalized(@"stream.virtual_button_editor.close") forState:UIControlStateNormal];
    _virtualButtonEditorCloseButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorCloseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualButtonEditorCloseButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    _virtualButtonEditorCloseButton.layer.cornerRadius = 11.0f;
    _virtualButtonEditorCloseButton.layer.borderWidth = 1.0f;
    _virtualButtonEditorCloseButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12f].CGColor;
    [_virtualButtonEditorCloseButton addTarget:self action:@selector(handleVirtualButtonEditorCloseTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorCloseButton];

    _virtualButtonEditorDeleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualButtonEditorDeleteButton setTitle:StreamMenuLocalized(@"stream.virtual_button_editor.delete") forState:UIControlStateNormal];
    _virtualButtonEditorDeleteButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorDeleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualButtonEditorDeleteButton.backgroundColor = [[UIColor colorWithRed:0.86f green:0.34f blue:0.36f alpha:1.0f] colorWithAlphaComponent:0.92f];
    _virtualButtonEditorDeleteButton.layer.cornerRadius = 11.0f;
    [_virtualButtonEditorDeleteButton addTarget:self action:@selector(handleVirtualButtonEditorDeleteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorDeleteButton];

    [self.view addSubview:_virtualButtonEditorView];
}

- (void)layoutVirtualButtonEditorForCurrentBounds {
    if (_virtualButtonEditorView == nil || _virtualButtonEditorView.hidden) {
        return;
    }

    CGRect bounds = self.view.bounds;
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = self.view.safeAreaInsets;
    }

    CGFloat panelWidth = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 286.0f : 248.0f;
    CGFloat x = 12.0f;
    CGFloat y = safeInsets.top + 12.0f;
    CGFloat contentX = 14.0f;
    CGFloat contentWidth = panelWidth - contentX * 2.0f;
    CGFloat rowY = 14.0f;
    BOOL isCircle = _virtualButtonEditorShapeControl.selectedSegmentIndex == 1;
    BOOL hideDeleteButton = _virtualButtonEditorDeleteButton.hidden;
    BOOL hideShapeControl = _virtualButtonEditorShapeControl.hidden;
    NSDictionary *definition = [_streamView isTemporaryVirtualButtonsEditingEnabled] ? [self selectedVirtualButtonDefinition] : [self selectedVirtualGamepadDefinition];
    NSString *mouseAction = definition[@"mouseAction"];
    BOOL showsTouchpadSensitivity = [mouseAction isKindOfClass:[NSString class]] && [mouseAction hasPrefix:@"touchpad_"];

    UILabel *scaleLabel = [_virtualButtonEditorView viewWithTag:9101];
    UILabel *widthLabel = [_virtualButtonEditorView viewWithTag:9102];
    UILabel *heightLabel = [_virtualButtonEditorView viewWithTag:9103];
    UILabel *touchSensitivityXLabel = [_virtualButtonEditorView viewWithTag:9104];
    UILabel *touchSensitivityYLabel = [_virtualButtonEditorView viewWithTag:9105];

    _virtualButtonEditorTitleLabel.frame = CGRectMake(contentX, rowY, contentWidth - (hideDeleteButton ? 132.0f : 194.0f), 20.0f);
    _virtualButtonEditorCloseButton.frame = CGRectMake(panelWidth - (hideDeleteButton ? 130.0f : 192.0f), 10.0f, 54.0f, 32.0f);
    _virtualButtonEditorDeleteButton.frame = hideDeleteButton ? CGRectZero : CGRectMake(panelWidth - 130.0f, 10.0f, 54.0f, 32.0f);
    _virtualButtonEditorSaveButton.frame = CGRectMake(panelWidth - 68.0f, 10.0f, 54.0f, 32.0f);

    rowY = CGRectGetMaxY(_virtualButtonEditorTitleLabel.frame) + 12.0f;
    if (hideShapeControl) {
        _virtualButtonEditorShapeControl.frame = CGRectZero;
    }
    else {
        _virtualButtonEditorShapeControl.frame = CGRectMake(contentX, rowY, contentWidth, 30.0f);
        rowY = CGRectGetMaxY(_virtualButtonEditorShapeControl.frame) + 12.0f;
    }

    scaleLabel.hidden = !isCircle;
    _virtualButtonEditorScaleSlider.hidden = !isCircle;
    _virtualButtonEditorScaleValueLabel.hidden = !isCircle;

    widthLabel.hidden = isCircle;
    _virtualButtonEditorWidthSlider.hidden = isCircle;
    _virtualButtonEditorWidthValueLabel.hidden = isCircle;
    heightLabel.hidden = isCircle;
    _virtualButtonEditorHeightSlider.hidden = isCircle;
    _virtualButtonEditorHeightValueLabel.hidden = isCircle;
    touchSensitivityXLabel.hidden = !showsTouchpadSensitivity;
    _virtualButtonEditorTouchSensitivityXSlider.hidden = !showsTouchpadSensitivity;
    _virtualButtonEditorTouchSensitivityXValueLabel.hidden = !showsTouchpadSensitivity;
    touchSensitivityYLabel.hidden = !showsTouchpadSensitivity;
    _virtualButtonEditorTouchSensitivityYSlider.hidden = !showsTouchpadSensitivity;
    _virtualButtonEditorTouchSensitivityYValueLabel.hidden = !showsTouchpadSensitivity;

    if (isCircle) {
        scaleLabel.frame = CGRectMake(contentX, rowY, 60.0f, 18.0f);
        _virtualButtonEditorScaleValueLabel.frame = CGRectMake(panelWidth - 64.0f, rowY, 50.0f, 18.0f);
        rowY = CGRectGetMaxY(scaleLabel.frame) + 4.0f;
        _virtualButtonEditorScaleSlider.frame = CGRectMake(contentX, rowY, contentWidth, 24.0f);
        rowY = CGRectGetMaxY(_virtualButtonEditorScaleSlider.frame) + 12.0f;
    }
    else {
        widthLabel.frame = CGRectMake(contentX, rowY, 60.0f, 18.0f);
        _virtualButtonEditorWidthValueLabel.frame = CGRectMake(panelWidth - 64.0f, rowY, 50.0f, 18.0f);
        rowY = CGRectGetMaxY(widthLabel.frame) + 4.0f;
        _virtualButtonEditorWidthSlider.frame = CGRectMake(contentX, rowY, contentWidth, 24.0f);
        rowY = CGRectGetMaxY(_virtualButtonEditorWidthSlider.frame) + 10.0f;

        heightLabel.frame = CGRectMake(contentX, rowY, 60.0f, 18.0f);
        _virtualButtonEditorHeightValueLabel.frame = CGRectMake(panelWidth - 64.0f, rowY, 50.0f, 18.0f);
        rowY = CGRectGetMaxY(heightLabel.frame) + 4.0f;
        _virtualButtonEditorHeightSlider.frame = CGRectMake(contentX, rowY, contentWidth, 24.0f);
        rowY = CGRectGetMaxY(_virtualButtonEditorHeightSlider.frame) + 12.0f;

        if (showsTouchpadSensitivity) {
            touchSensitivityXLabel.frame = CGRectMake(contentX, rowY, 88.0f, 18.0f);
            _virtualButtonEditorTouchSensitivityXValueLabel.frame = CGRectMake(panelWidth - 74.0f, rowY, 60.0f, 18.0f);
            rowY = CGRectGetMaxY(touchSensitivityXLabel.frame) + 4.0f;
            _virtualButtonEditorTouchSensitivityXSlider.frame = CGRectMake(contentX, rowY, contentWidth, 24.0f);
            rowY = CGRectGetMaxY(_virtualButtonEditorTouchSensitivityXSlider.frame) + 10.0f;

            touchSensitivityYLabel.frame = CGRectMake(contentX, rowY, 88.0f, 18.0f);
            _virtualButtonEditorTouchSensitivityYValueLabel.frame = CGRectMake(panelWidth - 74.0f, rowY, 60.0f, 18.0f);
            rowY = CGRectGetMaxY(touchSensitivityYLabel.frame) + 4.0f;
            _virtualButtonEditorTouchSensitivityYSlider.frame = CGRectMake(contentX, rowY, contentWidth, 24.0f);
            rowY = CGRectGetMaxY(_virtualButtonEditorTouchSensitivityYSlider.frame) + 12.0f;
        }
    }

    _virtualButtonEditorView.frame = CGRectMake(MIN(MAX(x, 0.0f), MAX(CGRectGetWidth(bounds) - panelWidth - 12.0f, 0.0f)),
                                                y,
                                                panelWidth,
                                                MAX(rowY, MAX(CGRectGetMaxY(_virtualButtonEditorSaveButton.frame), MAX(hideDeleteButton ? 0.0f : CGRectGetMaxY(_virtualButtonEditorDeleteButton.frame), CGRectGetMaxY(_virtualButtonEditorCloseButton.frame))) + 12.0f));
}

- (void)refreshVirtualButtonEditorForCurrentSelection {
    BOOL editingVirtualButtons = [_streamView isTemporaryVirtualButtonsEditingEnabled];
    BOOL editingVirtualGamepad = [_streamView isTemporaryVirtualGamepadEditingEnabled];
    NSDictionary *definition = editingVirtualButtons ? [self selectedVirtualButtonDefinition] : (editingVirtualGamepad ? [self selectedVirtualGamepadDefinition] : nil);
    if ((!editingVirtualButtons && !editingVirtualGamepad) || definition == nil) {
        _virtualButtonEditorView.hidden = YES;
        [self refreshVirtualControlsEditingToolbarIfNeeded];
        [self updateStreamOverlayMouseInputSuppression];
        return;
    }

    [self installVirtualButtonEditorIfNeeded];
    _virtualButtonEditorDeleteButton.hidden = editingVirtualGamepad;
    NSString *controlAction = definition[@"controlAction"];
    NSString *mouseAction = definition[@"mouseAction"];
    BOOL isTouchpadButton = [mouseAction isKindOfClass:[NSString class]] && [mouseAction hasPrefix:@"touchpad_"];
    BOOL shapeLocked = ([controlAction isKindOfClass:[NSString class]] &&
        ([controlAction hasPrefix:@"joystick_"] ||
         [controlAction hasPrefix:@"dpad_"] ||
         [controlAction isEqualToString:@"gamepad_left_stick"] ||
         [controlAction isEqualToString:@"gamepad_right_stick"] ||
         [controlAction isEqualToString:@"gamepad_dpad"] ||
         [controlAction isEqualToString:@"gamepad_face_buttons"])) ||
        isTouchpadButton;
    _virtualButtonEditorShapeControl.hidden = shapeLocked;
    _virtualButtonEditorTitleLabel.text = definition[@"title"] ?: (editingVirtualGamepad ? StreamMenuLocalized(@"stream.menu.virtual_gamepad.title") : StreamMenuLocalized(@"stream.virtual_buttons.panel_title"));
    _virtualButtonEditorShapeControl.selectedSegmentIndex = [definition[@"shape"] isEqualToString:@"circle"] ? 1 : 0;
    _virtualButtonEditorScaleSlider.value = MAX(0.5f, MIN([definition[@"scale"] floatValue], 2.0f));
    _virtualButtonEditorWidthSlider.maximumValue = isTouchpadButton ? 5.0f : 2.0f;
    _virtualButtonEditorHeightSlider.maximumValue = isTouchpadButton ? 5.0f : 2.0f;
    _virtualButtonEditorWidthSlider.value = MAX(0.5f, MIN([definition[@"widthScale"] floatValue], _virtualButtonEditorWidthSlider.maximumValue));
    _virtualButtonEditorHeightSlider.value = MAX(0.5f, MIN([definition[@"heightScale"] floatValue], _virtualButtonEditorHeightSlider.maximumValue));
    _virtualButtonEditorTouchSensitivityXSlider.value = MAX(0.5f, MIN([definition[@"touchSensitivityX"] floatValue] > 0.0f ? [definition[@"touchSensitivityX"] floatValue] : 1.0f, 3.0f));
    _virtualButtonEditorTouchSensitivityYSlider.value = MAX(0.5f, MIN([definition[@"touchSensitivityY"] floatValue] > 0.0f ? [definition[@"touchSensitivityY"] floatValue] : 1.0f, 3.0f));
    _virtualButtonEditorScaleValueLabel.text = [NSString stringWithFormat:@"%.2f", _virtualButtonEditorScaleSlider.value];
    _virtualButtonEditorWidthValueLabel.text = [NSString stringWithFormat:@"%.2f", _virtualButtonEditorWidthSlider.value];
    _virtualButtonEditorHeightValueLabel.text = [NSString stringWithFormat:@"%.2f", _virtualButtonEditorHeightSlider.value];
    _virtualButtonEditorTouchSensitivityXValueLabel.text = [NSString stringWithFormat:@"%.0f%%", _virtualButtonEditorTouchSensitivityXSlider.value * 100.0f];
    _virtualButtonEditorTouchSensitivityYValueLabel.text = [NSString stringWithFormat:@"%.0f%%", _virtualButtonEditorTouchSensitivityYSlider.value * 100.0f];
    _virtualButtonEditorView.hidden = NO;
    [self.view bringSubviewToFront:_virtualButtonEditorView];
    [self refreshVirtualControlsEditingToolbarIfNeeded];
    [self layoutVirtualButtonEditorForCurrentBounds];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)applyVirtualButtonEditorValuesToSelectedItem {
    BOOL editingVirtualButtons = [_streamView isTemporaryVirtualButtonsEditingEnabled];
    BOOL editingVirtualGamepad = [_streamView isTemporaryVirtualGamepadEditingEnabled];
    if (!editingVirtualButtons && !editingVirtualGamepad) {
        return;
    }

    NSString *selectedIdentifier = editingVirtualButtons ? _selectedVirtualButtonIdentifier : _selectedVirtualGamepadIdentifier;
    if (selectedIdentifier.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary *> *definitions = editingVirtualButtons ? [self virtualButtonDefinitions] : [self virtualGamepadDefinitions];
    NSUInteger index = [definitions indexOfObjectPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:selectedIdentifier];
    }];
    if (index == NSNotFound) {
        return;
    }

    NSMutableDictionary *updatedDefinition = [[definitions objectAtIndex:index] mutableCopy];
    NSString *controlAction = updatedDefinition[@"controlAction"];
    NSString *mouseAction = updatedDefinition[@"mouseAction"];
    BOOL shapeLockedToCircle = [controlAction isKindOfClass:[NSString class]] &&
        ([controlAction hasPrefix:@"joystick_"] ||
         [controlAction hasPrefix:@"dpad_"] ||
         [controlAction isEqualToString:@"gamepad_left_stick"] ||
         [controlAction isEqualToString:@"gamepad_right_stick"] ||
         [controlAction isEqualToString:@"gamepad_dpad"] ||
         [controlAction isEqualToString:@"gamepad_face_buttons"]);
    BOOL shapeLockedToRoundedRect = [mouseAction isKindOfClass:[NSString class]] && [mouseAction hasPrefix:@"touchpad_"];
    updatedDefinition[@"shape"] = shapeLockedToCircle ? @"circle" : (shapeLockedToRoundedRect ? @"roundedRect" : (_virtualButtonEditorShapeControl.selectedSegmentIndex == 1 ? @"circle" : @"roundedRect"));
    updatedDefinition[@"scale"] = @(_virtualButtonEditorScaleSlider.value);
    updatedDefinition[@"widthScale"] = @(MAX(0.5f, MIN(_virtualButtonEditorWidthSlider.value, shapeLockedToRoundedRect ? 5.0f : 2.0f)));
    updatedDefinition[@"heightScale"] = @(MAX(0.5f, MIN(_virtualButtonEditorHeightSlider.value, shapeLockedToRoundedRect ? 5.0f : 2.0f)));
    if (shapeLockedToRoundedRect) {
        updatedDefinition[@"touchSensitivityX"] = @(MAX(0.5f, MIN(_virtualButtonEditorTouchSensitivityXSlider.value, 3.0f)));
        updatedDefinition[@"touchSensitivityY"] = @(MAX(0.5f, MIN(_virtualButtonEditorTouchSensitivityYSlider.value, 3.0f)));
    }
    [definitions replaceObjectAtIndex:index withObject:updatedDefinition];
    if (editingVirtualButtons) {
        [self applyVirtualButtonDefinitionsToStreamView];
        [self persistCurrentVirtualButtonScheme];
    }
    else {
        [self applyVirtualGamepadDefinitionsToStreamView];
        [self persistCurrentVirtualGamepadScheme];
    }
}

- (void)handleVirtualButtonSelectionDidChange:(NSNotification *)notification {
    NSString *identifier = notification.userInfo[@"identifier"];
    _selectedVirtualButtonIdentifier = ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) ? [identifier copy] : nil;
    if (_selectedVirtualButtonIdentifier.length > 0) {
        _selectedVirtualGamepadIdentifier = nil;
    }
    [self refreshVirtualButtonEditorForCurrentSelection];
}

- (void)handleVirtualGamepadSelectionDidChange:(NSNotification *)notification {
    NSString *identifier = notification.userInfo[@"identifier"];
    _selectedVirtualGamepadIdentifier = ([identifier isKindOfClass:[NSString class]] && identifier.length > 0) ? [identifier copy] : nil;
    if (_selectedVirtualGamepadIdentifier.length > 0) {
        _selectedVirtualButtonIdentifier = nil;
    }
    [self refreshVirtualButtonEditorForCurrentSelection];
}

- (void)handleVirtualButtonEditorShapeChanged:(UISegmentedControl *)sender {
    (void)sender;
    [self applyVirtualButtonEditorValuesToSelectedItem];
    [self refreshVirtualButtonEditorForCurrentSelection];
}

- (void)handleVirtualButtonEditorScaleChanged:(UISlider *)sender {
    _virtualButtonEditorScaleValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    [self applyVirtualButtonEditorValuesToSelectedItem];
}

- (void)handleVirtualButtonEditorWidthChanged:(UISlider *)sender {
    _virtualButtonEditorWidthValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    [self applyVirtualButtonEditorValuesToSelectedItem];
}

- (void)handleVirtualButtonEditorHeightChanged:(UISlider *)sender {
    _virtualButtonEditorHeightValueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    [self applyVirtualButtonEditorValuesToSelectedItem];
}

- (void)handleVirtualButtonEditorTouchSensitivityXChanged:(UISlider *)sender {
    _virtualButtonEditorTouchSensitivityXValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100.0f];
    [self applyVirtualButtonEditorValuesToSelectedItem];
}

- (void)handleVirtualButtonEditorTouchSensitivityYChanged:(UISlider *)sender {
    _virtualButtonEditorTouchSensitivityYValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100.0f];
    [self applyVirtualButtonEditorValuesToSelectedItem];
}

- (void)handleVirtualButtonEditorSaveTapped:(UIButton *)sender {
    (void)sender;
    BOOL editingVirtualGamepad = [_streamView isTemporaryVirtualGamepadEditingEnabled];
    [self applyVirtualButtonEditorValuesToSelectedItem];
    [self showTemporaryTipText:(editingVirtualGamepad ? StreamMenuLocalized(@"stream.virtual_button_editor.saved_virtual_gamepad") : StreamMenuLocalized(@"stream.virtual_button_editor.saved_virtual_button"))];
}

- (void)handleVirtualButtonEditorCloseTapped:(UIButton *)sender {
    (void)sender;
    _virtualButtonEditorView.hidden = YES;
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)handleVirtualButtonEditorDeleteTapped:(UIButton *)sender {
    (void)sender;
    BOOL editingVirtualButtons = [_streamView isTemporaryVirtualButtonsEditingEnabled];
    BOOL editingVirtualGamepad = [_streamView isTemporaryVirtualGamepadEditingEnabled];
    if (editingVirtualGamepad) {
        return;
    }
    NSString *selectedIdentifier = editingVirtualButtons ? _selectedVirtualButtonIdentifier : _selectedVirtualGamepadIdentifier;
    if (selectedIdentifier.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary *> *definitions = editingVirtualButtons ? [self virtualButtonDefinitions] : [self virtualGamepadDefinitions];
    NSIndexSet *indexes = [definitions indexesOfObjectsPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:selectedIdentifier];
    }];
    if (indexes.count == 0) {
        return;
    }

    [definitions removeObjectsAtIndexes:indexes];
    _selectedVirtualButtonIdentifier = nil;
    _selectedVirtualGamepadIdentifier = nil;
    _virtualButtonEditorView.hidden = YES;
    [self updateStreamOverlayMouseInputSuppression];
    if (editingVirtualButtons) {
        [self applyVirtualButtonDefinitionsToStreamView];
        [self refreshVirtualButtonsPanelIfNeeded];
        [self persistCurrentVirtualButtonScheme];
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.virtual_button_editor.deleted_virtual_button")];
    }
    else {
        [self applyVirtualGamepadDefinitionsToStreamView];
        [self persistCurrentVirtualGamepadScheme];
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.virtual_button_editor.deleted_virtual_gamepad")];
    }
}

- (void)showVirtualButtonsPanel {
    if (@available(iOS 13.0, *)) {
        StreamVirtualButtonsPanelHostingViewController *controller = [[StreamVirtualButtonsPanelHostingViewController alloc] init];
        controller.delegate = (id<StreamVirtualButtonsPanelHostingViewControllerDelegate>)self;
        [controller configureWithTitle:StreamMenuLocalized(@"stream.virtual_buttons.panel_title")
                                 items:[self virtualButtonPanelItems]
                      isEditingEnabled:[_streamView isTemporaryVirtualButtonsEditingEnabled]
                          buttonOpacity:[self currentVirtualButtonOpacity]];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamVirtualButtonsPanelHostingViewController = controller;
        [self updateStreamOverlayMouseInputSuppression];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)refreshVirtualButtonsPanelIfNeeded {
    if (_streamVirtualButtonsPanelHostingViewController == nil) {
        return;
    }

    [_streamVirtualButtonsPanelHostingViewController configureWithTitle:StreamMenuLocalized(@"stream.virtual_buttons.panel_title")
                                                                 items:[self virtualButtonPanelItems]
                                                      isEditingEnabled:[_streamView isTemporaryVirtualButtonsEditingEnabled]
                                                          buttonOpacity:[self currentVirtualButtonOpacity]];
}

- (NSArray<NSDictionary *> *)defaultShortcutDefinitions {
    return @[
        @{@"id": @"shortcut_escape", @"title": StreamMenuLocalized(@"stream.shortcuts.default.back"), @"subtitle": @"ESC", @"symbol": @"escape", @"primary": @[@0x1B], @"secondary": @[]},
        @{@"id": @"shortcut_f11", @"title": StreamMenuLocalized(@"stream.shortcuts.default.browser_fullscreen"), @"subtitle": @"F11", @"symbol": @"macwindow.on.rectangle", @"primary": @[@0x7A], @"secondary": @[]},
        @{@"id": @"shortcut_alt_f4", @"title": StreamMenuLocalized(@"stream.shortcuts.default.close_app"), @"subtitle": @"Alt+F4", @"symbol": @"xmark.circle", @"primary": @[@0xA4, @0x73], @"secondary": @[]},
        @{@"id": @"shortcut_alt_enter", @"title": StreamMenuLocalized(@"stream.shortcuts.default.window_size"), @"subtitle": @"Alt+Enter", @"symbol": @"arrow.up.left.and.arrow.down.right", @"primary": @[@0xA4, @0x0D], @"secondary": @[]},
        @{@"id": @"shortcut_shift_tab", @"title": @"Steam OverLay", @"subtitle": @"Shift+Tab", @"symbol": @"rectangle.on.rectangle", @"primary": @[@0xA0, @0x09], @"secondary": @[]},

        @{@"id": @"shortcut_cursor_toggle", @"title": StreamMenuLocalized(@"stream.shortcuts.default.cursor"), @"subtitle": @"Ctrl+Alt+Shift+N", @"symbol": @"cursorarrow.motionlines", @"primary": @[@0xA2, @0xA4, @0xA0, @0x4E], @"secondary": @[]},
        @{@"id": @"shortcut_shutdown", @"title": StreamMenuLocalized(@"stream.shortcuts.default.shutdown"), @"subtitle": @"Win+X~U-U", @"symbol": @"power", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x55]},
        @{@"id": @"shortcut_restart", @"title": StreamMenuLocalized(@"stream.shortcuts.default.restart"), @"subtitle": @"Win+X~U-R", @"symbol": @"arrow.clockwise", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x52]},
        @{@"id": @"shortcut_sleep", @"title": StreamMenuLocalized(@"stream.shortcuts.default.sleep"), @"subtitle": @"Win+X~U-S", @"symbol": @"moon.zzz", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x53]},
        @{@"id": @"shortcut_logout", @"title": StreamMenuLocalized(@"stream.shortcuts.default.logout"), @"subtitle": @"Win+X~U-I", @"symbol": @"person.crop.circle.badge.xmark", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x49]},

        @{@"id": @"shortcut_copy", @"title": StreamMenuLocalized(@"stream.shortcuts.default.copy"), @"subtitle": @"Ctrl+C", @"symbol": @"doc.on.doc", @"primary": @[@0xA2, @0x43], @"secondary": @[]},
        @{@"id": @"shortcut_paste", @"title": StreamMenuLocalized(@"stream.shortcuts.default.paste"), @"subtitle": @"Ctrl+V", @"symbol": @"doc.on.clipboard", @"primary": @[@0xA2, @0x56], @"secondary": @[]},
        @{@"id": @"shortcut_cut", @"title": StreamMenuLocalized(@"stream.shortcuts.default.cut"), @"subtitle": @"Ctrl+X", @"symbol": @"scissors", @"primary": @[@0xA2, @0x58], @"secondary": @[]},
        @{@"id": @"shortcut_monitor_1", @"title": StreamMenuLocalized(@"stream.shortcuts.default.monitor_1"), @"subtitle": @"Ctrl+Alt+Shift+F1", @"symbol": @"display.2", @"primary": @[@0xA2, @0xA4, @0xA0, @0x70], @"secondary": @[]},
        @{@"id": @"shortcut_monitor_2", @"title": StreamMenuLocalized(@"stream.shortcuts.default.monitor_2"), @"subtitle": @"Ctrl+Alt+Shift+F12", @"symbol": @"display", @"primary": @[@0xA2, @0xA4, @0xA0, @0x7B], @"secondary": @[]},

        @{@"id": @"shortcut_win", @"title": StreamMenuLocalized(@"stream.shortcuts.default.start_menu"), @"subtitle": @"Win", @"symbol": @"command", @"primary": @[@0x5B], @"secondary": @[]},
        @{@"id": @"shortcut_hdr", @"title": StreamMenuLocalized(@"stream.shortcuts.default.hdr"), @"subtitle": @"Win+Alt+B", @"symbol": @"sun.max", @"primary": @[@0x5B, @0xA4, @0x42], @"secondary": @[]},
        @{@"id": @"shortcut_task_manager", @"title": StreamMenuLocalized(@"stream.shortcuts.default.task_manager"), @"subtitle": @"Ctrl+Shift+ESC", @"symbol": @"list.bullet.rectangle", @"primary": @[@0xA2, @0xA0, @0x1B], @"secondary": @[]},
        @{@"id": @"shortcut_desktop", @"title": StreamMenuLocalized(@"stream.shortcuts.default.desktop"), @"subtitle": @"Win+D", @"symbol": @"desktopcomputer", @"primary": @[@0x5B, @0x44], @"secondary": @[]},
        @{@"id": @"shortcut_display_mode", @"title": StreamMenuLocalized(@"stream.shortcuts.default.display_mode"), @"subtitle": @"Win+P", @"symbol": @"rectangle.3.group", @"primary": @[@0x5B, @0x50], @"secondary": @[]},

        @{@"id": @"shortcut_settings", @"title": StreamMenuLocalized(@"stream.shortcuts.default.windows_settings"), @"subtitle": @"Win+I", @"symbol": @"gearshape", @"primary": @[@0x5B, @0x49], @"secondary": @[]},
        @{@"id": @"shortcut_explorer", @"title": StreamMenuLocalized(@"stream.shortcuts.default.explorer"), @"subtitle": @"Win+E", @"symbol": @"folder", @"primary": @[@0x5B, @0x45], @"secondary": @[]},
        @{@"id": @"shortcut_mobility", @"title": StreamMenuLocalized(@"stream.shortcuts.default.mobility_center"), @"subtitle": @"Win+X", @"symbol": @"bolt.horizontal.circle", @"primary": @[@0x5B, @0x58], @"secondary": @[]},
        @{@"id": @"shortcut_desktop_left", @"title": StreamMenuLocalized(@"stream.shortcuts.default.desktop_left"), @"subtitle": @"Win+Shift+Left", @"symbol": @"arrow.left.circle", @"primary": @[@0x5B, @0xA0, @0x25], @"secondary": @[]},
        @{@"id": @"shortcut_desktop_right", @"title": StreamMenuLocalized(@"stream.shortcuts.default.desktop_right"), @"subtitle": @"Win+Shift+Right", @"symbol": @"arrow.right.circle", @"primary": @[@0x5B, @0xA0, @0x27], @"secondary": @[]}
    ];
}

- (void)loadCustomShortcutDefinitions {
    DataManager *dataManager = [[DataManager alloc] init];
    NSArray<NSDictionary *> *definitions = [dataManager customShortcutDefinitions];
    if ([definitions isKindOfClass:[NSArray class]]) {
        _customShortcutDefinitions = [definitions mutableCopy];
    }
    else {
        _customShortcutDefinitions = [[NSMutableArray alloc] init];
    }
}

- (void)persistCustomShortcutDefinitions {
    DataManager *dataManager = [[DataManager alloc] init];
    [dataManager saveCustomShortcutDefinitions:[self customShortcutDefinitions]];
}

- (NSMutableArray<NSDictionary *> *)customShortcutDefinitions {
    if (_customShortcutDefinitions == nil) {
        _customShortcutDefinitions = [[NSMutableArray alloc] init];
    }

    return _customShortcutDefinitions;
}

- (NSArray<NSDictionary *> *)shortcutDefinitions {
    NSMutableArray<NSDictionary *> *definitions = [[self defaultShortcutDefinitions] mutableCopy];
    [definitions addObjectsFromArray:[self customShortcutDefinitions]];
    return [definitions copy];
}

- (NSArray<StreamShortcutPanelItem *> *)shortcutItemsFromDefinitions:(NSArray<NSDictionary *> *)definitions
                                                           deletable:(BOOL)deletable {
    NSMutableArray<StreamShortcutPanelItem *> *items = [NSMutableArray arrayWithCapacity:definitions.count];
    for (NSDictionary *definition in definitions) {
        StreamShortcutPanelItem *item = [[StreamShortcutPanelItem alloc] init];
        item.identifier = definition[@"id"];
        item.title = definition[@"title"];
        item.subtitle = definition[@"subtitle"] ?: @"";
        item.symbolName = definition[@"symbol"];
        item.deletable = deletable;
        [items addObject:item];
    }
    return items;
}

- (NSArray<StreamShortcutPanelItem *> *)defaultShortcutItems {
    return [self shortcutItemsFromDefinitions:[self defaultShortcutDefinitions] deletable:NO];
}

- (NSArray<StreamShortcutPanelItem *> *)customShortcutItems {
    return [self shortcutItemsFromDefinitions:[self customShortcutDefinitions] deletable:YES];
}

- (void)showShortcutPanel {
    if (@available(iOS 13.0, *)) {
        StreamShortcutPanelHostingViewController *controller = [[StreamShortcutPanelHostingViewController alloc] init];
        controller.delegate = (id<StreamShortcutPanelHostingViewControllerDelegate>)self;
        [controller configureWithTitle:StreamMenuLocalized(@"stream.shortcuts.panel_title")
                          builtInItems:[self defaultShortcutItems]
                           customItems:[self customShortcutItems]];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamShortcutPanelHostingViewController = controller;
        [self updateStreamOverlayMouseInputSuppression];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)refreshShortcutPanelIfNeeded {
    if (_streamShortcutPanelHostingViewController == nil) {
        return;
    }

    [_streamShortcutPanelHostingViewController configureWithTitle:StreamMenuLocalized(@"stream.shortcuts.panel_title")
                                                     builtInItems:[self defaultShortcutItems]
                                                      customItems:[self customShortcutItems]];
}

- (void)showVirtualKeyboardPanel {
    if (@available(iOS 13.0, *)) {
        StreamVirtualKeyboardPanelHostingViewController *controller = [[StreamVirtualKeyboardPanelHostingViewController alloc] init];
        controller.delegate = (id<StreamVirtualKeyboardPanelHostingViewControllerDelegate>)self;
        [controller configureWithTitle:StreamMenuLocalized(@"stream.menu.full_keyboard.title")];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamVirtualKeyboardPanelHostingViewController = controller;
        [self updateStreamOverlayMouseInputSuppression];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)quitCurrentAppAndReturnToMainFrame {
    [self->_spinner startAnimating];
    self->_spinner.hidden = NO;
    self->_stageLabel.text = StreamMenuLocalized(@"stream.menu.quit_stream.progress");
    [self->_stageLabel sizeToFit];
    self->_stageLabel.hidden = NO;
    [self layoutStreamingSubviewsForCurrentBounds];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        HttpManager *httpManager = [[HttpManager alloc] initWithAddress:self.streamConfig.host
                                                             httpsPort:self.streamConfig.httpsPort
                                                            serverCert:self.streamConfig.serverCert];
        HttpResponse *quitResponse = [[HttpResponse alloc] init];
        HttpRequest *quitRequest = [HttpRequest requestForResponse:quitResponse
                                                    withUrlRequest:[httpManager newQuitAppRequest]];

        [httpManager executeRequestSynchronously:quitRequest];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];
            self->_spinner.hidden = YES;
            self->_stageLabel.hidden = YES;

            if (quitResponse.statusCode == 200) {
                [self returnToMainFrame];
                return;
            }

            self->_suppressTerminationAlertForManualExit = NO;
            self->_manualExitInProgress = NO;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:StreamMenuLocalized(@"stream.quit_app.failed_title")
                                                                           message:StreamMenuLocalized(@"stream.quit_app.failed_message")
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:StreamMenuLocalized(@"stream.quit_app.dismiss") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}

- (void)handleStreamMenuActionWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"disconnect"]) {
        _suppressTerminationAlertForManualExit = YES;
        [self returnToMainFrame];
        return;
    }

    if ([identifier isEqualToString:@"quit_app"]) {
        _suppressTerminationAlertForManualExit = YES;
        [self quitCurrentAppAndReturnToMainFrame];
        return;
    }

    if ([identifier isEqualToString:@"toggle_stats"]) {
        if (self->_statsUpdateTimer != nil) {
            if (self->_overlayView == nil) {
                return;
            }
            if (self->_overlayView.hidden) {
                [self->_overlayView setHidden:NO];
                [self startHUD];
            }
            else {
                [self->_statsUpdateTimer invalidate];
                self->_statsUpdateTimer = nil;
                [self->_overlayView setHidden:YES];
            }
            return;
        }

        [self startHUD];
        return;
    }

    if ([identifier isEqualToString:@"toggle_microphone"]) {
        [self applyMicrophoneEnabledToCurrentSession:!self->_microphoneEnabled];
        return;
    }

    if ([identifier isEqualToString:@"keyboard"] && self->_streamView != nil) {
        [self->_streamView showKeyInputBoard];
        return;
    }

    if ([identifier isEqualToString:@"virtual_gamepad"] && self->_streamView != nil) {
        [self toggleTemporaryVirtualGamepad];
        return;
    }

    if ([identifier isEqualToString:@"manage_virtual_gamepad"] && self->_streamView != nil) {
        if ([self->_streamView isTemporaryVirtualGamepadEditingEnabled]) {
            [self finishVirtualGamepadEditingModeRestoringPreviousVisibility:NO];
        }
        else {
            [self enterVirtualGamepadEditingMode];
            [self showTemporaryTipText:StreamMenuLocalized(@"stream.menu.manage_virtual_gamepad.tip")];
        }
        [self refreshVirtualButtonEditorForCurrentSelection];
        [self updateStreamOverlayMouseInputSuppression];
        return;
    }

    if ([identifier isEqualToString:@"virtual_buttons"] && self->_streamView != nil) {
        [self->_streamView setTemporaryVirtualButtonsVisible:![self->_streamView isTemporaryVirtualButtonsVisible]];
        return;
    }

    if ([identifier isEqualToString:@"manage_virtual_buttons"]) {
        [self showVirtualButtonsPanel];
        return;
    }

    if ([identifier isEqualToString:@"shortcuts"]) {
        [self showShortcutPanel];
        return;
    }

    if ([identifier isEqualToString:@"full_keyboard"]) {
        [self showVirtualKeyboardPanel];
        return;
    }

    if ([identifier isEqualToString:@"view_only"]) {
        [self toggleViewOnlyMode];
    }
}

- (void) startHUD {
    if (self->_statsUpdateTimer != nil) {
        return;
    }

    self->_statsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                               target:self
                                                             selector:@selector(updateStatsOverlay)
                                                             userInfo:nil
                                                              repeats:YES];
}

- (void) connectionStarted {
    Log(LOG_I, @"Connection started");
    dispatch_async(dispatch_get_main_queue(), ^{
        // Leave the spinner spinning until it's obscured by
        // the first frame of video.
        self->_stageLabel.hidden = YES;
        self->_tipLabel.hidden = YES;
        
        [self->_controllerSupport connectionEstablished];

#if !TARGET_OS_TV
        [self configurePictureInPictureIfNeeded];
#endif
        
        if (self->_settings.statsOverlay) {
            [self startHUD];
        }
    });
}

- (void)connectionTerminated:(int)errorCode {
    Log(LOG_I, @"Connection terminated: %d", errorCode);
    [_micUplinkManager stop];
    _micUplinkManager = nil;
    _microphoneStartRequested = NO;
    _microphoneEnabled = NO;

#if !TARGET_OS_TV
    [self resetPictureInPictureState];
#endif

    if (_manualExitInProgress) {
        return;
    }

    if (_suppressTerminationAlertForManualExit) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self returnToMainFrame];
        });
        return;
    }
    
    unsigned int portFlags = LiGetPortFlagsFromTerminationErrorCode(errorCode);
    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443, portFlags);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_manualExitInProgress) {
            return;
        }

        if (self->_suppressTerminationAlertForManualExit) {
            [self returnToMainFrame];
            return;
        }

        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        NSString* title;
        NSString* message;
        
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            title = StreamMenuLocalized(@"stream.connection.error_title");
            message = StreamMenuLocalized(@"stream.connection.restricted_network");
        }
        else {
            switch (errorCode) {
                case ML_ERROR_GRACEFUL_TERMINATION:
                    [self returnToMainFrame];
                    return;
                    
                case ML_ERROR_NO_VIDEO_TRAFFIC:
                    title = StreamMenuLocalized(@"stream.connection.error_title");
                    message = StreamMenuLocalized(@"stream.connection.no_video_traffic");
                    if (portFlags != 0) {
                        char failingPorts[256];
                        LiStringifyPortFlags(portFlags, "\n", failingPorts, sizeof(failingPorts));
                        message = [message stringByAppendingString:[NSString stringWithFormat:StreamMenuLocalized(@"stream.connection.failed_ports"), failingPorts]];
                    }
                    break;
                    
                case ML_ERROR_NO_VIDEO_FRAME:
                    title = StreamMenuLocalized(@"stream.connection.error_title");
                    message = StreamMenuLocalized(@"stream.connection.no_video_frame");
                    break;
                    
                case ML_ERROR_UNEXPECTED_EARLY_TERMINATION:
                case ML_ERROR_PROTECTED_CONTENT:
                    title = StreamMenuLocalized(@"stream.connection.error_title");
                    message = StreamMenuLocalized(@"stream.connection.host_problem");
                    break;
                    
                case ML_ERROR_FRAME_CONVERSION:
                    title = StreamMenuLocalized(@"stream.connection.error_title");
                    message = StreamMenuLocalized(@"stream.connection.frame_conversion");
                    break;
                    
                default:
                {
                    NSString* errorString;
                    if (abs(errorCode) > 1000) {
                        // We'll assume large errors are hex values
                        errorString = [NSString stringWithFormat:@"%08X", (uint32_t)errorCode];
                    }
                    else {
                        // Smaller values will just be printed as decimal (probably errno.h values)
                        errorString = [NSString stringWithFormat:@"%d", errorCode];
                    }
                    
                    title = StreamMenuLocalized(@"stream.connection.terminated_title");
                    message = [NSString stringWithFormat:StreamMenuLocalized(@"stream.connection.terminated_message"), errorString];
                    break;
                }
            }
        }
        
        [self presentConnectionAlertWithTitle:title message:message];
    });

    [_streamMan stopStream];
}

- (void) stageStarting:(const char*)stageName {
    Log(LOG_I, @"Starting %s", stageName);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* lowerCase = [NSString stringWithFormat:@"%s in progress...", stageName];
        NSString* titleCase = [[[lowerCase substringToIndex:1] uppercaseString] stringByAppendingString:[lowerCase substringFromIndex:1]];
        [self->_stageLabel setText:titleCase];
        [self layoutStreamingSubviewsForCurrentBounds];
    });
}

- (void) stageComplete:(const char*)stageName {
}

- (void) stageFailed:(const char*)stageName withError:(int)errorCode portTestFlags:(int)portTestFlags {
    Log(LOG_I, @"Stage %s failed: %d", stageName, errorCode);
    
    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443, portTestFlags);

    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        NSString* message = [NSString stringWithFormat:StreamMenuLocalized(@"stream.connection.stage_failed"),
                             [NSString stringWithUTF8String:stageName],
                             errorCode];
        if (portTestFlags != 0) {
            char failingPorts[256];
            LiStringifyPortFlags(portTestFlags, "\n", failingPorts, sizeof(failingPorts));
            message = [message stringByAppendingString:[NSString stringWithFormat:StreamMenuLocalized(@"stream.connection.failed_ports"), failingPorts]];
        }
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            message = [message stringByAppendingString:StreamMenuLocalized(@"stream.connection.restricted_network")];
        }
        
        [self presentConnectionAlertWithTitle:StreamMenuLocalized(@"stream.connection.failed_title") message:message];
    });
    
    [_streamMan stopStream];
}

- (void) launchFailed:(NSString*)message {
    Log(LOG_I, @"Launch failed: %@", message);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;

        [self presentConnectionAlertWithTitle:StreamMenuLocalized(@"stream.connection.error_title") message:message];
    });
}

- (void)rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor {
    Log(LOG_I, @"Rumble on gamepad %d: %04x %04x", controllerNumber, lowFreqMotor, highFreqMotor);
    
    [_controllerSupport rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
}

- (void)processAudioHapticsSamples:(const short *)samples
                        frameCount:(int)frameCount
                      channelCount:(int)channelCount
                        sampleRate:(int)sampleRate {
    [_controllerSupport processAudioHapticsSamples:samples
                                        frameCount:frameCount
                                      channelCount:channelCount
                                        sampleRate:sampleRate];
}

- (void)stopAudioHaptics {
    [_controllerSupport stopAudioHaptics];
}

- (void) rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger {
    Log(LOG_I, @"Trigger rumble on gamepad %d: %04x %04x", controllerNumber, leftTrigger, rightTrigger);
    
    [_controllerSupport rumbleTriggers:controllerNumber leftTrigger:leftTrigger rightTrigger:rightTrigger];
}

- (void) setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz {
    Log(LOG_I, @"Set motion state on gamepad %d: %02x %u Hz", controllerNumber, motionType, reportRateHz);
    
    [_controllerSupport setMotionEventState:controllerNumber motionType:motionType reportRateHz:reportRateHz];
}

- (void) setControllerLed:(uint16_t)controllerNumber r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b {
    Log(LOG_I, @"Set controller LED on gamepad %d: l%02x%02x%02x", controllerNumber, r, g, b);
    
    [_controllerSupport setControllerLed:controllerNumber r:r g:g b:b];
}

- (void)connectionStatusUpdate:(int)status {
    Log(LOG_W, @"Connection status update: %d", status);

    // The stats overlay takes precedence over these warnings
    if (_statsUpdateTimer != nil) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (status) {
            case CONN_STATUS_OKAY:
                [self updateOverlayText:nil];
                break;
                
            case CONN_STATUS_POOR:
                if (self->_streamConfig.bitRate > 5000) {
                    [self updateOverlayText:StreamMenuLocalized(@"stream.connection.poor_slow")];
                }
                else {
                    [self updateOverlayText:StreamMenuLocalized(@"stream.connection.poor")];
                }
                break;
        }
    });
}

- (void) updatePreferredDisplayMode:(BOOL)streamActive {
#if TARGET_OS_TV
    if (@available(tvOS 11.2, *)) {
        UIWindow* window = [[[UIApplication sharedApplication] delegate] window];
        AVDisplayManager* displayManager = [window avDisplayManager];
        
        // This logic comes from Kodi and MrMC
        if (streamActive) {
            int dynamicRange;
            
            if (LiGetCurrentHostDisplayHdrMode()) {
                dynamicRange = 2; // HDR10
            }
            else {
                dynamicRange = 0; // SDR
            }
            
            AVDisplayCriteria* displayCriteria = [[AVDisplayCriteria alloc] initWithRefreshRate:[_settings.framerate floatValue]
                                                                              videoDynamicRange:dynamicRange];
            displayManager.preferredDisplayCriteria = displayCriteria;
        }
        else {
            // Switch back to the default display mode
            displayManager.preferredDisplayCriteria = nil;
        }
    }
#endif
}

- (void) setHdrMode:(bool)enabled {
    Log(LOG_I, @"HDR is now: %s", enabled ? "active" : "inactive");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePreferredDisplayMode:YES];
    });
}

- (void) videoContentShown {
    [_spinner stopAnimating];
    [self.view setBackgroundColor:[UIColor blackColor]];
#if !TARGET_OS_TV
    [self configurePictureInPictureIfNeeded];
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [_micUplinkManager stop];
#if !TARGET_OS_TV
    [self stopObservingPictureInPictureController];
#endif
}

- (void)gamepadPresenceChanged {
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)mousePresenceChanged {
#if !TARGET_OS_TV
    if (@available(iOS 14.0, *)) {
        [self setNeedsUpdateOfPrefersPointerLocked];
    }
#endif
}

- (void) streamExitRequested {
    Log(LOG_I, @"Gamepad combo requested stream exit");
    
    [self returnToMainFrame];
}

- (void)userInteractionBegan {
    // Disable hiding home bar when user is interacting.
    // iOS will force it to be shown anyway, but it will
    // also discard our edges deferring system gestures unless
    // we willingly give up home bar hiding preference.
    _userIsInteracting = YES;
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)userInteractionEnded {
    // Enable home bar hiding again if conditions allow
    _userIsInteracting = NO;
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)streamViewDidRequestGameMenu {
    [self showActionSheetWithTitle:StreamMenuLocalized(@"stream.menu.title") options:nil];
}

- (void)gameMenuRequested {
    [self showActionSheetWithTitle:StreamMenuLocalized(@"stream.menu.title") options:nil];
}

#if !TARGET_OS_TV
// Require a confirmation when streaming to activate a system gesture
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeAll;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    if ([_controllerSupport getConnectedGamepadCount] > 0 &&
        _userIsInteracting == NO) {
        // Autohide the home bar when a gamepad is connected
        // while the user is not interacting. We can't do this
        // all the time because any touch on the display will
        // cause the home indicator to reappear, and our
        // preferredScreenEdgesDeferringSystemGestures will also
        // be suppressed (leading to possible errant exits of the
        // stream).
        return YES;
    }
    
    return NO;
}

- (UIInterfaceOrientationMask)preferredStreamOrientationMask {
    switch (_settings.streamOrientationSelection) {
        case StreamOrientationSelectionLandscape:
            return UIInterfaceOrientationMaskLandscape;
        case StreamOrientationSelectionPortrait:
            return UIInterfaceOrientationMaskPortrait;
        case StreamOrientationSelectionAutomatic:
        default:
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                return UIInterfaceOrientationMaskAll;
            }
            return UIInterfaceOrientationMaskAllButUpsideDown;
    }
}

- (void)applyPreferredOrientationIfNeeded {
    UIInterfaceOrientationMask mask = [self preferredStreamOrientationMask];
    if (mask == UIInterfaceOrientationMaskPortrait || mask == UIInterfaceOrientationMaskLandscape) {
        if (@available(iOS 16.0, *)) {
            UIWindowScene *windowScene = self.view.window.windowScene;
            if (windowScene != nil) {
                UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
                [windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
            }
        }
        else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            UIInterfaceOrientation targetOrientation = (mask == UIInterfaceOrientationMaskPortrait) ? UIInterfaceOrientationPortrait : UIInterfaceOrientationLandscapeRight;
            [[UIDevice currentDevice] setValue:@(targetOrientation) forKey:@"orientation"];
            [UIViewController attemptRotationToDeviceOrientation];
#pragma clang diagnostic pop
        }
    }
    else {
        if (@available(iOS 16.0, *)) {
            [self setNeedsUpdateOfSupportedInterfaceOrientations];
        }
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [self preferredStreamOrientationMask];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    switch (_settings.streamOrientationSelection) {
        case StreamOrientationSelectionLandscape:
            return UIInterfaceOrientationLandscapeRight;
        case StreamOrientationSelectionPortrait:
            return UIInterfaceOrientationPortrait;
        case StreamOrientationSelectionAutomatic:
        default:
            return UIInterfaceOrientationUnknown;
    }
}

- (BOOL)prefersPointerLocked {
    // Pointer lock breaks the UIKit mouse APIs, which is a problem because
    // GCMouse is horribly broken on iOS 14.0 for certain mice. Respect the
    // user-facing toggle semantics here so pointer lock matches the stream view.
    if (_settings.remoteMouseMode) {
        return NO;
    }
    return !_settings.captureMouseCursor && [GCMouse mice].count > 0;
}
#endif

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didSelectActionWithIdentifier:(NSString *)identifier {
    _streamActionSheetHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
        [self handleStreamMenuActionWithIdentifier:identifier];
    }];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeTouchModeSelection:(NSInteger)selection {
    [self applyTouchModeSelectionToCurrentSession:selection];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeVideoAlignmentSelection:(NSInteger)selection {
    (void)controller;
    [self applyVideoAlignmentSelectionToCurrentSession:selection];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeVideoAlignmentMargin:(double)margin {
    (void)controller;
    [self applyVideoAlignmentMarginToCurrentSession:(CGFloat)margin];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeStatsOverlayEnabled:(BOOL)enabled {
    (void)controller;
    [self applyPerformanceOverlayEnabledToCurrentSession:enabled];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeExtendedPerformanceMetricsEnabled:(BOOL)enabled {
    (void)controller;
    [self applyExtendedPerformanceMetricsEnabled:enabled];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangePerformanceOverlayDragEnabled:(BOOL)enabled {
    (void)controller;
    [self applyPerformanceOverlayDragEnabledToCurrentSession:enabled];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeAudioHapticsEnabled:(BOOL)enabled {
    (void)controller;
    _settings.audioHapticsEnabled = enabled;
    [self persistCurrentAudioHapticsSettings];
    [self applyCurrentAudioHapticsSettingsToSession];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeAudioHapticsOutputTarget:(NSInteger)selection {
    (void)controller;
    _settings.audioHapticsOutputTarget = selection;
    [self persistCurrentAudioHapticsSettings];
    [self applyCurrentAudioHapticsSettingsToSession];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeAudioHapticsStrength:(double)strength {
    (void)controller;
    _settings.audioHapticsStrength = (NSInteger)strength;
    [self persistCurrentAudioHapticsSettings];
    [self applyCurrentAudioHapticsSettingsToSession];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeAudioHapticsVoiceFilterSelection:(NSInteger)selection {
    (void)controller;
    _settings.audioHapticsVoiceFilterSelection = selection;
    [self persistCurrentAudioHapticsSettings];
    [self applyCurrentAudioHapticsSettingsToSession];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeAudioHapticsKeepControllerRumble:(BOOL)enabled {
    (void)controller;
    _settings.audioHapticsKeepControllerRumble = enabled;
    [self persistCurrentAudioHapticsSettings];
    [self applyCurrentAudioHapticsSettingsToSession];
}

- (void)streamActionSheetHostingViewControllerDidCancel:(StreamActionSheetHostingViewController *)controller {
    _streamActionSheetHostingViewController = nil;

    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
    }];
}

- (void)streamShortcutPanelHostingViewControllerDidCancel:(StreamShortcutPanelHostingViewController *)controller {
    _streamShortcutPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
    }];
}

- (void)streamShortcutPanelHostingViewController:(StreamShortcutPanelHostingViewController *)controller didSelectItemWithIdentifier:(NSString *)identifier {
    (void)controller;
    for (NSDictionary *definition in [self shortcutDefinitions]) {
        if (![definition[@"id"] isEqualToString:identifier]) {
            continue;
        }

        NSArray<NSNumber *> *primary = definition[@"primary"] ?: @[];
        NSArray<NSNumber *> *secondary = definition[@"secondary"] ?: @[];
        [_streamView sendShortcutPrimaryKeyCodes:primary secondaryKeyCodes:secondary];
        break;
    }
}

- (void)streamShortcutPanelHostingViewController:(StreamShortcutPanelHostingViewController *)controller
                          didSubmitItemWithTitle:(NSString *)title
                                       keyLabels:(NSArray<NSString *> *)keyLabels
                                        keyCodes:(NSArray<NSNumber *> *)keyCodes {
    (void)controller;
    if (title.length == 0 || keyCodes.count == 0) {
        return;
    }

    NSString *identifier = [NSString stringWithFormat:@"shortcut_custom_%@", [[NSUUID UUID] UUIDString]];
    NSString *subtitle = [keyLabels componentsJoinedByString:@" + "];
    NSDictionary *definition = @{
        @"id": identifier,
        @"title": title,
        @"subtitle": subtitle.length > 0 ? subtitle : title,
        @"symbol": @"command.square",
        @"primary": keyCodes,
        @"secondary": @[]
    };
    [[self customShortcutDefinitions] addObject:definition];
    [self persistCustomShortcutDefinitions];
    [self refreshShortcutPanelIfNeeded];
    [self showTemporaryTipText:StreamMenuLocalized(@"stream.shortcuts.added")];
}

- (void)streamShortcutPanelHostingViewController:(StreamShortcutPanelHostingViewController *)controller
                     didDeleteItemWithIdentifier:(NSString *)identifier {
    (void)controller;
    NSIndexSet *indexes = [[self customShortcutDefinitions] indexesOfObjectsPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:identifier];
    }];
    if (indexes.count == 0) {
        return;
    }

    [[self customShortcutDefinitions] removeObjectsAtIndexes:indexes];
    [self persistCustomShortcutDefinitions];
    [self refreshShortcutPanelIfNeeded];
    [self showTemporaryTipText:StreamMenuLocalized(@"stream.shortcuts.deleted")];
}

- (void)streamVirtualKeyboardPanelHostingViewControllerDidCancel:(StreamVirtualKeyboardPanelHostingViewController *)controller {
    _streamVirtualKeyboardPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
    }];
}

- (void)streamVirtualKeyboardPanelHostingViewController:(StreamVirtualKeyboardPanelHostingViewController *)controller didSubmitKeyCodes:(NSArray<NSNumber *> *)keyCodes {
    (void)controller;
    if (keyCodes.count == 0) {
        return;
    }

    [_streamView sendShortcutPrimaryKeyCodes:keyCodes secondaryKeyCodes:@[]];
}

- (void)streamVirtualKeyboardPanelHostingViewControllerDidRequestSystemKeyboard:(StreamVirtualKeyboardPanelHostingViewController *)controller {
    _streamVirtualKeyboardPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
        [self->_streamView showKeyInputBoard];
    }];
}

- (void)streamVirtualButtonsPanelHostingViewControllerDidCancel:(StreamVirtualButtonsPanelHostingViewController *)controller {
    _streamVirtualButtonsPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        [self updateStreamOverlayMouseInputSuppression];
    }];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller didChangeEditingEnabled:(BOOL)enabled {
    if (enabled) {
        [self enterVirtualButtonsEditingMode];
        _streamVirtualButtonsPanelHostingViewController = nil;
        [controller dismissViewControllerAnimated:YES completion:^{
            [self updateStreamOverlayMouseInputSuppression];
        }];
        [self showTemporaryTipText:StreamMenuLocalized(@"stream.virtual_buttons.editing_tip")];
    }
    else {
        [self finishVirtualButtonsEditingModeRestoringPreviousVisibility:NO];
    }
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self updateStreamOverlayMouseInputSuppression];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller didDeleteItemWithIdentifier:(NSString *)identifier {
    (void)controller;
    NSIndexSet *indexes = [[self virtualButtonDefinitions] indexesOfObjectsPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:identifier];
    }];
    if (indexes.count == 0) {
        return;
    }

    [[self virtualButtonDefinitions] removeObjectsAtIndexes:indexes];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller didSubmitItemWithTitle:(NSString *)title keyLabels:(NSArray<NSString *> *)keyLabels keyCodes:(NSArray<NSNumber *> *)keyCodes {
    (void)controller;
    if (title.length == 0 || keyCodes.count == 0) {
        return;
    }

    NSString *identifier = [NSString stringWithFormat:@"virtual_button_custom_%@", [[NSUUID UUID] UUIDString]];
    NSString *subtitle = [keyLabels componentsJoinedByString:@" + "];
    NSDictionary *definition = @{
        @"id": identifier,
        @"title": title,
        @"subtitle": subtitle.length > 0 ? subtitle : title,
        @"primary": keyCodes,
        @"secondary": @[],
        @"shape": @"roundedRect",
        @"scale": @1.0,
        @"widthScale": @1.0,
        @"heightScale": @1.0,
        @"xRatio": @0.5,
        @"yRatio": @0.5
    };
    [[self virtualButtonDefinitions] addObject:definition];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller
                         didSubmitMouseItemWithTitle:(NSString *)title
                                mouseActionIdentifier:(NSString *)mouseActionIdentifier
                                             subtitle:(NSString *)subtitle {
    (void)controller;
    if (title.length == 0 || mouseActionIdentifier.length == 0) {
        return;
    }

    NSString *identifier = [NSString stringWithFormat:@"virtual_button_mouse_%@", [[NSUUID UUID] UUIDString]];
    BOOL isTouchpadAction = [mouseActionIdentifier hasPrefix:@"touchpad_"];
    NSDictionary *definition = @{
        @"id": identifier,
        @"title": title,
        @"subtitle": subtitle.length > 0 ? subtitle : title,
        @"mouseAction": mouseActionIdentifier,
        @"shape": isTouchpadAction ? @"roundedRect" : @"circle",
        @"scale": @1.0,
        @"widthScale": isTouchpadAction ? @2.0 : @1.0,
        @"heightScale": isTouchpadAction ? @2.0 : @1.0,
        @"touchSensitivityX": isTouchpadAction ? @1.0 : @1.0,
        @"touchSensitivityY": isTouchpadAction ? @1.0 : @1.0,
        @"xRatio": @0.5,
        @"yRatio": @0.5
    };
    [[self virtualButtonDefinitions] addObject:definition];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller
                    didSubmitDirectionalItemWithTitle:(NSString *)title
                               controlActionIdentifier:(NSString *)controlActionIdentifier
                                              subtitle:(NSString *)subtitle {
    (void)controller;
    if (title.length == 0 || controlActionIdentifier.length == 0) {
        return;
    }

    BOOL isJoystick = [controlActionIdentifier hasPrefix:@"joystick_"];
    NSString *identifier = [NSString stringWithFormat:@"virtual_button_direction_%@", [[NSUUID UUID] UUIDString]];
    NSDictionary *definition = @{
        @"id": identifier,
        @"title": title,
        @"subtitle": subtitle.length > 0 ? subtitle : title,
        @"controlAction": controlActionIdentifier,
        @"shape": isJoystick ? @"circle" : @"roundedRect",
        @"scale": @1.0,
        @"widthScale": @1.0,
        @"heightScale": @1.0,
        @"xRatio": @0.5,
        @"yRatio": @0.5
    };
    [[self virtualButtonDefinitions] addObject:definition];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self refreshVirtualButtonsPanelIfNeeded];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller
                         didUpdateItemWithIdentifier:(NSString *)identifier
                                              shape:(NSString *)shape
                                              scale:(double)scale
                                         widthScale:(double)widthScale
                                        heightScale:(double)heightScale {
    (void)controller;
    if (identifier.length == 0) {
        return;
    }

    NSUInteger index = [[self virtualButtonDefinitions] indexOfObjectPassingTest:^BOOL(NSDictionary *definition, NSUInteger idx, BOOL *stop) {
        return [definition[@"id"] isEqualToString:identifier];
    }];
    if (index == NSNotFound) {
        return;
    }

    NSMutableDictionary *updatedDefinition = [[[self virtualButtonDefinitions] objectAtIndex:index] mutableCopy];
    NSString *mouseAction = updatedDefinition[@"mouseAction"];
    BOOL shapeLocked = [mouseAction isKindOfClass:[NSString class]] && [mouseAction hasPrefix:@"touchpad_"];
    updatedDefinition[@"shape"] = shapeLocked ? @"roundedRect" : ([shape isEqualToString:@"circle"] ? @"circle" : @"roundedRect");
    updatedDefinition[@"scale"] = @(MAX(0.5, MIN(scale, 2.0)));
    updatedDefinition[@"widthScale"] = @(MAX(0.5, MIN(widthScale, shapeLocked ? 5.0 : 2.0)));
    updatedDefinition[@"heightScale"] = @(MAX(0.5, MIN(heightScale, shapeLocked ? 5.0 : 2.0)));
    [[self virtualButtonDefinitions] replaceObjectAtIndex:index withObject:updatedDefinition];
    [self applyVirtualButtonDefinitionsToStreamView];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller
                                 didChangeButtonOpacity:(double)opacity {
    (void)controller;
    _currentSessionVirtualButtonOpacity = MAX(0.05f, MIN((CGFloat)opacity, 1.0f));
    [self applyVirtualButtonDefinitionsToStreamView];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualButtonsDidChange:(NSNotification *)notification {
    NSArray<NSDictionary *> *descriptors = notification.userInfo[@"descriptors"];
    if (![descriptors isKindOfClass:[NSArray class]]) {
        return;
    }

    _virtualButtonDefinitions = [descriptors mutableCopy];
    NSNumber *opacity = [descriptors.firstObject isKindOfClass:[NSDictionary class]] ? descriptors.firstObject[@"opacity"] : nil;
    if ([opacity isKindOfClass:[NSNumber class]]) {
        _currentSessionVirtualButtonOpacity = MAX(0.05f, MIN((CGFloat)opacity.doubleValue, 1.0f));
    }
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self persistCurrentVirtualButtonScheme];
}

- (void)streamVirtualGamepadDidChange:(NSNotification *)notification {
    NSArray<NSDictionary *> *descriptors = notification.userInfo[@"descriptors"];
    if (![descriptors isKindOfClass:[NSArray class]]) {
        return;
    }

    _virtualGamepadDefinitions = [[self normalizedVirtualGamepadDefinitions:descriptors
                                                                   portrait:_currentSessionVirtualGamepadLayoutPortrait
                                                                  didMutate:NULL] mutableCopy];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self persistCurrentVirtualGamepadScheme];
}

#if !TARGET_OS_TV
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    _pictureInPictureStartingForBackground = YES;
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    _pictureInPictureActive = YES;
    _pictureInPictureStartingForBackground = NO;
    if (_inactivityTimer != nil) {
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
 failedToStartPictureInPictureWithError:(NSError *)error API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    Log(LOG_E, @"Picture in Picture failed to start: %@", error);
    _pictureInPictureActive = NO;
    _pictureInPictureStartingForBackground = NO;

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self returnToMainFrame];
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    _pictureInPictureStartingForBackground = NO;
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    _pictureInPictureActive = NO;
    _pictureInPictureStartingForBackground = NO;

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self returnToMainFrame];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    (void)change;
    (void)context;

#if !TARGET_OS_TV
    if (@available(iOS 15.0, *)) {
        if (object == _pictureInPictureController &&
            [keyPath isEqualToString:@"pictureInPicturePossible"]) {
            return;
        }
    }
#endif

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    completionHandler(YES);
}

- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    return CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
}

- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    return NO;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
                        setPlaying:(BOOL)playing API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    (void)playing;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
          didTransitionToRenderSize:(CMVideoDimensions)newRenderSize API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    (void)newRenderSize;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
                    skipByInterval:(CMTime)skipInterval
                 completionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(15.0))
{
    (void)pictureInPictureController;
    (void)skipInterval;
    completionHandler();
}
#endif

@end
