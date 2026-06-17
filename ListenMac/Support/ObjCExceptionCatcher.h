#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridges Objective-C exceptions into Swift-catchable errors.
///
/// Some AVAudioEngine calls (e.g. `installTapOnBus:bufferSize:format:block:`) raise
/// `NSException`s on invalid audio state. Swift's `do/catch` cannot intercept Obj-C
/// exceptions, so without this they terminate the entire app. Wrap the risky call in
/// `perform:` and handle the thrown `NSError` in Swift instead.
@interface ObjCExceptionCatcher : NSObject

+ (BOOL)perform:(NS_NOESCAPE void (^)(void))block
          error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
