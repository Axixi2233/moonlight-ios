//
//  SensitivityBean.m
//  Moonlight
//
//  Created by Klee on 2024/5/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import "SensitivityBean.h"

@implementation SensitivityBean

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastAbsoluteX = -1;
        _lastAbsoluteY = -1;
        _lastRelativelyX = -1;
        _lastRelativelyY = -1;
    }
    return self;
}

@end
