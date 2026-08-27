//
//  DinhViColorPickerViewController.h
//  IMGUIDELTA
//
//  Color picker cho Định Vị Súng tự chọn màu (preset 3).
//  Server generate_dinhvi.php patch shader → IPA nhận binary → AutoPasteManager paste.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** Callback: success=YES và msg="✅ ..." nếu paste xong; NO + msg lỗi nếu thất bại. */
typedef void(^DinhViColorCompletion)(BOOL success, NSString *message);

@interface DinhViColorPickerViewController : UIViewController

/** "th" hoặc "max" */
@property (nonatomic, copy) NSString *game;

/** Thư mục gốc tìm file shader trong Documents (truyền rtTH / rtMax từ HUDControl) */
@property (nonatomic, copy) NSString *searchRoot;

/** Callback sau khi paste xong */
@property (nonatomic, copy, nullable) DinhViColorCompletion completion;

+ (instancetype)pickerForGame:(NSString *)game
                   searchRoot:(NSString *)searchRoot
                   completion:(DinhViColorCompletion)completion;

@end

NS_ASSUME_NONNULL_END
