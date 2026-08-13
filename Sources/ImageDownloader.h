#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Download and cache app images from remote URLs

@interface ImageDownloader : NSObject

+ (instancetype)sharedDownloader;

// Download images from URLs and cache locally
- (void)downloadImagesWithCompletion:(void (^)(BOOL success))completion;

// Get cached image by name
- (UIImage *)cachedImageNamed:(NSString *)name;

@end
