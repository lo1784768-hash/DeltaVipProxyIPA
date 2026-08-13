#import <Foundation/Foundation.h>

// Nơi lưu dữ liệu app NẰM NGOÀI Documents để dù bật UIFileSharingEnabled cũng
// không lộ gì (File Sharing chỉ soi được thư mục Documents).

// ~/Library/Application Support
static inline NSString *AppHiddenDataBase(void) {
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    return base;
}

// ~/Library/Application Support/Device Storage  (thay cho ~/Documents/Device Storage)
static inline NSString *AppHiddenDataRoot(void) {
    NSString *root = [AppHiddenDataBase() stringByAppendingPathComponent:@"Device Storage"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
}

// ~/Library/Caches  (cho ảnh, log — cũng không lộ qua File Sharing)
static inline NSString *AppHiddenCache(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}
