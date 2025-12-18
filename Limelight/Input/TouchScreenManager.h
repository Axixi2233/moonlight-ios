//
//  TouchScreenManager.h
//  Moonlight
//
//  Created by Klee on 2024/5/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TouchScreenManager : NSObject

- (uint32_t)identifierForTouch:(UITouch *)touch;
- (void)removeTouch:(UITouch *)touch;

@end
