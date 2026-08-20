/*
 * SEPKeyStoreProbe.h
 *
 * Kiểm tra xem sandboxed app có thể access "AppleKeyStore" IOKit service không.
 * Nếu được → CVE-2026-20637 (IOCommandGate UAF) có thể exploit từ trong app.
 *
 * Kết quả trả về:
 *   - Mỗi bước (match / open / call) thành công hay thất bại
 *   - Error codes cụ thể để phân biệt "sandbox block" vs "service not found"
 */

#ifndef SEPKeyStoreProbe_h
#define SEPKeyStoreProbe_h

#import <Foundation/Foundation.h>

@interface SEPKeyStoreProbe : NSObject

/**
 * Chạy đầy đủ probe: IOServiceGetMatchingService → IOServiceOpen → IOConnectCallMethod
 * Trả về string log chi tiết.
 */
+ (NSString * _Nonnull)runProbe;

@end

#endif /* SEPKeyStoreProbe_h */
