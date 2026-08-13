#import <Foundation/Foundation.h>

@interface AutoPasteManager : NSObject

+ (instancetype)sharedManager;

// Tải file từ URL rồi TÌM file theo TÊN trong thư mục (đệ quy) và ghi đè vào
// mọi vị trí tìm thấy. relativeRoot là thư mục gốc để tìm (tương đối với
// Documents của app); nil = tìm toàn bộ Documents.
- (void)pasteFromURL:(NSString *)urlString
           fileNamed:(NSString *)fileName
           underRoot:(NSString *)relativeRoot
          completion:(void (^)(BOOL success, NSString *message))completion;

@end
