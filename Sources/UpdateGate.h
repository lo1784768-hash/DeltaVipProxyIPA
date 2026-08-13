#import <UIKit/UIKit.h>

// Kiểm tra phiên bản với server; nếu app CŨ hơn min_version thì hiện màn hình
// chặn (không cho dùng) + nút mở link cập nhật.
@interface UpdateGate : NSObject
+ (void)checkFromViewController:(UIViewController *)host;
@end
