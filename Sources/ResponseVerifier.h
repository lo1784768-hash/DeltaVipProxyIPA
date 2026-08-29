#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ResponseVerifier — Verify HMAC chữ ký trên response từ check_key.php
 *
 * Server thêm `rsig` = HMAC-SHA256(canonical, RESP_SECRET) vào mỗi response.
 * App phải verify trước khi accept → cracker fake JSON local sẽ không tạo được rsig đúng.
 */
@interface ResponseVerifier : NSObject

/// Verify JSON response dict có rsig hợp lệ không.
/// Trả YES nếu hợp lệ, NO nếu bị fake/tampered.
+ (BOOL)verifyResponse:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END
