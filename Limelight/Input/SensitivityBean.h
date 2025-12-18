//
//  SensitivityBean.h
//  Moonlight
//
//  Created by Klee on 2024/5/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//
@interface SensitivityBean : NSObject

@property (nonatomic, assign) CGFloat lastAbsoluteX;
@property (nonatomic, assign) CGFloat lastAbsoluteY;
@property (nonatomic, assign) CGFloat lastRelativelyX;
@property (nonatomic, assign) CGFloat lastRelativelyY;

@end

