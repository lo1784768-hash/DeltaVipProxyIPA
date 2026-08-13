#import <Foundation/Foundation.h>

@interface AutoPasteManager : NSObject

+ (instancetype)sharedManager;

// Generic: download a file from a URL and write it to a path relative to the
// app's Documents directory (overwrites if it exists).
- (void)pasteFromURL:(NSString *)urlString
      toRelativePath:(NSString *)relativePath
          completion:(void (^)(BOOL success, NSString *message))completion;

@end
