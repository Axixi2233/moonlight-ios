//
//  MicUplinkManager.h
//  Moonlight
//

#import <Foundation/Foundation.h>

@class StreamConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef void (^MicUplinkStartCompletion)(BOOL started, NSString * _Nullable message);

@interface MicUplinkManager : NSObject

@property (atomic, readonly, getter=isRunning) BOOL running;

- (instancetype)initWithStreamConfig:(StreamConfiguration *)config;
- (void)startWithCompletion:(MicUplinkStartCompletion)completion;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
