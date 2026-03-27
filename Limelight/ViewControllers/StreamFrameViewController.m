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
#import "ControllerSupport.h"
#import "DataManager.h"
#import "Moonlight-Swift.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <Limelight.h>

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

@interface StreamFrameViewController () <StreamActionSheetHostingViewControllerDelegate, StreamShortcutPanelHostingViewControllerDelegate, StreamVirtualKeyboardPanelHostingViewControllerDelegate, StreamVirtualButtonsPanelHostingViewControllerDelegate, UIGestureRecognizerDelegate>
@end

static const CGFloat kStreamFloatingMenuPhoneButtonSize = 44.0f;
static const CGFloat kStreamFloatingMenuPadButtonSize = 48.0f;
static const CGFloat kStreamFloatingMenuExpandedMargin = 6.0f;
static const CGFloat kStreamFloatingMenuAutoCollapseDelay = 3.0f;
static const CGFloat kStreamFloatingMenuCollapsedAlpha = 0.42f;
static const CGFloat kStreamFloatingMenuExpandedAlpha = 0.96f;

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
    NSInteger _currentSessionTouchModeSelection;
    NSInteger _currentSessionVideoAlignmentSelection;
    CGFloat _currentSessionVideoAlignmentMargin;
    BOOL _extendedPerformanceMetricsEnabled;
    NSInteger _currentSessionPerformanceOverlayPositionSelection;
    CGFloat _currentSessionPerformanceOverlayMargin;
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
    NSString *_selectedVirtualButtonIdentifier;
    NSString *_selectedVirtualGamepadIdentifier;
    CGFloat _currentSessionVirtualButtonOpacity;
    CGFloat _currentSessionVirtualGamepadOpacity;
    NSInteger _currentSessionVirtualButtonSchemeSelection;
    NSInteger _currentSessionVirtualGamepadSchemeSelection;
    BOOL _currentSessionVirtualButtonLayoutPortrait;
    BOOL _currentSessionVirtualGamepadLayoutPortrait;
    
#if !TARGET_OS_TV
    UIScreenEdgePanGestureRecognizer *_exitSwipeRecognizer;
#endif
    //外接显示器-----------start
    UIWindow *_extWindow;
    UIView *_renderView;
    UIWindow *_deviceWindow;
    //外接显示器-----------end
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
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
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

    originX = MIN(MAX(originX, minX), maxX);
    originY = MIN(MAX(originY, minY), maxY);

    CGRect frame = CGRectMake(originX,
                              originY,
                              overlayWidth,
                              overlayHeight);
    _overlayView.frame = frame;
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

    [self showActionSheetWithTitle:@"游戏菜单" options:nil];
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
    if (_floatingMenuCenterY <= 0.0f) {
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
    
    self.previousBytes = 0;  // 初始化上次字节数为 0
    
    _settings = [[[DataManager alloc] init] getSettings];
    _currentSessionVirtualButtonSchemeSelection = _settings.virtualButtonSchemeSelection;
    _currentSessionVirtualGamepadSchemeSelection = _settings.virtualGamepadSchemeSelection;
    _currentSessionVirtualButtonLayoutPortrait = [self isVirtualButtonLayoutPortraitForSize:self.view.bounds.size];
    _currentSessionVirtualGamepadLayoutPortrait = _currentSessionVirtualButtonLayoutPortrait;
    [self loadVirtualButtonDefinitionsFromCurrentScheme];
    [self loadVirtualGamepadDefinitionsFromCurrentScheme];
    [self loadCustomShortcutDefinitions];
    _currentSessionTouchModeSelection = !_settings.absoluteTouchMode ? 0 : (_settings.multiTouchScreen ? 2 : 1);
    _currentSessionVideoAlignmentSelection = MAX(0, MIN(_settings.videoAlignmentSelection, 2));
    _currentSessionVideoAlignmentMargin = MAX(0.0f, MIN(_settings.videoAlignmentMargin, 150.0f));
    _currentSessionPerformanceOverlayPositionSelection = MAX(0, MIN(_settings.performanceOverlayPositionSelection, 5));
    _currentSessionPerformanceOverlayMargin = MAX(0.0f, MIN(_settings.performanceOverlayMargin, 150.0f));
    
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
        _renderView = (StreamView*)[[UIView alloc] initWithFrame:self.view.frame];
        _renderView.bounds = _streamView.bounds;
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
    [_tipLabel setText:@"提示：从左侧边缘向内滑动即可打开游戏菜单。"];
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
        [_streamMan stopStream];
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
    NSString* overlayText = [NSString stringWithFormat:@"%@ %@",
                             [self getInternetface],
                             [self->_streamMan getStatsOverlayTextWithExtendedMetrics:_extendedPerformanceMetricsEnabled]];
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
        [_overlayView setUserInteractionEnabled:NO];
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
    // Reset display mode back to default
    [self updatePreferredDisplayMode:NO];
    
    [_statsUpdateTimer invalidate];
    _statsUpdateTimer = nil;
    [self invalidateFloatingMenuDormancyTimer];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    _extWindow = nil;
    
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
    // Stop the background timer, since we're foregrounded again
    if (_inactivityTimer != nil) {
        Log(LOG_I, @"Stopping inactivity timer after becoming active again");
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
}

// This fires when the home button is pressed
- (void)applicationDidEnterBackground:(UIApplication *)application {
    Log(LOG_I, @"Terminating stream immediately for backgrounding");
    
    if (_inactivityTimer != nil) {
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
    
    [self returnToMainFrame];
}

- (void)edgeSwiped {
    Log(LOG_I, @"User swiped to end stream");
    [self showActionSheetWithTitle:@"游戏菜单" options:nil];
}


- (void)showActionSheetWithTitle:(NSString *)title options:(NSArray<NSString *> *)options {
    if (@available(iOS 13.0, *)) {
        NSMutableArray<StreamActionSheetItem *> *items = [NSMutableArray array];

        StreamActionSheetItem *disconnectItem = [[StreamActionSheetItem alloc] init];
        disconnectItem.identifier = @"disconnect";
        disconnectItem.title = @"断开串流";
        disconnectItem.subtitle = @"结束当前串流并返回应用列表";
        disconnectItem.symbolName = @"xmark.circle";
        disconnectItem.destructive = YES;
        [items addObject:disconnectItem];

        StreamActionSheetItem *quitStreamItem = [[StreamActionSheetItem alloc] init];
        quitStreamItem.identifier = @"quit_app";
        quitStreamItem.title = @"退出串流";
        quitStreamItem.subtitle = @"退出当前应用并返回应用列表";
        quitStreamItem.symbolName = @"rectangle.portrait.and.arrow.right";
        quitStreamItem.destructive = YES;
        [items addObject:quitStreamItem];

        StreamActionSheetItem *statsItem = [[StreamActionSheetItem alloc] init];
        statsItem.identifier = @"toggle_stats";
        statsItem.title = @"性能信息";
        statsItem.subtitle = @"切换当前帧率和网络状态浮层";
        statsItem.symbolName = @"chart.bar.xaxis";
        [items addObject:statsItem];

        StreamActionSheetItem *keyboardItem = [[StreamActionSheetItem alloc] init];
        keyboardItem.identifier = @"keyboard";
        keyboardItem.title = @"手机键盘";
        keyboardItem.subtitle = @"打开顶部功能键和系统输入法";
        keyboardItem.symbolName = @"keyboard";
        [items addObject:keyboardItem];

        StreamActionSheetItem *virtualGamepadItem = [[StreamActionSheetItem alloc] init];
        virtualGamepadItem.identifier = @"virtual_gamepad";
        virtualGamepadItem.title = @"虚拟手柄";
        virtualGamepadItem.subtitle = @"临时显示或隐藏屏幕虚拟手柄";
        virtualGamepadItem.symbolName = @"gamecontroller";
        [items addObject:virtualGamepadItem];

        StreamActionSheetItem *manageVirtualGamepadItem = [[StreamActionSheetItem alloc] init];
        manageVirtualGamepadItem.identifier = @"manage_virtual_gamepad";
        manageVirtualGamepadItem.title = @"编辑虚拟手柄";
        manageVirtualGamepadItem.subtitle = @"调整位置和大小";
        manageVirtualGamepadItem.symbolName = @"gamecontroller.fill";

        StreamActionSheetItem *virtualButtonsItem = [[StreamActionSheetItem alloc] init];
        virtualButtonsItem.identifier = @"virtual_buttons";
        virtualButtonsItem.title = @"虚拟按键";
        virtualButtonsItem.subtitle = @"显示或隐藏测试虚拟按键";
        virtualButtonsItem.symbolName = @"square.grid.2x2";
        [items addObject:virtualButtonsItem];

        StreamActionSheetItem *manageVirtualButtonsItem = [[StreamActionSheetItem alloc] init];
        manageVirtualButtonsItem.identifier = @"manage_virtual_buttons";
        manageVirtualButtonsItem.title = @"编辑虚拟按键";
        manageVirtualButtonsItem.subtitle = @"添加或删除当前串流会话的虚拟按键";
        manageVirtualButtonsItem.symbolName = @"square.and.pencil";

        StreamActionSheetItem *shortcutItem = [[StreamActionSheetItem alloc] init];
        shortcutItem.identifier = @"shortcuts";
        shortcutItem.title = @"快捷键";
        shortcutItem.subtitle = @"打开快捷键面板";
        shortcutItem.symbolName = @"command.square";
        [items addObject:shortcutItem];

        StreamActionSheetItem *fullKeyboardItem = [[StreamActionSheetItem alloc] init];
        fullKeyboardItem.identifier = @"full_keyboard";
        fullKeyboardItem.title = @"全键盘";
        fullKeyboardItem.subtitle = @"打开自定义完整键盘布局";
        fullKeyboardItem.symbolName = @"keyboard";
        [items addObject:fullKeyboardItem];

        StreamActionSheetItem *viewOnlyItem = [[StreamActionSheetItem alloc] init];
        viewOnlyItem.identifier = @"view_only";
        viewOnlyItem.title = @"仅查看";
        viewOnlyItem.subtitle = @"禁用控制，仅允许缩放和平移画面";
        viewOnlyItem.symbolName = @"eye";
        [items addObject:viewOnlyItem];
        [items addObject:manageVirtualGamepadItem];
        [items addObject:manageVirtualButtonsItem];

        StreamActionSheetHostingViewController *controller = [[StreamActionSheetHostingViewController alloc] init];
        controller.delegate = (id<StreamActionSheetHostingViewControllerDelegate>)self;
        controller.touchModeSelection = @([self currentTouchModeSelection]);
        controller.videoAlignmentSelection = @([self currentVideoAlignmentSelection]);
        controller.videoAlignmentMargin = @(_currentSessionVideoAlignmentMargin);
        controller.extendedPerformanceMetricsEnabled = _extendedPerformanceMetricsEnabled;
        controller.performanceOverlayPositionSelection = @(_currentSessionPerformanceOverlayPositionSelection);
        controller.performanceOverlayMargin = @(_currentSessionPerformanceOverlayMargin);
        [controller configureWithTitle:title subtitle:@"游戏内快捷操作" items:items];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;

        _streamActionSheetHostingViewController = controller;
        [self presentViewController:controller animated:YES completion:nil];
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"断开连接"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self returnToMainFrame];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"切换性能信息"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self handleStreamMenuActionWithIdentifier:@"toggle_stats"];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"弹出软键盘"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction * _Nonnull action) {
        [self handleStreamMenuActionWithIdentifier:@"keyboard"];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
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
    BOOL absoluteTouchMode = NO;
    BOOL multiTouchScreen = NO;
    BOOL directScreenTouchInputDisabled = NO;

    switch (selection) {
        case 1:
            absoluteTouchMode = YES;
            multiTouchScreen = NO;
            break;
        case 2:
            absoluteTouchMode = YES;
            multiTouchScreen = YES;
            break;
        case 3:
            absoluteTouchMode = NO;
            multiTouchScreen = NO;
            directScreenTouchInputDisabled = YES;
            break;
        default:
            absoluteTouchMode = NO;
            multiTouchScreen = NO;
            break;
    }

    _currentSessionTouchModeSelection = selection;
    _settings.absoluteTouchMode = absoluteTouchMode;
    _settings.multiTouchScreen = multiTouchScreen;

    [_streamView applyTemporaryTouchModeWithAbsoluteTouchMode:absoluteTouchMode
                                             multiTouchScreen:multiTouchScreen];
    [_streamView setDirectScreenTouchInputDisabled:directScreenTouchInputDisabled];
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

- (void)applyPerformanceOverlayPositionSelectionToCurrentSession:(NSInteger)selection {
    _currentSessionPerformanceOverlayPositionSelection = MAX(0, MIN(selection, 5));
    [self layoutOverlayViewForCurrentBounds];
}

- (void)applyPerformanceOverlayMarginToCurrentSession:(CGFloat)margin {
    _currentSessionPerformanceOverlayMargin = MAX(0.0f, MIN(margin, 150.0f));
    [self layoutOverlayViewForCurrentBounds];
}

- (NSString *)touchModeTitleForSelection:(NSInteger)selection {
    switch (selection) {
        case 1:
            return @"鼠标";
        case 2:
            return @"多点触控";
        case 3:
            return @"禁止触控";
        default:
            return @"触控板";
    }
}

- (void)showTemporaryTouchModeOverlayForSelection:(NSInteger)selection {
    NSString *title = [self touchModeTitleForSelection:selection];
    [self showTemporaryTipText:[NSString stringWithFormat:@"触控模式: %@", title]];
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
        [self showTemporaryTipText:@"仅查看已开启"];
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
    [self showTemporaryTipText:@"仅查看已关闭"];
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
        @{@"id": @"virtual_button_ctrl_shift_esc", @"title": @"任务管理器", @"subtitle": @"Ctrl + Shift + ESC", @"primary": @[@0x11, @0x10, @0x1B], @"secondary": @[], @"shape": @"roundedRect", @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0}
    ];
}

- (NSArray<NSDictionary *> *)defaultVirtualGamepadDefinitionsForPortrait:(BOOL)portrait {
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

- (void)loadDefaultVirtualGamepadDefinitionsForCurrentOrientation {
    _virtualGamepadDefinitions = [[self defaultVirtualGamepadDefinitionsForPortrait:_currentSessionVirtualGamepadLayoutPortrait] mutableCopy];
}

- (NSInteger)currentVirtualButtonSchemeSelection {
    return MAX(0, MIN(_currentSessionVirtualButtonSchemeSelection, 4));
}

- (NSInteger)currentVirtualGamepadSchemeSelection {
    return MAX(0, MIN(_currentSessionVirtualGamepadSchemeSelection, 4));
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

    _currentSessionVirtualGamepadLayoutPortrait = portrait;
    if (savedDefinitions != nil && savedDefinitions.count > 0) {
        _virtualGamepadDefinitions = [savedDefinitions mutableCopy];
    }
    else if (fallbackDefinitions.count > 0) {
        _virtualGamepadDefinitions = [fallbackDefinitions mutableCopy];
    }
    else {
        _virtualGamepadDefinitions = [[self defaultVirtualGamepadDefinitionsForPortrait:portrait] mutableCopy];
    }

    _currentSessionVirtualGamepadOpacity = [dataManager virtualGamepadOpacityForSchemeSelection:schemeSelection];
    if (_currentSessionVirtualGamepadOpacity <= 0.0f) {
        _currentSessionVirtualGamepadOpacity = fallbackOpacity;
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

    _virtualButtonEditorShapeControl = [[UISegmentedControl alloc] initWithItems:@[@"圆角矩形", @"圆形"]];
    [_virtualButtonEditorShapeControl addTarget:self action:@selector(handleVirtualButtonEditorShapeChanged:) forControlEvents:UIControlEventValueChanged];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorShapeControl];

    UILabel *scaleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    scaleLabel.tag = 9101;
    scaleLabel.text = @"尺寸";
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
    widthLabel.text = @"宽度";
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
    heightLabel.text = @"高度";
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
    touchSensitivityXLabel.text = @"X轴灵敏度";
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
    touchSensitivityYLabel.text = @"Y轴灵敏度";
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
    [_virtualButtonEditorSaveButton setTitle:@"保存" forState:UIControlStateNormal];
    _virtualButtonEditorSaveButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorSaveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualButtonEditorSaveButton.backgroundColor = [[UIColor colorWithRed:0.50f green:0.45f blue:0.94f alpha:1.0f] colorWithAlphaComponent:0.92f];
    _virtualButtonEditorSaveButton.layer.cornerRadius = 11.0f;
    [_virtualButtonEditorSaveButton addTarget:self action:@selector(handleVirtualButtonEditorSaveTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorSaveButton];

    _virtualButtonEditorCloseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualButtonEditorCloseButton setTitle:@"关闭" forState:UIControlStateNormal];
    _virtualButtonEditorCloseButton.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    [_virtualButtonEditorCloseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _virtualButtonEditorCloseButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    _virtualButtonEditorCloseButton.layer.cornerRadius = 11.0f;
    _virtualButtonEditorCloseButton.layer.borderWidth = 1.0f;
    _virtualButtonEditorCloseButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12f].CGColor;
    [_virtualButtonEditorCloseButton addTarget:self action:@selector(handleVirtualButtonEditorCloseTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_virtualButtonEditorView addSubview:_virtualButtonEditorCloseButton];

    _virtualButtonEditorDeleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_virtualButtonEditorDeleteButton setTitle:@"删除" forState:UIControlStateNormal];
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
    _virtualButtonEditorTitleLabel.text = definition[@"title"] ?: (editingVirtualGamepad ? @"虚拟手柄" : @"虚拟按键");
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
    [self layoutVirtualButtonEditorForCurrentBounds];
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
    [self showTemporaryTipText:(editingVirtualGamepad ? @"虚拟手柄已保存" : @"虚拟按键已保存")];
}

- (void)handleVirtualButtonEditorCloseTapped:(UIButton *)sender {
    (void)sender;
    _virtualButtonEditorView.hidden = YES;
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
    if (editingVirtualButtons) {
        [self applyVirtualButtonDefinitionsToStreamView];
        [self refreshVirtualButtonsPanelIfNeeded];
        [self persistCurrentVirtualButtonScheme];
        [self showTemporaryTipText:@"虚拟按键已删除"];
    }
    else {
        [self applyVirtualGamepadDefinitionsToStreamView];
        [self persistCurrentVirtualGamepadScheme];
        [self showTemporaryTipText:@"虚拟手柄控件已删除"];
    }
}

- (void)showVirtualButtonsPanel {
    if (@available(iOS 13.0, *)) {
        StreamVirtualButtonsPanelHostingViewController *controller = [[StreamVirtualButtonsPanelHostingViewController alloc] init];
        controller.delegate = (id<StreamVirtualButtonsPanelHostingViewControllerDelegate>)self;
        [controller configureWithTitle:@"虚拟按键"
                                 items:[self virtualButtonPanelItems]
                      isEditingEnabled:[_streamView isTemporaryVirtualButtonsEditingEnabled]
                          buttonOpacity:[self currentVirtualButtonOpacity]];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamVirtualButtonsPanelHostingViewController = controller;
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)refreshVirtualButtonsPanelIfNeeded {
    if (_streamVirtualButtonsPanelHostingViewController == nil) {
        return;
    }

    [_streamVirtualButtonsPanelHostingViewController configureWithTitle:@"虚拟按键"
                                                                 items:[self virtualButtonPanelItems]
                                                      isEditingEnabled:[_streamView isTemporaryVirtualButtonsEditingEnabled]
                                                          buttonOpacity:[self currentVirtualButtonOpacity]];
}

- (NSArray<NSDictionary *> *)defaultShortcutDefinitions {
    return @[
        @{@"id": @"shortcut_escape", @"title": @"返回/关闭页面", @"subtitle": @"ESC", @"symbol": @"escape", @"primary": @[@0x1B], @"secondary": @[]},
        @{@"id": @"shortcut_f11", @"title": @"网页全屏切换", @"subtitle": @"F11", @"symbol": @"macwindow.on.rectangle", @"primary": @[@0x7A], @"secondary": @[]},
        @{@"id": @"shortcut_alt_f4", @"title": @"关闭应用", @"subtitle": @"Alt+F4", @"symbol": @"xmark.circle", @"primary": @[@0xA4, @0x73], @"secondary": @[]},
        @{@"id": @"shortcut_alt_enter", @"title": @"窗口大小", @"subtitle": @"Alt+Enter", @"symbol": @"arrow.up.left.and.arrow.down.right", @"primary": @[@0xA4, @0x0D], @"secondary": @[]},
        @{@"id": @"shortcut_shift_tab", @"title": @"Steam OverLay", @"subtitle": @"Shift+Tab", @"symbol": @"rectangle.on.rectangle", @"primary": @[@0xA0, @0x09], @"secondary": @[]},

        @{@"id": @"shortcut_cursor_toggle", @"title": @"鼠标光标", @"subtitle": @"Ctrl+Alt+Shift+N", @"symbol": @"cursorarrow.motionlines", @"primary": @[@0xA2, @0xA4, @0xA0, @0x4E], @"secondary": @[]},
        @{@"id": @"shortcut_shutdown", @"title": @"关机", @"subtitle": @"Win+X~U-U", @"symbol": @"power", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x55]},
        @{@"id": @"shortcut_restart", @"title": @"重启", @"subtitle": @"Win+X~U-R", @"symbol": @"arrow.clockwise", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x52]},
        @{@"id": @"shortcut_sleep", @"title": @"睡眠", @"subtitle": @"Win+X~U-S", @"symbol": @"moon.zzz", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x53]},
        @{@"id": @"shortcut_logout", @"title": @"注销", @"subtitle": @"Win+X~U-I", @"symbol": @"person.crop.circle.badge.xmark", @"primary": @[@0x5B, @0x58], @"secondary": @[@0x55, @0x49]},

        @{@"id": @"shortcut_copy", @"title": @"复制", @"subtitle": @"Ctrl+C", @"symbol": @"doc.on.doc", @"primary": @[@0xA2, @0x43], @"secondary": @[]},
        @{@"id": @"shortcut_paste", @"title": @"粘贴", @"subtitle": @"Ctrl+V", @"symbol": @"doc.on.clipboard", @"primary": @[@0xA2, @0x56], @"secondary": @[]},
        @{@"id": @"shortcut_cut", @"title": @"剪切", @"subtitle": @"Ctrl+X", @"symbol": @"scissors", @"primary": @[@0xA2, @0x58], @"secondary": @[]},
        @{@"id": @"shortcut_monitor_1", @"title": @"切换显示器1", @"subtitle": @"Ctrl+Alt+Shift+F1", @"symbol": @"display.2", @"primary": @[@0xA2, @0xA4, @0xA0, @0x70], @"secondary": @[]},
        @{@"id": @"shortcut_monitor_2", @"title": @"切换显示器2", @"subtitle": @"Ctrl+Alt+Shift+F12", @"symbol": @"display", @"primary": @[@0xA2, @0xA4, @0xA0, @0x7B], @"secondary": @[]},

        @{@"id": @"shortcut_win", @"title": @"开始菜单", @"subtitle": @"Win", @"symbol": @"command", @"primary": @[@0x5B], @"secondary": @[]},
        @{@"id": @"shortcut_hdr", @"title": @"HDR开关", @"subtitle": @"Win+Alt+B", @"symbol": @"sun.max", @"primary": @[@0x5B, @0xA4, @0x42], @"secondary": @[]},
        @{@"id": @"shortcut_task_manager", @"title": @"任务管理器", @"subtitle": @"Ctrl+Shift+ESC", @"symbol": @"list.bullet.rectangle", @"primary": @[@0xA2, @0xA0, @0x1B], @"secondary": @[]},
        @{@"id": @"shortcut_desktop", @"title": @"返回桌面", @"subtitle": @"Win+D", @"symbol": @"desktopcomputer", @"primary": @[@0x5B, @0x44], @"secondary": @[]},
        @{@"id": @"shortcut_display_mode", @"title": @"显示器模式", @"subtitle": @"Win+P", @"symbol": @"rectangle.3.group", @"primary": @[@0x5B, @0x50], @"secondary": @[]},

        @{@"id": @"shortcut_settings", @"title": @"Windows设置", @"subtitle": @"Win+I", @"symbol": @"gearshape", @"primary": @[@0x5B, @0x49], @"secondary": @[]},
        @{@"id": @"shortcut_explorer", @"title": @"我的电脑", @"subtitle": @"Win+E", @"symbol": @"folder", @"primary": @[@0x5B, @0x45], @"secondary": @[]},
        @{@"id": @"shortcut_mobility", @"title": @"移动中心", @"subtitle": @"Win+X", @"symbol": @"bolt.horizontal.circle", @"primary": @[@0x5B, @0x58], @"secondary": @[]},
        @{@"id": @"shortcut_desktop_left", @"title": @"切换桌面左", @"subtitle": @"Win+Shift+Left", @"symbol": @"arrow.left.circle", @"primary": @[@0x5B, @0xA0, @0x25], @"secondary": @[]},
        @{@"id": @"shortcut_desktop_right", @"title": @"切换桌面右", @"subtitle": @"Win+Shift+Right", @"symbol": @"arrow.right.circle", @"primary": @[@0x5B, @0xA0, @0x27], @"secondary": @[]}
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
        [controller configureWithTitle:@"快捷键"
                          builtInItems:[self defaultShortcutItems]
                           customItems:[self customShortcutItems]];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamShortcutPanelHostingViewController = controller;
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)refreshShortcutPanelIfNeeded {
    if (_streamShortcutPanelHostingViewController == nil) {
        return;
    }

    [_streamShortcutPanelHostingViewController configureWithTitle:@"快捷键"
                                                     builtInItems:[self defaultShortcutItems]
                                                      customItems:[self customShortcutItems]];
}

- (void)showVirtualKeyboardPanel {
    if (@available(iOS 13.0, *)) {
        StreamVirtualKeyboardPanelHostingViewController *controller = [[StreamVirtualKeyboardPanelHostingViewController alloc] init];
        controller.delegate = (id<StreamVirtualKeyboardPanelHostingViewControllerDelegate>)self;
        [controller configureWithTitle:@"全键盘"];
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        _streamVirtualKeyboardPanelHostingViewController = controller;
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)quitCurrentAppAndReturnToMainFrame {
    [self->_spinner startAnimating];
    self->_spinner.hidden = NO;
    self->_stageLabel.text = @"正在退出应用...";
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
                self->_suppressTerminationAlertForManualExit = YES;
                [self returnToMainFrame];
                return;
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出应用失败"
                                                                           message:@"当前应用未能成功退出。如果这个应用是从其他设备启动的，可能需要在那台设备上退出。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}

- (void)handleStreamMenuActionWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"disconnect"]) {
        [self returnToMainFrame];
        return;
    }

    if ([identifier isEqualToString:@"quit_app"]) {
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

    if ([identifier isEqualToString:@"keyboard"] && self->_streamView != nil) {
        [self->_streamView showKeyInputBoard];
        return;
    }

    if ([identifier isEqualToString:@"virtual_gamepad"] && self->_streamView != nil) {
        [self toggleTemporaryVirtualGamepad];
        return;
    }

    if ([identifier isEqualToString:@"manage_virtual_gamepad"] && self->_streamView != nil) {
        [self->_streamView setTemporaryVirtualGamepadEditingEnabled:![self->_streamView isTemporaryVirtualGamepadEditingEnabled]];
        if ([self->_streamView isTemporaryVirtualGamepadEditingEnabled]) {
            [self->_streamView setTemporaryVirtualGamepadVisible:YES];
            [self showTemporaryTipText:@"点选虚拟手柄控件可调整位置和大小"];
        }
        else {
            self->_selectedVirtualGamepadIdentifier = nil;
            self->_virtualButtonEditorView.hidden = YES;
        }
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
        
        if (self->_settings.statsOverlay) {
            self->_statsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                                       target:self
                                                                     selector:@selector(updateStatsOverlay)
                                                                     userInfo:nil
                                                                      repeats:YES];
        }
    });
}

- (void)connectionTerminated:(int)errorCode {
    Log(LOG_I, @"Connection terminated: %d", errorCode);

    if (_suppressTerminationAlertForManualExit) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_suppressTerminationAlertForManualExit = NO;
            [self returnToMainFrame];
        });
        [_streamMan stopStream];
        return;
    }
    
    unsigned int portFlags = LiGetPortFlagsFromTerminationErrorCode(errorCode);
    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443, portFlags);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        NSString* title;
        NSString* message;
        
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            title = @"连接错误";
            message = @"您的设备网络连接受限，可能无法进行串流。";
        }
        else {
            switch (errorCode) {
                case ML_ERROR_GRACEFUL_TERMINATION:
                    [self returnToMainFrame];
                    return;
                    
                case ML_ERROR_NO_VIDEO_TRAFFIC:
                    title = @"连接错误";
                    message = @"未收到主机发送的视频。";
                    if (portFlags != 0) {
                        char failingPorts[256];
                        LiStringifyPortFlags(portFlags, "\n", failingPorts, sizeof(failingPorts));
                        message = [message stringByAppendingString:[NSString stringWithFormat:@"请检查您的防火墙和端口转发规则，确认端口是否已启用：\n%s", failingPorts]];
                    }
                    break;
                    
                case ML_ERROR_NO_VIDEO_FRAME:
                    title = @"连接错误";
                    message = @"您的网络连接性能不佳。请降低视频比特率设置或尝试更快的连接。";
                    break;
                    
                case ML_ERROR_UNEXPECTED_EARLY_TERMINATION:
                case ML_ERROR_PROTECTED_CONTENT:
                    title = @"连接错误";
                    message = @"启动串流时，主机电脑出现问题。\n\n请确保主机电脑上没有打开任何受 DRM 保护的内容。您也可以尝试重启主机电脑。\n\n如果问题仍然存在，请尝试重新安装显卡驱动程序和 GeForce Experience。";
                    break;
                    
                case ML_ERROR_FRAME_CONVERSION:
                    title = @"连接错误";
                    message = @"主机报告出现致命的视频编码错误。\n\n请尝试禁用 HDR 模式、更改流媒体分辨率或更改主机的显示分辨率。";
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
                    
                    title = @"连接已终止";
                    message = [NSString stringWithFormat: @"连接已终止\in\错误代码：%@", errorString];
                    break;
                }
            }
        }
        
        UIAlertController* conTermAlert = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:conTermAlert];
        [conTermAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:conTermAlert animated:YES completion:nil];
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
        
        NSString* message = [NSString stringWithFormat:@"%s failed with error %d", stageName, errorCode];
        if (portTestFlags != 0) {
            char failingPorts[256];
            LiStringifyPortFlags(portTestFlags, "\n", failingPorts, sizeof(failingPorts));
            message = [message stringByAppendingString:[NSString stringWithFormat:@"请检查您的防火墙和端口转发规则，确认端口是否已启用：\n%s", failingPorts]];
        }
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            message = [message stringByAppendingString:@"您的设备网络连接受限，可能无法进行串流。"];
        }
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"连接失败"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:alert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
    
    [_streamMan stopStream];
}

- (void) launchFailed:(NSString*)message {
    Log(LOG_I, @"Launch failed: %@", message);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"连接错误"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:alert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor {
    Log(LOG_I, @"Rumble on gamepad %d: %04x %04x", controllerNumber, lowFreqMotor, highFreqMotor);
    
    [_controllerSupport rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
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
                    [self updateOverlayText:@"电脑连接速度缓慢，请降低码率！"];
                }
                else {
                    [self updateOverlayText:@"电脑连接不良"];
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }

    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)prefersPointerLocked {
    // Pointer lock breaks the UIKit mouse APIs, which is a problem because
    // GCMouse is horribly broken on iOS 14.0 for certain mice. Only lock
    // the cursor if there is a GCMouse present.
    return [GCMouse mice].count > 0;
}
#endif

- (NSString*)getInternetface {
    long long currentBytes = [self getInterfaceBytes];  // 获取当前流量
    long long deltaBytes = currentBytes - self.previousBytes;  // 计算差值

    // 转换为 KB/s
    float kbPerSecond = deltaBytes / 1024.0;  // 将字节转换为千字节（KB）
    self.previousBytes = currentBytes;  // 更新上次字节数

    // 判断是否超过 1000 KB/s，转换为 MB/s
    if (kbPerSecond > 1000) {
        float mbPerSecond = kbPerSecond / 1024.0;  // 转换为兆字节每秒（MB/s）
//        NSLog(@"Network speed: %.2f MB/s", mbPerSecond);  // 输出 MB/s
        return [NSString stringWithFormat:@"带宽: %.2f MB/s",mbPerSecond];
    } else {
//        NSLog(@"Network speed: %.2f KB/s", kbPerSecond);  // 输出 KB/s
        return [NSString stringWithFormat:@"带宽: %.2f KB/s",kbPerSecond];
    }
    return @"";
}

/* 获取所有接口的网络流量信息 */
- (long long)getInterfaceBytes {
    struct ifaddrs *ifa_list = NULL, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return 0;  // 获取失败，返回 0
    }

    uint32_t iBytes = 0;  // 输入字节
    uint32_t oBytes = 0;  // 输出字节

    // 遍历所有接口
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        // 过滤掉非链路层接口
        if (AF_LINK != ifa->ifa_addr->sa_family) {
            continue;
        }

        // 仅统计活动接口
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) {
            continue;
        }

        // 如果没有相关的流量数据，跳过该接口
        if (ifa->ifa_data == 0) {
            continue;
        }

        // 获取接口的流量数据
        struct if_data *if_data = (struct if_data *)ifa->ifa_data;
        iBytes += if_data->ifi_ibytes;  // 累加输入字节
        oBytes += if_data->ifi_obytes;  // 累加输出字节
    }

    freeifaddrs(ifa_list);  // 释放内存

    // 返回输入字节和输出字节的总和
    return iBytes + oBytes;
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didSelectActionWithIdentifier:(NSString *)identifier {
    _streamActionSheetHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
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

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangeExtendedPerformanceMetricsEnabled:(BOOL)enabled {
    (void)controller;
    [self applyExtendedPerformanceMetricsEnabled:enabled];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangePerformanceOverlayPositionSelection:(NSInteger)selection {
    (void)controller;
    [self applyPerformanceOverlayPositionSelectionToCurrentSession:selection];
}

- (void)streamActionSheetHostingViewController:(StreamActionSheetHostingViewController *)controller didChangePerformanceOverlayMargin:(double)margin {
    (void)controller;
    [self applyPerformanceOverlayMarginToCurrentSession:(CGFloat)margin];
}

- (void)streamActionSheetHostingViewControllerDidCancel:(StreamActionSheetHostingViewController *)controller {
    _streamActionSheetHostingViewController = nil;

    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)streamShortcutPanelHostingViewControllerDidCancel:(StreamShortcutPanelHostingViewController *)controller {
    _streamShortcutPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:nil];
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
    [self showTemporaryTipText:@"快捷键已添加"];
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
    [self showTemporaryTipText:@"快捷键已删除"];
}

- (void)streamVirtualKeyboardPanelHostingViewControllerDidCancel:(StreamVirtualKeyboardPanelHostingViewController *)controller {
    _streamVirtualKeyboardPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:nil];
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
        [self->_streamView showKeyInputBoard];
    }];
}

- (void)streamVirtualButtonsPanelHostingViewControllerDidCancel:(StreamVirtualButtonsPanelHostingViewController *)controller {
    _streamVirtualButtonsPanelHostingViewController = nil;
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)streamVirtualButtonsPanelHostingViewController:(StreamVirtualButtonsPanelHostingViewController *)controller didChangeEditingEnabled:(BOOL)enabled {
    [_streamView setTemporaryVirtualButtonsEditingEnabled:enabled];
    if (enabled) {
        [_streamView setTemporaryVirtualButtonsVisible:YES];
        _streamVirtualButtonsPanelHostingViewController = nil;
        [controller dismissViewControllerAnimated:YES completion:nil];
        [self showTemporaryTipText:@"点选虚拟按键可调整位置和大小"];
    }
    else {
        _selectedVirtualButtonIdentifier = nil;
        _virtualButtonEditorView.hidden = YES;
    }
    [self refreshVirtualButtonsPanelIfNeeded];
    [self refreshVirtualButtonEditorForCurrentSelection];
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

    _virtualGamepadDefinitions = [descriptors mutableCopy];
    [self refreshVirtualButtonEditorForCurrentSelection];
    [self persistCurrentVirtualGamepadScheme];
}

@end
