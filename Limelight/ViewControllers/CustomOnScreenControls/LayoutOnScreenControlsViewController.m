//
//  LayoutOnScreenControlsViewController.m
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControlsViewController.h"
#import "OSCProfilesTableViewController.h"
#import "OnScreenButtonState.h"
#import "OnScreenControls.h"
#import "OSCProfilesManager.h"

@interface LayoutOnScreenControlsViewController ()

@end


@implementation LayoutOnScreenControlsViewController {
    BOOL isToolbarHidden;
    OSCProfilesManager *profilesManager;
    NSLayoutConstraint *toolbarTopConstraint;
}

@synthesize trashCanButton;
@synthesize undoButton;
@synthesize OSCSegmentSelected;
@synthesize toolbarRootView;
@synthesize chevronView;
@synthesize chevronImageView;

- (void)loadView {
    UIView *rootView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    rootView.backgroundColor = [UIColor colorWithRed:0.1215686275 green:0.1294117647 blue:0.1411764706 alpha:1.0];
    self.view = rootView;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    profilesManager = [OSCProfilesManager sharedManager];
    [self buildToolbarIfNeeded];

    isToolbarHidden = NO;   // keeps track if the toolbar is hidden up above the screen so that we know whether to hide or show it when the user taps the toolbar's hide/show button
            
    /* Add swipe gesture to toolbar to allow user to swipe it up and off screen */
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(moveToolbar:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.toolbarRootView addGestureRecognizer:swipeUp];

    /* Add tap gesture to toolbar's chevron to allow user to tap it in order to move the toolbar on and off screen */
    UITapGestureRecognizer *singleFingerTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(moveToolbar:)];
    [self.chevronView addGestureRecognizer:singleFingerTap];

    self.layoutOSC = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil oscLevel:OSCSegmentSelected];
    self.layoutOSC._level = 4;
    [self.layoutOSC show];  // draw on screen controls
    
    [self addInnerAnalogSticksToOuterAnalogLayers]; // allows inner and analog sticks to be dragged together around the screen together as one unit which is the expected behavior

    self.undoButton.alpha = 0.3;    // no changes to undo yet, so fade out the undo button a bit
    
    if ([[profilesManager getAllProfiles] count] == 0) { // if no saved OSC profiles exist yet then create one called 'Default' and associate it with Moonlight's legacy 'Full' OSC layout that's already been laid out on the screen at this point
        [profilesManager saveProfileWithName:@"Default" andButtonLayers:self.layoutOSC.OSCButtonLayers];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OSCLayoutChanged) name:@"OSCLayoutChanged" object:nil];    // used to notifiy this view controller that the user made a change to the OSC layout so that the VC can either fade in or out its 'Undo button' which will signify to the user whether there are any OSC layout changes to undo
    
    /* This will animate the toolbar with a subtle up and down motion intended to telegraph to the user that they can hide the toolbar if they wish*/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [UIView animateWithDuration:0.3
          delay:0.25
          usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
          options:UIViewAnimationOptionCurveEaseInOut animations:^{ // Animate toolbar up a a very small distance. Note the 0.35 time delay is necessary to avoid a bug that keeps animations from playing if the animation is presented immediately on a modally presented VC
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y - 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
            }
          completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3
              delay:0
              usingSpringWithDamping:0.7
              initialSpringVelocity:1.0
              options:UIViewAnimationOptionCurveEaseIn animations:^{ // Animate the toolbar back down that same distance
                self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y + 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
                }
              completion:^(BOOL finished) {
                NSLog (@"done");
            }];
        }];
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.chevronView.bounds
                                                   byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                                         cornerRadii:CGSizeMake(10.0, 10.0)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.chevronView.bounds;
    maskLayer.path = maskPath.CGPath;
    self.chevronView.layer.mask = maskLayer;
}


#pragma mark - Class Helper Functions

/* fades the 'Undo Button' in or out depending on whether the user has any OSC layout changes to undo */
- (void) OSCLayoutChanged {
    if ([self.layoutOSC.layoutChanges count] > 0) {
        self.undoButton.alpha = 1.0;
    }
    else {
        self.undoButton.alpha = 0.3;
    }
}

/* animates the toolbar up and off the screen or back down onto the screen */
- (void) moveToolbar:(UISwipeGestureRecognizer *)sender {
    if (isToolbarHidden == NO) {
        [UIView animateWithDuration:0.2 animations:^{   // animates toolbar up and off screen
            self->toolbarTopConstraint.constant = -self.toolbarRootView.frame.size.height;
            [self.view layoutIfNeeded];

        }
        completion:^(BOOL finished) {
            if (finished) {
                self->isToolbarHidden = YES;
                self.chevronImageView.image = [UIImage imageNamed:@"ChevronCompactDown"];
            }
        }];
    }
    else {
        [UIView animateWithDuration:0.2 animations:^{   // animates the toolbar back down into the screen
            self->toolbarTopConstraint.constant = 0;
            [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
            if (finished) {
                self->isToolbarHidden = NO;
                self.chevronImageView.image = [UIImage imageNamed:@"ChevronCompactUp"];
            }
        }];
    }
}

- (UIButton *)toolbarButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [button setTitleColor:[UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    button.layer.cornerRadius = 10.0;
    button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
    return button;
}

- (void)buildToolbarIfNeeded {
    if (self.toolbarRootView != nil) {
        return;
    }

    ToolBarContainerView *toolbarView = [[ToolBarContainerView alloc] init];
    toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    toolbarView.backgroundColor = [UIColor colorWithRed:0.1215686275 green:0.1294117647 blue:0.1411764706 alpha:0.92];
    toolbarView.layer.cornerRadius = 18.0;
    toolbarView.clipsToBounds = NO;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.spacing = 10.0;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.alignment = UIStackViewAlignmentFill;

    UIButton *trashButton = [self toolbarButtonWithTitle:@"删除" action:@selector(trashCanTapped:)];
    UIButton *undoButton = [self toolbarButtonWithTitle:@"撤销" action:@selector(undoTapped:)];
    UIButton *saveButton = [self toolbarButtonWithTitle:@"保存" action:@selector(saveTapped:)];
    UIButton *loadButton = [self toolbarButtonWithTitle:@"加载" action:@selector(loadTapped:)];
    UIButton *closeButton = [self toolbarButtonWithTitle:@"关闭" action:@selector(closeTapped:)];

    [stackView addArrangedSubview:trashButton];
    [stackView addArrangedSubview:undoButton];
    [stackView addArrangedSubview:saveButton];
    [stackView addArrangedSubview:loadButton];
    [stackView addArrangedSubview:closeButton];

    UIView *chevronContainerView = [[UIView alloc] init];
    chevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronContainerView.backgroundColor = toolbarView.backgroundColor;
    chevronContainerView.layer.cornerRadius = 10.0;
    chevronContainerView.clipsToBounds = YES;

    UIImageView *chevronIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.compact.up"]];
    chevronIconView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronIconView.tintColor = [UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0];
    chevronIconView.contentMode = UIViewContentModeScaleAspectFit;

    [chevronContainerView addSubview:chevronIconView];
    [toolbarView addSubview:stackView];
    [toolbarView addSubview:chevronContainerView];
    [self.view addSubview:toolbarView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    toolbarTopConstraint = [toolbarView.topAnchor constraintEqualToAnchor:safeArea.topAnchor];

    [NSLayoutConstraint activateConstraints:@[
        toolbarTopConstraint,
        [toolbarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [toolbarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],

        [stackView.topAnchor constraintEqualToAnchor:toolbarView.topAnchor constant:12.0],
        [stackView.leadingAnchor constraintEqualToAnchor:toolbarView.leadingAnchor constant:12.0],
        [stackView.trailingAnchor constraintEqualToAnchor:toolbarView.trailingAnchor constant:-12.0],
        [stackView.heightAnchor constraintEqualToConstant:44.0],
        [stackView.bottomAnchor constraintEqualToAnchor:toolbarView.bottomAnchor constant:-12.0],

        [chevronContainerView.centerXAnchor constraintEqualToAnchor:toolbarView.centerXAnchor],
        [chevronContainerView.topAnchor constraintEqualToAnchor:toolbarView.bottomAnchor constant:-2.0],
        [chevronContainerView.widthAnchor constraintEqualToConstant:72.0],
        [chevronContainerView.heightAnchor constraintEqualToConstant:22.0],

        [chevronIconView.centerXAnchor constraintEqualToAnchor:chevronContainerView.centerXAnchor],
        [chevronIconView.centerYAnchor constraintEqualToAnchor:chevronContainerView.centerYAnchor],
        [chevronIconView.widthAnchor constraintEqualToConstant:28.0],
        [chevronIconView.heightAnchor constraintEqualToConstant:16.0]
    ]];

    self.toolbarRootView = toolbarView;
    self.toolbarStackView = stackView;
    self.chevronView = chevronContainerView;
    self.chevronImageView = chevronIconView;
    self.trashCanButton = trashButton;
    self.undoButton = undoButton;
}

/**
 * Makes the inner analog stick layers a child layer of its corresponding outer analog stick layers so that both the inner and its corresponding outer layers move together when the user drags them around the screen as is the expected behavior when laying out OSC. Note that this is NOT expected behavior on the game stream view where the inner analog sticks move to follow toward the user's touch and their corresponding outer analog stick layers do not move
 */
- (void)addInnerAnalogSticksToOuterAnalogLayers {
    // right stick
    [self.layoutOSC._rightStickBackground addSublayer: self.layoutOSC._rightStick];
    self.layoutOSC._rightStick.position = CGPointMake(self.layoutOSC._rightStickBackground.frame.size.width / 2, self.layoutOSC._rightStickBackground.frame.size.height / 2);
    
    // left stick
    [self.layoutOSC._leftStickBackground addSublayer: self.layoutOSC._leftStick];
    self.layoutOSC._leftStick.position = CGPointMake(self.layoutOSC._leftStickBackground.frame.size.width / 2, self.layoutOSC._leftStickBackground.frame.size.height / 2);
}


#pragma mark - UIButton Actions

- (void)closeTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)trashCanTapped:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"将按钮拖放到“删除按钮”上以将其从界面中删除" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)undoTapped:(id)sender {
    if ([self.layoutOSC.layoutChanges count] > 0) { // check if there are layout changes to roll back to
        OnScreenButtonState *buttonState = [self.layoutOSC.layoutChanges lastObject];   //  Get the 'OnScreenButtonState' object that contains the name, position, and visiblity state of the button the user last moved
        
        CALayer *buttonLayer = [self.layoutOSC buttonLayerFromName:buttonState.name];   // get the on screen button layer that corresponds with the 'OnScreenButtonState' object that we retrieved above
        
        /* Set the button's position and visiblity to what it was before the user last moved it */
        buttonLayer.position = buttonState.position;
        buttonLayer.hidden = buttonState.isHidden;
        
        /* if user is showing or hiding dPad, then show or hide all four dPad button child layers as well since setting the 'hidden' property on the parent CALayer is not automatically setting the individual dPad child CALayers */
        if ([buttonLayer.name isEqualToString:@"dPad"]) {
            self.layoutOSC._upButton.hidden = buttonState.isHidden;
            self.layoutOSC._rightButton.hidden = buttonState.isHidden;
            self.layoutOSC._downButton.hidden = buttonState.isHidden;
            self.layoutOSC._leftButton.hidden = buttonState.isHidden;
        }
        
        /* if user is showing or hiding the left or right analog sticks, then show or hide their corresponding inner analog stick child layers as well since setting the 'hidden' property on the parent analog stick doesn't automatically hide its child inner analog stick CALayer */
        if ([buttonLayer.name isEqualToString:@"leftStickBackground"]) {
            self.layoutOSC._leftStick.hidden = buttonState.isHidden;
        }
        if ([buttonLayer.name isEqualToString:@"rightStickBackground"]) {
            self.layoutOSC._rightStick.hidden = buttonState.isHidden;
        }
        
        [self.layoutOSC.layoutChanges removeLastObject];
        
        [self OSCLayoutChanged]; // will fade the undo button in or out depending on whether there are any further changes to undo
    }
    else {  // there are no changes to undo. let user know there are no changes to undo
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@"提示"] message: @"没有可撤销的项" preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [savedAlertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:savedAlertController animated:YES completion:nil];
    }
}

/* show pop up notification that lets users choose to save the current OSC layout configuration as a profile they can load when they want. User can also choose to cancel out of this pop up */
- (void)saveTapped:(id)sender {
    UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: @"输入配置文件名称保存" message: @"" preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {  // pop up notification with text field where user can enter the text they wish to name their OSC layout profile
        textField.placeholder = @"name";
        textField.textColor = [UIColor lightGrayColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleNone;
    }];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {   // add save button to allow user to save the on screen controller configuration
        NSArray *textFields = inputNameAlertController.textFields;
        UITextField *nameField = textFields[0];
        NSString *enteredProfileName = nameField.text;
        
        if ([enteredProfileName isEqualToString:@"Default"]) {  // don't let user user overwrite the 'Default' profile
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"不允许保存“默认”配置文件"] preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [alertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
        }
        else if ([enteredProfileName length] == 0) {    // if user entered no text and taps the 'Save' button let them know they can't do that
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"配置名不能为空！"] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { // show pop up notification letting user know they must enter a name in the text field if they wish to save the controller profile
                
                [savedAlertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else if ([self->profilesManager profileNameAlreadyExist:enteredProfileName] == YES) {  // if the entered profile name already exists then let the user know. Offer to allow them to overwrite the existing profile
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"此名称的配置 '%@' 已存在，是否覆盖?", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"是" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {    // overwrite existing profile
                [self->profilesManager saveProfileWithName: enteredProfileName andButtonLayers:self.layoutOSC.OSCButtonLayers];
            }]];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"否" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { // don't overwrite the existing profile
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else {  // if user entered a valid name that doesn't already exist then save the profile to persistent storage
            [self->profilesManager saveProfileWithName: enteredProfileName andButtonLayers:self.layoutOSC.OSCButtonLayers];
            [self->profilesManager setProfileToSelected: enteredProfileName];
            
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"%@ 配置文件已保存并设置为游戏内控制器配置文件布局", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];  // Let user know this profile has been saved and is now the selected controller layout
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
    }]];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { // adds a button that allows user to decline the option to save the controller layout they currently see on screen
        [inputNameAlertController dismissViewControllerAnimated:NO completion:nil];
    }]];
    [self presentViewController:inputNameAlertController animated:YES completion:nil];
}

/* Presents the view controller that lists all OSC profiles the user can choose from */
- (void)loadTapped:(id)sender {
    OSCProfilesTableViewController *vc = [[OSCProfilesTableViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    vc.didDismissOSCProfilesTVC = ^() {   // a block that will be called when the modally presented 'OSCProfilesTableViewController' VC is dismissed. By the time the 'OSCProfilesTableViewController' VC is dismissed the user would have potentially selected a different OSC profile with a different layout and they want to see this layout on this 'LayoutOnScreenControlsViewController.' This block of code will load the profile and then hide/show and move each OSC button to their appropriate position
        [self.layoutOSC updateControls];  // creates and saves a 'Default' OSC profile or loads the one the user selected on the previous screen
        
        [self addInnerAnalogSticksToOuterAnalogLayers];
        
        [self.layoutOSC.layoutChanges removeAllObjects];  // since a new OSC profile is being loaded, this will remove all previous layout changes made from the array
        
        [self OSCLayoutChanged];    // fades the 'Undo Button' out
    };
    [self presentViewController:vc animated:YES completion:nil];
}


#pragma mark - Touch

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        UIView *touchView = touch.view;
        CGPoint touchLocation = [touch locationInView:self.view];
        CALayer *layer = [self.view.layer hitTest:touchLocation];
        if (touchView == nil ||
            [touchView isDescendantOfView:self.toolbarRootView] ||
            layer == self.view.layer) {
            return;
        }
    }
    [self.layoutOSC touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.layoutOSC touchesMoved:touches withEvent:event];
    
    if ([self.layoutOSC isLayer:self.layoutOSC.layerBeingDragged
                        hoveringOverButton:trashCanButton]) { // check if user is dragging around a button and hovering it over the trash can button
        trashCanButton.tintColor = [UIColor redColor];
    }
    else {
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.layoutOSC.layerBeingDragged != nil &&
        [self.layoutOSC isLayer:self.layoutOSC.layerBeingDragged hoveringOverButton:trashCanButton]) { // check if user wants to throw OSC button into the trash can
        
        self.layoutOSC.layerBeingDragged.hidden = YES;
        
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"dPad"]) { // if user is hiding dPad, then hide all four dPad button child layers as well since setting the 'hidden' property on the parent dPad CALayer doesn't automatically hide the four child CALayer dPad buttons
            self.layoutOSC._upButton.hidden = YES;
            self.layoutOSC._rightButton.hidden = YES;
            self.layoutOSC._downButton.hidden = YES;
            self.layoutOSC._leftButton.hidden = YES;
        }
        
        /* if user is hiding left or right analog sticks, then hide their corresponding inner analog stick child layers as well since setting the 'hidden' property on the parent analog stick doesn't automatically hide its child inner analog stick CALayer */
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"leftStickBackground"]) {
            self.layoutOSC._leftStick.hidden = YES;
        }
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"rightStickBackground"]) {
            self.layoutOSC._rightStick.hidden = YES;
        }
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
    [self.layoutOSC touchesEnded:touches withEvent:event];
}

@end
