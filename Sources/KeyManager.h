#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, KeyState) {
    KeyStateNone,     // chưa có key
    KeyStateActive,   // còn hạn
    KeyStateExpired   // hết hạn
};

@interface KeyManager : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSString *keyCode;   // key đang lưu (nil nếu chưa có)
@property (nonatomic, readonly) NSDate   *expiry;    // thời điểm hết hạn
@property (nonatomic, readonly) KeyState  state;

- (NSString *)deviceUDID;                 // định danh thiết bị gửi lên server
@property (nonatomic, readonly) BOOL usingHardwareUDID;  // YES = UDID thật, NO = fallback IDFV
- (NSTimeInterval)secondsLeft;            // >0 nếu còn hạn
- (NSString *)formattedRemaining;         // "Còn 4 ngày 3 giờ" / "Hết hạn"

// Kích hoạt / kiểm tra 1 key mới (POST key_code + udid tới check_key.php)
- (void)activateKey:(NSString *)key
         completion:(void (^)(BOOL success, NSString *message))completion;

// Kiểm tra lại key hiện đang lưu (nếu có)
- (void)refreshWithCompletion:(void (^)(BOOL success, NSString *message))completion;

// Admin: gỡ khoá thiết bị (app_udid) cho 1 key (cần mật khẩu admin)
- (void)resetBindForKey:(NSString *)key
              adminPass:(NSString *)pass
             completion:(void (^)(BOOL success, NSString *message))completion;

// ── Confirm flow: key 365/999/9999 ngày cần user đồng ý chuyển sang 3 tháng ──
// pendingConfirmKey != nil sau khi server trả needs_confirm
@property (nonatomic, copy, readonly) NSString *pendingConfirmKey;
@property (nonatomic, copy, readonly) NSString *pendingConfirmMessage;

// Gọi sau khi user bấm "Đồng Ý" — gửi lại key với confirm=1
- (void)confirmPendingActivationWithCompletion:(void (^)(BOOL success, NSString *message))completion;

@end
