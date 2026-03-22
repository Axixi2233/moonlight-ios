//
//  ProfileTableViewCell.m
//  Moonlight
//
//  Created by Long Le on 12/11/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "ProfileTableViewCell.h"
#import "Moonlight-Swift.h"

static UIColor *ProfileCellBackgroundColor(void) {
    return [UIColor colorWithRed:0.1215686275 green:0.1294117647 blue:0.1411764706 alpha:1.0];
}

static UIColor *ProfileCellTextColor(void) {
    return [UIColor colorWithRed:0.9529411765 green:0.9764705882 blue:1.0 alpha:1.0];
}

@interface ProfileTableViewCell ()

@property (strong, nonatomic) UILabel *fallbackNameLabel;
@property (strong, nonatomic, nullable) ProfileTableViewCellHostingBridge *hostingBridge;

@end

@implementation ProfileTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = ProfileCellBackgroundColor();
    self.contentView.backgroundColor = ProfileCellBackgroundColor();
    self.tintColor = [UIColor colorWithRed:0.6705882353 green:0.6156862745 blue:1.0 alpha:1.0];
    self.clipsToBounds = YES;

    self.fallbackNameLabel = [[UILabel alloc] init];
    self.fallbackNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fallbackNameLabel.font = [UIFont systemFontOfSize:17.0];
    self.fallbackNameLabel.textColor = ProfileCellTextColor();
    self.fallbackNameLabel.numberOfLines = 1;
    self.fallbackNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    [self.contentView addSubview:self.fallbackNameLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.fallbackNameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.fallbackNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.fallbackNameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.fallbackNameLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureWithName:(NSString *)name {
    self.fallbackNameLabel.hidden = YES;

    if (self.hostingBridge == nil) {
        self.hostingBridge = [[ProfileTableViewCellHostingBridge alloc] init];
    }

    [self.hostingBridge renderInView:self.contentView name:name];
}

@end
