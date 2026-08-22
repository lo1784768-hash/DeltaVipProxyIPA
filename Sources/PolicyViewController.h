#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Full-screen glassmorphism sheet — "Chính Sách & Điều Khoản Sử Dụng"
@interface PolicyViewController : UIViewController

/// YES nếu người dùng đã từng chấp nhận (lưu UserDefaults key "policy_accepted")
+ (BOOL)hasAccepted;

@end

NS_ASSUME_NONNULL_END
