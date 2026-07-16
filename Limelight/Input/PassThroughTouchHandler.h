//
//  PassThroughTouchHandler.h
//  Moonlight
//
//  Created by OpenAI Codex.
//

#import "StreamView.h"
#import "TemporarySettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface PassThroughTouchHandler : UIResponder

- (id)initWithView:(StreamView *)view;
- (id)initWithView:(StreamView *)view settings:(TemporarySettings *)settings;
- (void)cancelActiveTouches;

@end

NS_ASSUME_NONNULL_END
