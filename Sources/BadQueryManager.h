#ifndef BadQueryManager_h
#define BadQueryManager_h

#import <Foundation/Foundation.h>

/**
 * BadQueryManager — Cơ chế C: sandbox escape qua containermanager path traversal.
 *
 * Hoạt động trên iOS 26.0–26.6.1 (xác nhận), có thể hoạt động trên iOS 18.0+ (chưa test).
 * Không cần kernel exploit. Dùng khi kexploit_opa334 không có offsets cho phiên bản iOS.
 *
 * Sử dụng:
 *   1. Gọi [BadQueryManager activateWithCompletion:] một lần khi khởi động.
 *   2. Kiểm tra [BadQueryManager active] trước khi dùng containerPathForBundleID:.
 */
@interface BadQueryManager : NSObject

/** YES nếu bad_query đã consume extension thành công (ít nhất 1 route). */
@property (class, nonatomic, assign, readonly) BOOL active;

/**
 * Thử kích hoạt bad_query sandbox escape.
 * Thử 2 route: SystemGroup (class 13) rồi AppGroup (class 7 với group.com.imguidelta).
 * completion gọi trên main thread với YES = thành công, NO = thất bại.
 * Gọi lại nhiều lần sau khi đã active là no-op.
 */
+ (void)activateWithCompletion:(void (^ _Nullable)(BOOL success))completion;

/**
 * Tìm Data container path cho bundleID bằng cách đọc metadata plists.
 * Yêu cầu [BadQueryManager active] == YES.
 * Trả nil nếu không tìm thấy.
 */
+ (nullable NSString *)containerPathForBundleID:(NSString * _Nonnull)bundleID;

/**
 * Trả về dict bundleID → containerPath cho toàn bộ app.
 * Yêu cầu [BadQueryManager active] == YES.
 */
+ (NSDictionary<NSString *, NSString *> * _Nonnull)allContainerPaths;

/**
 * Chạy test nhanh tất cả các route và trả về string log để debug.
 * Không cần active. Dùng để test trực tiếp từ UI.
 */
+ (NSString * _Nonnull)runDiagnostic;

@end

#endif /* BadQueryManager_h */
