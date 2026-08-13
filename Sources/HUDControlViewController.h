#import <UIKit/UIKit.h>

@interface HUDControlViewController : UIViewController

- (instancetype)initWithBundleID:(NSString *)bundleID
                         appName:(NSString *)appName
                            icon:(UIImage *)icon;

@end
