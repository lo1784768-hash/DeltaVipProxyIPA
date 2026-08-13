#import "HUDControlViewController.h"
#import "AutoPasteManager.h"

// ── Palette ─────────────────────────────────────────────
#define HUD_BG_TOP      [UIColor colorWithRed:0.055 green:0.055 blue:0.094 alpha:1.0]
#define HUD_BG_BOTTOM   [UIColor colorWithRed:0.075 green:0.106 blue:0.204 alpha:1.0]
#define HUD_ORANGE      [UIColor colorWithRed:1.000 green:0.361 blue:0.169 alpha:1.0]
#define HUD_CYAN        [UIColor colorWithRed:0.000 green:0.831 blue:1.000 alpha:1.0]
#define HUD_PINK        [UIColor colorWithRed:1.000 green:0.231 blue:0.400 alpha:1.0]
#define HUD_PURPLE      [UIColor colorWithRed:0.659 green:0.333 blue:0.969 alpha:1.0]
#define HUD_MUTED       [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0]
#define HUD_GREEN       [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define HUD_RED         [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define HUD_TEXT        [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0]

#pragma mark - Feature model

@interface HUDFeature : NSObject
@property (nonatomic, copy)   NSString *symbol;       // SF Symbol name
@property (nonatomic, strong) UIColor  *tint;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *onURL;        // paste when ON  (MOD)
@property (nonatomic, copy)   NSString *offURL;       // paste when OFF (GỐC)
@property (nonatomic, copy)   NSString *relativePath; // target under app Documents
@property (nonatomic, readonly) BOOL configured;
@end

@implementation HUDFeature
- (BOOL)configured { return self.onURL.length && self.offURL.length && self.relativePath.length; }
@end

#pragma mark - Feature row

@class HUDFeatureRow;

@interface HUDFeatureRow : UIView
@property (nonatomic, strong) HUDFeature *feature;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusDot;
@property (nonatomic, copy)   void (^onChanged)(HUDFeatureRow *row, BOOL isOn);
- (instancetype)initWithFeature:(HUDFeature *)feature;
- (void)setLoading:(BOOL)loading;
- (void)showResult:(BOOL)success;
@end

@implementation HUDFeatureRow

- (instancetype)initWithFeature:(HUDFeature *)feature {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _feature = feature;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        // Icon chip (rounded square, tinted bg + SF Symbol)
        UIView *chip = [[UIView alloc] init];
        chip.backgroundColor = [feature.tint colorWithAlphaComponent:0.18];
        chip.layer.cornerRadius = 9;
        chip.layer.cornerCurve = kCACornerCurveContinuous;
        chip.layer.borderColor = [feature.tint colorWithAlphaComponent:0.45].CGColor;
        chip.layer.borderWidth = 1;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:chip];

        UIImageConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        UIImageView *symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:feature.symbol withConfiguration:cfg]];
        symbol.tintColor = feature.tint;
        symbol.contentMode = UIViewContentModeScaleAspectFit;
        symbol.translatesAutoresizingMaskIntoConstraints = NO;
        [chip addSubview:symbol];

        UILabel *title = [[UILabel alloc] init];
        title.text = feature.title;
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = HUD_TEXT;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:title];

        _statusDot = [[UILabel alloc] init];
        _statusDot.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _statusDot.textAlignment = NSTextAlignmentRight;
        _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_statusDot];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.color = HUD_CYAN;
        _spinner.hidesWhenStopped = YES;
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];

        _toggle = [[UISwitch alloc] init];
        _toggle.onTintColor = HUD_GREEN;
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggle addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggle];

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:56],

            [chip.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [chip.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [chip.widthAnchor constraintEqualToConstant:34],
            [chip.heightAnchor constraintEqualToConstant:34],

            [symbol.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
            [symbol.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],

            [title.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
            [title.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

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

- (void)switchChanged {
    if (self.onChanged) self.onChanged(self, self.toggle.isOn);
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
@property (nonatomic, strong) UILabel  *statusLabel;
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

    [self setupNavBarAppearance];
    [self buildUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgGradient.frame = self.view.bounds;
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
    self.navigationController.navigationBar.tintColor = HUD_CYAN; // back chevron
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.tintColor = nil; // restore for the list screen
}

- (void)buildUI {
    // ── Scroll container ────────────────────────────────
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
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
    iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    iconView.layer.borderWidth = 1;
    iconView.layer.magnificationFilter = kCAFilterTrilinear;
    iconView.layer.shadowColor = HUD_CYAN.CGColor;
    iconView.layer.shadowOpacity = 0.45;
    iconView.layer.shadowRadius = 14;
    iconView.layer.shadowOffset = CGSizeMake(0, 4);
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = self.appName;
    nameLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
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

    // ── Panel (blur → hoà vào nền gradient) ─────────────
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.clipsToBounds = YES;
    panel.layer.cornerRadius = 18;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.borderColor = [HUD_CYAN colorWithAlphaComponent:0.30].CGColor;
    panel.layer.borderWidth = 1;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:panel];
    UIView *panelContent = panel.contentView;

    // Neon title bar
    UIView *titleBar = [[UIView alloc] init];
    titleBar.translatesAutoresizingMaskIntoConstraints = NO;
    [panelContent addSubview:titleBar];

    UIView *accent = [[UIView alloc] init];
    accent.backgroundColor = HUD_CYAN;
    accent.layer.cornerRadius = 2;
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:accent];

    UIImageView *bolt = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bolt.fill"]];
    bolt.tintColor = HUD_CYAN;
    bolt.contentMode = UIViewContentModeScaleAspectFit;
    bolt.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:bolt];

    UILabel *menuTitle = [[UILabel alloc] init];
    menuTitle.text = @"PROXY MOD MENU";
    menuTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    menuTitle.textColor = HUD_CYAN;
    menuTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:menuTitle];

    UILabel *hint = [[UILabel alloc] init];
    hint.text = @"AUTO";
    hint.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    hint.textColor = HUD_MUTED;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:hint];

    // Rows stack
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [panelContent addSubview:stack];

    __weak typeof(self) weakSelf = self;
    for (HUDFeature *feature in [self featuresForBundle:self.bundleID]) {
        HUDFeatureRow *row = [[HUDFeatureRow alloc] initWithFeature:feature];
        row.onChanged = ^(HUDFeatureRow *r, BOOL isOn) {
            [weakSelf handleRow:r on:isOn];
        };
        [stack addArrangedSubview:row];
    }

    // ── Status line ─────────────────────────────────────
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Sẵn sàng — gạt công tắc để tự động paste";
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textColor = HUD_MUTED;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    // ── Constraints ─────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [iconView.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:80],
        [iconView.heightAnchor constraintEqualToConstant:80],

        [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [nameLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [bundleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:3],
        [bundleLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [bundleLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],

        [panel.topAnchor constraintEqualToAnchor:bundleLabel.bottomAnchor constant:24],
        [panel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [panel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [titleBar.topAnchor constraintEqualToAnchor:panelContent.topAnchor],
        [titleBar.leadingAnchor constraintEqualToAnchor:panelContent.leadingAnchor],
        [titleBar.trailingAnchor constraintEqualToAnchor:panelContent.trailingAnchor],
        [titleBar.heightAnchor constraintEqualToConstant:44],

        [accent.leadingAnchor constraintEqualToAnchor:titleBar.leadingAnchor constant:16],
        [accent.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [accent.widthAnchor constraintEqualToConstant:4],
        [accent.heightAnchor constraintEqualToConstant:16],

        [bolt.leadingAnchor constraintEqualToAnchor:accent.trailingAnchor constant:10],
        [bolt.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [bolt.widthAnchor constraintEqualToConstant:15],
        [bolt.heightAnchor constraintEqualToConstant:15],

        [menuTitle.leadingAnchor constraintEqualToAnchor:bolt.trailingAnchor constant:7],
        [menuTitle.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],

        [hint.trailingAnchor constraintEqualToAnchor:titleBar.trailingAnchor constant:-16],
        [hint.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],

        [stack.topAnchor constraintEqualToAnchor:titleBar.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:panelContent.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:panelContent.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:panelContent.bottomAnchor constant:-4],

        [self.statusLabel.topAnchor constraintEqualToAnchor:panel.bottomAnchor constant:18],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-32],
    ]];
}

#pragma mark - Feature config

- (HUDFeature *)featureWithSymbol:(NSString *)symbol tint:(UIColor *)tint title:(NSString *)title
                            onURL:(NSString *)onURL offURL:(NSString *)offURL
                     relativePath:(NSString *)relativePath {
    HUDFeature *f = [HUDFeature new];
    f.symbol = symbol; f.tint = tint; f.title = title;
    f.onURL = onURL; f.offURL = offURL; f.relativePath = relativePath;
    return f;
}

- (NSArray<HUDFeature *> *)featuresForBundle:(NSString *)bundleID {
    BOOL isTH = [bundleID isEqualToString:@"com.dts.freefireth"];
    NSString *base = @"Device Storage/[MHA-C2] App Data/com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles/";
    NSString *cacheRes = [base stringByAppendingString:@"cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"];

    return @[
        // Body — đã cấu hình
        [self featureWithSymbol:@"figure.stand" tint:HUD_ORANGE title:@"Proxy Body"
                          onURL:(isTH ? @"https://getuid.vip/ServerPaste/pastebody/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D" : nil)
                         offURL:(isTH ? @"https://getuid.vip/ServerPaste/pastebodygoc/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D" : nil)
                   relativePath:(isTH ? cacheRes : nil)],

        // Chờ URL từ bạn
        [self featureWithSymbol:@"scope"          tint:HUD_PINK   title:@"Proxy Neck"  onURL:nil offURL:nil relativePath:nil],
        [self featureWithSymbol:@"hand.draw.fill" tint:HUD_CYAN   title:@"Proxy Drag"  onURL:nil offURL:nil relativePath:nil],
        [self featureWithSymbol:@"wand.and.stars" tint:HUD_PURPLE title:@"Proxy Magic" onURL:nil offURL:nil relativePath:nil],
    ];
}

#pragma mark - Toggle handling (auto-paste)

- (void)handleRow:(HUDFeatureRow *)row on:(BOOL)isOn {
    UISelectionFeedbackGenerator *sel = [[UISelectionFeedbackGenerator alloc] init];
    [sel selectionChanged];

    HUDFeature *f = row.feature;
    if (!f.configured) {
        [row.toggle setOn:!isOn animated:YES];
        [row showResult:NO];
        [self setStatus:[NSString stringWithFormat:@"⚠️ %@ chưa có URL", f.title] color:HUD_ORANGE];
        return;
    }

    NSString *url = isOn ? f.onURL : f.offURL;
    NSString *mode = isOn ? @"MOD" : @"GỐC";

    [row setLoading:YES];
    [self setStatus:[NSString stringWithFormat:@"⏳ %@ → %@ …", f.title, mode] color:HUD_MUTED];

    __weak typeof(self) weakSelf = self;
    [[AutoPasteManager sharedManager] pasteFromURL:url
                                    toRelativePath:f.relativePath
                                        completion:^(BOOL success, NSString *message) {
        [row setLoading:NO];
        [row showResult:success];
        [weakSelf setStatus:[NSString stringWithFormat:@"%@ · %@ (%@)", message, f.title, mode]
                      color:(success ? HUD_GREEN : HUD_RED)];
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
