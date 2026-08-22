#import <UIKit/UIKit.h>

@interface KeyBarView : UIView
@property (nonatomic, copy) void (^onAddTapped)(void);
@property (nonatomic, copy) void (^onInfoTapped)(void);    // xem/copy UDID
@property (nonatomic, copy) void (^onPolicyTapped)(void);  // mở PolicyViewController
- (void)update;   // đọc lại trạng thái từ KeyManager và làm mới UI
@end
