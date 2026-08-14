#ifndef MCMFilzaIntegration_h
#define MCMFilzaIntegration_h

#import <Foundation/Foundation.h>

// High-level MCM integration for Filza-like file management

// ── Khởi tạo ────────────────────────────────────────────────────────────────

// [1] Gọi TRƯỚC MCMFilzaStart — báo hiệu sandbox escape đã chạy thành công.
//     Nếu kexploit/ chạy OK: gọi MCMFilzaSetUnrestrictedFilesystem(YES).
//     Nếu chưa có exploit: vẫn gọi (sẽ fallback về LSApplicationProxy).
void MCMFilzaSetUnrestrictedFilesystem(BOOL enabled);
BOOL MCMFilzaIsUnrestricted(void);

// [2] Khởi tạo MCM bridge (load dylib + function ptrs). Gọi sau [1].
void MCMFilzaStart(void);

// ── Filesystem ───────────────────────────────────────────────────────────────

// Virtual root: ~/Documents/Device Storage
NSString *MCMFilzaVirtualRoot(void);

// Container path cho appID (e.g. "com.dts.freefireth").
// Thử theo thứ tự:
//   1. MCM C API + sandbox extension activation (iOS 17-)
//   2. LSApplicationProxy.dataContainerURL (fallback iOS 18+)
// Trả nil + *error nếu thất bại.
NSString *MCMFilzaDataContainerPath(NSString *appID, NSString **error);

// Token sandbox cho container (sử dụng nội bộ).
void *MCMFilzaGetSandboxToken(NSString *appID);

#endif /* MCMFilzaIntegration_h */
