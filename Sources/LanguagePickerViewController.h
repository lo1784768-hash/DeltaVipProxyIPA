#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Bottom-sheet chọn ngôn ngữ — dùng cho first-launch và Settings.
/// Tự dismiss sau khi user bấm chọn.
@interface LanguagePickerViewController : UIViewController
/// Callback sau khi dismiss (optional)
@property (nonatomic, copy, nullable) void (^onDismiss)(void);
@end

NS_ASSUME_NONNULL_END
