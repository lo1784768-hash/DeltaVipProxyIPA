#import <UIKit/UIKit.h>

@interface KeyBarView : UIView
@property (nonatomic, copy) void (^onAddTapped)(void);
- (void)update;   // đọc lại trạng thái từ KeyManager và làm mới UI
@end
