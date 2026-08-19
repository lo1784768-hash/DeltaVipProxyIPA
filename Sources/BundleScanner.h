//
//  BundleScanner.h
//  Reads files from other apps' Bundle containers (/var/containers/Bundle/Application/)
//  using the bad_query sandbox escape (iOS 26.0–26.6.1 / 27.0b4).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BundleScanner : NSObject

/// Tìm đường dẫn đến .app bundle của game theo bundle ID.
/// Trả về nil nếu không tìm được hoặc sandbox escape thất bại.
/// @param bundleID  VD: @"com.dts.freefireth" / @"com.dts.freefiremax"
/// @param outHandle Con trỏ nhận sandbox handle — PHẢI gọi releaseHandle: sau khi xong
+ (nullable NSString *)findAppBundlePath:(NSString *)bundleID
                               outHandle:(int64_t *)outHandle;

/// Đọc nội dung file từ Bundle container (read-only).
/// Tự acquire + release sandbox extension.
/// Trả về nil nếu fail.
+ (nullable NSData *)readFileAtPath:(NSString *)absolutePath;

/// Tìm file theo tên trong toàn bộ .app bundle của game.
/// Trả về đường dẫn đầy đủ đến file đầu tiên tìm được, nil nếu không có.
/// @param fileName   VD: @"global-metadata.dat"
/// @param bundleID   VD: @"com.dts.freefireth"
+ (nullable NSString *)findFile:(NSString *)fileName inBundleForApp:(NSString *)bundleID;

/// Diagnostic full: chạy từng bước và trả về chuỗi log chi tiết.
/// Dùng để debug trực tiếp trong alert — không cần xem NSLog.
+ (NSString *)diagnosticForFile:(NSString *)fileName bundleID:(NSString *)bundleID;

/// Release sandbox handle từ findAppBundlePath:outHandle:
+ (void)releaseHandle:(int64_t)handle;

@end

NS_ASSUME_NONNULL_END
