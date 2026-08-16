#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * SecurityPinning — hai lớp bảo vệ mạng:
 *
 *  1. SSL Certificate Pinning  : từ chối kết nối tới bất kỳ server nào
 *     không có đúng certificate của chúng ta, dù URL bị patch sang server khác.
 *
 *  2. HMAC-SHA256 Request Signing: mỗi request gửi kèm chữ ký
 *     dựa trên secret nhúng trong binary (XOR-obfuscated). Server từ chối
 *     request không có sig đúng → không thể clone API dù biết URL.
 *
 * Dùng: thay [NSURLSession sharedSession] bằng [SecurityPinning shared].pinnedSession
 *        và thay body string bằng [[SecurityPinning shared] signedBody:rawBody]
 */
@interface SecurityPinning : NSObject <NSURLSessionDelegate>

+ (instancetype)shared;

/// NSURLSession có SSL pinning. Dùng cho mọi request tới server.
@property (nonatomic, readonly) NSURLSession *pinnedSession;

/// Thêm &ts=<unix>&sig=<hmac_hex> vào rawBody và trả về chuỗi đã ký.
- (NSString *)signedBody:(NSString *)rawBody;

@end

NS_ASSUME_NONNULL_END
