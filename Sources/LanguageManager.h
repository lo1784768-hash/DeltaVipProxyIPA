#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AppLanguage) {
    AppLanguageVietnamese = 0,
    AppLanguageEnglish    = 1,
};

/// Posted on the main thread whenever the language preference changes.
extern NSString * const LMLanguageChangedNotification;

@interface LanguageManager : NSObject
+ (instancetype)shared;
/// Current language. Setting this persists to NSUserDefaults and posts LMLanguageChangedNotification.
@property (nonatomic) AppLanguage language;
/// Returns vi if current language is Vietnamese, en if English.
- (NSString *)vi:(NSString *)vi en:(NSString *)en;
@end

/// Shorthand: LS(@"Tiếng Việt", @"English text")
/// NOTE: tham số dùng _vi/_en để tránh preprocessor thay nhầm vào selector vi:/en:
#define LS(_vi, _en) [[LanguageManager shared] vi:(_vi) en:(_en)]
