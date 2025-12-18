//
//  TouchScreenManager.m
//  Moonlight
//
//  Created by Klee on 2024/5/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import "TouchScreenManager.h"

@interface TouchScreenManager ()

@property (nonatomic, strong) NSMapTable<UITouch *, NSNumber *> *touchIdentifierMap;
@property (nonatomic, assign) uint32_t currentIdentifier;

@end

@implementation TouchScreenManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _touchIdentifierMap = [NSMapTable weakToStrongObjectsMapTable];
        _currentIdentifier = 0;
    }
    return self;
}

- (uint32_t)identifierForTouch:(UITouch *)touch {
    NSNumber *identifier = [self.touchIdentifierMap objectForKey:touch];
    if (!identifier) {
        identifier = @(self.currentIdentifier++);
        [self.touchIdentifierMap setObject:identifier forKey:touch];
    }
    return [identifier unsignedIntValue];
}

- (void)removeTouch:(UITouch *)touch {
    [self.touchIdentifierMap removeObjectForKey:touch];
}

@end

