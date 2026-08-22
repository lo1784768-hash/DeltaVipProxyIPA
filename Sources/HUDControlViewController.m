#import "HUDControlViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "SecurityGuard.h"
#import "Endpoints.h"
#import "LanguageManager.h"

// ── Palette ─────────────────────────────────────────────
#define HUD_BG_TOP      [UIColor colorWithRed:0.047 green:0.047 blue:0.086 alpha:1.0]
#define HUD_BG_BOTTOM   [UIColor colorWithRed:0.063 green:0.094 blue:0.196 alpha:1.0]
#define HUD_ORANGE      [UIColor colorWithRed:1.000 green:0.361 blue:0.169 alpha:1.0]
#define HUD_CYAN        [UIColor colorWithRed:0.000 green:0.831 blue:1.000 alpha:1.0]
#define HUD_PINK        [UIColor colorWithRed:1.000 green:0.231 blue:0.463 alpha:1.0]
#define HUD_PURPLE      [UIColor colorWithRed:0.659 green:0.333 blue:0.969 alpha:1.0]
#define HUD_MUTED       [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0]
#define HUD_GREEN       [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define HUD_RED         [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define HUD_TEXT        [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0]

// ── Tutorial video URLs — điền link YouTube thực tế ────────────────────────
static NSString *const kTutorialProxyURL = nil; // vd: @"https://youtu.be/XXXX"
static NSString *const kTutorialDragURL  = nil; // vd: @"https://youtu.be/YYYY"

static UIColor *HUDDarken(UIColor *c, CGFloat f) {
    CGFloat r,g,b,a; [c getRed:&r green:&g blue:&b alpha:&a];
    return [UIColor colorWithRed:r*f green:g*f blue:b*f alpha:a];
}
static UIColor *HUDLighten(UIColor *c, CGFloat t) {
    CGFloat r,g,b,a; [c getRed:&r green:&g blue:&b alpha:&a];
    return [UIColor colorWithRed:r+(1-r)*t green:g+(1-g)*t blue:b+(1-b)*t alpha:a];
}

#pragma mark - Feature model

@interface HUDFeature : NSObject
@property (nonatomic, copy)   NSString *symbol;
@property (nonatomic, strong) UIColor  *tint;
@property (nonatomic, copy)   NSString *title;      // VI title (default)
@property (nonatomic, copy)   NSString *subtitle;   // VI subtitle (default)
@property (nonatomic, copy)   NSString *enTitle;    // EN title (nil = same as title)
@property (nonatomic, copy)   NSString *enSubtitle; // EN subtitle (nil = same as subtitle)
@property (nonatomic, copy)   NSString *featureKey;  // body/neck/drag/magic (gửi server)
@property (nonatomic, copy)   NSString *fileName;    // tên file cần tìm & ghi đè
@property (nonatomic, copy)   NSString *searchRoot;  // thư mục gốc để tìm (tương đối Documents)
@property (nonatomic, assign) BOOL exclusive;        // YES = radio trong group; NO = độc lập
@property (nonatomic, copy)   NSString *exclusiveGroup;   // nhóm radio: @"aim" / @"skin" / nil
@property (nonatomic, copy)   NSString *previewImageURL;  // nil = không có nút xem ảnh
@property (nonatomic, readonly) BOOL configured;
@end

@implementation HUDFeature
- (BOOL)configured { return self.featureKey.length && self.fileName.length; }
@end

#pragma mark - Feature row

@class HUDFeatureRow;

@interface HUDFeatureRow : UIView {
    UIView *_chip;
    CAGradientLayer *_chipGradient;
    UIView *_accentBar;
    UIView *_glowBg;
}
@property (nonatomic, strong) HUDFeature *feature;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusDot;
@property (nonatomic, strong) UIButton *previewButton;   // nil nếu không có ảnh preview
@property (nonatomic, strong) UILabel *rowTitleLabel;    // để cập nhật khi đổi ngôn ngữ
@property (nonatomic, strong) UILabel *rowSubtitleLabel; // để cập nhật khi đổi ngôn ngữ
@property (nonatomic, copy)   void (^onChanged)(HUDFeatureRow *row, BOOL isOn);
@property (nonatomic, copy)   void (^onPreviewTapped)(void);
- (instancetype)initWithFeature:(HUDFeature *)feature;
- (void)setLoading:(BOOL)loading;
- (void)showResult:(BOOL)success;
- (void)setActive:(BOOL)active;
- (void)refreshLanguage;   // cập nhật VI/EN label khi ngôn ngữ thay đổi
@end

@implementation HUDFeatureRow

- (instancetype)initWithFeature:(HUDFeature *)feature {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _feature = feature;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        // glow background (fades in when active)
        _glowBg = [[UIView alloc] init];
        _glowBg.backgroundColor = [feature.tint colorWithAlphaComponent:0.10];
        _glowBg.alpha = 0;
        _glowBg.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_glowBg];

        // left neon accent bar (hidden until active)
        _accentBar = [[UIView alloc] init];
        _accentBar.backgroundColor = feature.tint;
        _accentBar.layer.cornerRadius = 1.5;
        _accentBar.layer.shadowColor = feature.tint.CGColor;
        _accentBar.layer.shadowOpacity = 0.9;
        _accentBar.layer.shadowRadius = 5;
        _accentBar.layer.shadowOffset = CGSizeZero;
        _accentBar.alpha = 0;
        _accentBar.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_accentBar];

        // Icon chip — gradient fill + neon glow
        _chip = [[UIView alloc] init];
        _chip.layer.cornerRadius = 9;
        _chip.layer.cornerCurve = kCACornerCurveContinuous;
        _chip.layer.shadowColor = feature.tint.CGColor;
        _chip.layer.shadowOpacity = 0.55;
        _chip.layer.shadowRadius = 7;
        _chip.layer.shadowOffset = CGSizeMake(0, 2);
        _chip.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_chip];

        _chipGradient = [CAGradientLayer layer];
        _chipGradient.colors = @[(id)HUDLighten(feature.tint, 0.25).CGColor, (id)HUDDarken(feature.tint, 0.65).CGColor];
        _chipGradient.startPoint = CGPointMake(0, 0);
        _chipGradient.endPoint   = CGPointMake(1, 1);
        _chipGradient.cornerRadius = 9;
        [_chip.layer insertSublayer:_chipGradient atIndex:0];

        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
        UIImageView *symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:feature.symbol withConfiguration:cfg]];
        symbol.tintColor = [UIColor whiteColor];
        symbol.contentMode = UIViewContentModeScaleAspectFit;
        symbol.translatesAutoresizingMaskIntoConstraints = NO;
        [_chip addSubview:symbol];

        UILabel *title = [[UILabel alloc] init];
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = HUD_TEXT;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:title];
        self.rowTitleLabel = title;

        UILabel *subtitle = [[UILabel alloc] init];
        subtitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        subtitle.textColor = HUD_MUTED;
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:subtitle];
        self.rowSubtitleLabel = subtitle;

        [self refreshLanguage];  // set initial text based on current language

        _statusDot = [[UILabel alloc] init];
        _statusDot.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _statusDot.textAlignment = NSTextAlignmentRight;
        _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_statusDot];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.color = feature.tint;
        _spinner.hidesWhenStopped = YES;
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];

        _toggle = [[UISwitch alloc] init];
        _toggle.onTintColor = feature.tint;
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggle addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggle];

        // Nút xem ảnh preview (photo.fill) — chỉ tạo khi feature có previewImageURL
        if (feature.previewImageURL.length) {
            _previewButton = [UIButton buttonWithType:UIButtonTypeSystem];
            UIImageSymbolConfiguration *pcfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
            [_previewButton setImage:[UIImage systemImageNamed:@"photo.fill" withConfiguration:pcfg] forState:UIControlStateNormal];
            _previewButton.tintColor = [feature.tint colorWithAlphaComponent:0.9];
            _previewButton.backgroundColor = [feature.tint colorWithAlphaComponent:0.12];
            _previewButton.layer.cornerRadius = 8;
            _previewButton.layer.masksToBounds = YES;
            _previewButton.layer.borderColor = [feature.tint colorWithAlphaComponent:0.35].CGColor;
            _previewButton.layer.borderWidth = 1;
            _previewButton.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:_previewButton];
            [_previewButton addTarget:self action:@selector(previewTapped) forControlEvents:UIControlEventTouchUpInside];
        }

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:62],

            [_glowBg.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_glowBg.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-0.5],
            [_glowBg.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_glowBg.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

            [_accentBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_accentBar.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_accentBar.widthAnchor constraintEqualToConstant:3],
            [_accentBar.heightAnchor constraintEqualToConstant:32],

            [_chip.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_chip.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_chip.widthAnchor constraintEqualToConstant:36],
            [_chip.heightAnchor constraintEqualToConstant:36],

            [symbol.centerXAnchor constraintEqualToAnchor:_chip.centerXAnchor],
            [symbol.centerYAnchor constraintEqualToAnchor:_chip.centerYAnchor],

            [title.leadingAnchor constraintEqualToAnchor:_chip.trailingAnchor constant:12],
            [title.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-1],

            [subtitle.leadingAnchor constraintEqualToAnchor:_chip.trailingAnchor constant:12],
            [subtitle.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:2],

            [_toggle.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        // Spinner & statusDot: đứng trái preview button (nếu có), ngược lại đứng trái toggle
        UIView   *dotRef   = _previewButton ?: _toggle;
        CGFloat   dotConst = _previewButton ? -8.0 : -12.0;
        [NSLayoutConstraint activateConstraints:@[
            [_spinner.trailingAnchor constraintEqualToAnchor:dotRef.leadingAnchor constant:dotConst],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_statusDot.trailingAnchor constraintEqualToAnchor:dotRef.leadingAnchor constant:dotConst],
            [_statusDot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_statusDot.widthAnchor constraintEqualToConstant:20],
        ]];
        if (_previewButton) {
            [NSLayoutConstraint activateConstraints:@[
                [_previewButton.trailingAnchor constraintEqualToAnchor:_toggle.leadingAnchor constant:-8],
                [_previewButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [_previewButton.widthAnchor constraintEqualToConstant:30],
                [_previewButton.heightAnchor constraintEqualToConstant:30],
            ]];
        }

        // bottom hairline
        UIView *line = [[UIView alloc] init];
        line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:line];
        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [line.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [line.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [line.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _chipGradient.frame = _chip.bounds;
}

- (void)switchChanged {
    // Scatter check — bẫy inject xảy ra sau khi app đã chạy ổn định
    if (![SecurityGuard isEnvironmentTrusted]) { [SecurityGuard bailOut]; return; }
    if (self.onChanged) self.onChanged(self, self.toggle.isOn);
}

- (void)previewTapped {
    if (self.onPreviewTapped) self.onPreviewTapped();
}

- (void)setActive:(BOOL)active {
    [UIView animateWithDuration:0.25 animations:^{
        self->_glowBg.alpha = active ? 1 : 0;
        self->_accentBar.alpha = active ? 1 : 0;
        self->_chip.layer.shadowOpacity = active ? 0.9 : 0.55;
    }];
}

- (void)setLoading:(BOOL)loading {
    self.toggle.enabled = !loading;
    if (loading) {
        self.statusDot.text = @"";
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

- (void)showResult:(BOOL)success {
    self.statusDot.text = success ? @"✓" : @"✕";
    self.statusDot.textColor = success ? HUD_GREEN : HUD_RED;
}

- (void)refreshLanguage {
    BOOL en = ([LanguageManager shared].language == AppLanguageEnglish);
    self.rowTitleLabel.text    = (en && self.feature.enTitle.length)
        ? self.feature.enTitle    : self.feature.title;
    self.rowSubtitleLabel.text = (en && self.feature.enSubtitle.length)
        ? self.feature.enSubtitle : self.feature.subtitle;
}

@end

#pragma mark - HUD Control View Controller

@interface HUDControlViewController ()
@property (nonatomic, copy)   NSString *bundleID;
@property (nonatomic, copy)   NSString *appName;
@property (nonatomic, strong) UIImage  *icon;
@property (nonatomic, strong) CAGradientLayer *bgGradient;
@property (nonatomic, strong) CAGradientLayer *radialGlow;
@property (nonatomic, strong) UILabel  *statusLabel;
@property (nonatomic, strong) UIButton *openGameButton;
@property (nonatomic, strong) CAGradientLayer *openGameGradient;
@property (nonatomic, strong) NSMutableArray<HUDFeatureRow *> *rows;
// ── Tab UI ──
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;   // 3 segment buttons
@property (nonatomic, strong) NSArray<UIColor *>  *tabTints;     // per-tab neon color
@property (nonatomic, strong) UIView  *panelProxy;
@property (nonatomic, strong) UIView  *panelDinhVi;
@property (nonatomic, strong) UIView  *panelModNV;
@property (nonatomic, strong) UIView  *panelDrag;   // AimDrag — luôn hiển thị bên dưới tab
@property (nonatomic, strong) UILabel *panelDinhViTitleLabel;  // để cập nhật ngôn ngữ
@property (nonatomic, strong) UILabel *panelModNVTitleLabel;   // để cập nhật ngôn ngữ
// ── Sliding segmented bar ──
@property (nonatomic, strong) UIView  *segmentBar;              // outer wrapper (has shadow)
@property (nonatomic, strong) UIView  *segThumb;                // floating pill indicator
@property (nonatomic, strong) NSLayoutConstraint *thumbLeft;    // animated leading
@property (nonatomic, assign) NSInteger pendingThumbTab;        // -1 = nothing pending
@property (nonatomic, strong) NSMutableArray<UILabel *> *segLabels; // for language refresh
@end

// Private API để mở app game theo bundle id
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

@implementation HUDControlViewController

- (instancetype)initWithBundleID:(NSString *)bundleID appName:(NSString *)appName icon:(UIImage *)icon {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _bundleID = [bundleID copy];
        _appName  = [appName copy];
        _icon     = icon;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pendingThumbTab = -1;
    self.title = self.appName;

    self.bgGradient = [CAGradientLayer layer];
    self.bgGradient.colors = @[(id)HUD_BG_TOP.CGColor, (id)HUD_BG_BOTTOM.CGColor];
    self.bgGradient.startPoint = CGPointMake(0.5, 0.0);
    self.bgGradient.endPoint   = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:self.bgGradient atIndex:0];

    // Quầng sáng tím (trên) như web
    self.radialGlow = [CAGradientLayer layer];
    self.radialGlow.type = kCAGradientLayerRadial;
    self.radialGlow.colors = @[(id)[HUD_PURPLE colorWithAlphaComponent:0.32].CGColor,
                               (id)[HUD_PURPLE colorWithAlphaComponent:0.0].CGColor];
    self.radialGlow.startPoint = CGPointMake(0.5, 0.5);
    self.radialGlow.endPoint   = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:self.radialGlow above:self.bgGradient];

    // Faint grid overlay
    UIView *grid = [[UIView alloc] initWithFrame:self.view.bounds];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = [self gridPatternColor];
    grid.userInteractionEnabled = NO;
    [self.view addSubview:grid];

    [self setupNavBarAppearance];
    [self buildUI];
    [self fetchAndShowNotice];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(refreshLocalizedStrings)
        name:LMLanguageChangedNotification
        object:nil];
}

#pragma mark - Thông báo (modal, sửa từ admin)

- (void)fetchAndShowNotice {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:EndpointVersion()]];
    req.timeoutInterval = 12;
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) return;
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![j isKindOfClass:[NSDictionary class]]) return;
        BOOL on = [j[@"notice_enabled"] boolValue];
        NSString *title = j[@"notice_title"] ?: LS(@"Thông Báo", @"Notice");
        NSString *body  = j[@"notice_body"];
        if (on && body.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showNoticeTitle:title body:body]; });
        }
    }];
    [task resume];
}

- (void)showNoticeTitle:(NSString *)title body:(NSString *)body {
    UIView *dim = [[UIView alloc] initWithFrame:self.view.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.0];
    dim.tag = 8801;
    [self.view addSubview:dim];

    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    card.clipsToBounds = YES;
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderColor = [HUD_CYAN colorWithAlphaComponent:0.5].CGColor;
    card.layer.borderWidth = 1;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [dim addSubview:card];
    UIView *cc = card.contentView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    titleLabel.textColor = HUD_CYAN;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cc addSubview:titleLabel];

    UILabel *bodyLabel = [[UILabel alloc] init];
    bodyLabel.text = body;
    bodyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    bodyLabel.textColor = HUD_TEXT;
    bodyLabel.textAlignment = NSTextAlignmentCenter;
    bodyLabel.numberOfLines = 0;
    bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cc addSubview:bodyLabel];

    UIButton *ok = [UIButton buttonWithType:UIButtonTypeSystem];
    [ok setTitle:LS(@"ĐÃ HIỂU", @"GOT IT") forState:UIControlStateNormal];
    [ok setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0] forState:UIControlStateNormal];
    ok.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy];
    ok.layer.cornerRadius = 14;
    ok.clipsToBounds = YES;
    ok.translatesAutoresizingMaskIntoConstraints = NO;
    [ok addTarget:self action:@selector(dismissNotice) forControlEvents:UIControlEventTouchUpInside];
    [cc addSubview:ok];

    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)HUD_PURPLE.CGColor, (id)HUD_CYAN.CGColor];
    g.startPoint = CGPointMake(0, 0.5); g.endPoint = CGPointMake(1, 0.5);
    g.cornerRadius = 14;
    [ok.layer insertSublayer:g atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:dim.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:dim.centerYAnchor],
        [card.leadingAnchor constraintEqualToAnchor:dim.leadingAnchor constant:32],
        [card.trailingAnchor constraintEqualToAnchor:dim.trailingAnchor constant:-32],

        [titleLabel.topAnchor constraintEqualToAnchor:cc.topAnchor constant:22],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cc.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-20],

        [bodyLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14],
        [bodyLabel.leadingAnchor constraintEqualToAnchor:cc.leadingAnchor constant:20],
        [bodyLabel.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-20],

        [ok.topAnchor constraintEqualToAnchor:bodyLabel.bottomAnchor constant:18],
        [ok.leadingAnchor constraintEqualToAnchor:cc.leadingAnchor constant:20],
        [ok.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-20],
        [ok.heightAnchor constraintEqualToConstant:50],
        [ok.bottomAnchor constraintEqualToAnchor:cc.bottomAnchor constant:-20],
    ]];

    [self.view layoutIfNeeded];
    g.frame = ok.bounds;

    [UIView animateWithDuration:0.25 animations:^{
        dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        card.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismissNotice {
    UIView *dim = [self.view viewWithTag:8801];
    if (!dim) return;
    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 0; }
                     completion:^(BOOL f){ [dim removeFromSuperview]; }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgGradient.frame = self.view.bounds;
    CGFloat top = self.view.safeAreaInsets.top;
    self.radialGlow.frame = CGRectMake(self.view.bounds.size.width/2 - 240, top - 60, 480, 480);
    self.openGameGradient.frame = self.openGameButton.bounds;

    // Once the segmented bar has real size, place the thumb at the correct slot
    if (self.pendingThumbTab >= 0 && self.segmentBar.bounds.size.width > 1) {
        NSInteger t = self.pendingThumbTab;
        self.pendingThumbTab = -1;
        [self updateThumbForTab:t animated:NO];
    }
}

- (void)launchGame {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    BOOL ok = NO;
    Class ws = NSClassFromString(@"LSApplicationWorkspace");
    if (ws) {
        id workspace = [ws performSelector:@selector(defaultWorkspace)];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            ok = [workspace openApplicationWithBundleID:self.bundleID];
        }
    }

    if (!ok) {
        [self setStatus:LS(@"⚠️ Không mở được game (mở tay giúp mình nhé)",
                          @"⚠️ Could not open game — please open it manually") color:HUD_RED];
    }
}

// Hiện fullscreen ảnh preview từ URL (tap màn hình để đóng)
- (void)showPreviewURL:(NSString *)urlString {
    UIView *dim = [[UIView alloc] initWithFrame:self.view.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor  = [UIColor colorWithWhite:0 alpha:0];
    dim.tag = 9901;
    [self.view addSubview:dim];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPreview)];
    [dim addGestureRecognizer:tap];

    // Card blur
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    card.clipsToBounds = YES;
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    card.layer.borderWidth  = 1;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [dim addSubview:card];

    UIImageView *imgView = [[UIImageView alloc] init];
    imgView.contentMode = UIViewContentModeScaleAspectFit;
    imgView.clipsToBounds = YES;
    imgView.translatesAutoresizingMaskIntoConstraints = NO;
    imgView.tag = 9902;
    [card.contentView addSubview:imgView];

    UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spin.color = HUD_CYAN;
    spin.translatesAutoresizingMaskIntoConstraints = NO;
    spin.tag = 9903;
    [card.contentView addSubview:spin];
    [spin startAnimating];

    UILabel *closeHint = [[UILabel alloc] init];
    closeHint.text = LS(@"Chạm vào màn hình để đóng", @"Tap anywhere to close");
    closeHint.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    closeHint.textColor = HUD_MUTED;
    closeHint.textAlignment = NSTextAlignmentCenter;
    closeHint.translatesAutoresizingMaskIntoConstraints = NO;
    [dim addSubview:closeHint];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:dim.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:dim.centerYAnchor constant:-20],
        [card.widthAnchor   constraintEqualToAnchor:dim.widthAnchor multiplier:0.88],
        [card.heightAnchor  constraintEqualToAnchor:card.widthAnchor multiplier:1.3],

        [imgView.topAnchor      constraintEqualToAnchor:card.contentView.topAnchor constant:8],
        [imgView.leadingAnchor  constraintEqualToAnchor:card.contentView.leadingAnchor constant:8],
        [imgView.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-8],
        [imgView.bottomAnchor   constraintEqualToAnchor:card.contentView.bottomAnchor constant:-8],

        [spin.centerXAnchor constraintEqualToAnchor:card.contentView.centerXAnchor],
        [spin.centerYAnchor constraintEqualToAnchor:card.contentView.centerYAnchor],

        [closeHint.topAnchor    constraintEqualToAnchor:card.bottomAnchor constant:14],
        [closeHint.centerXAnchor constraintEqualToAnchor:dim.centerXAnchor],
    ]];

    [UIView animateWithDuration:0.2 animations:^{ dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78]; }];

    // Tải ảnh bất đồng bộ
    NSURL *url = [NSURL URLWithString:urlString];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *d = [weakSelf.view viewWithTag:9901];
            if (!d) return;
            UIImageView *iv = (UIImageView *)[d viewWithTag:9902];
            UIActivityIndicatorView *sp = (UIActivityIndicatorView *)[d viewWithTag:9903];
            [sp stopAnimating];
            UIImage *img = data ? [UIImage imageWithData:data] : nil;
            if (img) {
                iv.image = img;
            } else {
                UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:40 weight:UIImageSymbolWeightRegular];
                iv.image = [UIImage systemImageNamed:@"photo.slash" withConfiguration:cfg];
                iv.tintColor = HUD_MUTED;
            }
        });
    }] resume];
}

- (void)dismissPreview {
    UIView *dim = [self.view viewWithTag:9901];
    if (!dim) return;
    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 0; }
                     completion:^(BOOL f){ [dim removeFromSuperview]; }];
}

- (UIColor *)gridPatternColor {
    CGFloat s = 26;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext, [UIColor colorWithWhite:1 alpha:0.05].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 0.5);
        CGContextMoveToPoint(ctx.CGContext, s, 0);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextMoveToPoint(ctx.CGContext, 0, s);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}

// White title + cyan back chevron on the dark HUD, scoped to this screen only
- (void)setupNavBarAppearance {
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithTransparentBackground];
    ap.titleTextAttributes = @{NSForegroundColorAttributeName: HUD_TEXT,
                               NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]};
    self.navigationItem.standardAppearance = ap;
    self.navigationItem.scrollEdgeAppearance = ap;
    self.navigationItem.compactAppearance = ap;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = HUD_CYAN;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.tintColor = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startButtonShimmer];
}

// Sweeping shimmer effect on the MỞ GAME sticky button
- (void)startButtonShimmer {
    // Remove any pre-existing shimmer layer
    for (CALayer *layer in [self.openGameButton.layer.sublayers copy]) {
        if ([layer.name isEqualToString:@"shimmer"]) [layer removeFromSuperlayer];
    }
    CGFloat w = self.openGameButton.bounds.size.width;
    CGFloat h = self.openGameButton.bounds.size.height;
    if (w < 1) return;

    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.name = @"shimmer";
    shimmer.colors = @[
        (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.30].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
    ];
    shimmer.locations  = @[@0.3, @0.5, @0.7];
    shimmer.startPoint = CGPointMake(0, 0.5);
    shimmer.endPoint   = CGPointMake(1, 0.5);
    shimmer.frame = CGRectMake(0, 0, w, h);
    [self.openGameButton.layer addSublayer:shimmer];

    // Slide from -w to +w; clipped by button's clipsToBounds=YES
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.fromValue    = @(-w);
    anim.toValue      = @(w);
    anim.duration     = 2.2;
    anim.repeatCount  = INFINITY;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime    = CACurrentMediaTime() + 0.8;
    [shimmer addAnimation:anim forKey:@"shimmerAnim"];
}

- (void)buildUI {
    // ── Scroll container ────────────────────────────────
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.backgroundColor = [UIColor clearColor];
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    // ── Header: icon + name + bundle ────────────────────
    UIImageView *iconView = [[UIImageView alloc] initWithImage:self.icon];
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.clipsToBounds = YES;
    iconView.layer.cornerRadius = 18;
    iconView.layer.cornerCurve = kCACornerCurveContinuous;
    iconView.layer.borderColor = [HUD_CYAN colorWithAlphaComponent:0.45].CGColor;
    iconView.layer.borderWidth = 1.5;
    iconView.layer.magnificationFilter = kCAFilterTrilinear;
    iconView.layer.shadowColor = HUD_CYAN.CGColor;
    iconView.layer.shadowOpacity = 0.6;
    iconView.layer.shadowRadius = 18;
    iconView.layer.shadowOffset = CGSizeMake(0, 4);
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = self.appName;
    nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    nameLabel.textColor = HUD_TEXT;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:nameLabel];

    UILabel *bundleLabel = [[UILabel alloc] init];
    bundleLabel.text = self.bundleID;
    bundleLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    bundleLabel.textColor = HUD_MUTED;
    bundleLabel.textAlignment = NSTextAlignmentCenter;
    bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:bundleLabel];

    // ── Sliding Segmented Bar ────────────────────────────
    NSArray<NSString *> *tabSyms   = @[@"bolt.fill", @"location.fill", @"person.fill.badge.plus"];
    NSArray<NSString *> *tabLabels = @[
        LS(@"Proxy",   @"Proxy"),
        LS(@"Định Vị", @"Aim Bot"),
        LS(@"Mod NV",  @"Mod Skin"),
    ];
    self.tabTints = @[HUD_CYAN, HUD_GREEN, HUD_PURPLE];

    // Outer shadow wrapper (not clipping, so glow shows)
    UIView *segWrap = [[UIView alloc] init];
    segWrap.backgroundColor = [UIColor clearColor];
    segWrap.layer.shadowColor   = HUD_PURPLE.CGColor;
    segWrap.layer.shadowOpacity = 0.30;
    segWrap.layer.shadowRadius  = 14;
    segWrap.layer.shadowOffset  = CGSizeMake(0, 4);
    segWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:segWrap];
    self.segmentBar = segWrap;

    // Glass blur container (clips sublayers)
    UIVisualEffectView *segBlur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    segBlur.clipsToBounds = YES;
    segBlur.layer.cornerRadius = 16;
    segBlur.layer.cornerCurve  = kCACornerCurveContinuous;
    segBlur.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.09].CGColor;
    segBlur.layer.borderWidth  = 0.5;
    segBlur.translatesAutoresizingMaskIntoConstraints = NO;
    [segWrap addSubview:segBlur];
    [NSLayoutConstraint activateConstraints:@[
        [segBlur.topAnchor    constraintEqualToAnchor:segWrap.topAnchor],
        [segBlur.leadingAnchor  constraintEqualToAnchor:segWrap.leadingAnchor],
        [segBlur.trailingAnchor constraintEqualToAnchor:segWrap.trailingAnchor],
        [segBlur.bottomAnchor constraintEqualToAnchor:segWrap.bottomAnchor],
    ]];

    UIView *cv = segBlur.contentView;

    // Sliding thumb pill (lives beneath the buttons in Z-order)
    UIView *thumb = [[UIView alloc] init];
    thumb.layer.cornerRadius = 13;
    thumb.layer.cornerCurve  = kCACornerCurveContinuous;
    thumb.layer.borderWidth  = 1;
    thumb.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:thumb];
    self.segThumb = thumb;

    // Equal-width button slots stacked on top of the thumb
    UIStackView *segStack = [[UIStackView alloc] init];
    segStack.axis         = UILayoutConstraintAxisHorizontal;
    segStack.distribution = UIStackViewDistributionFillEqually;
    segStack.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:segStack];

    NSMutableArray<UIButton *> *btns = [NSMutableArray array];
    NSMutableArray<UILabel *>  *lbls = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        UIImageView *iconIV = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:tabSyms[(NSUInteger)i] withConfiguration:symCfg]];
        iconIV.contentMode = UIViewContentModeScaleAspectFit;
        iconIV.translatesAutoresizingMaskIntoConstraints = NO;
        iconIV.userInteractionEnabled = NO;
        iconIV.tag = 10 + i;
        [btn addSubview:iconIV];

        UILabel *lbl = [[UILabel alloc] init];
        lbl.text          = tabLabels[(NSUInteger)i];
        lbl.font          = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        lbl.userInteractionEnabled = NO;
        lbl.tag = 20 + i;
        [btn addSubview:lbl];
        [lbls addObject:lbl];

        [NSLayoutConstraint activateConstraints:@[
            [iconIV.centerXAnchor constraintEqualToAnchor:btn.centerXAnchor],
            [iconIV.bottomAnchor  constraintEqualToAnchor:btn.centerYAnchor constant:0],
            [iconIV.widthAnchor   constraintEqualToConstant:14],
            [iconIV.heightAnchor  constraintEqualToConstant:14],
            [lbl.centerXAnchor    constraintEqualToAnchor:btn.centerXAnchor],
            [lbl.topAnchor        constraintEqualToAnchor:iconIV.bottomAnchor constant:3],
        ]];

        [segStack addArrangedSubview:btn];
        [btns addObject:btn];
    }
    self.tabButtons = [btns copy];
    self.segLabels  = lbls;

    // Thumb: 1/3 bar width, inset 4pt top/bottom; leading drives the slide
    self.thumbLeft = [thumb.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:0];
    [NSLayoutConstraint activateConstraints:@[
        self.thumbLeft,
        [thumb.widthAnchor  constraintEqualToAnchor:cv.widthAnchor multiplier:1.0/3.0],
        [thumb.topAnchor    constraintEqualToAnchor:cv.topAnchor    constant:4],
        [thumb.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-4],

        [segStack.topAnchor    constraintEqualToAnchor:cv.topAnchor],
        [segStack.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor],
        [segStack.leadingAnchor  constraintEqualToAnchor:cv.leadingAnchor],
        [segStack.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor],
    ]];

    [self selectTab:0];

    // ── 3 Panels ─────────────────────────────────────────
    self.rows = [NSMutableArray array];

    self.panelProxy  = [self buildPanelWithTitle:@"PROXY DELTA VIP"
                                          symbol:@"bolt.fill"     tint:HUD_CYAN   badge:@"AUTO"
                                        features:[self proxyFeaturesForBundle:self.bundleID]
                                     tutorialURL:kTutorialProxyURL ?: @""
                                  outTitleLabel:nil];
    self.panelDinhVi = [self buildPanelWithTitle:LS(@"ĐỊNH VỊ SÚNG", @"AIM BOT")
                                          symbol:@"location.fill" tint:HUD_GREEN  badge:@"LIVE"
                                        features:[self dinhViFeaturesForBundle:self.bundleID]
                                     tutorialURL:nil
                                  outTitleLabel:&_panelDinhViTitleLabel];
    self.panelModNV  = [self buildPanelWithTitle:LS(@"MOD NHÂN VẬT", @"CHARACTER MOD")
                                          symbol:@"person.fill.badge.plus" tint:HUD_PURPLE badge:@"SOON"
                                        features:[self modNVFeaturesForBundle:self.bundleID]
                                     tutorialURL:nil
                                  outTitleLabel:&_panelModNVTitleLabel];

    // ── PROXY DELTA VIP V2 panel ─────────────────────────────────────────────
    self.panelDrag = [self buildPanelWithTitle:@"PROXY DELTA VIP V2"
                                        symbol:@"hand.draw.fill"
                                          tint:HUD_ORANGE
                                         badge:@"V2"
                                      features:[self dragFeaturesForBundle:self.bundleID]
                                   tutorialURL:kTutorialDragURL ?: @""
                                outTitleLabel:nil];

    self.panelDinhVi.hidden = YES;
    self.panelModNV.hidden  = YES;
    // panelDrag KHÔNG ẩn lúc khởi tạo vì tab 0 (Proxy) là tab mặc định
    // switchToPanel: sẽ ẩn nó khi user chuyển sang tab khác

    // Container stack — UIStackView tự collapse view hidden → không chiếm không gian
    UIStackView *panelsStack = [[UIStackView alloc] init];
    panelsStack.axis    = UILayoutConstraintAxisVertical;
    panelsStack.spacing = 0;
    panelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:panelsStack];
    [panelsStack addArrangedSubview:self.panelProxy];
    [panelsStack addArrangedSubview:self.panelDrag];   // sau panelProxy, cùng ẩn/hiện
    [panelsStack addArrangedSubview:self.panelDinhVi];
    [panelsStack addArrangedSubview:self.panelModNV];
    // Khoảng cách 14pt giữa panelProxy và panelDrag (chỉ tác dụng khi cả 2 visible)
    [panelsStack setCustomSpacing:14 afterView:self.panelProxy];

    // ── Status line ─────────────────────────────────────
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = LS(@"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy",
                              @"Ready — Activate Proxy Now");
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textColor = HUD_MUTED;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    // ── Nút MỞ GAME (gradient) ──────────────────────────
    self.openGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openGameButton setTitle:LS(@"▶  MỞ GAME", @"▶  OPEN GAME") forState:UIControlStateNormal];
    [self.openGameButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0] forState:UIControlStateNormal];
    self.openGameButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    self.openGameButton.layer.cornerRadius = 16;
    self.openGameButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.openGameButton.clipsToBounds = YES;
    self.openGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openGameButton addTarget:self action:@selector(launchGame) forControlEvents:UIControlEventTouchUpInside];
    // Note: added to self.view (sticky) below — NOT to content

    self.openGameGradient = [CAGradientLayer layer];
    self.openGameGradient.colors = @[(id)HUD_PURPLE.CGColor, (id)HUD_CYAN.CGColor];
    self.openGameGradient.startPoint = CGPointMake(0, 0.5);
    self.openGameGradient.endPoint   = CGPointMake(1, 0.5);
    self.openGameGradient.cornerRadius = 16;
    [self.openGameButton.layer insertSublayer:self.openGameGradient atIndex:0];

    // ── Constraints ─────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [iconView.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:82],
        [iconView.heightAnchor constraintEqualToConstant:82],

        [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [nameLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [bundleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:3],
        [bundleLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [bundleLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [segWrap.topAnchor constraintEqualToAnchor:bundleLabel.bottomAnchor constant:20],
        [segWrap.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [segWrap.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [segWrap.heightAnchor constraintEqualToConstant:52],

        [panelsStack.topAnchor constraintEqualToAnchor:segWrap.bottomAnchor constant:16],
        [panelsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [panelsStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [self.statusLabel.topAnchor constraintEqualToAnchor:panelsStack.bottomAnchor constant:18],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
        // Status label closes the scroll content — MỞ GAME is a sticky overlay button
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
    ]];

    // ── Sticky MỞ GAME button (fixed above safe area, outside scroll) ─────
    [self.view addSubview:self.openGameButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.openGameButton.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor  constant:20],
        [self.openGameButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.openGameButton.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.openGameButton.heightAnchor   constraintEqualToConstant:56],
    ]];
    // Extra bottom inset so status label isn't hidden behind the sticky button
    scroll.contentInset = UIEdgeInsetsMake(0, 0, 88, 0);
    scroll.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 88, 0);
}

// Tạo 1 panel card (neon blur card) với title bar + danh sách feature rows.
// Các row được append vào self.rows để handleRow: / radio logic vẫn hoạt động.
// tutorialURL: @"" = hiện "sắp có"; @"https://…" = mở YouTube; nil = ẩn row
- (UIView *)buildPanelWithTitle:(NSString *)title
                         symbol:(NSString *)symbol
                           tint:(UIColor *)tint
                          badge:(NSString *)badge
                       features:(NSArray<HUDFeature *> *)features
                    tutorialURL:(NSString * _Nullable)tutorialURL
                 outTitleLabel:(UILabel * __strong *)outTitleLabel {
    UIView *panelWrap = [[UIView alloc] init];
    panelWrap.backgroundColor = [UIColor clearColor];
    panelWrap.layer.shadowColor = tint.CGColor;
    panelWrap.layer.shadowOpacity = 0.35;
    panelWrap.layer.shadowRadius = 18;
    panelWrap.layer.shadowOffset = CGSizeZero;
    panelWrap.translatesAutoresizingMaskIntoConstraints = NO;

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.clipsToBounds = YES;
    panel.layer.cornerRadius = 18;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.borderColor = [tint colorWithAlphaComponent:0.55].CGColor;
    panel.layer.borderWidth = 1;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [panelWrap addSubview:panel];
    UIView *pc = panel.contentView;   // pc = panelContent

    // Title bar
    UIView *titleBar = [[UIView alloc] init];
    titleBar.translatesAutoresizingMaskIntoConstraints = NO;
    [pc addSubview:titleBar];

    UIView *accent = [[UIView alloc] init];
    accent.backgroundColor = tint;
    accent.layer.cornerRadius = 2;
    accent.layer.shadowColor = tint.CGColor;
    accent.layer.shadowOpacity = 0.9;
    accent.layer.shadowRadius = 5;
    accent.layer.shadowOffset = CGSizeZero;
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:accent];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:symCfg]];
    icon.tintColor = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.layer.shadowColor = tint.CGColor;
    icon.layer.shadowOpacity = 0.9;
    icon.layer.shadowRadius = 6;
    icon.layer.shadowOffset = CGSizeZero;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:icon];

    UILabel *menuTitle = [[UILabel alloc] init];
    menuTitle.text = title;
    menuTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    menuTitle.textColor = tint;
    menuTitle.layer.shadowColor = tint.CGColor;
    menuTitle.layer.shadowOpacity = 0.7;
    menuTitle.layer.shadowRadius = 6;
    menuTitle.layer.shadowOffset = CGSizeZero;
    menuTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:menuTitle];
    if (outTitleLabel) *outTitleLabel = menuTitle;

    UILabel *hint = [[UILabel alloc] init];
    hint.text = [NSString stringWithFormat:@"  %@  ", badge];
    hint.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    hint.textColor = tint;
    hint.backgroundColor = [tint colorWithAlphaComponent:0.15];
    hint.layer.cornerRadius = 8;
    hint.layer.masksToBounds = YES;
    hint.layer.borderColor = [tint colorWithAlphaComponent:0.5].CGColor;
    hint.layer.borderWidth = 1;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:hint];

    // Rows stack
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [pc addSubview:stack];

    __weak typeof(self) weakSelf = self;
    for (HUDFeature *feature in features) {
        HUDFeatureRow *row = [[HUDFeatureRow alloc] initWithFeature:feature];
        row.onChanged = ^(HUDFeatureRow *r, BOOL isOn) {
            [weakSelf handleRow:r on:isOn];
        };
        if (feature.previewImageURL.length) {
            NSString *url = feature.previewImageURL;
            row.onPreviewTapped = ^{ [weakSelf showPreviewURL:url]; };
        }
        [self.rows addObject:row];
        [stack addArrangedSubview:row];
    }

    // ── Tutorial row bên trong panel (tuỳ chọn) ─────────────────────────────
    NSLayoutYAxisAnchor *stackBottomAnchor = pc.bottomAnchor;
    CGFloat stackBottomConst = -4;

    if (tutorialURL != nil) {
        BOOL hasURL = tutorialURL.length > 0;
        UIColor *ytRed = [UIColor colorWithRed:1.0 green:0.22 blue:0.18 alpha:1.0];
        UIColor *tutColor = hasURL ? ytRed : HUD_MUTED;

        // Separator hairline
        UIView *sep = [[UIView alloc] init];
        sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        [pc addSubview:sep];

        // Tutorial row
        UIView *tutRow = [[UIView alloc] init];
        tutRow.translatesAutoresizingMaskIntoConstraints = NO;
        [pc addSubview:tutRow];

        // Play icon
        UIImageSymbolConfiguration *playCfg = [UIImageSymbolConfiguration
            configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
        UIImageView *playIcon = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:@"play.circle.fill" withConfiguration:playCfg]];
        playIcon.tintColor   = tutColor;
        playIcon.contentMode = UIViewContentModeScaleAspectFit;
        playIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [tutRow addSubview:playIcon];

        UILabel *tutTitle = [[UILabel alloc] init];
        tutTitle.text      = LS(@"Xem Video Hướng Dẫn", @"Watch Tutorial Video");
        tutTitle.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        tutTitle.textColor = hasURL ? HUD_TEXT : HUD_MUTED;
        tutTitle.translatesAutoresizingMaskIntoConstraints = NO;
        [tutRow addSubview:tutTitle];

        UILabel *tutSub = [[UILabel alloc] init];
        tutSub.text = hasURL
            ? LS(@"Nhấn để mở YouTube ▶", @"Tap to open YouTube ▶")
            : LS(@"🎬 Video hướng dẫn sắp có...", @"🎬 Tutorial coming soon...");
        tutSub.font      = [UIFont systemFontOfSize:11];
        tutSub.textColor = HUD_MUTED;
        tutSub.translatesAutoresizingMaskIntoConstraints = NO;
        [tutRow addSubview:tutSub];

        [NSLayoutConstraint activateConstraints:@[
            [sep.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor  constant:16],
            [sep.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor constant:-16],
            [sep.heightAnchor   constraintEqualToConstant:0.5],

            [tutRow.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor],
            [tutRow.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor],
            [tutRow.heightAnchor   constraintEqualToConstant:50],
            [tutRow.bottomAnchor   constraintEqualToAnchor:pc.bottomAnchor],
            [sep.bottomAnchor      constraintEqualToAnchor:tutRow.topAnchor],

            [playIcon.leadingAnchor  constraintEqualToAnchor:tutRow.leadingAnchor constant:16],
            [playIcon.centerYAnchor  constraintEqualToAnchor:tutRow.centerYAnchor],
            [playIcon.widthAnchor    constraintEqualToConstant:20],
            [playIcon.heightAnchor   constraintEqualToConstant:20],

            [tutTitle.leadingAnchor constraintEqualToAnchor:playIcon.trailingAnchor constant:12],
            [tutTitle.bottomAnchor  constraintEqualToAnchor:tutRow.centerYAnchor constant:-1],

            [tutSub.leadingAnchor constraintEqualToAnchor:tutTitle.leadingAnchor],
            [tutSub.topAnchor     constraintEqualToAnchor:tutRow.centerYAnchor constant:3],
        ]];

        if (hasURL) {
            UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            tapBtn.backgroundColor = [UIColor clearColor];
            tapBtn.translatesAutoresizingMaskIntoConstraints = NO;
            tapBtn.accessibilityIdentifier = tutorialURL;
            [tapBtn addTarget:self action:@selector(tutorialButtonTapped:)
                 forControlEvents:UIControlEventTouchUpInside];
            [tutRow addSubview:tapBtn];
            [NSLayoutConstraint activateConstraints:@[
                [tapBtn.topAnchor    constraintEqualToAnchor:tutRow.topAnchor],
                [tapBtn.leadingAnchor  constraintEqualToAnchor:tutRow.leadingAnchor],
                [tapBtn.trailingAnchor constraintEqualToAnchor:tutRow.trailingAnchor],
                [tapBtn.bottomAnchor constraintEqualToAnchor:tutRow.bottomAnchor],
            ]];
        }

        // Stack bottom anchors to sep top
        stackBottomAnchor = sep.topAnchor;
        stackBottomConst  = 0;
    }

    [NSLayoutConstraint activateConstraints:@[
        [panel.topAnchor constraintEqualToAnchor:panelWrap.topAnchor],
        [panel.leadingAnchor constraintEqualToAnchor:panelWrap.leadingAnchor],
        [panel.trailingAnchor constraintEqualToAnchor:panelWrap.trailingAnchor],
        [panel.bottomAnchor constraintEqualToAnchor:panelWrap.bottomAnchor],

        [titleBar.topAnchor constraintEqualToAnchor:pc.topAnchor],
        [titleBar.leadingAnchor constraintEqualToAnchor:pc.leadingAnchor],
        [titleBar.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor],
        [titleBar.heightAnchor constraintEqualToConstant:46],

        [accent.leadingAnchor constraintEqualToAnchor:titleBar.leadingAnchor constant:16],
        [accent.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [accent.widthAnchor constraintEqualToConstant:4],
        [accent.heightAnchor constraintEqualToConstant:16],

        [icon.leadingAnchor constraintEqualToAnchor:accent.trailingAnchor constant:10],
        [icon.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:15],
        [icon.heightAnchor constraintEqualToConstant:15],

        [menuTitle.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:7],
        [menuTitle.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],

        [hint.trailingAnchor constraintEqualToAnchor:titleBar.trailingAnchor constant:-16],
        [hint.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [hint.heightAnchor constraintEqualToConstant:18],

        [stack.topAnchor constraintEqualToAnchor:titleBar.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:pc.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:stackBottomAnchor constant:stackBottomConst],
    ]];

    return panelWrap;
}


- (void)tutorialButtonTapped:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:sender.accessibilityIdentifier];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

#pragma mark - Tab switching

// Cập nhật màu icon+label — tab chọn: neon tint; còn lại: muted
- (void)selectTab:(NSInteger)tab {
    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        UIColor *tint  = self.tabTints[(NSUInteger)i];
        BOOL    active = (i == tab);

        // Icon color via tag 10+i
        UIView *iconV = [self.tabButtons[(NSUInteger)i] viewWithTag:10 + i];
        if ([iconV isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)iconV).tintColor = active ? tint : HUD_MUTED;
        }
        // Label color via tag 20+i
        UIView *lblV = [self.tabButtons[(NSUInteger)i] viewWithTag:20 + i];
        if ([lblV isKindOfClass:[UILabel class]]) {
            ((UILabel *)lblV).textColor = active ? tint : HUD_MUTED;
        }
    }
    [self updateThumbForTab:tab animated:YES];
}

// Spring-animate the thumb pill to the selected slot
- (void)updateThumbForTab:(NSInteger)tab animated:(BOOL)animated {
    CGFloat segWidth = self.segmentBar.bounds.size.width;
    if (segWidth < 1) {
        // Layout not done yet — defer until viewDidLayoutSubviews
        self.pendingThumbTab = tab;
        return;
    }
    UIColor *tint = self.tabTints[(NSUInteger)tab];
    self.thumbLeft.constant          = tab * (segWidth / 3.0);
    self.segThumb.backgroundColor    = [tint colorWithAlphaComponent:0.20];
    self.segThumb.layer.borderColor  = [tint colorWithAlphaComponent:0.45].CGColor;

    if (animated) {
        [UIView animateWithDuration:0.44 delay:0
             usingSpringWithDamping:0.72 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{ [self.segmentBar layoutIfNeeded]; }
                         completion:nil];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self.segmentBar layoutIfNeeded];
        [CATransaction commit];
    }
}

// Bấm tab → cập nhật pills + fade crossfade giữa 2 panel
- (void)tabButtonTapped:(UIButton *)sender {
    [self selectTab:sender.tag];
    [self switchToPanel:sender.tag];
}

// Crossfade mượt: fade-out cũ → collapse → fade-in mới
- (void)switchToPanel:(NSInteger)tab {
    NSArray<UIView *> *panels = @[self.panelProxy, self.panelDinhVi, self.panelModNV];
    UIView *toShow = panels[(NSUInteger)tab];

    // Tìm panel đang visible
    UIView *toHide = nil;
    for (UIView *p in panels) { if (!p.hidden) { toHide = p; break; } }
    if (!toHide || toHide == toShow) return;

    // panelDrag đi kèm tab 0 (Proxy) — hiện/ẩn cùng panelProxy
    BOOL dragShouldShow = (tab == 0);

    // Pre-show toShow + panelDrag nếu cần
    toShow.alpha  = 0;
    toShow.hidden = NO;
    if (dragShouldShow) {
        self.panelDrag.alpha  = 0;
        self.panelDrag.hidden = NO;
    }

    // Phase 1: fade-out panel cũ (+ panelDrag nếu đang rời tab 0)
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        toHide.alpha = 0;
        if (!dragShouldShow) self.panelDrag.alpha = 0;
    }
                     completion:^(BOOL f) {
        toHide.hidden = YES;
        toHide.alpha  = 1;
        if (!dragShouldShow) { self.panelDrag.hidden = YES; self.panelDrag.alpha = 1; }
        // Phase 2: fade-in panel mới
        [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            toShow.alpha = 1;
            if (dragShouldShow) self.panelDrag.alpha = 1;
        }
                         completion:nil];
    }];

    NSString *hint = (tab == 0)
        ? LS(@"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy", @"Ready — Activate Proxy Now")
        : (tab == 1)
        ? LS(@"Định Vị - Hiện Vị Trí Súng & Vật Phẩm Trên Map", @"Aim Bot — Gun & Item Location on Map")
        : LS(@"Mod Nhân Vật - Đang Cập Nhật Thêm Tính Năng Mới", @"Character Mod — More Features Coming");
    [self setStatus:hint color:HUD_MUTED];
}

#pragma mark - Feature config

// Builder helper — exclusive=YES mặc định (aim / radio); gọi xong đặt NO nếu cần độc lập.
- (HUDFeature *)featureWithSymbol:(NSString *)symbol tint:(UIColor *)tint
                            title:(NSString *)title subtitle:(NSString *)subtitle
                       featureKey:(NSString *)featureKey
                         fileName:(NSString *)fileName searchRoot:(NSString *)searchRoot {
    HUDFeature *f = [HUDFeature new];
    f.symbol = symbol; f.tint = tint; f.title = title; f.subtitle = subtitle;
    f.featureKey = featureKey; f.fileName = fileName; f.searchRoot = searchRoot;
    f.exclusive = YES;
    f.exclusiveGroup = @"aim";
    return f;
}

// ── Tab 1: Proxy ────────────────────────────────────────────
- (NSArray<HUDFeature *> *)proxyFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];

    NSString *cacheRes = @"cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";
    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *fn = supported ? cacheRes : nil;
    NSString *rt = supported ? root : nil;
    NSString *(^k)(NSString *) = ^NSString *(NSString *key) { return supported ? key : nil; };

    HUDFeature *body = [self featureWithSymbol:@"figure.stand" tint:HUD_ORANGE
        title:@"Proxy Body" subtitle:@"Full Đỏ Xoá Máu Vàng"
        featureKey:k(@"body") fileName:fn searchRoot:rt];
    body.enTitle = @"Proxy Body"; body.enSubtitle = @"Full Red + Remove Yellow HP";

    HUDFeature *coV1 = [self featureWithSymbol:@"camera.metering.center.weighted"
        tint:[UIColor colorWithRed:1.0 green:0.78 blue:0.25 alpha:1.0]
        title:@"Proxy Cổ V1" subtitle:@"Aim Cổ Ít Lộ Hơn"
        featureKey:k(@"chest") fileName:fn searchRoot:rt];
    coV1.enTitle = @"Proxy Neck V1"; coV1.enSubtitle = @"Neck Aim — Less Visible";

    HUDFeature *coV2 = [self featureWithSymbol:@"scope" tint:HUD_PINK
        title:@"Proxy Cổ V2" subtitle:@"Vùng Cổ Máu Đỏ To Hơn, Bám Hơn"
        featureKey:k(@"neck") fileName:fn searchRoot:rt];
    coV2.enTitle = @"Proxy Neck V2"; coV2.enSubtitle = @"Bigger Red Neck Zone, Stickier";

    HUDFeature *magic = [self featureWithSymbol:@"wand.and.stars" tint:HUD_PURPLE
        title:@"Proxy Magic" subtitle:@"Đạn Ma Thuật"
        featureKey:k(@"magic") fileName:fn searchRoot:rt];
    magic.enTitle = @"Proxy Magic"; magic.enSubtitle = @"Magic Bullet";

    return @[body, coV1, coV2, magic];
}

// ── AimDrag — panel riêng bên dưới tab ──────────────────────────────────────
- (NSArray<HUDFeature *> *)dragFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    NSString *cacheRes = @"cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";
    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *fn = supported ? cacheRes : nil;
    NSString *rt = supported ? root : nil;
    NSString *(^k)(NSString *) = ^NSString *(NSString *key) { return supported ? key : nil; };

    HUDFeature *drag = [self featureWithSymbol:@"hand.draw.fill" tint:HUD_ORANGE
        title:LS(@"Aim Drag", @"Aim Drag")
        subtitle:LS(@"Kéo Nhẹ Tâm Lên Đỉnh Đầu", @"Soft Pull — Aim Rises to Head")
        featureKey:k(@"drag") fileName:fn searchRoot:rt];
    drag.enTitle    = @"Aim Drag";
    drag.enSubtitle = @"Soft Pull — Aim Rises to Head";
    return @[drag];
}

// ── Tab 2: Định Vị Súng ─────────────────────────────────────
// Mỗi loại súng / vật phẩm là 1 row độc lập (exclusive=NO).
// Điền fileName + featureKey khi có file thực; để nil → hiện "Đang Bảo Trì".
- (NSArray<HUDFeature *> *)dinhViFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL isMax = [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL isTH  = [bundleID isEqualToString:@"com.dts.freefireth"];

    NSString *sfMax = @"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D";
    NSString *sfTH  = @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D";
    NSString *sf    = isMax ? sfMax : (isTH ? sfTH : nil);
    NSString *root  = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *rt    = supported ? root : nil;
    NSString *rtTH  = isTH  ? root : nil;
    NSString *rtMax = isMax ? root : nil;
    NSString *(^k)(NSString *)    = ^NSString *(NSString *key) { return supported ? key : nil; };
    NSString *(^kTH)(NSString *)  = ^NSString *(NSString *key) { return isTH     ? key : nil; };
    NSString *(^kMax)(NSString *) = ^NSString *(NSString *key) { return isMax    ? key : nil; };

    // Định Vị Súng Xanh + Hologram Keo (cả 2 game)
    HUDFeature *dvXanh = [self featureWithSymbol:@"location.fill" tint:HUD_CYAN
                                           title:@"Định Vị Súng Xanh" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                      featureKey:k(@"dinhvixanh") fileName:sf searchRoot:rt];
    dvXanh.exclusive = NO;
    dvXanh.enTitle = @"Blue Gun Locator"; dvXanh.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Súng Đỏ (cả 2 game)
    HUDFeature *dvDo = [self featureWithSymbol:@"location.fill.viewfinder" tint:HUD_RED
                                         title:@"Định Vị Súng Đỏ" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                    featureKey:k(@"dinhvido") fileName:sf searchRoot:rt];
    dvDo.exclusive = NO;
    dvDo.enTitle = @"Red Gun Locator"; dvDo.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Xanh Lá — chỉ FF Thường (folder dinhvihong, file TH)
    HUDFeature *dvXanhLa = [self featureWithSymbol:@"location.fill" tint:HUD_GREEN
                                             title:@"Định Vị Xanh Lá" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                        featureKey:kTH(@"dinhvihong") fileName:(isTH ? sfTH : nil) searchRoot:rtTH];
    dvXanhLa.exclusive = NO;
    dvXanhLa.enTitle = @"Green Locator"; dvXanhLa.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Hồng — chỉ FF Max (folder dinhvihong, file Max)
    HUDFeature *dvHong = [self featureWithSymbol:@"location.fill" tint:HUD_PINK
                                           title:@"Định Vị Hồng" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                      featureKey:kMax(@"dinhvihong") fileName:(isMax ? sfMax : nil) searchRoot:rtMax];
    dvHong.exclusive = NO;
    dvHong.enTitle = @"Pink Locator"; dvHong.enSubtitle = @"Show Gun Locations on Map";

    // Lọc theo game (tránh hiện "Bảo Trì" cho feature sai game)
    NSMutableArray *result = [NSMutableArray array];
    for (HUDFeature *f in @[dvXanh, dvDo, dvXanhLa, dvHong]) {
        if (f.configured) [result addObject:f];
    }
    return result;
}

// ── Tab 3: Mod Nhân Vật ─────────────────────────────────────
- (NSArray<HUDFeature *> *)modNVFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL isTH  = [bundleID isEqualToString:@"com.dts.freefireth"];
    BOOL isMax = [bundleID isEqualToString:@"com.dts.freefiremax"];
    NSString *root  = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *rt    = supported ? root : nil;
    NSString *rtTH  = isTH     ? root : nil;
    NSString *rtMax = isMax    ? root : nil;
    NSString *(^k)(NSString *)    = ^NSString *(NSString *key) { return supported ? key : nil; };
    NSString *(^kTH)(NSString *)  = ^NSString *(NSString *key) { return isTH     ? key : nil; };
    NSString *(^kMax)(NSString *) = ^NSString *(NSString *key) { return isMax    ? key : nil; };

    // Mod Skin Maro One Punch Man (cả Max + Thường)
    HUDFeature *skinMaro = [self featureWithSymbol:@"person.crop.circle.fill"
                                              tint:HUD_ORANGE
                                             title:@"Mod Skin Maro"
                                          subtitle:@"Mod Skin Maro One Punch Man"
                                        featureKey:k(@"skinmaro")
                                          fileName:(supported ? @"optionalab_avatar_35.PVdPx~2B~2BIEgbM63Zhe895~2FlLLRc0~3D" : nil)
                                        searchRoot:rt];
    skinMaro.exclusive = YES; skinMaro.exclusiveGroup = @"skin";
    skinMaro.previewImageURL = @"https://getuid.vip/skin_previews/maro.jpg";
    skinMaro.enSubtitle = @"Maro — One Punch Man Skin";

    NSString *alokFileTH  = @"optionalab_avatar_66.DfUs7MzeaoXWJ4jWN8zRBmYoY7Q~3D";
    NSString *alokFileMax = @"optionalab_avatar_66.CoOEgYl5yYUMEbFNIb8L3onAO6o~3D";

    // Mod Skin Alok V1 (cả FF Thường + FF Max, file khác nhau)
    HUDFeature *skinAlokV1 = [self featureWithSymbol:@"crown.fill"
                                                tint:HUD_PURPLE
                                               title:@"Mod Skin Alok V1"
                                            subtitle:@"Mod Skin Alok"
                                          featureKey:k(@"skinalokv1")
                                            fileName:(isTH ? alokFileTH : alokFileMax)
                                          searchRoot:rt];
    skinAlokV1.exclusive = YES; skinAlokV1.exclusiveGroup = @"skin";
    skinAlokV1.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv1.jpg";
    skinAlokV1.enSubtitle = @"Alok Skin";

    // Mod Skin Alok V2
    HUDFeature *skinAlokV2 = [self featureWithSymbol:@"crown.fill" tint:HUD_CYAN
                                               title:@"Mod Skin Alok V2" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv2") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV2.exclusive = YES; skinAlokV2.exclusiveGroup = @"skin";
    skinAlokV2.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv2.jpg";
    skinAlokV2.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V3
    HUDFeature *skinAlokV3 = [self featureWithSymbol:@"crown.fill" tint:HUD_PINK
                                               title:@"Mod Skin Alok V3" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv3") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV3.exclusive = YES; skinAlokV3.exclusiveGroup = @"skin";
    skinAlokV3.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv3.jpg";
    skinAlokV3.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V4
    HUDFeature *skinAlokV4 = [self featureWithSymbol:@"crown.fill" tint:HUD_ORANGE
                                               title:@"Mod Skin Alok V4" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv4") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV4.exclusive = YES; skinAlokV4.exclusiveGroup = @"skin";
    skinAlokV4.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv4.jpg";
    skinAlokV4.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V5
    HUDFeature *skinAlokV5 = [self featureWithSymbol:@"crown.fill" tint:HUD_GREEN
                                               title:@"Mod Skin Alok V5" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv5") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV5.exclusive = YES; skinAlokV5.exclusiveGroup = @"skin";
    skinAlokV5.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv5.jpg";
    skinAlokV5.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V6
    HUDFeature *skinAlokV6 = [self featureWithSymbol:@"crown.fill" tint:HUD_RED
                                               title:@"Mod Skin Alok V6" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv6") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV6.exclusive = YES; skinAlokV6.exclusiveGroup = @"skin";
    skinAlokV6.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv6.jpg";
    skinAlokV6.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V7
    HUDFeature *skinAlokV7 = [self featureWithSymbol:@"crown.fill" tint:HUD_MUTED
                                               title:@"Mod Skin Alok V7" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv7") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV7.exclusive = YES; skinAlokV7.exclusiveGroup = @"skin";
    skinAlokV7.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv7.jpg";
    skinAlokV7.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Alok V8
    HUDFeature *skinAlokV8 = [self featureWithSymbol:@"crown.fill" tint:HUD_PURPLE
                                               title:@"Mod Skin Alok V8" subtitle:@"Mod Skin Alok Free Fire Thường"
                                          featureKey:kTH(@"skinalokv8") fileName:(isTH ? alokFileTH : nil) searchRoot:rtTH];
    skinAlokV8.exclusive = YES; skinAlokV8.exclusiveGroup = @"skin";
    skinAlokV8.previewImageURL = @"https://getuid.vip/skin_previews/skinalokv8.jpg";
    skinAlokV8.enSubtitle = @"Alok Skin — Free Fire";

    // Mod Skin Hayato V1 (chỉ FF Max)
    HUDFeature *skinHayatoV1 = [self featureWithSymbol:@"flame.fill"
                                                  tint:HUD_RED
                                                 title:@"Mod Skin Hayato V1"
                                              subtitle:@"Mod Skin Hayato Free Fire Max"
                                            featureKey:kMax(@"skinhayatov1")
                                              fileName:(isMax ? @"optionalab_avatar_29.a11YMaJRzGNvT2uOMK8b0WNe2KM~3D" : nil)
                                            searchRoot:rtMax];
    skinHayatoV1.exclusive = YES; skinHayatoV1.exclusiveGroup = @"skin";
    skinHayatoV1.previewImageURL = @"https://getuid.vip/skin_previews/skinhayatov1.jpg";
    skinHayatoV1.enSubtitle = @"Hayato Skin — Free Fire Max";

    // Mod Skin Dimitri V1 (chỉ FF Max)
    HUDFeature *skinDimitriV1 = [self featureWithSymbol:@"waveform.path"
                                                   tint:HUD_CYAN
                                                  title:@"Mod Skin Dimitri V1"
                                               subtitle:@"Mod Skin Dimitri Free Fire Max"
                                             featureKey:kMax(@"skindimitriv1")
                                               fileName:(isMax ? @"optionalab_avatar_38.fY~2BV~2Fg5ly68AQRNSPTsXobJUziI~3D" : nil)
                                             searchRoot:rtMax];
    skinDimitriV1.exclusive = YES; skinDimitriV1.exclusiveGroup = @"skin";
    skinDimitriV1.previewImageURL = @"https://getuid.vip/skin_previews/skindimitriv1.jpg";
    skinDimitriV1.enSubtitle = @"Dimitri Skin — Free Fire Max";

    // Chỉ trả features phù hợp với game đang chạy (tránh hiện "Bảo Trì" cho skin sai game)
    NSMutableArray *result = [NSMutableArray array];
    for (HUDFeature *f in @[skinMaro,
                             skinAlokV1, skinAlokV2, skinAlokV3, skinAlokV4,
                             skinAlokV5, skinAlokV6, skinAlokV7, skinAlokV8,
                             skinHayatoV1, skinDimitriV1]) {
        if (f.configured) [result addObject:f];
    }
    return result;
}

#pragma mark - Toggle handling (auto-paste)

- (void)handleRow:(HUDFeatureRow *)row on:(BOOL)isOn {
    UISelectionFeedbackGenerator *sel = [[UISelectionFeedbackGenerator alloc] init];
    [sel selectionChanged];

    HUDFeature *f = row.feature;

    // Chống can thiệp: môi trường bị Frida/tiêm/debug thì khoá mod
    if (![SecurityGuard isEnvironmentTrusted]) {
        [row.toggle setOn:!isOn animated:YES];
        [row setActive:NO];
        [self setStatus:LS(@"⛔ Phát hiện can thiệp — đã khoá chức năng",
                          @"⛔ Tampering detected — feature locked") color:HUD_RED];
        return;
    }

    // Khoá chức năng sau license key hợp lệ (đã bind đúng máy)
    if ([KeyManager shared].state != KeyStateActive) {
        [row.toggle setOn:!isOn animated:YES];
        [row setActive:NO];
        NSString *msg = ([KeyManager shared].state == KeyStateExpired)
            ? LS(@"🔒 Key đã hết hạn — vui lòng gia hạn", @"🔒 Key expired — please renew")
            : LS(@"🔒 Cần nhập license key hợp lệ để dùng", @"🔒 Enter a valid license key");
        [self setStatus:msg color:HUD_RED];
        UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
        [nfb notificationOccurred:UINotificationFeedbackTypeError];
        return;
    }

    if (!f.configured) {
        [row.toggle setOn:!isOn animated:YES];
        [row setActive:NO];
        [row showResult:NO];
        [self setStatus:[NSString stringWithFormat:LS(@"🔧 %@ đang Bảo Trì", @"🔧 %@ under maintenance"), f.title] color:HUD_ORANGE];
        return;
    }

    [row setActive:isOn];

    // Radio trong cùng exclusiveGroup. Bật 1 → tắt các feature khác CÙNG group.
    // Khác group (aim vs skin) hoàn toàn độc lập với nhau.
    if (isOn && f.exclusive && f.exclusiveGroup.length) {
        for (HUDFeatureRow *other in self.rows) {
            if (other != row && other.feature.exclusive
                && [other.feature.exclusiveGroup isEqualToString:f.exclusiveGroup]
                && other.toggle.isOn) {
                [other.toggle setOn:NO animated:YES];   // programmatic → không kích hoạt paste
                [other setActive:NO];
                other.statusDot.text = @"";
            }
        }
    }

    [row setLoading:YES];
    [self setStatus:LS(@"⏳ Đang Kích Hoạt", @"⏳ Activating") color:HUD_MUTED];

    NSString *game = [self.bundleID isEqualToString:@"com.dts.freefiremax"] ? @"max" : @"th";


    __weak typeof(self) weakSelf = self;
    [[AutoPasteManager sharedManager] pasteFeature:f.featureKey
                                               mod:isOn
                                              game:game
                                         fileNamed:f.fileName
                                         underRoot:f.searchRoot
                                        completion:^(BOOL success, NSString *message) {
        [row setLoading:NO];
        [row showResult:success];
        if (!success) { [row.toggle setOn:NO animated:YES]; [row setActive:NO]; }
        NSString *statusText;
        if (success) {
            statusText = isOn
                ? [NSString stringWithFormat:LS(@"✅ Kích Hoạt Thành Công %@", @"✅ Activated %@"), f.title]
                : [NSString stringWithFormat:LS(@"✅ Đã Tắt Thành Công %@",    @"✅ Deactivated %@"), f.title];
        } else {
            statusText = message;   // giữ nguyên thông báo lỗi
        }
        [weakSelf setStatus:statusText color:(success ? HUD_GREEN : HUD_RED)];
        UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
        [nfb notificationOccurred:(success ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError)];
    }];
}

- (void)setStatus:(NSString *)text color:(UIColor *)color {
    self.statusLabel.textColor = color;
    self.statusLabel.text = text;
    self.statusLabel.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.statusLabel.alpha = 1; }];
}

// Cập nhật toàn bộ chuỗi khi người dùng đổi ngôn ngữ
- (void)refreshLocalizedStrings {
    // Segmented bar labels
    NSArray *tabLabels = @[
        LS(@"Proxy",   @"Proxy"),
        LS(@"Định Vị", @"Aim Bot"),
        LS(@"Mod NV",  @"Mod Skin"),
    ];
    for (NSInteger i = 0; i < 3 && i < (NSInteger)self.segLabels.count; i++) {
        self.segLabels[(NSUInteger)i].text = tabLabels[(NSUInteger)i];
    }

    // Panel header titles (DinhVi + ModNV)
    self.panelDinhViTitleLabel.text = LS(@"ĐỊNH VỊ SÚNG", @"AIM BOT");
    self.panelModNVTitleLabel.text  = LS(@"MOD NHÂN VẬT", @"CHARACTER MOD");

    // Feature row title + subtitle
    for (HUDFeatureRow *row in self.rows) {
        [row refreshLanguage];
    }

    // Nút mở game
    [self.openGameButton setTitle:LS(@"▶  MỞ GAME", @"▶  OPEN GAME") forState:UIControlStateNormal];
    // Status label (chỉ reset khi đang ở trạng thái idle)
    self.statusLabel.text = LS(@"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy",
                               @"Ready — Activate Proxy Now");
    self.statusLabel.textColor = HUD_MUTED;
}

@end
