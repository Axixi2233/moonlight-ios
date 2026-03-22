//
//  OSCProfilesTableViewController.m
//  Moonlight
//
//  Created by Long Le on 11/28/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfilesTableViewController.h"
#import "LayoutOnScreenControlsViewController.h"
#import "ProfileTableViewCell.h"
#import "OSCProfile.h"
#import "OnScreenButtonState.h"
#import "OSCProfilesManager.h"

const double NAV_BAR_HEIGHT = 50;

@interface OSCProfilesTableViewController ()

@end

@implementation OSCProfilesTableViewController {
    OSCProfilesManager *profilesManager;
}

@synthesize tableView;

- (void)loadView {
    UIView *rootView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    rootView.backgroundColor = [UIColor colorWithRed:0.1215686275 green:0.1294117647 blue:0.1411764706 alpha:1.0];

    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    headerView.backgroundColor = [UIColor colorWithRed:0.1215686275 green:0.1294117647 blue:0.1411764706 alpha:0.96];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"选择布局配置";
    titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
    titleLabel.textColor = [UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [cancelButton setTitleColor:[UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *loadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    loadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [loadButton setTitle:@"加载" forState:UIControlStateNormal];
    loadButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [loadButton setTitleColor:[UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [loadButton addTarget:self action:@selector(loadTapped:) forControlEvents:UIControlEventTouchUpInside];

    UITableView *profilesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    profilesTableView.translatesAutoresizingMaskIntoConstraints = NO;
    profilesTableView.backgroundColor = [UIColor clearColor];
    profilesTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    profilesTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    profilesTableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    if (@available(iOS 15.0, *)) {
        profilesTableView.sectionHeaderTopPadding = 0.0;
    }

    [headerView addSubview:titleLabel];
    [headerView addSubview:cancelButton];
    [headerView addSubview:loadButton];
    [rootView addSubview:headerView];
    [rootView addSubview:profilesTableView];

    UILayoutGuide *safeArea = rootView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [headerView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [headerView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [headerView.topAnchor constraintEqualToAnchor:rootView.topAnchor],

        [cancelButton.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16.0],
        [cancelButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8.0],
        [cancelButton.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-10.0],

        [loadButton.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16.0],
        [loadButton.centerYAnchor constraintEqualToAnchor:cancelButton.centerYAnchor],

        [titleLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:cancelButton.centerYAnchor],

        [headerView.bottomAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:18.0],

        [profilesTableView.topAnchor constraintEqualToAnchor:headerView.bottomAnchor],
        [profilesTableView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [profilesTableView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [profilesTableView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];

    self.tableView = profilesTableView;
    self.view = rootView;
}

- (void) viewDidLoad {
    [super viewDidLoad];
        
    profilesManager = [OSCProfilesManager sharedManager];

    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];
    self.tableView.rowHeight = 44.0;

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[ProfileTableViewCell class] forCellReuseIdentifier:@"Cell"];

}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    if ([[profilesManager getAllProfiles] count] > 0) { // scroll to selected profile if user has any saved profiles
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}


#pragma mark - UIButton Actions

/* Loads the OSC profile that user selected, dismisses this VC, then tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions */
- (void)loadTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];

    if (self.didDismissOSCProfilesTVC) {    // tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions
        self.didDismissOSCProfilesTVC();
    }
}

- (void)cancelTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - TableView DataSource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[profilesManager getAllProfiles] count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex: indexPath.row];
    [cell configureWithName:profile.name];
    
    if ([profile.name isEqualToString: [profilesManager getSelectedProfile].name]) { // if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *profiles = [profilesManager getAllProfiles];

    if ([[[profiles objectAtIndex:indexPath.row] name] isEqualToString:@"Default"]) {   // if user is attempting to delete the 'Default' profile then show a pop up telling user they can't do that and return out of this method
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OSCProfile *profile = [profiles objectAtIndex:indexPath.row];
        if (profile.isSelected) {   // if user is deleting the currently selected OSC profile then make the  profile at its previous index the currently selected profile
            if (indexPath.row > 0) {    // check that row is greater than zero to avoid an out of bounds crash, although that should not be possible right now since the 'Default' profile is always at row 0 and they're not allowed to delete it
                OSCProfile *profile = [profiles objectAtIndex:indexPath.row - 1];
                profile.isSelected = YES;
            }
        }
        
        [profiles removeObjectAtIndex:indexPath.row];
        
        /* save OSC profiles array to persistent storage */
        NSMutableArray *profilesEncoded = [[NSMutableArray alloc] init];
        for (OSCProfile *profileDecoded in profiles) {  // encode each OSC profile object and add them to an array
            
            NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
            [profilesEncoded addObject:profileEncoded];
        }
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded
                                             requiringSecureCoding:YES error:nil];  // encode the array itself, NOT the objects in the array
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [tableView reloadData]; 
    }
}


#pragma mark - TableView Delegate

/* When user taps a cell it moves the checkmark to that cell indicating to the user the profile associated with that cell is now the selected profile. It also sets that cell's associated OSCProfile object's 'isSelected' property to YES  */
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    NSIndexPath *lastSelectedIndexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];

    if (selectedIndexPath != lastSelectedIndexPath) {
        /* Place checkmark on selected cell and set profile associated with cell as selected profile */
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;  // add checkmark to the cell the user tapped
        OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex:indexPath.row];
        [profilesManager setProfileToSelected: profile.name];   // set the profile associated with this cell's 'isSelected' property to YES
        
        /* Remove checkmark on the previously selected cell  */
        UITableViewCell *lastSelectedCell = [tableView cellForRowAtIndexPath: lastSelectedIndexPath];
        lastSelectedCell.accessoryType = UITableViewCellAccessoryNone; 
        [tableView deselectRowAtIndexPath:lastSelectedIndexPath animated:YES];
    }
}


@end
