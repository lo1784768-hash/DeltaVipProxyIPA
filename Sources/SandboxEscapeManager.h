#ifndef SandboxEscapeManager_h
#define SandboxEscapeManager_h

#import <Foundation/Foundation.h>

/**
 * SandboxEscapeManager — wrapper chạy kexploit + sandbox escape cho app độc lập.
 *
 * Gọi sớm nhất có thể trong AppDelegate sau UIApplicationDidFinishLaunching.
 * Chỉ cần gọi 1 lần; dispatch_once đảm bảo không chạy lại.
 *
 * Sau khi escape thành công:
 *   - Process có thể đọc/ghi /var/mobile/ và /var/containers/...
 *   - SandboxEscapeManager.containerPathForBundleID: hoạt động mà không cần MCM.
 */
@interface SandboxEscapeManager : NSObject

/** Trạng thái escape. */
@property (class, nonatomic, assign, readonly) BOOL escaped;

/**
 * Chạy kernel exploit + sandbox escape trên background thread.
 * completion được gọi trên main thread với kết quả (YES = thành công).
 */
+ (void)runEscapeWithCompletion:(void (^)(BOOL success))completion;

/**
 * Tìm data container path của app theo bundleID bằng cách đọc metadata plists.
 * Yêu cầu sandbox đã escaped; trả nil nếu không tìm thấy.
 */
+ (NSString *)containerPathForBundleID:(NSString *)bundleID;

@end

#endif /* SandboxEscapeManager_h */
