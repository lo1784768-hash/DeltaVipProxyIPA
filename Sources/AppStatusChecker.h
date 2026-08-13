#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Check if app is currently running

@interface AppStatusChecker : NSObject

+ (instancetype)sharedChecker;

// Check if app with given bundle ID is running
- (BOOL)isAppRunning:(NSString *)bundleID;

// Get app icon
- (UIImage *)iconForApp:(NSString *)bundleID;

// Get app display name
- (NSString *)displayNameForApp:(NSString *)bundleID;

@end
