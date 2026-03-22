//
//  StreamView.m
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "StreamView.h"
#include <Limelight.h>
#import "DataManager.h"
#import "ControllerSupport.h"
#import "KeyboardSupport.h"
#import "RelativeTouchHandler.h"
#import "AbsoluteTouchHandler.h"
#import "KeyboardInputField.h"
#import "OSCProfilesManager.h"

static const double X1_MOUSE_SPEED_DIVISOR = 2.5;
NSString * const StreamViewBoundsDidChangeNotification = @"StreamViewBoundsDidChangeNotification";
NSString * const StreamViewVirtualButtonsDidChangeNotification = @"StreamViewVirtualButtonsDidChangeNotification";
NSString * const StreamViewVirtualButtonSelectionDidChangeNotification = @"StreamViewVirtualButtonSelectionDidChangeNotification";
static NSString * const kVirtualButtonShapeCircle = @"circle";
static NSString * const kVirtualButtonShapeRoundedRect = @"roundedRect";
static NSString * const kVirtualControlJoystick = @"joystick";
static NSString * const kVirtualControlDPad = @"dpad";

typedef NS_OPTIONS(NSUInteger, StreamVirtualDirectionMask) {
    StreamVirtualDirectionMaskNone  = 0,
    StreamVirtualDirectionMaskUp    = 1 << 0,
    StreamVirtualDirectionMaskDown  = 1 << 1,
    StreamVirtualDirectionMaskLeft  = 1 << 2,
    StreamVirtualDirectionMaskRight = 1 << 3,
};

@interface KeyboardAccessoryScrollView : UIScrollView
@end

@implementation KeyboardAccessoryScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    return YES;
}

@end

@interface StreamVirtualDirectionalControl : UIControl
@property(nonatomic, copy) NSString *controlAction;
@property(nonatomic, assign) BOOL editingEnabled;
@property(nonatomic, assign) BOOL selectedForEditing;
@property(nonatomic, assign) CGFloat controlOpacity;
@property(nonatomic, copy) dispatch_block_t selectionHandler;
@property(nonatomic, copy) void (^directionMaskChangedHandler)(StreamVirtualDirectionMask previousMask, StreamVirtualDirectionMask currentMask);
- (void)configureWithDescriptor:(NSDictionary<NSString *, id> *)descriptor;
- (void)resetInteractionState;
@end

@implementation StreamVirtualDirectionalControl {
    UIView *_baseView;
    UIView *_knobView;
    UIView *_centerDotView;
    NSArray<UILabel *> *_directionLabels;
    UIPanGestureRecognizer *_interactionPanGestureRecognizer;
    UITapGestureRecognizer *_selectionTapGestureRecognizer;
    StreamVirtualDirectionMask _currentMask;
    CGPoint _normalizedVector;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.exclusiveTouch = YES;

        _baseView = [[UIView alloc] initWithFrame:CGRectZero];
        _baseView.userInteractionEnabled = NO;
        [self addSubview:_baseView];

        NSMutableArray<UILabel *> *labels = [NSMutableArray arrayWithCapacity:4];
        for (NSInteger index = 0; index < 4; index++) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
            label.userInteractionEnabled = NO;
            [_baseView addSubview:label];
            [labels addObject:label];
        }
        _directionLabels = [labels copy];

        _knobView = [[UIView alloc] initWithFrame:CGRectZero];
        _knobView.userInteractionEnabled = NO;
        [_baseView addSubview:_knobView];

        _centerDotView = [[UIView alloc] initWithFrame:CGRectZero];
        _centerDotView.userInteractionEnabled = NO;
        [_baseView addSubview:_centerDotView];

        _interactionPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleInteractionPan:)];
        [self addGestureRecognizer:_interactionPanGestureRecognizer];

        _selectionTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionTap:)];
        _selectionTapGestureRecognizer.enabled = NO;
        [self addGestureRecognizer:_selectionTapGestureRecognizer];

        _controlAction = @"";
        _controlOpacity = 0.52f;
        _currentMask = StreamVirtualDirectionMaskNone;
        _normalizedVector = CGPointZero;
    }
    return self;
}

- (BOOL)isJoystick {
    return [_controlAction hasPrefix:@"joystick_"];
}

- (BOOL)usesWASDMapping {
    return [_controlAction hasSuffix:@"_wasd"];
}

- (void)setEditingEnabled:(BOOL)editingEnabled {
    _editingEnabled = editingEnabled;
    _interactionPanGestureRecognizer.enabled = NO;
    _selectionTapGestureRecognizer.enabled = editingEnabled;
    [self updateVisualState];
}

- (void)setSelectedForEditing:(BOOL)selectedForEditing {
    _selectedForEditing = selectedForEditing;
    [self updateVisualState];
}

- (void)setControlOpacity:(CGFloat)controlOpacity {
    _controlOpacity = controlOpacity;
    [self updateVisualState];
}

- (void)configureWithDescriptor:(NSDictionary<NSString *,id> *)descriptor {
    NSString *controlAction = descriptor[@"controlAction"];
    if ([controlAction isKindOfClass:[NSString class]] && controlAction.length > 0) {
        self.controlAction = controlAction;
    }

    NSArray<NSString *> *labels = [self usesWASDMapping] ? @[ @"W", @"S", @"A", @"D" ] : @[ @"↑", @"↓", @"←", @"→" ];
    [_directionLabels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger idx, BOOL *stop) {
        label.text = idx < labels.count ? labels[idx] : @"";
    }];

    [self updateVisualState];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    CGRect baseFrame = CGRectMake((CGRectGetWidth(self.bounds) - side) * 0.5f,
                                  (CGRectGetHeight(self.bounds) - side) * 0.5f,
                                  side,
                                  side);
    _baseView.frame = baseFrame;

    CGFloat centerX = CGRectGetMidX(_baseView.bounds);
    CGFloat centerY = CGRectGetMidY(_baseView.bounds);

    UILabel *upLabel = _directionLabels.count > 0 ? _directionLabels[0] : nil;
    UILabel *downLabel = _directionLabels.count > 1 ? _directionLabels[1] : nil;
    UILabel *leftLabel = _directionLabels.count > 2 ? _directionLabels[2] : nil;
    UILabel *rightLabel = _directionLabels.count > 3 ? _directionLabels[3] : nil;

    if ([self isJoystick]) {
        CGFloat labelSize = floor(side * 0.24f);
        CGFloat inset = floor(side * 0.12f);
        CGFloat knobSide = floor(side * 0.28f);
        CGFloat centerDotSide = floor(side * 0.10f);

        upLabel.frame = CGRectMake(centerX - labelSize * 0.5f, inset, labelSize, labelSize);
        downLabel.frame = CGRectMake(centerX - labelSize * 0.5f, CGRectGetHeight(_baseView.bounds) - inset - labelSize, labelSize, labelSize);
        leftLabel.frame = CGRectMake(inset, centerY - labelSize * 0.5f, labelSize, labelSize);
        rightLabel.frame = CGRectMake(CGRectGetWidth(_baseView.bounds) - inset - labelSize, centerY - labelSize * 0.5f, labelSize, labelSize);

        _centerDotView.bounds = CGRectMake(0, 0, centerDotSide, centerDotSide);
        _centerDotView.center = CGPointMake(centerX, centerY);
        _centerDotView.layer.cornerRadius = centerDotSide * 0.5f;

        _knobView.bounds = CGRectMake(0, 0, knobSide, knobSide);
        _knobView.layer.cornerRadius = knobSide * 0.5f;
        CGFloat travelRadius = MAX((side * 0.5f) - (knobSide * 0.5f) - (side * 0.12f), 0.0f);
        _knobView.center = CGPointMake(centerX + _normalizedVector.x * travelRadius,
                                       centerY + _normalizedVector.y * travelRadius);
    }
    else {
        CGFloat buttonSide = floor(side * 0.24f);
        CGFloat inset = floor(side * 0.12f);

        upLabel.frame = CGRectMake(centerX - buttonSide * 0.5f,
                                   inset,
                                   buttonSide,
                                   buttonSide);
        downLabel.frame = CGRectMake(centerX - buttonSide * 0.5f,
                                     CGRectGetHeight(_baseView.bounds) - inset - buttonSide,
                                     buttonSide,
                                     buttonSide);
        leftLabel.frame = CGRectMake(inset,
                                     centerY - buttonSide * 0.5f,
                                     buttonSide,
                                     buttonSide);
        rightLabel.frame = CGRectMake(CGRectGetWidth(_baseView.bounds) - inset - buttonSide,
                                      centerY - buttonSide * 0.5f,
                                      buttonSide,
                                      buttonSide);

        _centerDotView.bounds = CGRectZero;
        _centerDotView.center = CGPointMake(centerX, centerY);
        _knobView.bounds = CGRectZero;
        _knobView.center = CGPointMake(centerX, centerY);
    }

    for (UILabel *label in _directionLabels) {
        label.layer.cornerRadius = CGRectGetWidth(label.bounds) * 0.5f;
    }
}

- (void)resetInteractionState {
    [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
}

- (void)handleSelectionTap:(UITapGestureRecognizer *)gestureRecognizer {
    if (!self.editingEnabled) {
        return;
    }

    if (self.selectionHandler != nil) {
        self.selectionHandler();
    }
}

- (void)handleInteractionPan:(UIPanGestureRecognizer *)gestureRecognizer {
    if (self.editingEnabled) {
        return;
    }

    CGPoint location = [gestureRecognizer locationInView:_baseView];
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled || gestureRecognizer.state == UIGestureRecognizerStateFailed) {
        [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
        return;
    }

    CGFloat halfWidth = CGRectGetWidth(_baseView.bounds) * 0.5f;
    CGFloat halfHeight = CGRectGetHeight(_baseView.bounds) * 0.5f;
    if (halfWidth <= 0.0f || halfHeight <= 0.0f) {
        return;
    }

    CGFloat rawX = (location.x - halfWidth) / halfWidth;
    CGFloat rawY = (location.y - halfHeight) / halfHeight;
    rawX = MIN(MAX(rawX, -1.0f), 1.0f);
    rawY = MIN(MAX(rawY, -1.0f), 1.0f);

    CGFloat magnitude = sqrt((rawX * rawX) + (rawY * rawY));
    CGFloat deadZone = [self isJoystick] ? 0.28f : 0.24f;
    if (magnitude < deadZone) {
        [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
        return;
    }

    StreamVirtualDirectionMask mask = StreamVirtualDirectionMaskNone;
    if (rawX <= -0.32f) {
        mask |= StreamVirtualDirectionMaskLeft;
    }
    else if (rawX >= 0.32f) {
        mask |= StreamVirtualDirectionMaskRight;
    }

    if (rawY <= -0.32f) {
        mask |= StreamVirtualDirectionMaskUp;
    }
    else if (rawY >= 0.32f) {
        mask |= StreamVirtualDirectionMaskDown;
    }

    CGPoint normalizedVector = CGPointMake(rawX / MAX(magnitude, 1.0f), rawY / MAX(magnitude, 1.0f));
    if (![self isJoystick]) {
        normalizedVector = CGPointZero;
    }
    [self updateDirectionMask:mask normalizedVector:normalizedVector];
}

- (StreamVirtualDirectionMask)directionMaskForDPadLocation:(CGPoint)location {
    CGFloat centerX = CGRectGetMidX(_baseView.bounds);
    CGFloat centerY = CGRectGetMidY(_baseView.bounds);
    CGFloat deltaX = location.x - centerX;
    CGFloat deltaY = location.y - centerY;
    CGFloat distance = hypot(deltaX, deltaY);
    CGFloat deadZone = CGRectGetWidth(_baseView.bounds) * 0.14f;

    if (distance < deadZone) {
        return StreamVirtualDirectionMaskNone;
    }

    if (fabs(deltaX) > fabs(deltaY)) {
        return deltaX < 0.0f ? StreamVirtualDirectionMaskLeft : StreamVirtualDirectionMaskRight;
    }

    return deltaY < 0.0f ? StreamVirtualDirectionMaskUp : StreamVirtualDirectionMaskDown;
}

- (void)updateTrackingForLocation:(CGPoint)location gestureDriven:(BOOL)gestureDriven {
    CGFloat halfWidth = CGRectGetWidth(_baseView.bounds) * 0.5f;
    CGFloat halfHeight = CGRectGetHeight(_baseView.bounds) * 0.5f;
    if (halfWidth <= 0.0f || halfHeight <= 0.0f) {
        return;
    }

    if (![self isJoystick]) {
        if (gestureDriven) {
            return;
        }
        [self updateDirectionMask:[self directionMaskForDPadLocation:location] normalizedVector:CGPointZero];
        return;
    }

    CGFloat rawX = (location.x - halfWidth) / halfWidth;
    CGFloat rawY = (location.y - halfHeight) / halfHeight;
    rawX = MIN(MAX(rawX, -1.0f), 1.0f);
    rawY = MIN(MAX(rawY, -1.0f), 1.0f);

    CGFloat magnitude = sqrt((rawX * rawX) + (rawY * rawY));
    CGFloat deadZone = 0.28f;
    if (magnitude < deadZone) {
        [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
        return;
    }

    StreamVirtualDirectionMask mask = StreamVirtualDirectionMaskNone;
    if (rawX <= -0.32f) {
        mask |= StreamVirtualDirectionMaskLeft;
    }
    else if (rawX >= 0.32f) {
        mask |= StreamVirtualDirectionMaskRight;
    }

    if (rawY <= -0.32f) {
        mask |= StreamVirtualDirectionMaskUp;
    }
    else if (rawY >= 0.32f) {
        mask |= StreamVirtualDirectionMaskDown;
    }

    CGPoint normalizedVector = CGPointMake(rawX / MAX(magnitude, 1.0f), rawY / MAX(magnitude, 1.0f));
    [self updateDirectionMask:mask normalizedVector:normalizedVector];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;
    if (self.editingEnabled) {
        return [super beginTrackingWithTouch:touch withEvent:event];
    }

    CGPoint location = [touch locationInView:_baseView];
    [self updateTrackingForLocation:location gestureDriven:NO];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;
    if (self.editingEnabled) {
        return [super continueTrackingWithTouch:touch withEvent:event];
    }

    if ([self isJoystick]) {
        CGPoint location = [touch locationInView:_baseView];
        [self updateTrackingForLocation:location gestureDriven:NO];
    }
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)touch;
    (void)event;
    [super endTrackingWithTouch:touch withEvent:event];
    if (!self.editingEnabled) {
        [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
    }
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [super cancelTrackingWithEvent:event];
    if (!self.editingEnabled) {
        [self updateDirectionMask:StreamVirtualDirectionMaskNone normalizedVector:CGPointZero];
    }
}

- (void)updateDirectionMask:(StreamVirtualDirectionMask)newMask normalizedVector:(CGPoint)normalizedVector {
    StreamVirtualDirectionMask previousMask = _currentMask;
    _currentMask = newMask;
    _normalizedVector = normalizedVector;
    [self updateVisualState];
    [self setNeedsLayout];

    if (self.directionMaskChangedHandler != nil && previousMask != newMask) {
        self.directionMaskChangedHandler(previousMask, newMask);
    }
}

- (void)updateVisualState {
    BOOL joystick = [self isJoystick];
    CGFloat borderWidth = self.editingEnabled ? (self.selectedForEditing ? 2.0f : 1.3f) : 1.0f;
    UIColor *editingBorderColor = self.editingEnabled ?
        (self.selectedForEditing ? [UIColor colorWithRed:0.60 green:0.55 blue:0.98 alpha:1.0] : [[UIColor colorWithRed:0.50 green:0.45 blue:0.94 alpha:1.0] colorWithAlphaComponent:0.86]) :
        [[UIColor whiteColor] colorWithAlphaComponent:0.14];
    UIColor *fillColor = self.editingEnabled ?
        (self.selectedForEditing ? [UIColor colorWithRed:0.19 green:0.19 blue:0.25 alpha:0.90] : [[UIColor blackColor] colorWithAlphaComponent:self.controlOpacity]) :
        [[UIColor blackColor] colorWithAlphaComponent:self.controlOpacity];

    _baseView.backgroundColor = fillColor;
    _baseView.layer.borderWidth = borderWidth;
    _baseView.layer.borderColor = editingBorderColor.CGColor;
    _baseView.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5f;

    UIColor *joystickActiveFill = [UIColor clearColor];
    UIColor *dpadActiveFill = [[UIColor whiteColor] colorWithAlphaComponent:0.10f];
    UIColor *inactiveFill = [UIColor clearColor];
    UIColor *textColor = joystick ? [UIColor colorWithWhite:1.0 alpha:0.88] : [UIColor colorWithWhite:1.0 alpha:0.88];

    UILabel *upLabel = _directionLabels.count > 0 ? _directionLabels[0] : nil;
    UILabel *downLabel = _directionLabels.count > 1 ? _directionLabels[1] : nil;
    UILabel *leftLabel = _directionLabels.count > 2 ? _directionLabels[2] : nil;
    UILabel *rightLabel = _directionLabels.count > 3 ? _directionLabels[3] : nil;
    NSArray<NSDictionary *> *states = @[
        @{ @"label": upLabel ?: [UILabel new], @"active": @((_currentMask & StreamVirtualDirectionMaskUp) != 0) },
        @{ @"label": downLabel ?: [UILabel new], @"active": @((_currentMask & StreamVirtualDirectionMaskDown) != 0) },
        @{ @"label": leftLabel ?: [UILabel new], @"active": @((_currentMask & StreamVirtualDirectionMaskLeft) != 0) },
        @{ @"label": rightLabel ?: [UILabel new], @"active": @((_currentMask & StreamVirtualDirectionMaskRight) != 0) }
    ];

    for (NSDictionary *state in states) {
        UILabel *label = state[@"label"];
        BOOL active = [state[@"active"] boolValue];
        label.textColor = active ? [UIColor whiteColor] : textColor;
        label.backgroundColor = active ? (joystick ? joystickActiveFill : dpadActiveFill) : inactiveFill;
        label.layer.cornerRadius = CGRectGetWidth(label.bounds) * 0.5f;
        label.layer.masksToBounds = YES;
        label.layer.borderWidth = joystick ? 0.0f : 0.8f;
        label.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:(active ? 0.92f : 0.72f)].CGColor;
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOpacity = 0.0f;
        label.layer.shadowRadius = 0.0f;
        label.layer.shadowOffset = CGSizeMake(0, 4);
        label.transform = (!joystick && active) ? CGAffineTransformMakeScale(0.92f, 0.92f) : CGAffineTransformIdentity;
    }

    _centerDotView.hidden = !joystick;
    _centerDotView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.34];
    _knobView.hidden = !joystick;
    _knobView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    _knobView.layer.borderWidth = 0.8f;
    _knobView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor;
}

@end

@implementation StreamView {
    OnScreenControls* onScreenControls;

    KeyboardInputField* keyInputField;
    BOOL isInputingText;
    NSMutableSet* keysDown;
    
    float streamAspectRatio;
    
    // iOS 13.4 mouse support
    NSInteger lastMouseButtonMask;
    float lastMouseX;
    float lastMouseY;
    CGPoint lastScrollTranslation;
    
    // Citrix X1 mouse support
    X1Mouse* x1mouse;
    double accumulatedMouseDeltaX;
    double accumulatedMouseDeltaY;
    
    UIResponder* touchHandler;
    ControllerSupport* controllerSupport;
    
    id<UserInteractionDelegate> interactionDelegate;
    NSTimer* interactionTimer;
    BOOL hasUserInteracted;
    TemporarySettings* settings;
    NSDictionary<NSString *, NSNumber *> *dictCodes;
    TouchScreenManager* touchManager;
    
    NSMutableDictionary<NSNumber *, SensitivityBean *> *sensitivityMap;
    BOOL touchSensitivityGlobal;
    BOOL enableTouchSensitivity;
    CGFloat touchSensitivity;
    CGSize lastPostedBoundsSize;
    StreamViewVideoAlignmentMode videoAlignmentMode;
    CGFloat videoAlignmentMargin;
    BOOL viewOnlyModeEnabled;
    OnScreenControlsLevel requestedOnScreenControlsLevel;
    UIView *virtualButtonsContainerView;
    NSArray<UIView *> *virtualButtons;
    NSArray<NSDictionary<NSString *, id> *> *virtualButtonDescriptors;
    BOOL temporaryVirtualButtonsVisible;
    BOOL temporaryVirtualButtonsEditingEnabled;
    NSString *selectedVirtualButtonIdentifier;
    NSMutableSet<NSString *> *lockedMouseActionIdentifiers;
}

- (BOOL)shouldUseFullOnScreenControlsForCurrentOrientation {
    return self.bounds.size.height > self.bounds.size.width;
}

- (OnScreenControlsLevel)effectiveOnScreenControlsLevelForRequestedLevel:(OnScreenControlsLevel)level {
    if (level != OnScreenControlsCustom) {
        return level;
    }

    OSCProfile *selectedProfile = [[OSCProfilesManager sharedManager] getSelectedProfile];
    if (selectedProfile == nil || [self shouldUseFullOnScreenControlsForCurrentOrientation]) {
        return OnScreenControlsLevelFull;
    }

    return OnScreenControlsCustom;
}

- (void)applyRequestedOnScreenControlsLevel {
#if !TARGET_OS_TV
    if (onScreenControls == nil) {
        return;
    }

    if (requestedOnScreenControlsLevel == OnScreenControlsLevelAuto && controllerSupport != nil) {
        [controllerSupport initAutoOnScreenControlMode:onScreenControls];
        return;
    }

    OnScreenControlsLevel effectiveLevel = [self effectiveOnScreenControlsLevelForRequestedLevel:requestedOnScreenControlsLevel];
    if ([onScreenControls getLevel] != effectiveLevel) {
        [onScreenControls setLevel:effectiveLevel];
    }
    [onScreenControls show];
#endif
}

- (void) setupStreamView:(ControllerSupport*)controllerSupport
     interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                  config:(StreamConfiguration*)streamConfig {
    self->interactionDelegate = interactionDelegate;
    self->streamAspectRatio = (float)streamConfig.width / (float)streamConfig.height;
    self->settings = [[[DataManager alloc] init] getSettings];
    self->controllerSupport = controllerSupport;
    self.multipleTouchEnabled = YES;
    virtualButtonDescriptors = [[self builtInVirtualButtonDescriptors] copy];
    lockedMouseActionIdentifiers = [[NSMutableSet alloc] init];
    
    self->touchManager = [[TouchScreenManager alloc] init];
    
    self->sensitivityMap = [NSMutableDictionary dictionary];
    self->touchSensitivityGlobal = settings.touchSensitivityGlobal; // 根据你的实际需求初始化
    self->touchSensitivity = settings.touchSensitivity.floatValue; // 根据你的实际需求初始化
    self->enableTouchSensitivity=settings.enableTouchSensitivity;
    
    keysDown = [[NSMutableSet alloc] init];
    keyInputField = [[KeyboardInputField alloc] initWithFrame:CGRectZero];
    [keyInputField setKeyboardType:UIKeyboardTypeDefault];
    [keyInputField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [keyInputField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [keyInputField setSpellCheckingType:UITextSpellCheckingTypeNo];
    [self addSubview:keyInputField];
    
#if TARGET_OS_TV
    // tvOS requires RelativeTouchHandler to manage Apple Remote input
    self->touchHandler = [[RelativeTouchHandler alloc] initWithView:self];
#else
    // iOS uses RelativeTouchHandler or AbsoluteTouchHandler depending on user preference
    [self applyTemporaryTouchModeWithAbsoluteTouchMode:settings.absoluteTouchMode
                                      multiTouchScreen:settings.multiTouchScreen];
    
    onScreenControls = [[OnScreenControls alloc] initWithView:self controllerSup:controllerSupport streamConfig:streamConfig];
    requestedOnScreenControlsLevel = (OnScreenControlsLevel)[settings.onscreenControls integerValue];
    Log(LOG_I, @"Setting requested on-screen controls level: %d", (int)requestedOnScreenControlsLevel);
    [self applyRequestedOnScreenControlsLevel];
    
    // It would be nice to just use GCMouse on iOS 14+ and the older API on iOS 13
    // but unfortunately that isn't possible today. GCMouse doesn't recognize many
    // mice correctly, but UIKit does. We will register for both and ignore UIKit
    // events if a GCMouse is connected.
    if (@available(iOS 13.4, *)) {
        [self addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
        
        UIPanGestureRecognizer *discreteMouseWheelRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(mouseWheelMovedDiscrete:)];
        discreteMouseWheelRecognizer.maximumNumberOfTouches = 0;
        discreteMouseWheelRecognizer.allowedScrollTypesMask = UIScrollTypeMaskDiscrete;
        discreteMouseWheelRecognizer.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];
        [self addGestureRecognizer:discreteMouseWheelRecognizer];
        
        UIPanGestureRecognizer *continuousMouseWheelRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(mouseWheelMovedContinuous:)];
        continuousMouseWheelRecognizer.maximumNumberOfTouches = 0;
        continuousMouseWheelRecognizer.allowedScrollTypesMask = UIScrollTypeMaskContinuous;
        continuousMouseWheelRecognizer.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];
        [self addGestureRecognizer:continuousMouseWheelRecognizer];
    }
    
#if defined(__IPHONE_16_1) || defined(__TVOS_16_1)
    if (@available(iOS 16.1, *)) {
        UIHoverGestureRecognizer *stylusHoverRecognizer = [[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(sendStylusHoverEvent:)];
        stylusHoverRecognizer.allowedTouchTypes = @[@(UITouchTypePencil)];
        [self addGestureRecognizer:stylusHoverRecognizer];
    }
#endif
#endif
    
    x1mouse = [[X1Mouse alloc] init];
    x1mouse.delegate = self;
    
    if (settings.btMouseSupport) {
        [x1mouse start];
    }
    
    // This is critical to ensure keyboard events are delivered to this
    // StreamView and not our parent UIView, especially on tvOS.
    [self becomeFirstResponder];
}

- (void)applyTemporaryTouchModeWithAbsoluteTouchMode:(BOOL)absoluteTouchMode
                                    multiTouchScreen:(BOOL)multiTouchScreen {
#if !TARGET_OS_TV
    settings.absoluteTouchMode = absoluteTouchMode;
    settings.multiTouchScreen = multiTouchScreen;
    self.multipleTouchEnabled = YES;
    touchManager = [[TouchScreenManager alloc] init];

    if (absoluteTouchMode) {
        touchHandler = [[AbsoluteTouchHandler alloc] initWithView:self settings:settings];
    }
    else {
        touchHandler = [[RelativeTouchHandler alloc] initWithView:self settings:settings];
    }

    if (onScreenControls != nil) {
        [self applyRequestedOnScreenControlsLevel];
    }
#endif
}

- (void)resetAfterTemporaryTouchModeChange {
#if !TARGET_OS_TV
    if (isInputingText) {
        [keyInputField resignFirstResponder];
        isInputingText = NO;
    }

    [interactionTimer invalidate];
    interactionTimer = nil;
    hasUserInteracted = NO;

    lastMouseButtonMask = 0;
    lastMouseX = 0;
    lastMouseY = 0;
    lastScrollTranslation = CGPointZero;
    accumulatedMouseDeltaX = 0;
    accumulatedMouseDeltaY = 0;

    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_MIDDLE);

    [self becomeFirstResponder];
#endif
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self layoutVirtualButtonsOverlay];

    if (!CGSizeEqualToSize(lastPostedBoundsSize, self.bounds.size)) {
        [self applyRequestedOnScreenControlsLevel];
        lastPostedBoundsSize = self.bounds.size;
        [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewBoundsDidChangeNotification object:self];
    }
}

- (void)startInteractionTimer {
    // Restart user interaction tracking
    hasUserInteracted = NO;
    
    BOOL timerAlreadyRunning = interactionTimer != nil;
    
    // Start/restart the timer
    [interactionTimer invalidate];
    interactionTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                        target:self
                        selector:@selector(interactionTimerExpired:)
                        userInfo:nil
                        repeats:NO];
    
    // Notify the delegate if this was a new user interaction
    if (!timerAlreadyRunning) {
        [interactionDelegate userInteractionBegan];
    }
}

- (void)interactionTimerExpired:(NSTimer *)timer {
    if (!hasUserInteracted) {
        // User has finished touching the screen
        interactionTimer = nil;
        [interactionDelegate userInteractionEnded];
    }
    else {
        // User is still touching the screen. Restart the timer.
        [self startInteractionTimer];
    }
}

- (void) showOnScreenControls {
#if !TARGET_OS_TV
    [onScreenControls show];
#endif
}

- (OnScreenControlsLevel) getCurrentOscState {
    if (onScreenControls == nil) {
        return OnScreenControlsLevelOff;
    }
    else {
        return [onScreenControls getLevel];
    }
}

- (NSArray<NSDictionary<NSString *, id> *> *)builtInVirtualButtonDescriptors {
    return @[
        @{ @"title": @"ESC", @"primary": @[ @(0x1B) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 },
        @{ @"title": @"Tab", @"primary": @[ @(0x09) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 },
        @{ @"title": @"Enter", @"primary": @[ @(0x0D) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 },
        @{ @"title": @"Win", @"primary": @[ @(0x5B) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 },
        @{ @"title": @"Alt+Tab", @"primary": @[ @(0x12), @(0x09) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 },
        @{ @"title": @"Ctrl+Shift+Esc", @"primary": @[ @(0x11), @(0x10), @(0x1B) ], @"shape": kVirtualButtonShapeRoundedRect, @"scale": @1.0, @"widthScale": @1.0, @"heightScale": @1.0 }
    ];
}

- (NSArray<NSDictionary<NSString *, id> *> *)activeVirtualButtonDescriptors {
    if (virtualButtonDescriptors.count > 0) {
        return virtualButtonDescriptors;
    }

    return @[];
}

- (BOOL)isDirectionalVirtualButtonDescriptor:(NSDictionary<NSString *, id> *)descriptor {
    NSString *controlAction = descriptor[@"controlAction"];
    return [controlAction isKindOfClass:[NSString class]] && controlAction.length > 0;
}

- (BOOL)isJoystickDirectionalControlDescriptor:(NSDictionary<NSString *, id> *)descriptor {
    NSString *controlAction = descriptor[@"controlAction"];
    return [controlAction isKindOfClass:[NSString class]] && [controlAction hasPrefix:@"joystick_"];
}

- (void)rebuildVirtualButtonsOverlay {
    if (virtualButtonsContainerView == nil) {
        return;
    }

    for (UIView *button in virtualButtons) {
        if ([button isKindOfClass:[UIButton class]]) {
            NSTimer *scrollTimer = objc_getAssociatedObject(button, "virtualScrollTimer");
            [scrollTimer invalidate];
        }
        else if ([button isKindOfClass:[StreamVirtualDirectionalControl class]]) {
            [(StreamVirtualDirectionalControl *)button resetInteractionState];
        }
        [button removeFromSuperview];
    }

    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    [[self activeVirtualButtonDescriptors] enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id> *descriptor, NSUInteger idx, BOOL *stop) {
        UIView *controlView = nil;

        if ([self isDirectionalVirtualButtonDescriptor:descriptor]) {
            StreamVirtualDirectionalControl *directionalControl = [[StreamVirtualDirectionalControl alloc] initWithFrame:CGRectZero];
            directionalControl.translatesAutoresizingMaskIntoConstraints = NO;
            __weak typeof(self) weakSelf = self;
            directionalControl.selectionHandler = ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf == nil) { return; }
                [strongSelf selectVirtualButtonWithIdentifier:descriptor[@"id"] descriptor:descriptor];
            };
            directionalControl.directionMaskChangedHandler = ^(StreamVirtualDirectionMask previousMask, StreamVirtualDirectionMask currentMask) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf == nil) { return; }
                [strongSelf applyDirectionalControlAction:descriptor[@"controlAction"] previousMask:previousMask currentMask:currentMask];
            };
            [directionalControl configureWithDescriptor:descriptor];
            controlView = directionalControl;
        }
        else {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.52];
            button.layer.borderWidth = temporaryVirtualButtonsEditingEnabled ? 1.3f : 1.0f;
            button.clipsToBounds = YES;
            [button setTitle:descriptor[@"title"] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.titleLabel.adjustsFontSizeToFitWidth = YES;
            button.titleLabel.minimumScaleFactor = 0.60f;
            [button addTarget:self action:@selector(virtualShortcutButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            [button addTarget:self action:@selector(virtualMouseButtonPressDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(virtualMouseButtonPressRelease:) forControlEvents:UIControlEventTouchUpInside];
            [button addTarget:self action:@selector(virtualMouseButtonPressRelease:) forControlEvents:UIControlEventTouchUpOutside];
            [button addTarget:self action:@selector(virtualMouseButtonPressRelease:) forControlEvents:UIControlEventTouchCancel];
            [button addTarget:self action:@selector(virtualMouseButtonPressDown:) forControlEvents:UIControlEventTouchDragEnter];
            [button addTarget:self action:@selector(virtualMouseButtonPressRelease:) forControlEvents:UIControlEventTouchDragExit];
            [button addTarget:self action:@selector(toolbarButtonPressDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchUpInside];
            [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchUpOutside];
            [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchCancel];
            [button addTarget:self action:@selector(toolbarButtonPressDown:) forControlEvents:UIControlEventTouchDragEnter];
            [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchDragExit];
            objc_setAssociatedObject(button, "virtualPrimaryKeyCodes", descriptor[@"primary"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(button, "virtualSecondaryKeyCodes", descriptor[@"secondary"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            controlView = button;
        }

        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleVirtualButtonPan:)];
        panGestureRecognizer.enabled = temporaryVirtualButtonsEditingEnabled;
        [controlView addGestureRecognizer:panGestureRecognizer];
        objc_setAssociatedObject(controlView, "virtualIdentifier", descriptor[@"id"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [virtualButtonsContainerView addSubview:controlView];
        [buttons addObject:controlView];
    }];

    virtualButtons = [buttons copy];
    virtualButtonsContainerView.hidden = !temporaryVirtualButtonsVisible || virtualButtons.count == 0;
    [self layoutVirtualButtonsOverlay];
}

- (void)ensureVirtualButtonsOverlayIfNeeded {
    if (virtualButtonsContainerView != nil) {
        return;
    }

    virtualButtonsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    virtualButtonsContainerView.backgroundColor = [UIColor clearColor];
    virtualButtonsContainerView.hidden = YES;
    [self addSubview:virtualButtonsContainerView];
    [self rebuildVirtualButtonsOverlay];
}

- (BOOL)isCircularVirtualButtonDescriptor:(NSDictionary<NSString *, id> *)descriptor {
    NSString *shape = descriptor[@"shape"];
    return [shape isEqualToString:kVirtualButtonShapeCircle];
}

- (CGSize)virtualButtonSizeForDescriptor:(NSDictionary<NSString *, id> *)descriptor {
    BOOL isPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    CGFloat baseRoundedWidth = isPad ? 118.0f : 96.0f;
    CGFloat baseRoundedHeight = isPad ? 52.0f : 46.0f;
    CGFloat baseCircleSide = isPad ? 60.0f : 52.0f;
    CGFloat baseDirectionalSide = isPad ? 138.0f : 116.0f;

    if ([self isDirectionalVirtualButtonDescriptor:descriptor]) {
        BOOL isCircle = [self isCircularVirtualButtonDescriptor:descriptor];
        if (isCircle) {
            NSNumber *scaleNumber = descriptor[@"scale"];
            CGFloat scale = MIN(MAX(scaleNumber != nil ? scaleNumber.doubleValue : 1.0, 0.50), 2.00);
            CGFloat side = baseDirectionalSide * scale;
            return CGSizeMake(side, side);
        }

        NSNumber *widthScaleNumber = descriptor[@"widthScale"];
        NSNumber *heightScaleNumber = descriptor[@"heightScale"];
        CGFloat widthScale = MIN(MAX(widthScaleNumber != nil ? widthScaleNumber.doubleValue : 1.0, 0.50), 2.00);
        CGFloat heightScale = MIN(MAX(heightScaleNumber != nil ? heightScaleNumber.doubleValue : 1.0, 0.50), 2.00);
        return CGSizeMake(baseDirectionalSide * widthScale, baseDirectionalSide * heightScale);
    }

    if ([self isCircularVirtualButtonDescriptor:descriptor]) {
        NSNumber *scaleNumber = descriptor[@"scale"];
        CGFloat scale = MIN(MAX(scaleNumber != nil ? scaleNumber.doubleValue : 1.0, 0.50), 2.00);
        CGFloat side = baseCircleSide * scale;
        return CGSizeMake(side, side);
    }

    NSNumber *widthScaleNumber = descriptor[@"widthScale"];
    NSNumber *heightScaleNumber = descriptor[@"heightScale"];
    CGFloat widthScale = MIN(MAX(widthScaleNumber != nil ? widthScaleNumber.doubleValue : 1.0, 0.50), 2.00);
    CGFloat heightScale = MIN(MAX(heightScaleNumber != nil ? heightScaleNumber.doubleValue : 1.0, 0.50), 2.00);
    return CGSizeMake(baseRoundedWidth * widthScale, baseRoundedHeight * heightScale);
}

- (NSArray<NSNumber *> *)keyCodesForDirectionalControlAction:(NSString *)controlAction mask:(StreamVirtualDirectionMask)mask {
    if (![controlAction isKindOfClass:[NSString class]] || controlAction.length == 0 || mask == StreamVirtualDirectionMaskNone) {
        return @[];
    }

    BOOL usesWASD = [controlAction hasSuffix:@"_wasd"];
    NSNumber *up = @(usesWASD ? 0x57 : 0x26);
    NSNumber *down = @(usesWASD ? 0x53 : 0x28);
    NSNumber *left = @(usesWASD ? 0x41 : 0x25);
    NSNumber *right = @(usesWASD ? 0x44 : 0x27);
    NSMutableArray<NSNumber *> *keyCodes = [NSMutableArray array];

    if ((mask & StreamVirtualDirectionMaskUp) != 0) {
        [keyCodes addObject:up];
    }
    if ((mask & StreamVirtualDirectionMaskDown) != 0) {
        [keyCodes addObject:down];
    }
    if ((mask & StreamVirtualDirectionMaskLeft) != 0) {
        [keyCodes addObject:left];
    }
    if ((mask & StreamVirtualDirectionMaskRight) != 0) {
        [keyCodes addObject:right];
    }
    return keyCodes;
}

- (void)applyDirectionalControlAction:(NSString *)controlAction
                         previousMask:(StreamVirtualDirectionMask)previousMask
                          currentMask:(StreamVirtualDirectionMask)currentMask {
    NSArray<NSNumber *> *previousKeyCodes = [self keyCodesForDirectionalControlAction:controlAction mask:previousMask];
    NSArray<NSNumber *> *currentKeyCodes = [self keyCodesForDirectionalControlAction:controlAction mask:currentMask];

    for (NSNumber *keyCode in [previousKeyCodes reverseObjectEnumerator]) {
        if (![currentKeyCodes containsObject:keyCode]) {
            LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_UP, 0);
        }
    }

    for (NSNumber *keyCode in currentKeyCodes) {
        if (![previousKeyCodes containsObject:keyCode]) {
            LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_DOWN, 0);
        }
    }
}

- (void)selectVirtualButtonWithIdentifier:(NSString *)identifier descriptor:(NSDictionary<NSString *, id> *)descriptor {
    selectedVirtualButtonIdentifier = [identifier copy];
    [self rebuildVirtualButtonsOverlay];
    [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewVirtualButtonSelectionDidChangeNotification
                                                        object:self
                                                      userInfo:@{
                                                        @"identifier": selectedVirtualButtonIdentifier ?: @"",
                                                        @"descriptor": descriptor ?: @{}
                                                      }];
}

- (UIImage *)virtualMouseButtonImageForAction:(NSString *)mouseAction {
    NSString *assetName = nil;
    NSString *fallbackSystemName = nil;

    if ([mouseAction isEqualToString:@"mouse_left"]) {
        assetName = @"ic_mouse_left";
        fallbackSystemName = @"cursorarrow.click";
    }
    else if ([mouseAction isEqualToString:@"mouse_right"]) {
        assetName = @"ic_mouse_right";
        fallbackSystemName = @"cursorarrow.rays";
    }
    else if ([mouseAction isEqualToString:@"mouse_middle"]) {
        assetName = @"ic_mouse_middle";
        fallbackSystemName = @"circle.grid.2x1";
    }
    else if ([mouseAction isEqualToString:@"mouse_scroll_up"]) {
        assetName = @"ic_mouse_scroll_up";
        fallbackSystemName = @"arrow.up.to.line";
    }
    else if ([mouseAction isEqualToString:@"mouse_scroll_down"]) {
        assetName = @"ic_mouse_scroll_down";
        fallbackSystemName = @"arrow.down.to.line";
    }
    else if ([mouseAction isEqualToString:@"mouse_left_lock"]) {
        assetName = @"ic_mouse_left_p";
        fallbackSystemName = @"cursorarrow.click";
    }
    else if ([mouseAction isEqualToString:@"mouse_right_lock"]) {
        assetName = @"ic_mouse_right_p";
        fallbackSystemName = @"cursorarrow.rays";
    }

    UIImage *assetImage = assetName.length > 0 ? [UIImage imageNamed:assetName] : nil;
    if (assetImage != nil) {
        return [assetImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:fallbackSystemName withConfiguration:configuration];
        if (image != nil) {
            return [image imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    return nil;
}

- (int)virtualMouseButtonValueForAction:(NSString *)mouseAction {
    if ([mouseAction isEqualToString:@"mouse_left"] || [mouseAction isEqualToString:@"mouse_left_lock"]) {
        return BUTTON_LEFT;
    }
    else if ([mouseAction isEqualToString:@"mouse_right"] || [mouseAction isEqualToString:@"mouse_right_lock"]) {
        return BUTTON_RIGHT;
    }
    else if ([mouseAction isEqualToString:@"mouse_middle"]) {
        return BUTTON_MIDDLE;
    }

    return 0;
}

- (BOOL)isLockingMouseAction:(NSString *)mouseAction {
    return [mouseAction isEqualToString:@"mouse_left_lock"] || [mouseAction isEqualToString:@"mouse_right_lock"];
}

- (void)releaseLockedMouseActionsNotPresentInDescriptors:(NSArray<NSDictionary<NSString *, id> *> *)descriptors {
    NSMutableSet<NSString *> *availableActions = [NSMutableSet set];
    for (NSDictionary<NSString *, id> *descriptor in descriptors) {
        NSString *mouseAction = descriptor[@"mouseAction"];
        if ([mouseAction isKindOfClass:[NSString class]] && mouseAction.length > 0) {
            [availableActions addObject:mouseAction];
        }
    }

    for (NSString *mouseAction in [lockedMouseActionIdentifiers allObjects]) {
        if (descriptors != nil && [availableActions containsObject:mouseAction]) {
            continue;
        }

        int mouseButton = [self virtualMouseButtonValueForAction:mouseAction];
        if (mouseButton != 0) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, mouseButton);
        }
        [lockedMouseActionIdentifiers removeObject:mouseAction];
    }
}

- (void)applyAppearanceForVirtualButton:(UIButton *)button
                             descriptor:(NSDictionary<NSString *, id> *)descriptor
                                   size:(CGSize)size {
    BOOL isCircle = [self isCircularVirtualButtonDescriptor:descriptor];
    BOOL isSelected = selectedVirtualButtonIdentifier != nil && [selectedVirtualButtonIdentifier isEqualToString:descriptor[@"id"]];
    NSString *mouseAction = descriptor[@"mouseAction"];
    BOOL isMouseButton = [mouseAction isKindOfClass:[NSString class]] && mouseAction.length > 0;
    BOOL isLockedMouseButton = isMouseButton && [self isLockingMouseAction:mouseAction] && [lockedMouseActionIdentifiers containsObject:mouseAction];
    NSNumber *opacityNumber = descriptor[@"opacity"];
    CGFloat buttonOpacity = MIN(MAX(opacityNumber != nil ? opacityNumber.doubleValue : 0.52, 0.05), 1.0);
    button.layer.cornerRadius = isCircle ? size.width * 0.5f : MIN(size.height * 0.32f, 18.0f);
    CGFloat mouseInset = floor(MIN(size.width, size.height) * 0.22f);
    button.contentEdgeInsets = isMouseButton ? UIEdgeInsetsMake(mouseInset, mouseInset, mouseInset, mouseInset) : (isCircle ? UIEdgeInsetsZero : UIEdgeInsetsMake(0, 12, 0, 12));
    button.imageEdgeInsets = isMouseButton ? UIEdgeInsetsZero : UIEdgeInsetsZero;
    button.titleLabel.font = [UIFont systemFontOfSize:(isCircle ? 12.0f : 13.0f) weight:UIFontWeightSemibold];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.tintColor = [UIColor whiteColor];

    if (isMouseButton) {
        [button setTitle:nil forState:UIControlStateNormal];
        [button setImage:[self virtualMouseButtonImageForAction:mouseAction] forState:UIControlStateNormal];
    }
    else {
        [button setTitle:descriptor[@"title"] forState:UIControlStateNormal];
        [button setImage:nil forState:UIControlStateNormal];
    }

    if (temporaryVirtualButtonsEditingEnabled) {
        button.layer.borderWidth = isSelected ? 2.0f : 1.3f;
        button.layer.borderColor = (isSelected ? [UIColor colorWithRed:0.60 green:0.55 blue:0.98 alpha:1.0] : [[UIColor colorWithRed:0.50 green:0.45 blue:0.94 alpha:1.0] colorWithAlphaComponent:0.86]).CGColor;
        UIColor *editingBackgroundColor = isSelected ? [UIColor colorWithRed:0.19 green:0.19 blue:0.25 alpha:0.90] : [[UIColor blackColor] colorWithAlphaComponent:buttonOpacity];
        button.backgroundColor = editingBackgroundColor;
    }
    else {
        button.layer.borderWidth = 1.0f;
        button.layer.borderColor = (isLockedMouseButton ? [UIColor colorWithRed:0.60 green:0.55 blue:0.98 alpha:0.94] : [[UIColor whiteColor] colorWithAlphaComponent:0.14]).CGColor;
        button.backgroundColor = isLockedMouseButton ? [UIColor colorWithRed:0.22 green:0.20 blue:0.33 alpha:0.94] : [[UIColor blackColor] colorWithAlphaComponent:buttonOpacity];
    }
}

- (void)layoutVirtualButtonsOverlay {
    if (virtualButtonsContainerView == nil) {
        return;
    }

    if (virtualButtons.count == 0) {
        virtualButtonsContainerView.frame = CGRectZero;
        return;
    }

    CGFloat defaultButtonWidth = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 118.0f : 96.0f;
    CGFloat defaultButtonHeight = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 52.0f : 46.0f;
    CGFloat horizontalSpacing = 10.0f;
    CGFloat verticalSpacing = 10.0f;
    NSInteger columnCount = 2;
    NSInteger rowCount = (NSInteger)ceil((double)virtualButtons.count / (double)columnCount);

    CGFloat safeTop = 0.0f;
    CGFloat safeBottom = 0.0f;
    CGFloat safeLeft = 0.0f;
    CGFloat safeRight = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeTop = self.safeAreaInsets.top;
        safeBottom = self.safeAreaInsets.bottom;
        safeLeft = self.safeAreaInsets.left;
        safeRight = self.safeAreaInsets.right;
    }

    virtualButtonsContainerView.frame = self.bounds;

    [virtualButtons enumerateObjectsUsingBlock:^(UIView *button, NSUInteger idx, BOOL *stop) {
        NSDictionary<NSString *, id> *descriptor = idx < self->virtualButtonDescriptors.count ? self->virtualButtonDescriptors[idx] : nil;
        CGSize buttonSize = [self virtualButtonSizeForDescriptor:descriptor ?: @{}];
        CGFloat buttonWidth = buttonSize.width;
        CGFloat buttonHeight = buttonSize.height;
        CGFloat minCenterX = safeLeft + 12.0f + buttonWidth * 0.5f;
        CGFloat maxCenterX = CGRectGetWidth(self.bounds) - safeRight - 12.0f - buttonWidth * 0.5f;
        CGFloat minCenterY = safeTop + 12.0f + buttonHeight * 0.5f;
        CGFloat maxCenterY = CGRectGetHeight(self.bounds) - safeBottom - 20.0f - buttonHeight * 0.5f;

        CGFloat centerX = 0.0f;
        CGFloat centerY = 0.0f;
        NSNumber *storedX = descriptor[@"xRatio"];
        NSNumber *storedY = descriptor[@"yRatio"];
        if (storedX != nil && storedY != nil) {
            centerX = minCenterX + (maxCenterX - minCenterX) * MIN(MAX(storedX.doubleValue, 0.0), 1.0);
            centerY = minCenterY + (maxCenterY - minCenterY) * MIN(MAX(storedY.doubleValue, 0.0), 1.0);
        }
        else {
            NSInteger row = (NSInteger)idx / columnCount;
            NSInteger column = (NSInteger)idx % columnCount;
            CGFloat containerWidth = columnCount * defaultButtonWidth + (columnCount - 1) * horizontalSpacing;
            CGFloat containerHeight = rowCount * defaultButtonHeight + MAX(rowCount - 1, 0) * verticalSpacing;
            CGFloat originX = MAX(safeLeft + 12.0f, CGRectGetWidth(self.bounds) - safeRight - 16.0f - containerWidth) + column * (defaultButtonWidth + horizontalSpacing);
            CGFloat originY = MAX(safeTop + 12.0f, CGRectGetHeight(self.bounds) - safeBottom - 24.0f - containerHeight) + row * (defaultButtonHeight + verticalSpacing);
            centerX = originX + buttonWidth * 0.5f;
            centerY = originY + buttonHeight * 0.5f;
            [self updateVirtualButtonDescriptorAtIndex:idx center:CGPointMake(centerX, centerY) buttonSize:CGSizeMake(buttonWidth, buttonHeight) notify:NO];
        }

        button.bounds = CGRectMake(0, 0, buttonWidth, buttonHeight);
        if ([button isKindOfClass:[UIButton class]]) {
            [self applyAppearanceForVirtualButton:(UIButton *)button descriptor:descriptor ?: @{} size:buttonSize];
            objc_setAssociatedObject(button, "virtualMouseAction", descriptor[@"mouseAction"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        else if ([button isKindOfClass:[StreamVirtualDirectionalControl class]]) {
            StreamVirtualDirectionalControl *directionalControl = (StreamVirtualDirectionalControl *)button;
            directionalControl.editingEnabled = self->temporaryVirtualButtonsEditingEnabled;
            directionalControl.selectedForEditing = selectedVirtualButtonIdentifier != nil && [selectedVirtualButtonIdentifier isEqualToString:descriptor[@"id"]];
            directionalControl.controlOpacity = MIN(MAX([descriptor[@"opacity"] doubleValue], 0.05), 1.0);
            [directionalControl configureWithDescriptor:descriptor ?: @{}];
        }
        button.center = CGPointMake(MIN(MAX(centerX, minCenterX), maxCenterX),
                                    MIN(MAX(centerY, minCenterY), maxCenterY));
        button.alpha = temporaryVirtualButtonsEditingEnabled ? 0.98f : 1.0f;
    }];

    [self bringSubviewToFront:virtualButtonsContainerView];
}

- (void)virtualShortcutButtonTapped:(UIButton *)sender {
    if (temporaryVirtualButtonsEditingEnabled) {
        NSString *identifier = objc_getAssociatedObject(sender, "virtualIdentifier");
        NSUInteger index = [virtualButtons indexOfObject:sender];
        NSDictionary *descriptor = index != NSNotFound && index < virtualButtonDescriptors.count ? virtualButtonDescriptors[index] : nil;
        [self selectVirtualButtonWithIdentifier:identifier descriptor:descriptor];
        return;
    }

    NSString *mouseAction = objc_getAssociatedObject(sender, "virtualMouseAction");
    if ([mouseAction isKindOfClass:[NSString class]] && [self isLockingMouseAction:mouseAction]) {
        int mouseButton = [self virtualMouseButtonValueForAction:mouseAction];
        if (mouseButton == 0) {
            return;
        }

        if ([lockedMouseActionIdentifiers containsObject:mouseAction]) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, mouseButton);
            [lockedMouseActionIdentifiers removeObject:mouseAction];
        }
        else {
            LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, mouseButton);
            [lockedMouseActionIdentifiers addObject:mouseAction];
        }
        [self rebuildVirtualButtonsOverlay];
    }
}

- (void)virtualMouseButtonPressDown:(UIButton *)sender {
    if (temporaryVirtualButtonsEditingEnabled) {
        return;
    }

    NSString *mouseAction = objc_getAssociatedObject(sender, "virtualMouseAction");
    if ([mouseAction isKindOfClass:[NSString class]] && mouseAction.length > 0) {
        if ([self isLockingMouseAction:mouseAction]) {
            return;
        }
        if ([mouseAction isEqualToString:@"mouse_scroll_up"] || [mouseAction isEqualToString:@"mouse_scroll_down"]) {
            NSTimer *existingTimer = objc_getAssociatedObject(sender, "virtualScrollTimer");
            if (existingTimer != nil) {
                return;
            }

            LiSendScrollEvent([mouseAction isEqualToString:@"mouse_scroll_up"] ? 1 : -1);
            NSTimer *scrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.10
                                                                    target:self
                                                                  selector:@selector(virtualScrollTimerFired:)
                                                                  userInfo:@{
                                                                    @"mouseAction": mouseAction,
                                                                    @"button": sender
                                                                  }
                                                                   repeats:YES];
            objc_setAssociatedObject(sender, "virtualScrollTimer", scrollTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        NSNumber *isPressedNumber = objc_getAssociatedObject(sender, "virtualMousePressed");
        if (isPressedNumber.boolValue) {
            return;
        }

        int mouseButton = [self virtualMouseButtonValueForAction:mouseAction];

        if (mouseButton == 0) {
            return;
        }

        objc_setAssociatedObject(sender, "virtualMousePressed", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, mouseButton);
        return;
    }

    NSNumber *isPressedNumber = objc_getAssociatedObject(sender, "virtualKeyboardPressed");
    if (isPressedNumber.boolValue) {
        return;
    }

    NSArray<NSNumber *> *primaryKeyCodes = objc_getAssociatedObject(sender, "virtualPrimaryKeyCodes");
    if (![primaryKeyCodes isKindOfClass:[NSArray class]] || primaryKeyCodes.count == 0) {
        return;
    }

    for (NSNumber *keyCode in primaryKeyCodes) {
        LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_DOWN, 0);
    }
    objc_setAssociatedObject(sender, "virtualKeyboardPressed", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)virtualMouseButtonPressRelease:(UIButton *)sender {
    NSString *mouseAction = objc_getAssociatedObject(sender, "virtualMouseAction");
    if ([mouseAction isKindOfClass:[NSString class]] && mouseAction.length > 0) {
        if ([self isLockingMouseAction:mouseAction]) {
            return;
        }
        if ([mouseAction isEqualToString:@"mouse_scroll_up"] || [mouseAction isEqualToString:@"mouse_scroll_down"]) {
            NSTimer *scrollTimer = objc_getAssociatedObject(sender, "virtualScrollTimer");
            [scrollTimer invalidate];
            objc_setAssociatedObject(sender, "virtualScrollTimer", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        NSNumber *isPressedNumber = objc_getAssociatedObject(sender, "virtualMousePressed");
        if (!isPressedNumber.boolValue) {
            return;
        }

        int mouseButton = [self virtualMouseButtonValueForAction:mouseAction];

        if (mouseButton != 0) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, mouseButton);
        }
        objc_setAssociatedObject(sender, "virtualMousePressed", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSNumber *isPressedNumber = objc_getAssociatedObject(sender, "virtualKeyboardPressed");
    if (!isPressedNumber.boolValue) {
        return;
    }

    NSArray<NSNumber *> *primaryKeyCodes = objc_getAssociatedObject(sender, "virtualPrimaryKeyCodes");
    for (NSNumber *keyCode in [primaryKeyCodes reverseObjectEnumerator]) {
        LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_UP, 0);
    }
    objc_setAssociatedObject(sender, "virtualKeyboardPressed", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)virtualScrollTimerFired:(NSTimer *)timer {
    NSDictionary *userInfo = timer.userInfo;
    NSString *mouseAction = userInfo[@"mouseAction"];
    UIButton *button = userInfo[@"button"];
    if (![button isKindOfClass:[UIButton class]]) {
        [timer invalidate];
        return;
    }

    if (![mouseAction isKindOfClass:[NSString class]] || mouseAction.length == 0) {
        [timer invalidate];
        objc_setAssociatedObject(button, "virtualScrollTimer", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    LiSendScrollEvent([mouseAction isEqualToString:@"mouse_scroll_up"] ? 1 : -1);
}

- (void)handleVirtualButtonPan:(UIPanGestureRecognizer *)gestureRecognizer {
#if !TARGET_OS_TV
    if (!temporaryVirtualButtonsEditingEnabled) {
        return;
    }

    UIView *button = gestureRecognizer.view;
    if (![button isKindOfClass:[UIView class]]) {
        return;
    }

    CGPoint translation = [gestureRecognizer translationInView:virtualButtonsContainerView];
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged || gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGFloat buttonWidth = CGRectGetWidth(button.bounds);
        CGFloat buttonHeight = CGRectGetHeight(button.bounds);
        CGFloat safeTop = 0.0f;
        CGFloat safeBottom = 0.0f;
        CGFloat safeLeft = 0.0f;
        CGFloat safeRight = 0.0f;
        if (@available(iOS 11.0, *)) {
            safeTop = self.safeAreaInsets.top;
            safeBottom = self.safeAreaInsets.bottom;
            safeLeft = self.safeAreaInsets.left;
            safeRight = self.safeAreaInsets.right;
        }

        CGFloat minCenterX = safeLeft + 12.0f + buttonWidth * 0.5f;
        CGFloat maxCenterX = CGRectGetWidth(self.bounds) - safeRight - 12.0f - buttonWidth * 0.5f;
        CGFloat minCenterY = safeTop + 12.0f + buttonHeight * 0.5f;
        CGFloat maxCenterY = CGRectGetHeight(self.bounds) - safeBottom - 20.0f - buttonHeight * 0.5f;

        CGPoint center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
        center.x = MIN(MAX(center.x, minCenterX), maxCenterX);
        center.y = MIN(MAX(center.y, minCenterY), maxCenterY);
        button.center = center;
        [gestureRecognizer setTranslation:CGPointZero inView:virtualButtonsContainerView];

        NSUInteger index = [virtualButtons indexOfObject:button];
        if (index != NSNotFound) {
            [self updateVirtualButtonDescriptorAtIndex:index center:center buttonSize:CGSizeMake(buttonWidth, buttonHeight) notify:(gestureRecognizer.state == UIGestureRecognizerStateEnded)];
        }
    }
#endif
}

- (void)updateVirtualButtonDescriptorAtIndex:(NSUInteger)index center:(CGPoint)center buttonSize:(CGSize)buttonSize notify:(BOOL)notify {
    if (index >= virtualButtonDescriptors.count) {
        return;
    }

    CGFloat safeTop = 0.0f;
    CGFloat safeBottom = 0.0f;
    CGFloat safeLeft = 0.0f;
    CGFloat safeRight = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeTop = self.safeAreaInsets.top;
        safeBottom = self.safeAreaInsets.bottom;
        safeLeft = self.safeAreaInsets.left;
        safeRight = self.safeAreaInsets.right;
    }

    CGFloat minCenterX = safeLeft + 12.0f + buttonSize.width * 0.5f;
    CGFloat maxCenterX = CGRectGetWidth(self.bounds) - safeRight - 12.0f - buttonSize.width * 0.5f;
    CGFloat minCenterY = safeTop + 12.0f + buttonSize.height * 0.5f;
    CGFloat maxCenterY = CGRectGetHeight(self.bounds) - safeBottom - 20.0f - buttonSize.height * 0.5f;
    CGFloat widthRange = MAX(maxCenterX - minCenterX, 1.0f);
    CGFloat heightRange = MAX(maxCenterY - minCenterY, 1.0f);
    CGFloat xRatio = MIN(MAX((center.x - minCenterX) / widthRange, 0.0f), 1.0f);
    CGFloat yRatio = MIN(MAX((center.y - minCenterY) / heightRange, 0.0f), 1.0f);

    NSMutableArray *updatedDescriptors = [virtualButtonDescriptors mutableCopy];
    NSMutableDictionary *updatedDescriptor = [virtualButtonDescriptors[index] mutableCopy];
    updatedDescriptor[@"xRatio"] = @(xRatio);
    updatedDescriptor[@"yRatio"] = @(yRatio);
    updatedDescriptors[index] = updatedDescriptor;
    virtualButtonDescriptors = [updatedDescriptors copy];

    if (notify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewVirtualButtonsDidChangeNotification object:self userInfo:@{ @"descriptors": virtualButtonDescriptors ?: @[] }];
    }
}

- (void)setTemporaryVirtualButtonsVisible:(BOOL)visible {
#if !TARGET_OS_TV
    [self ensureVirtualButtonsOverlayIfNeeded];
    temporaryVirtualButtonsVisible = visible;
    if (!visible) {
        [self releaseLockedMouseActionsNotPresentInDescriptors:nil];
        for (UIView *button in virtualButtons) {
            if ([button isKindOfClass:[StreamVirtualDirectionalControl class]]) {
                [(StreamVirtualDirectionalControl *)button resetInteractionState];
            }
        }
    }
    virtualButtonsContainerView.hidden = !visible || virtualButtons.count == 0;
    if (visible && virtualButtons.count > 0) {
        [self layoutVirtualButtonsOverlay];
        [self bringSubviewToFront:virtualButtonsContainerView];
    }
#endif
}

- (void)setTemporaryVirtualButtonDescriptors:(NSArray<NSDictionary<NSString *,id> *> *)descriptors {
#if !TARGET_OS_TV
    virtualButtonDescriptors = [descriptors copy] ?: @[];
    [self releaseLockedMouseActionsNotPresentInDescriptors:virtualButtonDescriptors];
    if (virtualButtonsContainerView != nil) {
        [self rebuildVirtualButtonsOverlay];
    }
#endif
}

- (BOOL)isTemporaryVirtualButtonsVisible {
    return temporaryVirtualButtonsVisible;
}

- (void)setTemporaryVirtualButtonsEditingEnabled:(BOOL)enabled {
#if !TARGET_OS_TV
    temporaryVirtualButtonsEditingEnabled = enabled;
    [self ensureVirtualButtonsOverlayIfNeeded];
    if (enabled) {
        temporaryVirtualButtonsVisible = YES;
    }
    else {
        selectedVirtualButtonIdentifier = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewVirtualButtonSelectionDidChangeNotification
                                                            object:self
                                                          userInfo:@{
                                                            @"identifier": @"",
                                                            @"descriptor": @{}
                                                          }];
    }
    [self rebuildVirtualButtonsOverlay];
#endif
}

- (BOOL)isTemporaryVirtualButtonsEditingEnabled {
    return temporaryVirtualButtonsEditingEnabled;
}

- (NSArray<NSDictionary<NSString *,id> *> *)currentTemporaryVirtualButtonDescriptors {
    return [virtualButtonDescriptors copy] ?: @[];
}

- (void)setTemporaryVirtualGamepadVisible:(BOOL)visible {
#if !TARGET_OS_TV
    if (onScreenControls == nil) {
        return;
    }

    [controllerSupport setOscEnabledForCurrentSession:visible];
    requestedOnScreenControlsLevel = OnScreenControlsLevelOff;
    if (visible) {
        OSCProfile *selectedProfile = [[OSCProfilesManager sharedManager] getSelectedProfile];
        requestedOnScreenControlsLevel = (selectedProfile != nil) ? OnScreenControlsCustom : OnScreenControlsLevelFull;
    }

    [self applyRequestedOnScreenControlsLevel];
#endif
}

- (void)setTemporaryOnScreenControlsLevel:(OnScreenControlsLevel)level {
#if !TARGET_OS_TV
    if (onScreenControls == nil) {
        return;
    }

    [controllerSupport setOscEnabledForCurrentSession:(level != OnScreenControlsLevelOff)];
    requestedOnScreenControlsLevel = level;
    [self applyRequestedOnScreenControlsLevel];
#endif
}

- (void)setVideoAlignmentMode:(StreamViewVideoAlignmentMode)alignmentMode {
    if (videoAlignmentMode == alignmentMode) {
        return;
    }

    videoAlignmentMode = alignmentMode;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewBoundsDidChangeNotification object:self];
}

- (StreamViewVideoAlignmentMode)videoAlignmentMode {
    return videoAlignmentMode;
}

- (void)setVideoAlignmentMargin:(CGFloat)alignmentMargin {
    CGFloat clampedMargin = MAX(0.0f, MIN(alignmentMargin, 150.0f));
    if (videoAlignmentMargin == clampedMargin) {
        return;
    }

    videoAlignmentMargin = clampedMargin;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [[NSNotificationCenter defaultCenter] postNotificationName:StreamViewBoundsDidChangeNotification object:self];
}

- (CGFloat)videoAlignmentMargin {
    return videoAlignmentMargin;
}

- (void)setViewOnlyModeEnabled:(BOOL)enabled {
    viewOnlyModeEnabled = enabled;
}

- (BOOL)isViewOnlyModeEnabled {
    return viewOnlyModeEnabled;
}

- (CGSize) getVideoAreaSize {
    if (self.bounds.size.width > self.bounds.size.height * streamAspectRatio) {
        return CGSizeMake(self.bounds.size.height * streamAspectRatio, self.bounds.size.height);
    } else {
        return CGSizeMake(self.bounds.size.width, self.bounds.size.width / streamAspectRatio);
    }
}

- (CGPoint)getVideoOriginForCurrentAlignment {
    CGSize videoSize = [self getVideoAreaSize];
    CGFloat originX = self.bounds.size.width / 2 - videoSize.width / 2;
    CGFloat originY = self.bounds.size.height / 2 - videoSize.height / 2;
    CGFloat availableVerticalPadding = MAX(self.bounds.size.height - videoSize.height, 0.0f);
    CGFloat clampedMargin = MIN(videoAlignmentMargin, availableVerticalPadding);

    if (videoSize.height < self.bounds.size.height) {
        switch (videoAlignmentMode) {
            case StreamViewVideoAlignmentModeTop:
                originY = clampedMargin;
                break;
            case StreamViewVideoAlignmentModeBottom:
                originY = self.bounds.size.height - videoSize.height - clampedMargin;
                break;
            case StreamViewVideoAlignmentModeCenter:
            default:
                break;
        }
    }

    return CGPointMake(originX, originY);
}

- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point {
    // These are now relative to the StreamView, however we need to scale them
    // further to make them relative to the actual video portion.
    float x = point.x - self.bounds.origin.x;
    float y = point.y - self.bounds.origin.y;
    
    // For some reason, we don't seem to always get to the bounds of the window
    // so we'll subtract 1 pixel if we're to the left/below of the origin and
    // and add 1 pixel if we're to the right/above. It should be imperceptible
    // to the user but it will allow activation of gestures that require contact
    // with the edge of the screen (like Aero Snap).
    if (x < self.bounds.size.width / 2) {
        x--;
    }
    else {
        x++;
    }
    if (y < self.bounds.size.height / 2) {
        y--;
    }
    else {
        y++;
    }
    
    // This logic mimics what iOS does with AVLayerVideoGravityResizeAspect
    CGSize videoSize = [self getVideoAreaSize];
    CGPoint videoOrigin = [self getVideoOriginForCurrentAlignment];
    
    // Confine the cursor to the video region. We don't just discard events outside
    // the region because we won't always get one exactly when the mouse leaves the region.
    return CGPointMake(MIN(MAX(x, videoOrigin.x), videoOrigin.x + videoSize.width) - videoOrigin.x,
                       MIN(MAX(y, videoOrigin.y), videoOrigin.y + videoSize.height) - videoOrigin.y);
}

#if !TARGET_OS_TV

- (uint16_t)getRotationFromAzimuthAngle:(float)azimuthAngle {
    // iOS reports azimuth of 0 when the stylus is pointing west, but Moonlight expects
    // rotation of 0 to mean the stylus is pointing north. Rotate the azimuth angle
    // clockwise by 90 degrees to convert from iOS to Moonlight rotation conventions.
    int32_t rotationAngle = (azimuthAngle - M_PI_2) * (180.f / M_PI);
    if (rotationAngle < 0) {
        rotationAngle += 360;
    }
    return (uint16_t)rotationAngle;
}

- (uint8_t)getTiltFromAltitudeAngle:(float)altitudeAngle {
    // iOS reports an altitude of 0 when the stylus is parallel to the touch surface,
    // while Moonlight expects a tilt of 0 when the stylus is perpendicular to the surface.
    // Subtract the tilt angle from 90 to convert from iOS to Moonlight tilt conventions.
    uint8_t altitudeDegs = abs((int16_t)(altitudeAngle * (180.f / M_PI)));
    return 90 - MIN(90, altitudeDegs);
}

- (BOOL)trySendTouchEvent:(UITouch*)event{
    uint8_t type;
    uint32_t touchID;
    switch (event.phase) {
        case UITouchPhaseBegan://开始触摸
            type = LI_TOUCH_EVENT_DOWN;
            touchID= [touchManager identifierForTouch:event];
            break;
        case UITouchPhaseMoved://移动
            type = LI_TOUCH_EVENT_MOVE;
            touchID= [touchManager identifierForTouch:event];
            break;
        case UITouchPhaseEnded://触摸结束
            type = LI_TOUCH_EVENT_UP;
            touchID= [touchManager identifierForTouch:event];
            [touchManager removeTouch:event];
            break;
        case UITouchPhaseCancelled://触摸取消
            type = LI_TOUCH_EVENT_CANCEL_ALL;
            touchID= [touchManager identifierForTouch:event];
            [touchManager removeTouch:event];
//            NSLog(@"trySendTouchEvent UITouchPhaseCancelled %d,%d",(uint32_t)UITouchPhaseCancelled,(uint32_t)event);
            break;
        default:
//            NSLog(@"trySendTouchEvent %ld,%d",(long)event.phase,(uint32_t)event);
            return NO;
    }
    CGPoint location = [self adjustCoordinatesForVideoArea:[event locationInView:self]];
    //触控灵敏度
    if(enableTouchSensitivity&&touchSensitivity!=100.0){
        location=[self getStreamViewRelativeSensitivityXY:event touchID:touchID];
    }
    CGSize videoSize = [self getVideoAreaSize];
//    NSLog(@"trySendTouchEvent touchID %d,%d",type,touchID);
//    uint32_t pointerId = [self crc32OfUint64:((uint64_t)event)];
    return LiSendTouchEvent(type,touchID,location.x / videoSize.width, location.y / videoSize.height,(event.force / event.maximumPossibleForce) / sin(event.altitudeAngle),0.0f, 0.0f,[self getRotationFromAzimuthAngle:[event azimuthAngleInView:self]]);
}


- (BOOL)sendStylusEvent:(UITouch*)event {
    uint8_t type;
    
    // Don't touch stylus events if the host doesn't support them. We want to pass
    // them as normal touches for legacy hosts that don't understand pen events.
    if (!(LiGetHostFeatureFlags() & LI_FF_PEN_TOUCH_EVENTS)) {
        return NO;
    }
    
    switch (event.phase) {
        case UITouchPhaseBegan:
            type = LI_TOUCH_EVENT_DOWN;
            break;
        case UITouchPhaseMoved:
            type = LI_TOUCH_EVENT_MOVE;
            break;
        case UITouchPhaseEnded:
            type = LI_TOUCH_EVENT_UP;
            break;
        case UITouchPhaseCancelled:
            type = LI_TOUCH_EVENT_CANCEL;
            break;
        default:
            return YES;
    }

    CGPoint location = [self adjustCoordinatesForVideoArea:[event locationInView:self]];
    CGSize videoSize = [self getVideoAreaSize];
    
    return LiSendPenEvent(type, LI_TOOL_TYPE_PEN, 0, location.x / videoSize.width, location.y / videoSize.height,
                          (event.force / event.maximumPossibleForce) / sin(event.altitudeAngle),
                          0.0f, 0.0f,
                          [self getRotationFromAzimuthAngle:[event azimuthAngleInView:self]],
                          [self getTiltFromAltitudeAngle:event.altitudeAngle]) != LI_ERR_UNSUPPORTED;
}

- (void)sendStylusHoverEvent:(UIHoverGestureRecognizer*)gesture API_AVAILABLE(ios(13.0)) {
    uint8_t type;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            type = LI_TOUCH_EVENT_HOVER;
            break;

        case UIGestureRecognizerStateEnded:
            type = LI_TOUCH_EVENT_HOVER_LEAVE;
            break;

        default:
            return;
    }

    CGPoint location = [self adjustCoordinatesForVideoArea:[gesture locationInView:self]];
    CGSize videoSize = [self getVideoAreaSize];
    
    float distance = 0.0f;
#if defined(__IPHONE_16_1) || defined(__TVOS_16_1)
    if (@available(iOS 16.1, *)) {
        distance = gesture.zOffset;
    }
#endif
    
    uint16_t rotationAngle = LI_ROT_UNKNOWN;
    uint8_t tiltAngle = LI_TILT_UNKNOWN;
#if defined(__IPHONE_16_4) || defined(__TVOS_16_4)
    if (@available(iOS 16.4, *)) {
        rotationAngle = [self getRotationFromAzimuthAngle:[gesture azimuthAngleInView:self]];
        tiltAngle = [self getTiltFromAltitudeAngle:gesture.altitudeAngle];
    }
#endif
    
    LiSendPenEvent(type, LI_TOOL_TYPE_PEN, 0, location.x / videoSize.width, location.y / videoSize.height,
                   distance, 0.0f, 0.0f, rotationAngle, tiltAngle);
}

#endif

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (viewOnlyModeEnabled) {
        [super touchesBegan:touches withEvent:event];
        return;
    }

    if ([self handleMouseButtonEvent:BUTTON_ACTION_PRESS
                          forTouches:touches
                           withEvent:event]) {
        // If it's a mouse event, we're done
        return;
    }
    
    Log(LOG_D, @"Touch down");
    
    // Notify of user interaction and start expiration timer
    [self startInteractionTimer];
    
#if !TARGET_OS_TV
    for (UITouch* touch in touches) {
        if (@available(iOS 13.4, *)) {
            if(touch.type == UITouchTypePencil){
                if ([self sendStylusEvent:touch]) {
                    return;
                }
            }
        }
        if (settings.multiTouchScreen) {
            if([self trySendTouchEvent:touch]){
                return;
            }
        }
    }
#endif
    
    if (![onScreenControls handleTouchDownEvent:touches]) {
        // We still inform the touch handler even if we're going trigger the
        // keyboard activation gesture. This is important to ensure the touch
        // handler has a consistent view of touch events to correctly suppress
        // activation of one or two finger gestures when a three finger gesture
        // is triggered.
        [touchHandler touchesBegan:touches withEvent:event];
        
        if ([[event allTouches] count] == 5) {
            [self showKeyInputBoard];
        }
    }
}

-(void)showKeyInputBoard{
    if (isInputingText) {
        Log(LOG_D, @"Closing the keyboard");
        [keyInputField resignFirstResponder];
        isInputingText = false;
    } else {
        Log(LOG_D, @"Opening the keyboard");
        // Prepare the textbox used to capture keyboard events.
        keyInputField.delegate = self;
        keyInputField.text = @"0";
#if !TARGET_OS_TV
        // Prepare the toolbar above the keyboard for more options
        const BOOL isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
        const CGFloat BUTTON_HEIGHT = isPad ? 44.0 : 38.0;
        const CGFloat FUNCTION_BUTTON_WIDTH = isPad ? 72.0 : 54.0;
        const CGFloat DONE_BUTTON_WIDTH = isPad ? 72.0 : 52.0;
        const CGFloat BUTTON_SPACING = isPad ? 6.0 : 4.0;
        const CGFloat ACCESSORY_OUTER_HORIZONTAL_PADDING = isPad ? 10.0 : 8.0;
        const CGFloat ACCESSORY_OUTER_VERTICAL_PADDING = isPad ? 8.0 : 6.0;
        // Function key count except for the `Done` button. `Done` button is not in the scrollView, but is always on top.
        const CGFloat FUNCTION_KEY_COUNT = 23;
        const CGFloat TOOLBAR_WIDTH = (FUNCTION_BUTTON_WIDTH * FUNCTION_KEY_COUNT) + (BUTTON_SPACING * (FUNCTION_KEY_COUNT - 1));
        
        // Function toolbar
        UIButton *doneButton = [self createToolbarIconButtonWithSystemName:@"xmark"
                                                                buttonWidth:DONE_BUTTON_WIDTH
                                                               buttonHeight:BUTTON_HEIGHT
                                                                     target:self
                                                                     action:@selector(toolbarButtonClicked:)
                                                                    keyCode:0x00
                                                               isToggleable:NO];
        NSArray<UIButton *> *functionButtons = @[
            [self createToolbarTextButtonWithTitle:@"Win" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x5B isToggleable:YES],
            [self createToolbarTextButtonWithTitle:@"Esc" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x1B isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"Tab" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x09 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"Shift" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0xA0 isToggleable:YES],
            [self createToolbarTextButtonWithTitle:@"Ctrl" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0xA2 isToggleable:YES],
            [self createToolbarTextButtonWithTitle:@"Alt" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0xA4 isToggleable:YES],
            [self createToolbarTextButtonWithTitle:@"Del" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x2E isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"←" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x25 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"↓" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x28 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"↑" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x26 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"→" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x27 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F1" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x70 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F2" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x71 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F3" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x72 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F4" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x73 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F5" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x74 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F6" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x75 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F7" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x76 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F8" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x77 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F9" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x78 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F10" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x79 isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F11" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x7A isToggleable:NO],
            [self createToolbarTextButtonWithTitle:@"F12" buttonWidth:FUNCTION_BUTTON_WIDTH buttonHeight:BUTTON_HEIGHT target:self action:@selector(toolbarButtonClicked:) keyCode:0x7B isToggleable:NO]
        ];
        
        UIStackView *functionButtonStackView = [[UIStackView alloc] init];
        functionButtonStackView.axis = UILayoutConstraintAxisHorizontal;
        functionButtonStackView.alignment = UIStackViewAlignmentFill;
        functionButtonStackView.distribution = UIStackViewDistributionFill;
        functionButtonStackView.spacing = BUTTON_SPACING;
        functionButtonStackView.translatesAutoresizingMaskIntoConstraints = NO;
        for (UIButton *functionButton in functionButtons) {
            [functionButtonStackView addArrangedSubview:functionButton];
        }
        
        KeyboardAccessoryScrollView *scrollView = [[KeyboardAccessoryScrollView alloc] initWithFrame:CGRectZero];
        scrollView.autoresizingMask = UIViewAutoresizingNone;
        scrollView.scrollEnabled = YES;
        scrollView.alwaysBounceHorizontal = YES;
        scrollView.delaysContentTouches = YES;
        scrollView.canCancelContentTouches = YES;
        scrollView.bounces = false;
        scrollView.bouncesZoom = false;
        scrollView.showsVerticalScrollIndicator = false;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        [scrollView setBackgroundColor:[UIColor clearColor]];
        
        [scrollView addSubview:functionButtonStackView];
        
        UIView *accessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, BUTTON_HEIGHT + ACCESSORY_OUTER_VERTICAL_PADDING * 2.0)];
        accessoryView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
        
        doneButton.translatesAutoresizingMaskIntoConstraints = NO;
        scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [accessoryView addSubview:doneButton];
        [accessoryView addSubview:scrollView];
        
        [NSLayoutConstraint activateConstraints:@[
            [doneButton.leadingAnchor constraintEqualToAnchor:accessoryView.leadingAnchor constant:ACCESSORY_OUTER_HORIZONTAL_PADDING],
            [doneButton.topAnchor constraintEqualToAnchor:accessoryView.topAnchor constant:ACCESSORY_OUTER_VERTICAL_PADDING],
            [doneButton.bottomAnchor constraintEqualToAnchor:accessoryView.bottomAnchor constant:-ACCESSORY_OUTER_VERTICAL_PADDING],
            
            [scrollView.leadingAnchor constraintEqualToAnchor:doneButton.trailingAnchor constant:BUTTON_SPACING],
            [scrollView.trailingAnchor constraintEqualToAnchor:accessoryView.trailingAnchor constant:-ACCESSORY_OUTER_HORIZONTAL_PADDING],
            [scrollView.topAnchor constraintEqualToAnchor:accessoryView.topAnchor constant:ACCESSORY_OUTER_VERTICAL_PADDING],
            [scrollView.bottomAnchor constraintEqualToAnchor:accessoryView.bottomAnchor constant:-ACCESSORY_OUTER_VERTICAL_PADDING],
            
            [functionButtonStackView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
            [functionButtonStackView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
            [functionButtonStackView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
            [functionButtonStackView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
            [functionButtonStackView.heightAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor],
            [functionButtonStackView.widthAnchor constraintEqualToConstant:TOOLBAR_WIDTH]
        ]];
        
        scrollView.contentSize = CGSizeMake(TOOLBAR_WIDTH, BUTTON_HEIGHT);
        
        keyInputField.inputAccessoryView = accessoryView;
#endif
        [keyInputField becomeFirstResponder];
        [keyInputField addTarget:self action:@selector(onKeyboardPressed:) forControlEvents:UIControlEventEditingChanged];
        
        // Undo causes issues for our state management, so turn it off
        [keyInputField.undoManager disableUndoRegistration];
        
        isInputingText = true;
    }
}

- (UIButton *)createToolbarButtonWithTitle:(NSString *)title
                               systemImage:(NSString *)systemImageName
                               buttonWidth:(CGFloat)buttonWidth
                              buttonHeight:(CGFloat)buttonHeight
                                    target:(id)target
                                    action:(SEL)action
                                   keyCode:(NSInteger)keyCode
                              isToggleable:(BOOL)isToggleable {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.layer.cornerRadius = 10.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    button.clipsToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    if (title.length > 0) {
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    }
    if (systemImageName.length > 0) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:systemImageName withConfiguration:configuration];
        [button setImage:image forState:UIControlStateNormal];
        [button setTintColor:[UIColor whiteColor]];
    }
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(toolbarButtonPressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchCancel];
    [button addTarget:self action:@selector(toolbarButtonPressDown:) forControlEvents:UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(toolbarButtonPressRelease:) forControlEvents:UIControlEventTouchDragExit];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:buttonWidth],
        [button.heightAnchor constraintEqualToConstant:buttonHeight]
    ]];
    UIColor *baseBackgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    if (keyCode == 0x00) {
        baseBackgroundColor = [UIColor colorWithRed:0.89 green:0.49 blue:0.52 alpha:0.98];
        button.layer.borderColor = [UIColor colorWithRed:1.0 green:0.90 blue:0.90 alpha:0.34].CGColor;
    }
    button.backgroundColor = baseBackgroundColor;
    objc_setAssociatedObject(button, "keyCode", @(keyCode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, "isToggleable", @(isToggleable), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, "isOn", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, "baseBackgroundColor", baseBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return button;
}

- (UIButton *)createToolbarTextButtonWithTitle:(NSString *)title
                                   buttonWidth:(CGFloat)buttonWidth
                                  buttonHeight:(CGFloat)buttonHeight
                                        target:(id)target
                                        action:(SEL)action
                                       keyCode:(NSInteger)keyCode
                                  isToggleable:(BOOL)isToggleable {
    return [self createToolbarButtonWithTitle:title
                                  systemImage:nil
                                  buttonWidth:buttonWidth
                                 buttonHeight:buttonHeight
                                       target:target
                                       action:action
                                      keyCode:keyCode
                                 isToggleable:isToggleable];
}

- (UIButton *)createToolbarIconButtonWithSystemName:(NSString *)systemImageName
                                        buttonWidth:(CGFloat)buttonWidth
                                       buttonHeight:(CGFloat)buttonHeight
                                             target:(id)target
                                             action:(SEL)action
                                            keyCode:(NSInteger)keyCode
                                       isToggleable:(BOOL)isToggleable {
    return [self createToolbarButtonWithTitle:nil
                                  systemImage:systemImageName
                                  buttonWidth:buttonWidth
                                 buttonHeight:buttonHeight
                                       target:target
                                       action:action
                                      keyCode:keyCode
                                 isToggleable:isToggleable];
}

- (UIBarButtonItem *)createButtonWithImageNamed:(NSString *)imageName backgroundColor:(UIColor *)backgroundColor buttonWidth:(CGFloat)buttonWidth target:(id)target action:(SEL)action keyCode:(NSInteger)keyCode isToggleable:(BOOL)isToggleable {
    (void)imageName;
    (void)backgroundColor;
    UIButton *button = [self createToolbarTextButtonWithTitle:@""
                                                  buttonWidth:buttonWidth
                                                 buttonHeight:44.0
                                                       target:target
                                                       action:action
                                                      keyCode:keyCode
                                                 isToggleable:isToggleable];
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return barButton;
}

- (void)toolbarButtonClicked:(UIButton *)sender {
    BOOL isToggleable = [objc_getAssociatedObject(sender, "isToggleable") boolValue];
    BOOL isOn = [objc_getAssociatedObject(sender, "isOn") boolValue];
    if (isToggleable){
        isOn = !isOn;
        // Update the button's appearance based on its new state
        if (isOn) {
            sender.backgroundColor = [UIColor colorWithRed:0.48 green:0.45 blue:0.90 alpha:1.0];
        } else {
            UIColor *baseBackgroundColor = objc_getAssociatedObject(sender, "baseBackgroundColor");
            sender.backgroundColor = baseBackgroundColor ?: [UIColor colorWithWhite:0.18 alpha:1.0];
        }
    }
    // Update the new on/off state of the button
    objc_setAssociatedObject(sender, "isOn", @(isOn), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Get the keyCode parameter and convert to short for key press event
    short keyCode = [objc_getAssociatedObject(sender, "keyCode") shortValue];
    // Close keyboard if done button clicked
    if (!keyCode) {
        [keyInputField resignFirstResponder];
        isInputingText = false;
    }
    else {
        // Send key press event using keyCode parameter, toggle if necessary
        if (isToggleable){
            if (isOn){
                LiSendKeyboardEvent(keyCode, KEY_ACTION_DOWN, 0);
                [keysDown addObject:@(keyCode)];
            } else {
                LiSendKeyboardEvent(keyCode, KEY_ACTION_UP, 0);
                [keysDown removeObject:@(keyCode)];
            }
        }
        else {
            LiSendKeyboardEvent(keyCode, KEY_ACTION_DOWN, 0);
            usleep(50 * 1000);
            LiSendKeyboardEvent(keyCode, KEY_ACTION_UP, 0);
        }
    }
}

- (void)toolbarButtonPressDown:(UIButton *)sender {
    [UIView animateWithDuration:0.08 animations:^{
        sender.alpha = 0.72f;
        sender.transform = CGAffineTransformMakeScale(0.94f, 0.94f);
    }];
}

- (void)toolbarButtonPressRelease:(UIButton *)sender {
    [UIView animateWithDuration:0.12 animations:^{
        sender.alpha = 1.0f;
        sender.transform = CGAffineTransformIdentity;
    }];
}

- (void)sendShortcutPrimaryKeyCodes:(NSArray<NSNumber *> *)primaryKeyCodes
                   secondaryKeyCodes:(NSArray<NSNumber *> *)secondaryKeyCodes {
    NSArray<NSNumber *> *primaryCodes = [primaryKeyCodes copy] ?: @[];
    NSArray<NSNumber *> *secondaryCodes = [secondaryKeyCodes copy] ?: @[];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSNumber *keyCode in primaryCodes) {
            LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_DOWN, 0);
        }

        if (primaryCodes.count > 0) {
            usleep(50 * 1000);
            for (NSNumber *keyCode in [primaryCodes reverseObjectEnumerator]) {
                LiSendKeyboardEvent((short)[keyCode integerValue], KEY_ACTION_UP, 0);
            }
        }

        if (secondaryCodes.count > 0) {
            usleep(80 * 1000);
            for (NSNumber *keyCode in secondaryCodes) {
                short code = (short)[keyCode integerValue];
                LiSendKeyboardEvent(code, KEY_ACTION_DOWN, 0);
                usleep(50 * 1000);
                LiSendKeyboardEvent(code, KEY_ACTION_UP, 0);
                usleep(50 * 1000);
            }
        }
    });
}

- (BOOL)handleMouseButtonEvent:(int)buttonAction forTouches:(NSSet *)touches withEvent:(UIEvent *)event {
#if !TARGET_OS_TV
    if (@available(iOS 13.4, *)) {
        UITouch* touch = [touches anyObject];
        if (touch.type == UITouchTypeIndirectPointer) {
            if (@available(iOS 14.0, *)) {
                if ([GCMouse current] != nil) {
                    // We'll handle this with GCMouse. Do nothing here.
                    return YES;
                }
            }
            
            UIEventButtonMask normalizedButtonMask;
            
            // iOS 14 includes the released button in the buttonMask for the release
            // event, while iOS 13 does not. Normalize that behavior here.
            if (@available(iOS 14.0, *)) {
                if (buttonAction == BUTTON_ACTION_RELEASE) {
                    normalizedButtonMask = lastMouseButtonMask & ~event.buttonMask;
                }
                else {
                    normalizedButtonMask = event.buttonMask;
                }
            }
            else {
                normalizedButtonMask = event.buttonMask;
            }
            
            UIEventButtonMask changedButtons = lastMouseButtonMask ^ normalizedButtonMask;
                        
            for (int i = BUTTON_LEFT; i <= BUTTON_X2; i++) {
                UIEventButtonMask buttonFlag;
                
                switch (i) {
                    // Right and Middle are reversed from what iOS uses
                    case BUTTON_RIGHT:
                        buttonFlag = UIEventButtonMaskForButtonNumber(2);
                        break;
                    case BUTTON_MIDDLE:
                        buttonFlag = UIEventButtonMaskForButtonNumber(3);
                        break;
                        
                    default:
                        buttonFlag = UIEventButtonMaskForButtonNumber(i);
                        break;
                }
                
                if (changedButtons & buttonFlag) {
                    LiSendMouseButtonEvent(buttonAction, i);
                }
            }
            
            lastMouseButtonMask = normalizedButtonMask;
            return YES;
        }
    }
#endif
    
    return NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (viewOnlyModeEnabled) {
        [super touchesMoved:touches withEvent:event];
        return;
    }

#if !TARGET_OS_TV
    
    for (UITouch* touch in touches) {
        if (@available(iOS 13.4, *)) {
            if(touch.type == UITouchTypePencil){
                if ([self sendStylusEvent:touch]) {
                    return;
                }
            }
        }
        if (settings.multiTouchScreen) {
            if([self trySendTouchEvent:touch]){
                return;
            }
        }
    }
    if (@available(iOS 13.4, *)) {
        UITouch *touch = [touches anyObject];
        if (touch.type == UITouchTypeIndirectPointer) {
            if (@available(iOS 14.0, *)) {
                if ([GCMouse current] != nil) {
                    // We'll handle this with GCMouse. Do nothing here.
                    return;
                }
            }
            
            // We must handle this event to properly support
            // drags while the middle, X1, or X2 mouse buttons are
            // held down. For some reason, left and right buttons
            // don't require this, but we do it anyway for them too.
            // Cursor movement without a button held down is handled
            // in pointerInteraction:regionForRequest:defaultRegion.
            [self updateCursorLocation:[touch locationInView:self] isMouse:YES];
            return;
        }
    }
#endif
    
    hasUserInteracted = YES;
    
    if (![onScreenControls handleTouchMovedEvent:touches]) {
        [touchHandler touchesMoved:touches withEvent:event];
    }
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    
    if (@available(iOS 13.4, tvOS 13.4, *)) {
        for (UIPress* press in presses) {
            // For now, we'll treated it as handled if we handle at least one of the
            // UIPress events inside the set.
            if ([KeyboardSupport sendKeyEventForPress:press down:YES]) {
                // This will prevent the legacy UITextField from receiving the event
                handled = YES;
            }
        }
    }
    
    if (!handled) {
        [super pressesBegan:presses withEvent:event];
    }
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    
    if (@available(iOS 13.4, tvOS 13.4, *)) {
        for (UIPress* press in presses) {
            // For now, we'll treated it as handled if we handle at least one of the
            // UIPress events inside the set.
            if ([KeyboardSupport sendKeyEventForPress:press down:NO]) {
                // This will prevent the legacy UITextField from receiving the event
                handled = YES;
            }
        }
    }
    
    if (!handled) {
        [super pressesEnded:presses withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (viewOnlyModeEnabled) {
        [super touchesEnded:touches withEvent:event];
        return;
    }

    if ([self handleMouseButtonEvent:BUTTON_ACTION_RELEASE
                          forTouches:touches
                           withEvent:event]) {
        // If it's a mouse event, we're done
        return;
    }
    
    Log(LOG_D, @"Touch up");
    
    hasUserInteracted = YES;
    
#if !TARGET_OS_TV
    for (UITouch* touch in touches) {
        if (@available(iOS 13.4, *)) {
            if(touch.type == UITouchTypePencil){
                if ([self sendStylusEvent:touch]) {
                    return;
                }
            }
        }
        if (settings.multiTouchScreen) {
            if([self trySendTouchEvent:touch]){
                return;
            }
        }
    }
#endif
    
    if (![onScreenControls handleTouchUpEvent:touches]) {
        [touchHandler touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (viewOnlyModeEnabled) {
        [super touchesCancelled:touches withEvent:event];
        return;
    }

    [touchHandler touchesCancelled:touches withEvent:event];
    [self handleMouseButtonEvent:BUTTON_ACTION_RELEASE
                      forTouches:touches
                       withEvent:event];
#if !TARGET_OS_TV
    for (UITouch* touch in touches) {
        if (@available(iOS 13.4, *)) {
            if(touch.type == UITouchTypePencil){
                if ([self sendStylusEvent:touch]) {
                    return;
                }
            }
        }
        if (settings.multiTouchScreen) {
            if([self trySendTouchEvent:touch]){
                return;
            }
        }
    }
#endif
}

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse {
    CGPoint normalizedLocation = [self adjustCoordinatesForVideoArea:location];
    CGSize videoSize = [self getVideoAreaSize];
    
    // Send the mouse position relative to the video region if it has changed
    // if we're receiving coordinates from a real mouse.
    //
    // NB: It is important for functionality (not just optimization) to only
    // send it if the value has changed. We will receive one of these events
    // any time the user presses a modifier key, which can result in errant
    // mouse motion when using a Citrix X1 mouse.
    if (normalizedLocation.x != lastMouseX || normalizedLocation.y != lastMouseY || !isMouse) {
        if (lastMouseX != 0 || lastMouseY != 0 || !isMouse) {
            LiSendMousePositionEvent(normalizedLocation.x, normalizedLocation.y, videoSize.width, videoSize.height);
        }
        
        if (isMouse) {
            lastMouseX = normalizedLocation.x;
            lastMouseY = normalizedLocation.y;
        }
    }
}

- (UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction
                       regionForRequest:(UIPointerRegionRequest *)request
                          defaultRegion:(UIPointerRegion *)defaultRegion API_AVAILABLE(ios(13.4)) {
    if (@available(iOS 14.0, *)) {
        if ([GCMouse current] != nil) {
            // We'll handle this with GCMouse. Do nothing here.
            return nil;
        }
    }
    
    // This logic mimics what iOS does with AVLayerVideoGravityResizeAspect
    CGSize videoSize;
    CGPoint videoOrigin;
    if (self.bounds.size.width > self.bounds.size.height * streamAspectRatio) {
        videoSize = CGSizeMake(self.bounds.size.height * streamAspectRatio, self.bounds.size.height);
    } else {
        videoSize = CGSizeMake(self.bounds.size.width, self.bounds.size.width / streamAspectRatio);
    }
    videoOrigin = [self getVideoOriginForCurrentAlignment];
    
    // Move the cursor on the host if no buttons are pressed.
    // Motion with buttons pressed in handled in touchesMoved:
    if (lastMouseButtonMask == 0) {
        [self updateCursorLocation:request.location isMouse:YES];
    }
    
    // The pointer interaction should cover the video region only
    return [UIPointerRegion regionWithRect:CGRectMake(videoOrigin.x, videoOrigin.y, videoSize.width, videoSize.height) identifier:nil];
}

- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region  API_AVAILABLE(ios(13.4)) {
    // Always hide the mouse cursor over our stream view
    return [UIPointerStyle hiddenPointerStyle];
}

- (void)mouseWheelMovedContinuous:(UIPanGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            break;
        
        case UIGestureRecognizerStateEnded:
        default:
            // Ignore recognition failure and other states
            lastScrollTranslation = CGPointMake(0, 0);
            return;
    }
    
    CGPoint currentScrollTranslation = [gesture translationInView:self];
    const short translationMultiplier = 120 * 20; // WHEEL_DELTA * 20
    
    {
        short translationDeltaY = ((currentScrollTranslation.y - lastScrollTranslation.y) / self.bounds.size.height) * translationMultiplier;
        if (translationDeltaY != 0) {
            LiSendHighResScrollEvent(translationDeltaY);
            lastScrollTranslation = currentScrollTranslation;
        }
    }

    {
        short translationDeltaX = ((currentScrollTranslation.x - lastScrollTranslation.x) / self.bounds.size.width) * translationMultiplier;
        if (translationDeltaX != 0) {
            // Direction is reversed from vertical scrolling
            LiSendHighResHScrollEvent(-translationDeltaX);
            lastScrollTranslation = currentScrollTranslation;
        }
    }
}

- (void)mouseWheelMovedDiscrete:(UIPanGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            break;
        
        case UIGestureRecognizerStateEnded:
        default:
            // Ignore recognition failure and other states
            lastScrollTranslation = CGPointMake(0, 0);
            return;
    }
    
    // Using velocityInView is 0 for discrete scroll events
    // when scrolling very slowly, but translationInView does work.
    CGPoint currentScrollTranslation = [gesture translationInView:self];
    
    {
        short translationDeltaY = currentScrollTranslation.y - lastScrollTranslation.y;
        if (translationDeltaY != 0) {
            LiSendScrollEvent(translationDeltaY > 0 ? 1 : -1);
        }
    }

    {
        short translationDeltaX = currentScrollTranslation.x - lastScrollTranslation.x;
        if (translationDeltaX != 0) {
            // Direction is reversed from vertical scrolling
            LiSendHScrollEvent(translationDeltaX < 0 ? 1 : -1);
        }
    }
    
    lastScrollTranslation = currentScrollTranslation;
}

#endif

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (@available(iOS 13.0, *)) {
        // Disable the 3 finger tap gestures that trigger the copy/paste/undo toolbar on iOS 13+
        return gestureRecognizer.name == nil || ![gestureRecognizer.name hasPrefix:@"kbProductivity."];
    }
    else {
        return YES;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // This method is called when the "Return" key is pressed.
    LiSendKeyboardEvent(0x0d, KEY_ACTION_DOWN, 0);
    usleep(50 * 1000);
    LiSendKeyboardEvent(0x0d, KEY_ACTION_UP, 0);
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    for (NSNumber* keyCode in keysDown) {
        LiSendKeyboardEvent([keyCode shortValue], KEY_ACTION_UP, 0);
    }
    [keysDown removeAllObjects];
}

- (void)onKeyboardPressed:(UITextField *)textField {
    NSString* inputText = textField.text;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // If the text became empty, we know the user pressed the backspace key.
        if ([inputText isEqual:@""]) {
            LiSendKeyboardEvent(0x08, KEY_ACTION_DOWN, 0);
            usleep(50 * 1000);
            LiSendKeyboardEvent(0x08, KEY_ACTION_UP, 0);
        } else {
            // Character 0 will be our known sentinel value
            
            // Check if any characters exist which can't be represented in a basic key event
            for (int i = 1; i < [inputText length]; i++) {
                struct KeyEvent event = [KeyboardSupport translateKeyEvent:[inputText characterAtIndex:i] withModifierFlags:0];
                if (event.keycode == 0) {
                    // We found an unknown key, so send the entire string as UTF-8
                    const char* utf8String = [inputText UTF8String];
                    
                    // Skip the first character which is our sentinel
                    LiSendUtf8TextEvent(utf8String + 1, (int)strlen(utf8String) - 1);
                    return;
                }
            }
            
            // We didn't find any unknown characters, so send them all as basic key events
            for (int i = 1; i < [inputText length]; i++) {
                struct KeyEvent event = [KeyboardSupport translateKeyEvent:[inputText characterAtIndex:i] withModifierFlags:0];
                assert(event.keycode != 0);
                [self sendLowLevelEvent:event];
            }
        }
    });
    
    // Reset text field back to known state
    textField.text = @"0";
    
    // Move the insertion point back to the end of the text box
    UITextRange *textRange = [textField textRangeFromPosition:textField.endOfDocument toPosition:textField.endOfDocument];
    [textField setSelectedTextRange:textRange];
}

- (void)specialCharPressed:(UIKeyCommand *)cmd {
    struct KeyEvent event = [KeyboardSupport translateKeyEvent:0x20 withModifierFlags:[cmd modifierFlags]];
    event.keycode = [[dictCodes valueForKey:[cmd input]] intValue];
    [self sendLowLevelEvent:event];
}

- (void)keyPressed:(UIKeyCommand *)cmd {
    struct KeyEvent event = [KeyboardSupport translateKeyEvent:[[cmd input] characterAtIndex:0] withModifierFlags:[cmd modifierFlags]];
    [self sendLowLevelEvent:event];
}

- (void)sendLowLevelEvent:(struct KeyEvent)event {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // When we want to send a modified key (like uppercase letters) we need to send the
        // modifier ("shift") seperately from the key itself.
        if (event.modifier != 0) {
            LiSendKeyboardEvent(event.modifierKeycode, KEY_ACTION_DOWN, event.modifier);
        }
        // Let the host know these are not (necessarily) normalized to US English scancodes
        LiSendKeyboardEvent2(event.keycode, KEY_ACTION_DOWN, event.modifier, SS_KBE_FLAG_NON_NORMALIZED);
        usleep(50 * 1000);
        LiSendKeyboardEvent2(event.keycode, KEY_ACTION_UP, event.modifier, SS_KBE_FLAG_NON_NORMALIZED);
        if (event.modifier != 0) {
            LiSendKeyboardEvent(event.modifierKeycode, KEY_ACTION_UP, event.modifier);
        }
    });
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
    NSString *charset = @"qwertyuiopasdfghjklzxcvbnm1234567890\t§[]\\'\"/.,`<>-´ç+`¡'º;ñ= ";
    
    NSMutableArray<UIKeyCommand *> * commands = [NSMutableArray<UIKeyCommand *> array];
    dictCodes = [[NSDictionary alloc] initWithObjectsAndKeys: [NSNumber numberWithInt: 0x0d], @"\r", [NSNumber numberWithInt: 0x08], @"\b", [NSNumber numberWithInt: 0x1b], UIKeyInputEscape, [NSNumber numberWithInt: 0x28], UIKeyInputDownArrow, [NSNumber numberWithInt: 0x26], UIKeyInputUpArrow, [NSNumber numberWithInt: 0x25], UIKeyInputLeftArrow, [NSNumber numberWithInt: 0x27], UIKeyInputRightArrow, nil];
    
    [charset enumerateSubstringsInRange:NSMakeRange(0, charset.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                 [commands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:0 action:@selector(keyPressed:)]];
                                 [commands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierShift action:@selector(keyPressed:)]];
                                 [commands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierControl action:@selector(keyPressed:)]];
                                 [commands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierAlternate action:@selector(keyPressed:)]];
                             }];
    
    for (NSString *c in [dictCodes keyEnumerator]) {
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:0
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierShift
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierShift | UIKeyModifierAlternate
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierShift | UIKeyModifierControl
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierControl
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierControl | UIKeyModifierAlternate
                                                       action:@selector(specialCharPressed:)]];
        [commands addObject:[UIKeyCommand keyCommandWithInput:c
                                                modifierFlags:UIKeyModifierAlternate
                                                       action:@selector(specialCharPressed:)]];
    }
    
    return commands;
}

- (void)connectedStateDidChangeWithIdentifier:(NSUUID * _Nonnull)identifier isConnected:(BOOL)isConnected {
    NSLog(@"Citrix X1 mouse state change: %@ -> %s",
          identifier, isConnected ? "connected" : "disconnected");
}

- (void)mouseDidMoveWithIdentifier:(NSUUID * _Nonnull)identifier deltaX:(int16_t)deltaX deltaY:(int16_t)deltaY {
    accumulatedMouseDeltaX += deltaX / X1_MOUSE_SPEED_DIVISOR;
    accumulatedMouseDeltaY += deltaY / X1_MOUSE_SPEED_DIVISOR;
    
    short shortX = (short)accumulatedMouseDeltaX;
    short shortY = (short)accumulatedMouseDeltaY;
    
    if (shortX == 0 && shortY == 0) {
        return;
    }
    
    LiSendMouseMoveEvent(shortX, shortY);
    
    accumulatedMouseDeltaX -= shortX;
    accumulatedMouseDeltaY -= shortY;
}

- (int) buttonFromX1ButtonCode:(enum X1MouseButton)button {
    switch (button) {
        case X1MouseButtonLeft:
            return BUTTON_LEFT;
        case X1MouseButtonRight:
            return BUTTON_RIGHT;
        case X1MouseButtonMiddle:
            return BUTTON_MIDDLE;
        default:
            return -1;
    }
}

- (void)mouseDownWithIdentifier:(NSUUID * _Nonnull)identifier button:(enum X1MouseButton)button {
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, [self buttonFromX1ButtonCode:button]);
}

- (void)mouseUpWithIdentifier:(NSUUID * _Nonnull)identifier button:(enum X1MouseButton)button {
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, [self buttonFromX1ButtonCode:button]);
}

- (void)wheelDidScrollWithIdentifier:(NSUUID * _Nonnull)identifier deltaZ:(int8_t)deltaZ {
    LiSendScrollEvent(deltaZ);
}

- (CGFloat)getScreenWidth {
    return [UIScreen mainScreen].bounds.size.width;
}

- (CGPoint)getStreamViewRelativeSensitivityXY:(UITouch *)touch touchID:(uint32_t)touchID {
    CGPoint location = [self adjustCoordinatesForVideoArea:[touch locationInView:self]];
    CGFloat normalizedX = location.x;
    CGFloat normalizedY = location.y;
    if (!touchSensitivityGlobal && normalizedX < [self getScreenWidth] / 2) {
        return location;
    }
    NSNumber *key = [NSNumber numberWithUnsignedInt:touchID];

    if (touch.phase == UITouchPhaseMoved) {
        SensitivityBean *bean = [sensitivityMap objectForKey:key];
        if (!bean) {
            bean = [[SensitivityBean alloc] init];
        }

        if (bean.lastAbsoluteX != -1) {
            CGFloat dx = normalizedX - bean.lastAbsoluteX;
            CGFloat dy = normalizedY - bean.lastAbsoluteY;
            dx *= 0.01f * touchSensitivity; // 灵敏度
            dy *= 0.01f * touchSensitivity;
            normalizedX = bean.lastRelativelyX + dx;
            normalizedY = bean.lastRelativelyY + dy;
        }

        bean.lastAbsoluteX = location.x;
        bean.lastAbsoluteY = location.y;
        bean.lastRelativelyX = normalizedX;
        bean.lastRelativelyY = normalizedY;
        [sensitivityMap setObject:bean forKey:key];
    }

    if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
        [sensitivityMap removeObjectForKey:key];
    }

    location.x = normalizedX;
    location.y = normalizedY;
    return location;
}


#if !TARGET_OS_TV
- (BOOL)isMultipleTouchEnabled {
    return YES;
}
#endif

@end
