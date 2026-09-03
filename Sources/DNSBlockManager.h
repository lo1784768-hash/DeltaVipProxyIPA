#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^DNSBlock)(BOOL success, NSError * _Nullable error);

@interface DNSBlockManager : NSObject

+ (instancetype)shared;

/// Trạng thái hiện tại (YES = profile DNS đang bật)
@property (nonatomic, readonly) BOOL isEnabled;

/// Bật DNS profile NextDNS — hiện popup confirm nếu chưa cài
- (void)enableWithCompletion:(DNSBlock)completion;

/// Tắt DNS profile NextDNS
- (void)disableWithCompletion:(DNSBlock)completion;

/// Load trạng thái từ hệ thống (gọi khi app mở)
/// installed = profile đã cài, active = đang được chọn trong Settings > DNS
- (void)refreshStatusWithCompletion:(void(^)(BOOL installed, BOOL active))completion;

@end

NS_ASSUME_NONNULL_END
