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
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:LMLanguageChangedNotification object:nil];
    });
}

- (NSString *)vi:(NSString *)vi en:(NSString *)en {
    return (_language == AppLanguageEnglish) ? en : vi;
}

@end
