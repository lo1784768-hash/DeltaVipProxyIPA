#import <Foundation/Foundation.h>

@interface AutoPasteManager : NSObject

+ (instancetype)sharedManager;

// Tải file mod qua endpoint CÓ KIỂM TRA key+udid (server tự xác thực, chống crack),
// rồi TÌM file theo TÊN (đệ quy) dưới relativeRoot và ghi đè mọi vị trí.
// feature: body/neck/drag/magic ; isMod = YES(MOD) / NO(GỐC)
- (void)pasteFeature:(NSString *)feature
                 mod:(BOOL)isMod
                game:(NSString *)game
           fileNamed:(NSString *)fileName
           underRoot:(NSString *)relativeRoot
          completion:(void (^)(BOOL success, NSString *message))completion;

// Variant cho Speed: speedFile = tên file cụ thể cần lấy từ pastespeed/ (server phân biệt theo param).
// Khi speedFile = nil thì hoạt động y hệt phương thức trên.
- (void)pasteFeature:(NSString *)feature
                 mod:(BOOL)isMod
                game:(NSString *)game
           fileNamed:(NSString *)fileName
           underRoot:(NSString *)relativeRoot
           speedFile:(NSString *)speedFile
          completion:(void (^)(BOOL success, NSString *message))completion;

// Xoá file trên device theo prefix (phần trước dấu '.', ví dụ "assembly-csharp-patch").
// Duyệt đệ quy underRoot, xoá mọi file mà lastPathComponent.prefix khớp prefixes.
// completion(deletedCount, message) trên main queue.
- (void)deleteFilesWithPrefixes:(NSArray<NSString *> *)prefixes
                      underRoot:(NSString *)relativeRoot
                     completion:(void (^)(NSInteger deletedCount, NSString *message))completion;

@end
