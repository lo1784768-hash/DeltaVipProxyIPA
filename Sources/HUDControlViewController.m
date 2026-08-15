#import "HUDControlViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "SecurityGuard.h"
#import "Endpoints.h"

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
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *subtitle;
@property (nonatomic, copy)   NSString *featureKey;  // body/neck/drag/magic (gửi server)
@property (nonatomic, copy)   NSString *fileName;    // tên file cần tìm & ghi đè
@property (nonatomic, copy)   NSString *searchRoot;  // thư mục gốc để tìm (tương đối Documents)
@property (nonatomic, assign) BOOL exclusive;        // YES = radio (aim); NO = độc lập (định vị)
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
@property (nonatomic, copy)   void (^onChanged)(HUDFeatureRow *row, BOOL isOn);
- (instancetype)initWithFeature:(HUDFeature *)feature;
- (void)setLoading:(BOOL)loading;
- (void)showResult:(BOOL)success;
- (void)setActive:(BOOL)active;
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
        title.text = feature.title;
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = HUD_TEXT;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:title];

        UILabel *subtitle = [[UILabel alloc] init];
        subtitle.text = feature.subtitle;
        subtitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        subtitle.textColor = HUD_MUTED;
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:subtitle];

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

            [_spinner.trailingAnchor constraintEqualToAnchor:_toggle.leadingAnchor constant:-12],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_statusDot.trailingAnchor constraintEqualToAnchor:_toggle.leadingAnchor constant:-12],
            [_statusDot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_statusDot.widthAnchor constraintEqualToConstant:20],
        ]];

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
    if (self.onChanged) self.onChanged(self, self.toggle.isOn);
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
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;   // 3 tab pills
@property (nonatomic, strong) NSArray<UIColor *>  *tabTints;     // per-tab neon color
@property (nonatomic, strong) UIView *panelProxy;
@property (nonatomic, strong) UIView *panelDinhVi;
@property (nonatomic, strong) UIView *panelModNV;
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
        NSString *title = j[@"notice_title"] ?: @"Thông Báo";
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
    [ok setTitle:@"ĐÃ HIỂU" forState:UIControlStateNormal];
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
        [self setStatus:@"⚠️ Không mở được game (mở tay giúp mình nhé)" color:HUD_RED];
    }
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

    // ── Custom tab bar (3 pill buttons) ─────────────────
    UIView *tabBar = [[UIView alloc] init];
    tabBar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    tabBar.layer.cornerRadius = 14;
    tabBar.layer.masksToBounds = YES;
    tabBar.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    tabBar.layer.borderWidth  = 0.5;
    tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:tabBar];

    NSArray<NSString *> *tabSyms   = @[@"bolt.fill", @"location.fill", @"person.fill.badge.plus"];
    NSArray<NSString *> *tabLabels = @[@"Proxy", @"Định Vị", @"Mod NV"];
    self.tabTints = @[HUD_CYAN, HUD_GREEN, HUD_PURPLE];

    UIStackView *tabStack = [[UIStackView alloc] init];
    tabStack.axis         = UILayoutConstraintAxisHorizontal;
    tabStack.distribution = UIStackViewDistributionFillEqually;
    tabStack.spacing      = 3;
    tabStack.translatesAutoresizingMaskIntoConstraints = NO;
    [tabBar addSubview:tabStack];

    NSMutableArray<UIButton *> *btns = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.layer.cornerRadius = 11;
        btn.layer.masksToBounds = YES;
        btn.layer.borderWidth   = 1;
        btn.layer.borderColor   = [UIColor clearColor].CGColor;

        UIButtonConfiguration *conf = [UIButtonConfiguration plainButtonConfiguration];
        conf.imagePlacement   = NSDirectionalRectEdgeLeading;
        conf.imagePadding     = 5;
        conf.contentInsets    = NSDirectionalEdgeInsetsMake(0, 10, 0, 10);
        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        conf.image = [UIImage systemImageNamed:tabSyms[i] withConfiguration:symCfg];
        conf.attributedTitle  = [[NSAttributedString alloc] initWithString:tabLabels[i] attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
        }];
        conf.baseForegroundColor = HUD_MUTED;
        UIBackgroundConfiguration *bgConf = [UIBackgroundConfiguration clearConfiguration];
        bgConf.cornerRadius = 11;
        conf.background = bgConf;
        btn.configuration = conf;

        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabStack addArrangedSubview:btn];
        [btns addObject:btn];
    }
    self.tabButtons = [btns copy];
    [self selectTab:0];   // highlight tab 0 on load

    [NSLayoutConstraint activateConstraints:@[
        [tabStack.topAnchor    constraintEqualToAnchor:tabBar.topAnchor    constant:3],
        [tabStack.bottomAnchor constraintEqualToAnchor:tabBar.bottomAnchor constant:-3],
        [tabStack.leadingAnchor  constraintEqualToAnchor:tabBar.leadingAnchor  constant:3],
        [tabStack.trailingAnchor constraintEqualToAnchor:tabBar.trailingAnchor constant:-3],
    ]];

    // ── 3 Panels ─────────────────────────────────────────
    self.rows = [NSMutableArray array];

    self.panelProxy  = [self buildPanelWithTitle:@"PROXY DELTA VIP"
                                          symbol:@"bolt.fill"              tint:HUD_CYAN   badge:@"AUTO"
                                        features:[self proxyFeaturesForBundle:self.bundleID]];
    self.panelDinhVi = [self buildPanelWithTitle:@"ĐỊNH VỊ SÚNG"
                                          symbol:@"location.fill"          tint:HUD_GREEN  badge:@"LIVE"
                                        features:[self dinhViFeaturesForBundle:self.bundleID]];
    self.panelModNV  = [self buildPanelWithTitle:@"MOD NHÂN VẬT"
                                          symbol:@"person.fill.badge.plus" tint:HUD_PURPLE badge:@"SOON"
                                        features:[self modNVFeaturesForBundle:self.bundleID]];

    self.panelDinhVi.hidden = YES;
    self.panelModNV.hidden  = YES;

    // Container stack — chỉ panel đang chọn visible, UIStackView tự co/giãn chiều cao
    UIStackView *panelsStack = [[UIStackView alloc] init];
    panelsStack.axis = UILayoutConstraintAxisVertical;
    panelsStack.spacing = 0;
    panelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:panelsStack];
    [panelsStack addArrangedSubview:self.panelProxy];
    [panelsStack addArrangedSubview:self.panelDinhVi];
    [panelsStack addArrangedSubview:self.panelModNV];

    // ── Status line ─────────────────────────────────────
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy";
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textColor = HUD_MUTED;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    // ── Nút MỞ GAME (gradient) ──────────────────────────
    self.openGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openGameButton setTitle:@"▶  MỞ GAME" forState:UIControlStateNormal];
    [self.openGameButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0] forState:UIControlStateNormal];
    self.openGameButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    self.openGameButton.layer.cornerRadius = 16;
    self.openGameButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.openGameButton.clipsToBounds = YES;
    self.openGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openGameButton addTarget:self action:@selector(launchGame) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.openGameButton];

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

        [tabBar.topAnchor constraintEqualToAnchor:bundleLabel.bottomAnchor constant:20],
        [tabBar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [tabBar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [tabBar.heightAnchor constraintEqualToConstant:46],

        [panelsStack.topAnchor constraintEqualToAnchor:tabBar.bottomAnchor constant:16],
        [panelsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [panelsStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [self.statusLabel.topAnchor constraintEqualToAnchor:panelsStack.bottomAnchor constant:18],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [self.openGameButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:20],
        [self.openGameButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [self.openGameButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [self.openGameButton.heightAnchor constraintEqualToConstant:54],
        [self.openGameButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-32],
    ]];
}

// Tạo 1 panel card (neon blur card) với title bar + danh sách feature rows.
// Các row được append vào self.rows để handleRow: / radio logic vẫn hoạt động.
- (UIView *)buildPanelWithTitle:(NSString *)title
                         symbol:(NSString *)symbol
                           tint:(UIColor *)tint
                          badge:(NSString *)badge
                       features:(NSArray<HUDFeature *> *)features {
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
        [self.rows addObject:row];
        [stack addArrangedSubview:row];
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
        [stack.bottomAnchor constraintEqualToAnchor:pc.bottomAnchor constant:-4],
    ]];

    return panelWrap;
}

#pragma mark - Tab switching

// Cập nhật màu sắc 3 pill buttons — tab chọn: neon fill + border; còn lại: muted
- (void)selectTab:(NSInteger)tab {
    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        UIButton *btn   = self.tabButtons[i];
        UIColor  *tint  = self.tabTints[i];
        BOOL active     = (i == tab);

        UIButtonConfiguration *conf = btn.configuration;
        conf.baseForegroundColor = active ? tint : HUD_MUTED;

        UIBackgroundConfiguration *bg = [UIBackgroundConfiguration clearConfiguration];
        bg.backgroundColor = active ? [tint colorWithAlphaComponent:0.16] : [UIColor clearColor];
        bg.cornerRadius    = 11;
        conf.background    = bg;
        btn.configuration  = conf;
        btn.layer.borderColor = active ? [tint colorWithAlphaComponent:0.45].CGColor
                                       : [UIColor clearColor].CGColor;
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

    // Pre-show toShow (trong UIStackView nó đã có width, chỉ collapse theo height)
    toShow.alpha  = 0;
    toShow.hidden = NO;

    // Phase 1: fade-out panel cũ
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{ toHide.alpha = 0; }
                     completion:^(BOOL f) {
        // Collapse cũ (UIStackView thu chiều cao ngay lập tức — alpha đã 0 nên không thấy)
        toHide.hidden = YES;
        toHide.alpha  = 1;   // reset để lần sau dùng lại
        // Phase 2: fade-in panel mới
        [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut
                         animations:^{ toShow.alpha = 1; }
                         completion:nil];
    }];

    NSString *hint = (tab == 0) ? @"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy"
                  : (tab == 1) ? @"Định Vị - Hiện Vị Trí Súng & Vật Phẩm Trên Map"
                               : @"Mod Nhân Vật - Đang Cập Nhật Thêm Tính Năng Mới";
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

    return @[
        [self featureWithSymbol:@"figure.stand" tint:HUD_ORANGE title:@"Proxy Body" subtitle:@"Full Đỏ Xoá Máu Vàng"
                     featureKey:k(@"body")  fileName:fn searchRoot:rt],

        [self featureWithSymbol:@"camera.metering.center.weighted"
                           tint:[UIColor colorWithRed:1.0 green:0.78 blue:0.25 alpha:1.0]
                          title:@"Proxy Cổ V1" subtitle:@"Aim Cổ Ít Lộ Hơn"
                     featureKey:k(@"chest") fileName:fn searchRoot:rt],

        [self featureWithSymbol:@"scope"          tint:HUD_PINK   title:@"Proxy Cổ V2"  subtitle:@"Vùng Cổ Máu Đỏ To Hơn, Bám Hơn"
                     featureKey:k(@"neck")  fileName:fn searchRoot:rt],

        [self featureWithSymbol:@"hand.draw.fill" tint:HUD_CYAN   title:@"Proxy Drag"  subtitle:@"Hỗ Trợ Kéo Nhẹ Tâm Lên Đỉnh Đầu"
                     featureKey:k(@"drag")  fileName:fn searchRoot:rt],

        [self featureWithSymbol:@"wand.and.stars" tint:HUD_PURPLE title:@"Proxy Magic" subtitle:@"Đạn Ma Thuật"
                     featureKey:k(@"magic") fileName:fn searchRoot:rt],
    ];
}

// ── Tab 2: Định Vị Súng ─────────────────────────────────────
// Mỗi loại súng / vật phẩm là 1 row độc lập (exclusive=NO).
// Điền fileName + featureKey khi có file thực; để nil → hiện "Đang Bảo Trì".
- (NSArray<HUDFeature *> *)dinhViFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL isMax = [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL isTH  = [bundleID isEqualToString:@"com.dts.freefireth"];

    NSString *shaders = isMax ? @"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D"
                     : (isTH  ? @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D" : nil);
    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *sf = supported ? shaders : nil;   // shaders file
    NSString *rt = supported ? root : nil;
    NSString *(^k)(NSString *) = ^NSString *(NSString *key) { return supported ? key : nil; };

    // Định vị tổng — file shaders, đang hoạt động
    HUDFeature *dv = [self featureWithSymbol:@"location.fill" tint:HUD_GREEN
                                       title:@"Định Vị Súng" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                  featureKey:k(@"dinhvi") fileName:sf searchRoot:rt];
    dv.exclusive = NO;

    // ── Thêm định vị súng khác vào đây — điền fileName khi có file ──
    // Ví dụ (hiện placeholder — featureKey/fileName nil → hiển thị "Đang Bảo Trì"):
    HUDFeature *dv2 = [self featureWithSymbol:@"scope" tint:HUD_ORANGE
                                        title:@"Định Vị AR" subtitle:@"Đang Cập Nhật"
                                   featureKey:nil fileName:nil searchRoot:nil];
    dv2.exclusive = NO;

    HUDFeature *dv3 = [self featureWithSymbol:@"bolt.horizontal.fill" tint:HUD_PINK
                                        title:@"Định Vị SMG" subtitle:@"Đang Cập Nhật"
                                   featureKey:nil fileName:nil searchRoot:nil];
    dv3.exclusive = NO;

    return @[dv, dv2, dv3];
}

// ── Tab 3: Mod Nhân Vật ─────────────────────────────────────
// Tất cả placeholder — điền featureKey + fileName khi có file.
- (NSArray<HUDFeature *> *)modNVFeaturesForBundle:(NSString *)bundleID {
    HUDFeature *nv1 = [self featureWithSymbol:@"person.fill"
                                         tint:HUD_ORANGE
                                        title:@"Mod Nhân Vật"
                                     subtitle:@"Đang Cập Nhật"
                                   featureKey:nil fileName:nil searchRoot:nil];
    nv1.exclusive = NO;

    HUDFeature *nv2 = [self featureWithSymbol:@"tshirt.fill"
                                         tint:[UIColor colorWithRed:1.0 green:0.78 blue:0.25 alpha:1.0]
                                        title:@"Mod Trang Phục"
                                     subtitle:@"Đang Cập Nhật"
                                   featureKey:nil fileName:nil searchRoot:nil];
    nv2.exclusive = NO;

    HUDFeature *nv3 = [self featureWithSymbol:@"star.fill"
                                         tint:HUD_CYAN
                                        title:@"Mod Đặc Biệt"
                                     subtitle:@"Đang Cập Nhật"
                                   featureKey:nil fileName:nil searchRoot:nil];
    nv3.exclusive = NO;

    return @[nv1, nv2, nv3];
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
        [self setStatus:@"⛔ Phát hiện can thiệp — đã khoá chức năng" color:HUD_RED];
        return;
    }

    // Khoá chức năng sau license key hợp lệ (đã bind đúng máy)
    if ([KeyManager shared].state != KeyStateActive) {
        [row.toggle setOn:!isOn animated:YES];
        [row setActive:NO];
        NSString *msg = ([KeyManager shared].state == KeyStateExpired)
            ? @"🔒 Key đã hết hạn — vui lòng gia hạn"
            : @"🔒 Cần nhập license key hợp lệ để dùng";
        [self setStatus:msg color:HUD_RED];
        UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
        [nfb notificationOccurred:UINotificationFeedbackTypeError];
        return;
    }

    if (!f.configured) {
        [row.toggle setOn:!isOn animated:YES];
        [row setActive:NO];
        [row showResult:NO];
        [self setStatus:[NSString stringWithFormat:@"🔧 %@ đang Bảo Trì", f.title] color:HUD_ORANGE];
        return;
    }

    [row setActive:isOn];

    // Radio CHỈ giữa các aim (exclusive). Bật 1 aim → tắt aim khác.
    // Định vị (exclusive=NO) là ĐỘC LẬP: bật nó không tắt aim, và aim bật cũng không tắt nó.
    if (isOn && f.exclusive) {
        for (HUDFeatureRow *other in self.rows) {
            if (other != row && other.feature.exclusive && other.toggle.isOn) {
                [other.toggle setOn:NO animated:YES];   // programmatic → không kích hoạt paste
                [other setActive:NO];
                other.statusDot.text = @"";
            }
        }
    }

    [row setLoading:YES];
    [self setStatus:@"⏳ Đang Kích Hoạt" color:HUD_MUTED];

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
            statusText = isOn ? [NSString stringWithFormat:@"✅ Kích Hoạt Thành Công %@", f.title]
                              : [NSString stringWithFormat:@"✅ Đã Tắt Thành Công %@", f.title];
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

@end
