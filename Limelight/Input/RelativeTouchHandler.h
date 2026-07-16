//
//  RelativeTouchHandler.h
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "StreamView.h"
#import "TemporarySettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface RelativeTouchHandler : UIResponder

-(id)initWithView:(StreamView*)view;
-(id)initWithView:(StreamView*)view settings:(TemporarySettings*)settings;
-(void)cancelActiveTouches;

@end

NS_ASSUME_NONNULL_END
