#import <Foundation/Foundation.h>

@interface AutoPasteManager : NSObject

+ (instancetype)sharedManager;

- (void)pasteFileWithServerMode:(BOOL)isServer1
                       bundleID:(NSString *)bundleID
                     completion:(void (^)(BOOL success, NSString *message))completion;

@end
