#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (BOOL)perform:(NS_NOESCAPE void (^)(void))block
          error:(NSError *_Nullable *_Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            NSString *reason = exception.reason ?: exception.name ?: @"Audio engine error";
            *error = [NSError errorWithDomain:@"com.divyam.listen.AudioEngineException"
                                         code:0
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return NO;
    }
}

@end
