#import "LanguageManager.h"

NSString * const LMLanguageChangedNotification = @"LMLanguageChangedNotification";
static NSString * const kLangKey = @"app_language";

@implementation LanguageManager

+ (instancetype)shared {
    static LanguageManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _language = (AppLanguage)[[NSUserDefaults standardUserDefaults] integerForKey:kLangKey];
    }
    return self;
}

- (void)setLanguage:(AppLanguage)language {
    if (_language == language) return;
    _language = language;
    [[NSUserDefaults standardUserDefaults] setInteger:language forKey:kLangKey];
    // Post synchronously — setLanguage luôn được gọi từ main thread (UI action)
    // dispatch_async ở đây gây race: VC có thể bị deallocate trước khi notification đến
    [[NSNotificationCenter defaultCenter]
        postNotificationName:LMLanguageChangedNotification object:nil];
}

- (NSString *)vi:(NSString *)vi en:(NSString *)en {
    return (_language == AppLanguageEnglish) ? en : vi;
}

@end
