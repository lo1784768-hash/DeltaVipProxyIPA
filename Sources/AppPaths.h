#import <Foundation/Foundation.h>

// Virtual FS (Device Storage) PHẢI nằm ở ~/Documents vì MCM/exploit đọc data game
// theo đúng path này (dời đi -> app không thấy game). Dùng NSHomeDirectory như bản
// gốc MCMFilzaVirtualRoot để nhất quán khi đã thoát sandbox.
// (Dữ liệu nhạy cảm — key/endpoint — đã được bảo vệ nơi khác: Keychain + mã hoá.
//  Ảnh & log để ở ~/Library/Caches, không lộ qua File Sharing.)

// ~/Documents
static inline NSString *AppHiddenDataBase(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
}

// ~/Documents/Device Storage
static inline NSString *AppHiddenDataRoot(void) {
    NSString *root = [AppHiddenDataBase() stringByAppendingPathComponent:@"Device Storage"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
}

// ~/Library/Caches  (cho ảnh, log — không lộ qua File Sharing)
static inline NSString *AppHiddenCache(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}
