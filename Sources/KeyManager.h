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
- (NSTimeInterval)secondsLeft;            // >0 nếu còn hạn
- (NSString *)formattedRemaining;         // "Còn 4 ngày 3 giờ" / "Hết hạn"

// Kích hoạt / kiểm tra 1 key mới (POST key_code + udid tới check_key.php)
- (void)activateKey:(NSString *)key
         completion:(void (^)(BOOL success, NSString *message))completion;

// Kiểm tra lại key hiện đang lưu (nếu có)
- (void)refreshWithCompletion:(void (^)(BOOL success, NSString *message))completion;

@end
