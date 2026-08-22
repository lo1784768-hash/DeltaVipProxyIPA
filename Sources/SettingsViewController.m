#import "SettingsViewController.h"
#import "BrandTheme.h"
#import "Endpoints.h"
#import "KeyManager.h"
#import "LanguageManager.h"
#import <sys/utsname.h>

// ── Liên hệ — chỉnh lại URL thực tế ────────────────────────────────────────
static NSString *const kContactZalo     = @"https://zalo.me/deltaipavn";
static NSString *const kContactTelegram = @"https://t.me/deltaipavn";
static NSString *const kContactFacebook = @"https://fb.me/deltaipavn";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - SettingsRow (touch-interactive glass row)

@interface SettingsRow : UIView
- (instancetype)initWithSymbol:(NSString *)symbol
                          tint:(UIColor *)tint
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                        action:(void (^)(void))action;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SettingsRow {
    UIView *_chipView;
    CAGradientLayer *_chipGrad;
    void (^_action)(void);
    UIView *_bg;
}

- (instancetype)initWithSymbol:(NSString *)symbol
                          tint:(UIColor *)tint
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                        action:(void (^)(void))action {
    self = [super init];
    if (!self) return nil;
    _action = [action copy];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;

    // Pressed glow background
    _bg = [[UIView alloc] init];
    _bg.backgroundColor = [tint colorWithAlphaComponent:0.0];
    _bg.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_bg];

    // Icon chip
    _chipView = [[UIView alloc] init];
    _chipView.layer.cornerRadius  = 10;
    _chipView.layer.cornerCurve   = kCACornerCurveContinuous;
    _chipView.layer.shadowColor   = tint.CGColor;
    _chipView.layer.shadowOpacity = 0.55;
    _chipView.layer.shadowRadius  = 6;
    _chipView.layer.shadowOffset  = CGSizeMake(0, 2);
    _chipView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_chipView];

    _chipGrad = [CAGradientLayer layer];
    CGFloat r, g, b, a;
    [tint getRed:&r green:&g blue:&b alpha:&a];
    UIColor *light = [UIColor colorWithRed:MIN(r+0.25,1) green:MIN(g+0.25,1) blue:MIN(b+0.25,1) alpha:1];
    UIColor *dark  = [UIColor colorWithRed:r*0.65 green:g*0.65 blue:b*0.65 alpha:1];
    _chipGrad.colors      = @[(id)light.CGColor, (id)dark.CGColor];
    _chipGrad.startPoint  = CGPointMake(0, 0);
    _chipGrad.endPoint    = CGPointMake(1, 1);
    _chipGrad.cornerRadius = 10;
    [_chipView.layer insertSublayer:_chipGrad atIndex:0];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:symCfg]];
    icon.tintColor   = [UIColor whiteColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [_chipView addSubview:icon];

    // Title
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text      = title;
    titleLbl.font      = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLbl.textColor = BRAND_TEXT;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:titleLbl];

    // Subtitle
    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.text      = subtitle;
    subLbl.font      = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    subLbl.textColor = BRAND_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:subLbl];

    // Chevron
    UIImageSymbolConfiguration *chvCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:chvCfg]];
    chevron.tintColor   = [BRAND_MUTED colorWithAlphaComponent:0.5];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:chevron];

    // Spinner (hidden, shown during async work)
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color = tint;
    _spinner.hidesWhenStopped = YES;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:60],

        [_bg.topAnchor    constraintEqualToAnchor:self.topAnchor],
        [_bg.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_bg.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_bg.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [_chipView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_chipView.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
        [_chipView.widthAnchor    constraintEqualToConstant:36],
        [_chipView.heightAnchor   constraintEqualToConstant:36],

        [icon.centerXAnchor constraintEqualToAnchor:_chipView.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:_chipView.centerYAnchor],

        [titleLbl.leadingAnchor constraintEqualToAnchor:_chipView.trailingAnchor constant:14],
        [titleLbl.bottomAnchor  constraintEqualToAnchor:self.centerYAnchor constant:-1],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-8],

        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.topAnchor     constraintEqualToAnchor:self.centerYAnchor constant:3],
        [subLbl.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-8],

        [chevron.trailingAnchor  constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [chevron.centerYAnchor   constraintEqualToAnchor:self.centerYAnchor],
        [chevron.widthAnchor     constraintEqualToConstant:14],

        [_spinner.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_spinner.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _chipGrad.frame = _chipView.bounds;
    _bg.layer.cornerRadius = 0;
}

- (void)handleTap {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (_action) _action();
}

// Press highlight
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self->_bg.backgroundColor = [self->_bg.backgroundColor colorWithAlphaComponent:0.06];
        self.transform = CGAffineTransformMakeScale(0.98, 0.98);
    }];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.15 animations:^{
        self->_bg.backgroundColor = [UIColor clearColor];
        self.transform = CGAffineTransformIdentity;
    }];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.15 animations:^{
        self->_bg.backgroundColor = [UIColor clearColor];
        self.transform = CGAffineTransformIdentity;
    }];
}
@end

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - SettingsViewController

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildUI];
}

- (void)buildUI {
    // Full-bleed glass background
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:blur];
    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor    constraintEqualToAnchor:self.view.topAnchor],
        [blur.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Dark overlay
    UIView *overlay = [[UIView alloc] init];
    overlay.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:0.65];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [blur.contentView addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor    constraintEqualToAnchor:blur.contentView.topAnchor],
        [overlay.leadingAnchor  constraintEqualToAnchor:blur.contentView.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
    ]];

    UIView *root = blur.contentView;

    // ── Header ──────────────────────────────────────────────────────────────
    UIView *headerChip = [[UIView alloc] init];
    headerChip.layer.cornerRadius = 14;
    headerChip.layer.cornerCurve = kCACornerCurveContinuous;
    headerChip.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:headerChip];

    CAGradientLayer *chipGrad = [CAGradientLayer layer];
    chipGrad.colors      = @[(id)BRAND_PURPLE.CGColor, (id)[BRAND_PURPLE colorWithAlphaComponent:0.5].CGColor];
    chipGrad.startPoint  = CGPointMake(0, 0);
    chipGrad.endPoint    = CGPointMake(1, 1);
    chipGrad.cornerRadius = 14;
    [headerChip.layer insertSublayer:chipGrad atIndex:0];

    UIImageSymbolConfiguration *gearCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImageView *gearIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"gear" withConfiguration:gearCfg]];
    gearIcon.tintColor   = [UIColor whiteColor];
    gearIcon.contentMode = UIViewContentModeScaleAspectFit;
    gearIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [headerChip addSubview:gearIcon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text      = @"Cài Đặt";
    titleLbl.font      = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    titleLbl.textColor = BRAND_TEXT;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:titleLbl];

    NSString *appVer = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"1.3.6";
    UILabel *verLbl = [[UILabel alloc] init];
    verLbl.text      = [NSString stringWithFormat:@"DELTA IPA VN  v%@", appVer];
    verLbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    verLbl.textColor = BRAND_MUTED;
    verLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:verLbl];

    // ── Settings card ────────────────────────────────────────────────────────
    UIVisualEffectView *card = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    card.clipsToBounds    = YES;
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    card.layer.borderWidth  = 1;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:card];

    UIView *cc = card.contentView;

    // ── Build rows ───────────────────────────────────────────────────────────
    __weak typeof(self) weakSelf = self;

    SettingsRow *updateRow = [[SettingsRow alloc]
        initWithSymbol:@"arrow.triangle.2.circlepath"
                  tint:BRAND_CYAN
                 title:LS(@"Kiểm Tra Cập Nhật", @"Check for Updates")
              subtitle:LS(@"So sánh với server", @"Compare with server")
                action:^{ [weakSelf checkForUpdate]; }];

    SettingsRow *cacheRow = [[SettingsRow alloc]
        initWithSymbol:@"trash.fill"
                  tint:[UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0]
                 title:LS(@"Xoá Bộ Nhớ Đệm", @"Clear Cache")
              subtitle:LS(@"File tạm + ảnh đã tải", @"Temp files + downloaded images")
                action:^{ [weakSelf clearCache]; }];

    SettingsRow *contactRow = [[SettingsRow alloc]
        initWithSymbol:@"message.fill"
                  tint:[UIColor colorWithRed:0.2 green:0.85 blue:0.4 alpha:1.0]
                 title:LS(@"Liên Hệ Hỗ Trợ", @"Contact Support")
              subtitle:LS(@"Zalo · Telegram · Facebook", @"Zalo · Telegram · Facebook")
                action:^{ [weakSelf openContact]; }];

    SettingsRow *infoRow = [[SettingsRow alloc]
        initWithSymbol:@"info.circle.fill"
                  tint:BRAND_PURPLE
                 title:LS(@"Thông Tin Ứng Dụng", @"App Info")
              subtitle:LS(@"Phiên bản · Thiết bị · ID", @"Version · Device · ID")
                action:^{ [weakSelf showAppInfo]; }];

    NSArray<SettingsRow *> *rows = @[updateRow, cacheRow, contactRow, infoRow];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:rows];
    stack.axis         = UILayoutConstraintAxisVertical;
    stack.spacing      = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cc addSubview:stack];

    // Hairline separators between rows
    for (NSUInteger i = 0; i + 1 < rows.count; i++) {
        UIView *line = [[UIView alloc] init];
        line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [cc addSubview:line];
        SettingsRow *row = rows[i];
        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor  constraintEqualToAnchor:cc.leadingAnchor  constant:66],
            [line.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-16],
            [line.bottomAnchor   constraintEqualToAnchor:row.bottomAnchor],
            [line.heightAnchor   constraintEqualToConstant:0.5],
        ]];
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [headerChip.topAnchor    constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:28],
        [headerChip.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor constant:20],
        [headerChip.widthAnchor  constraintEqualToConstant:52],
        [headerChip.heightAnchor constraintEqualToConstant:52],

        [gearIcon.centerXAnchor constraintEqualToAnchor:headerChip.centerXAnchor],
        [gearIcon.centerYAnchor constraintEqualToAnchor:headerChip.centerYAnchor],

        [titleLbl.leadingAnchor constraintEqualToAnchor:headerChip.trailingAnchor constant:14],
        [titleLbl.bottomAnchor  constraintEqualToAnchor:headerChip.centerYAnchor constant:-1],

        [verLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [verLbl.topAnchor     constraintEqualToAnchor:headerChip.centerYAnchor constant:3],

        [card.topAnchor     constraintEqualToAnchor:headerChip.bottomAnchor constant:24],
        [card.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor  constant:16],
        [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],

        [stack.topAnchor    constraintEqualToAnchor:cc.topAnchor],
        [stack.leadingAnchor  constraintEqualToAnchor:cc.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:cc.bottomAnchor],
    ]];

    // Neon top line trên card (purple → cyan)
    CAGradientLayer *topLine = [CAGradientLayer layer];
    topLine.colors     = @[(id)[BRAND_PURPLE colorWithAlphaComponent:0.0].CGColor,
                           (id)BRAND_PURPLE.CGColor,
                           (id)BRAND_CYAN.CGColor,
                           (id)[BRAND_CYAN colorWithAlphaComponent:0.0].CGColor];
    topLine.startPoint = CGPointMake(0, 0.5);
    topLine.endPoint   = CGPointMake(1, 0.5);
    topLine.frame      = CGRectMake(20, 0, 0, 1);  // width set in viewDidLayoutSubviews
    topLine.name       = @"topLine";
    [card.layer addSublayer:topLine];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Cập nhật chip gradient frame (không có clipsToBounds trên wrapper)
    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *blurV = (UIVisualEffectView *)sub;
            for (UIView *card in blurV.contentView.subviews) {
                if ([card isKindOfClass:[UIVisualEffectView class]]) {
                    // Neon top line
                    for (CALayer *layer in card.layer.sublayers) {
                        if ([layer.name isEqualToString:@"topLine"]) {
                            layer.frame = CGRectMake(20, 0, card.bounds.size.width - 40, 1);
                        }
                    }
                }
            }
        }
    }
}

// ── Actions ──────────────────────────────────────────────────────────────────

- (void)checkForUpdate {
    NSURL *url = [NSURL URLWithString:EndpointVersion()];
    if (!url) return;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *r, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) {
                [weakSelf showAlert:LS(@"Lỗi Kết Nối", @"Connection Error")
                            message:LS(@"Không thể kiểm tra cập nhật.\nVui lòng thử lại sau.", @"Could not check for updates.\nPlease try again later.")];
                return;
            }
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *latest  = j[@"version_latest"] ?: j[@"version"];
            NSString *current = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"1.3.6";
            if (latest.length && ![latest isEqualToString:current]) {
                [weakSelf showAlert:LS(@"Có Bản Mới! 🎉", @"New Version Available! 🎉")
                            message:[NSString stringWithFormat:
                                LS(@"Phiên bản %@ đã sẵn sàng.\nBạn đang dùng %@.\n\nVui lòng cập nhật để có tính năng mới nhất.",
                                   @"Version %@ is available.\nYou are on %@.\n\nPlease update for the latest features."),
                                latest, current]];
            } else {
                [weakSelf showAlert:LS(@"Đã Cập Nhật ✓", @"Up to Date ✓")
                            message:[NSString stringWithFormat:
                                LS(@"Bạn đang dùng phiên bản mới nhất (%@).", @"You are on the latest version (%@)."), current]];
            }
        });
    }];
    [task resume];
}

- (void)clearCache {
    // URL cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];

    // Temp directory
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp     = NSTemporaryDirectory();
    NSArray  *files   = [fm contentsOfDirectoryAtPath:tmp error:nil] ?: @[];
    NSInteger deleted = 0;
    for (NSString *f in files) {
        if ([fm removeItemAtPath:[tmp stringByAppendingPathComponent:f] error:nil]) deleted++;
    }

    // Caches directory
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSArray  *cacheFiles = [fm contentsOfDirectoryAtPath:caches error:nil] ?: @[];
    for (NSString *f in cacheFiles) {
        NSString *path = [caches stringByAppendingPathComponent:f];
        BOOL isDir = NO;
        [fm fileExistsAtPath:path isDirectory:&isDir];
        if (!isDir) { // Chỉ xoá file, giữ lại folder con (WebKit cache, v.v.)
            if ([fm removeItemAtPath:path error:nil]) deleted++;
        }
    }

    [self showAlert:LS(@"Đã Xoá ✓", @"Cleared ✓")
            message:[NSString stringWithFormat:
                LS(@"Đã xoá %ld file tạm và làm sạch bộ nhớ đệm.", @"Cleared %ld temporary files and cache."),
                (long)deleted]];
}

- (void)openContact {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:LS(@"Liên Hệ Hỗ Trợ", @"Contact Support")
        message:LS(@"Chọn kênh hỗ trợ bạn muốn liên hệ", @"Choose a support channel")
        preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"💬  Zalo"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kContactZalo]
                options:@{} completionHandler:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"✈️  Telegram"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kContactTelegram]
                options:@{} completionHandler:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"📘  Facebook"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kContactFacebook]
                options:@{} completionHandler:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LS(@"Huỷ", @"Cancel")
        style:UIAlertActionStyleCancel handler:nil]];

    // iPad popover anchor
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, 200, 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showAppInfo {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *ver    = info[@"CFBundleShortVersionString"] ?: @"1.3.6";
    NSString *build  = info[@"CFBundleVersion"] ?: @"1";
    NSString *ios    = [[UIDevice currentDevice] systemVersion];
    NSString *device = [self deviceModelIdentifier];
    NSString *udid   = [[KeyManager shared] deviceUDID] ?: @"—";
    NSString *udidMasked = udid.length > 8
        ? [NSString stringWithFormat:@"%@••••%@", [udid substringToIndex:4], [udid substringFromIndex:udid.length-4]]
        : udid;

    NSString *msg = [NSString stringWithFormat:
        @"Phiên bản:  %@ (build %@)\n"
        @"iOS:            %@\n"
        @"Thiết bị:     %@\n"
        @"Device ID:  %@",
        ver, build, ios, device, udidMasked];

    [self showAlert:LS(@"Thông Tin Ứng Dụng", @"App Information") message:msg];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)deviceModelIdentifier {
    struct utsname sys; uname(&sys);
    return [NSString stringWithUTF8String:sys.machine] ?: [[UIDevice currentDevice] model];
}

@end
