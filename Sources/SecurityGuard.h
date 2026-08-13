#import <Foundation/Foundation.h>

// Lớp bảo vệ: chống debug / Frida / tiêm dylib / crack.
@interface SecurityGuard : NSObject

// Gọi sớm nhất trong AppDelegate: chặn debugger + bật giám sát định kỳ.
+ (void)activate;

// Môi trường có sạch không (dùng để khoá chức năng mod nếu bị can thiệp).
+ (BOOL)isEnvironmentTrusted;

@end
