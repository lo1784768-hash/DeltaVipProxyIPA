#import "AppDataViewController.h"
#import "FileManagerViewController.h"
#import "AppEnumerator.h"
#import "AppStatusChecker.h"
#import "MCMFilzaIntegration.h"
#import "SandboxEscapeManager.h"
#import "VirtualFileSystemBuilder.h"
#import "DebugLogger.h"
#import "ImageDownloader.h"
#import "HUDControlViewController.h"
#import "KeyManager.h"
#import "KeyBarView.h"
#import "BrandTheme.h"
#import "AppPaths.h"
#import "UpdateGate.h"
#import "LanguageManager.h"
#import "PolicyViewController.h"
#import "SettingsViewController.h"
#import <sys/sysctl.h>

// ── Synthwave Arcade palette ───────────────────────────────────────────────────
// Defines phải đặt TRƯỚC mọi @implementation dùng chúng
#define SW_PINK   [UIColor colorWithRed:1.0   green:0.0   blue:0.498 alpha:1.0]  // #FF007F
#define SW_CYAN   [UIColor colorWithRed:0.0   green:0.941 blue:1.0   alpha:1.0]  // #00F0FF
#define SW_YELLOW [UIColor colorWithRed:1.0   green:0.902 blue:0.0   alpha:1.0]  // #FFE600
#define SW_CARD   [UIColor colorWithRed:0.106 green:0.082 blue:0.157 alpha:1.0]  // #1B1528
#define SW_BG     [UIColor colorWithRed:0.055 green:0.043 blue:0.086 alpha:1.0]  // #0E0B16

#pragma mark - GlassView (frosted card khớp web)

@interface GlassView : UIView
@end
@implementation GlassView {
    CAGradientLayer *_sheen;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Synthwave Arcade: card bg + subtle top sheen
        self.backgroundColor = SW_CARD;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
        self.layer.borderWidth = 1;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        _sheen = [CAGradientLayer layer];
        _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.04].CGColor,
                          (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
        _sheen.startPoint = CGPointMake(0.5, 0.0);
        _sheen.endPoint   = CGPointMake(0.5, 0.5);
        [self.layer addSublayer:_sheen];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _sheen.frame = self.bounds;
    _sheen.cornerRadius = self.layer.cornerRadius;
}
@end

@interface AppDataCell : UICollectionViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
// Neon glow border shown when selected
@property (nonatomic, strong) CAGradientLayer *glowBorder;
@property (nonatomic, strong) CALayer *glowShadow;
@end

// Diagonal stripe pattern for Synthwave bg
static UIColor *SWStripePattern(void) {
    CGFloat s = 14;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext,
            [UIColor colorWithRed:1.0 green:0.0 blue:0.498 alpha:0.04].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 1.0);
        // Diagonal lines -45°
        CGContextMoveToPoint(ctx.CGContext, 0, s); CGContextAddLineToPoint(ctx.CGContext, s, 0);
        CGContextMoveToPoint(ctx.CGContext, -s, s); CGContextAddLineToPoint(ctx.CGContext, 0, 0);
        CGContextMoveToPoint(ctx.CGContext, s, s*2); CGContextAddLineToPoint(ctx.CGContext, s*2, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}

@implementation AppDataCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];

    // ── Synthwave Arcade card ────────────────────────────────────────────────
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = SW_CARD;
    self.cardView.layer.cornerRadius = 16;
    self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.cardView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    self.cardView.layer.borderWidth = 1.5;
    // Hard-drop shadow — Arcade style (will be tinted per game in cellForItem)
    self.cardView.layer.shadowColor  = SW_PINK.CGColor;
    self.cardView.layer.shadowOpacity = 0.35;
    self.cardView.layer.shadowOffset  = CGSizeMake(4, 4);
    self.cardView.layer.shadowRadius  = 0;   // crisp hard shadow
    self.cardView.clipsToBounds = NO;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    // Inner clip view (for banner + rounded corners)
    UIView *clipView = [[UIView alloc] init];
    clipView.backgroundColor = [UIColor clearColor];
    clipView.layer.cornerRadius = 16;
    clipView.layer.cornerCurve = kCACornerCurveContinuous;
    clipView.clipsToBounds = YES;
    clipView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:clipView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [clipView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [clipView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [clipView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [clipView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor],
    ]];

    // ── Banner: full-width game image ─────────────────────────────────────
    UIView *bannerView = [[UIView alloc] init];
    bannerView.backgroundColor = [UIColor colorWithRed:0.13 green:0.10 blue:0.22 alpha:1.0];
    bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    [clipView addSubview:bannerView];
    self.bannerView = bannerView;

    // Game image fills banner
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.clipsToBounds = YES;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [bannerView addSubview:self.iconView];

    // Gradient overlay: image fades into card background at bottom
    CAGradientLayer *fadeGrad = [CAGradientLayer layer];
    fadeGrad.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)SW_CARD.CGColor,
    ];
    fadeGrad.startPoint = CGPointMake(0.5, 0.4);
    fadeGrad.endPoint   = CGPointMake(0.5, 1.0);
    // Will be sized in layoutSubviews via tag
    self.glowBorder = fadeGrad;  // reuse property to carry layer reference
    [bannerView.layer addSublayer:fadeGrad];

    [NSLayoutConstraint activateConstraints:@[
        [bannerView.topAnchor constraintEqualToAnchor:clipView.topAnchor],
        [bannerView.leadingAnchor constraintEqualToAnchor:clipView.leadingAnchor],
        [bannerView.trailingAnchor constraintEqualToAnchor:clipView.trailingAnchor],
        [bannerView.heightAnchor constraintEqualToConstant:108],
        [self.iconView.topAnchor constraintEqualToAnchor:bannerView.topAnchor],
        [self.iconView.leadingAnchor constraintEqualToAnchor:bannerView.leadingAnchor],
        [self.iconView.trailingAnchor constraintEqualToAnchor:bannerView.trailingAnchor],
        [self.iconView.bottomAnchor constraintEqualToAnchor:bannerView.bottomAnchor],
    ]];

    // ── Game label sticker (top-left corner of banner) ────────────────────
    self.bundleLabel = [[UILabel alloc] init];  // reused as sticker label
    self.bundleLabel.font = [UIFont monospacedSystemFontOfSize:8 weight:UIFontWeightBold];
    self.bundleLabel.textColor = [UIColor whiteColor];
    self.bundleLabel.backgroundColor = SW_PINK;
    self.bundleLabel.layer.cornerRadius = 3;
    self.bundleLabel.layer.masksToBounds = YES;
    self.bundleLabel.textAlignment = NSTextAlignmentCenter;
    self.bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [clipView addSubview:self.bundleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.bundleLabel.topAnchor constraintEqualToAnchor:clipView.topAnchor constant:8],
        [self.bundleLabel.leadingAnchor constraintEqualToAnchor:clipView.leadingAnchor constant:8],
        [self.bundleLabel.heightAnchor constraintEqualToConstant:16],
    ]];

    // ── App name — Arcade style, uppercase heavy ───────────────────────────
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    self.nameLabel.textColor = [UIColor whiteColor];
    self.nameLabel.textAlignment = NSTextAlignmentLeft;
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [clipView addSubview:self.nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:bannerView.bottomAnchor constant:8],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:clipView.leadingAnchor constant:10],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:clipView.trailingAnchor constant:-10],
        [self.nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:clipView.bottomAnchor constant:-10],
    ]];

    // ── Ambient glow shadow (reuse glowShadow for selected state) ─────────
    self.glowShadow = [CALayer layer];
    self.glowShadow.shadowColor    = SW_PINK.CGColor;
    self.glowShadow.shadowOpacity  = 0;
    self.glowShadow.shadowRadius   = 16;
    self.glowShadow.shadowOffset   = CGSizeZero;
    self.glowShadow.backgroundColor = [UIColor clearColor].CGColor;
    [self.layer insertSublayer:self.glowShadow atIndex:0];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glowShadow.frame = self.bounds;
    // Resize fade gradient to match bannerView bounds
    CALayer *bannerLayer = self.bannerView.layer;
    self.glowBorder.frame = bannerLayer.bounds;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self applyGlow:selected animated:YES];
}

- (void)applyGlow:(BOOL)on animated:(BOOL)animated {
    void (^change)(void) = ^{
        self.glowShadow.shadowOpacity = on ? 0.65f : 0.0f;
        self.cardView.layer.borderColor = on
            ? [UIColor colorWithWhite:1 alpha:0.35].CGColor
            : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        // Intensify card hard shadow while selected (keep offset/radius arcade-style)
        self.cardView.layer.shadowOpacity = on ? 0.65f : 0.35f;
    };
    if (animated) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.25];
        [CATransaction setAnimationTimingFunction:
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        change();
        [CATransaction commit];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        change();
        [CATransaction commit];
    }
}

// Arcade bounce: scale down on press, spring back on release
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.08 delay:0
         usingSpringWithDamping:0.85 initialSpringVelocity:4
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.cardView.transform = CGAffineTransformMakeScale(0.94, 0.94); }
                     completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:0.5 initialSpringVelocity:6
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.cardView.transform = CGAffineTransformIdentity; }
                     completion:nil];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.2 animations:^{ self.cardView.transform = CGAffineTransformIdentity; }];
}

@end

@interface AppDataViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *appIDs;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *appDisplayNames;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *customAppImages;
@property (nonatomic, strong) UIView *statsView;
@property (nonatomic, strong) CAGradientLayer *bgGradient;
@property (nonatomic, strong) CAGradientLayer *purpleGlow;
@property (nonatomic, strong) CAGradientLayer *cyanGlow;
@property (nonatomic, strong) KeyBarView *keyBar;
@property (nonatomic, strong) NSTimer *keyTimer;
@property (nonatomic, strong) UIView *loadingView;   // Loading overlay
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // ── Synthwave Arcade title ─────────────────────────────────────────────
    // "DELTA" white · " IPA" pink · " VN" white — uppercase heavy
    NSMutableAttributedString *titleAttr = [[NSMutableAttributedString alloc] init];
    NSDictionary *titleBase = @{
        NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSKernAttributeName: @1.5,
    };
    NSDictionary *titlePink = @{
        NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy],
        NSForegroundColorAttributeName: SW_PINK,
        NSKernAttributeName: @1.5,
    };
    [titleAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@"DELTA" attributes:titleBase]];
    [titleAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@" IPA" attributes:titlePink]];
    [titleAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@" VN" attributes:titleBase]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.attributedText = titleAttr;
    [titleLabel sizeToFit];

    // Version badge — pink border, arcade style
    UILabel *badge = [[UILabel alloc] init];
    NSString *_bdgVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.4.3";
    badge.text = [NSString stringWithFormat:@"  v%@  ", _bdgVer];
    badge.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    badge.textColor = SW_PINK;
    badge.backgroundColor = [SW_PINK colorWithAlphaComponent:0.10];
    badge.layer.cornerRadius = 4;
    badge.layer.masksToBounds = YES;
    badge.layer.borderColor = SW_PINK.CGColor;
    badge.layer.borderWidth = 1.5;

    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, badge]];
    titleStack.axis = UILayoutConstraintAxisHorizontal;
    titleStack.spacing = 7;
    titleStack.alignment = UIStackViewAlignmentCenter;
    self.navigationItem.titleView = titleStack;

    // ── Settings → glass gear button ────────────────────────────────────────
    // Wrap trong UIView cố định 34×34 để iOS không auto-resize shape thành marquise
    // Gear button — Arcade square style
    UIView *gearContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
    gearContainer.backgroundColor = [SW_CYAN colorWithAlphaComponent:0.08];
    gearContainer.layer.cornerRadius = 8;
    gearContainer.layer.cornerCurve = kCACornerCurveContinuous;
    gearContainer.layer.masksToBounds = NO;
    gearContainer.layer.borderColor = [SW_CYAN colorWithAlphaComponent:0.4].CGColor;
    gearContainer.layer.borderWidth = 1.5;
    // Hard shadow — Arcade
    gearContainer.layer.shadowColor  = SW_CYAN.CGColor;
    gearContainer.layer.shadowOpacity = 0.35;
    gearContainer.layer.shadowRadius  = 0;
    gearContainer.layer.shadowOffset  = CGSizeMake(2, 2);

    UIButton *settingsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    settingsBtn.frame = gearContainer.bounds;
    settingsBtn.layer.cornerRadius = 8;
    settingsBtn.layer.masksToBounds = YES;
    UIImageSymbolConfiguration *rCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [settingsBtn setImage:[UIImage systemImageNamed:@"gearshape.fill" withConfiguration:rCfg]
                 forState:UIControlStateNormal];
    settingsBtn.tintColor = SW_CYAN;
    settingsBtn.backgroundColor = [UIColor clearColor];
    settingsBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [settingsBtn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    [gearContainer addSubview:settingsBtn];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:gearContainer];

    // Display name mapping
    self.appDisplayNames = @{
        @"com.dts.freefiremax": @"Free Fire Max",
        @"com.dts.freefireth": @"Free Fire"
    };
    self.customAppImages = @{
        @"com.dts.freefiremax": @"FreeFireMax",
        @"com.dts.freefireth": @"FreeFireTH"
    };
    self.view.backgroundColor = SW_BG;

    // Synthwave gradient: deep purple top → slightly warmer bottom
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[
        (id)[UIColor colorWithRed:0.055 green:0.043 blue:0.086 alpha:1.0].CGColor,  // #0E0B16
        (id)[UIColor colorWithRed:0.068 green:0.047 blue:0.118 alpha:1.0].CGColor,  // #11081E
    ];
    bg.startPoint = CGPointMake(0.5, 0.0);
    bg.endPoint   = CGPointMake(0.5, 1.0);
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];
    self.bgGradient = bg;

    // Pink radial glow (top) + Cyan radial glow (bottom)
    self.purpleGlow = BrandRadialGlow([SW_PINK colorWithAlphaComponent:0.10]);
    self.cyanGlow   = BrandRadialGlow([SW_CYAN colorWithAlphaComponent:0.08]);
    [self.view.layer insertSublayer:self.purpleGlow above:bg];
    [self.view.layer insertSublayer:self.cyanGlow above:self.purpleGlow];

    // Diagonal stripe pattern
    UIView *grid = [[UIView alloc] initWithFrame:self.view.bounds];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = SWStripePattern();
    grid.userInteractionEnabled = NO;
    [self.view addSubview:grid];

    // Nav bar transparent
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithTransparentBackground];
    self.navigationItem.standardAppearance = ap;
    self.navigationItem.scrollEdgeAppearance = ap;
    self.navigationController.navigationBar.tintColor = SW_PINK;

    // Stats (device info card)
    [self createStatsView];

    // Collection view — Synthwave 2-column grid
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cvW = self.view.bounds.size.width;
    layout.itemSize = CGSizeMake((cvW - 44.0) / 2.0, 178);
    layout.minimumLineSpacing      = 12;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(10, 16, 16, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                              collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 110, 0); // room for floating pill
    [self.collectionView registerClass:[AppDataCell class] forCellWithReuseIdentifier:@"AppCell"];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.collectionView];

    // ── Floating Pill KeyBar ───────────────────────────────────────────────
    self.keyBar = [[KeyBarView alloc] init];
    self.keyBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyBar.layer.shadowColor  = SW_PINK.CGColor;
    self.keyBar.layer.shadowOpacity = 0.40;
    self.keyBar.layer.shadowRadius  = 18;
    self.keyBar.layer.shadowOffset  = CGSizeZero;
    [self.view addSubview:self.keyBar];

    __weak typeof(self) weakSelf = self;
    self.keyBar.onAddTapped    = ^{ [weakSelf promptAddKey]; };
    self.keyBar.onInfoTapped   = ^{ [weakSelf showUDIDInfo]; };
    self.keyBar.onPolicyTapped = ^{ [weakSelf showPolicy]; };

    // Layout: full-width collection view, floating pill overlays bottom
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:12],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Floating pill: 16pt inset each side, 16pt above safe-area bottom, 68pt tall
        [self.keyBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.keyBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.keyBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [self.keyBar.heightAnchor constraintEqualToConstant:68],
    ]];

    // Load apps immediately without waiting
    [self loadAppsImmediately];

    // Chặn bản cũ: bắt buộc cập nhật nếu app cũ hơn min_version
    [UpdateGate checkFromViewController:self];

    // Cập nhật support label khi đổi ngôn ngữ
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(refreshLocalizedStrings)
        name:LMLanguageChangedNotification object:nil];

    // Responsive layout khi xoay màn hình
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(_orientationDidChange:)
        name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)refreshLocalizedStrings {
    // Cập nhật label "Supported" / "Not Supported" (tag 998)
    BOOL supported = [self isIOSSupported];
    UILabel *supportLabel = (UILabel *)[self.statsView viewWithTag:998];
    if (supportLabel) {
        supportLabel.text = supported
            ? LS(@"✦ Có Hỗ Trợ ✦", @"✦ Supported ✦")
            : LS(@"✦ Chưa Hỗ Trợ ✦", @"✦ Not Supported ✦");
    }
    // Refresh keyBar labels
    [self.keyBar update];
}

#pragma mark - License key

- (void)promptAddKey {
    KeyManager *km = [KeyManager shared];
    NSString *udid = [km deviceUDID];
    NSString *msg  = [NSString stringWithFormat:LS(@"Dán key để kích hoạt.\n\nThiết bị này:\n%@",
                                                    @"Paste key to activate.\n\nThis device:\n%@"), udid];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"License Key"
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = LS(@"Nhập / dán key…", @"Enter / paste key…");
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.text = [KeyManager shared].keyCode;
    }];

    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Kích hoạt", @"Activate") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *key = weakAlert.textFields.firstObject.text;
        // Đặt UI loading state trước khi gọi network
        [[KeyManager shared] activateKey:key completion:^(BOOL success, NSString *message) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.keyBar update];
            KeyManager *km = [KeyManager shared];
            if (!success && km.pendingConfirmKey) {
                // Alert gốc đã dismiss (user bấm Kích hoạt) — present confirm sau 1 tick
                // để tránh "attempt to present while a presentation is in progress" crash
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) s = weakSelf;
                    if (!s) return;
                    UIAlertController *confirm = [UIAlertController
                        alertControllerWithTitle:LS(@"⚠️ Thông Báo Quan Trọng", @"⚠️ Important Notice")
                                        message:km.pendingConfirmMessage
                                 preferredStyle:UIAlertControllerStyleAlert];
                    [confirm addAction:[UIAlertAction actionWithTitle:LS(@"Đồng Ý", @"Agree")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *ca) {
                        [[KeyManager shared] confirmPendingActivationWithCompletion:^(BOOL ok, NSString *msg) {
                            __strong typeof(weakSelf) ss = weakSelf;
                            if (!ss) return;
                            [ss.keyBar update];
                            [ss toast:msg success:ok];
                        }];
                    }]];
                    [confirm addAction:[UIAlertAction actionWithTitle:LS(@"Huỷ", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil]];
                    // Nếu VC đang present cái gì đó (alert cũ đang dismiss), đợi nó xong
                    if (s.presentedViewController) {
                        [s.presentedViewController dismissViewControllerAnimated:NO completion:^{
                            [weakSelf presentViewController:confirm animated:YES completion:nil];
                        }];
                    } else {
                        [s presentViewController:confirm animated:YES completion:nil];
                    }
                });
            } else {
                [self toast:message success:success];
            }
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Sao chép UDID", @"Copy UDID") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = udid;
        [weakSelf toast:LS(@"Đã sao chép UDID vào clipboard.", @"Copied UDID to clipboard.") success:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Đóng", @"Close") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showUDIDInfo {
    KeyManager *km = [KeyManager shared];
    NSString *udid = [km deviceUDID];
    NSString *udidSrc;
    if (km.usingHardwareUDID)              udidSrc = LS(@"UDID phần cứng (MobileGestalt)", @"Hardware UDID (MobileGestalt)");
    else if ([udid hasPrefix:@"IV-"])      udidSrc = LS(@"Vendor ID (eSign ổn định)", @"Vendor ID (eSign stable)");
    else                                   udidSrc = @"Keychain UUID (last resort)";
    NSString *src = udidSrc;
    NSString *msg  = [NSString stringWithFormat:
        LS(@"Nguồn: %@\n\n%@\n\nGửi ID này cho admin khi cần mở khoá / chuyển máy.",
           @"Source: %@\n\n%@\n\nSend this ID to admin when you need to unlock / transfer device."),
        src, udid];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LS(@"🆔 ID Thiết Bị", @"🆔 Device ID")
                                                                  message:msg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Sao chép ID", @"Copy ID") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = udid;
        [weakSelf toast:LS(@"Đã sao chép ID thiết bị.", @"Copied device ID.") success:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Đóng", @"Close") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAdminReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔧 Admin — Unlock Device"
                                                                  message:@"Enter key + admin password to reset bind (new device will re-bind)."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Key to unlock";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.text = [KeyManager shared].keyCode;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Admin password";
        tf.secureTextEntry = YES;
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *key  = alert.textFields[0].text;
        NSString *pass = alert.textFields[1].text;
        [[KeyManager shared] resetBindForKey:key adminPass:pass completion:^(BOOL success, NSString *message) {
            [weakSelf toast:message success:success];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toast:(NSString *)message success:(BOOL)success {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:(success ? @"✅ Success" : @"⚠️ Error")
                                                              message:message
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    // Nếu đang present VC khác (alert/confirm đang dismiss), đợi nó xong rồi present
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:a animated:YES completion:nil];
        }];
    } else {
        [self presentViewController:a animated:YES completion:nil];
    }
}

// Load apps immediately on first view
- (void)loadAppsImmediately {
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"[AppData] 🚀 Quick loading app list..."];

    // [1] Báo hiệu unrestricted TRƯỚC khi khởi tạo MCM.
    //     Khi kexploit/ chạy, nó sẽ bypass sandbox trước bước này;
    //     flag này cho MCM wrapper biết có thể dùng sandbox extension activation.
    MCMFilzaSetUnrestrictedFilesystem(YES);

    // [2] Initialize MCM bridge
    MCMFilzaStart();

    // Get virtual root
    NSString *virtualRoot = AppHiddenDataRoot();
    [logger log:@"[AppData] Virtual root: %@", virtualRoot];

    // Scan the virtual filesystem directory immediately
    NSString *appDataPath = [virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appDataPath error:nil];

    if (dirContents && dirContents.count > 0) {
        // Only show target apps
        NSArray *targetApps = @[@"com.dts.freefiremax", @"com.dts.freefireth"];
        NSMutableArray *appIDs = [NSMutableArray array];

        for (NSString *targetApp in targetApps) {
            for (NSString *item in dirContents) {
                if ([item isEqualToString:targetApp]) {
                    [appIDs addObject:targetApp];
                    [logger log:@"[AppData]   📦 %@", targetApp];
                    break;
                }
            }
        }

        self.appIDs = appIDs;
        [logger log:@"[AppData] ✅ Found %lu apps immediately", (unsigned long)self.appIDs.count];
        [self updateStatsKeysCount];
        [self.collectionView reloadData];
    } else {
        [logger log:@"[AppData] ⚠️  No apps in VFS yet, loading in background..."];
        // Hiện loading screen trong khi build VFS (lần đầu mở app)
        [self showLoadingView];
        [self loadApps];
    }
}

- (void)updateStatsKeysCount {
    UILabel *keysLabel = [self.statsView viewWithTag:999];
    if (keysLabel) {
        keysLabel.text = [NSString stringWithFormat:@"Active Keys  %lu", (unsigned long)self.appIDs.count];
    }
}

- (void)loadApps {
    static BOOL isLoading = NO;

    if (isLoading) {
        [[DebugLogger sharedLogger] log:@"[AppData] ⚠️  Already loading, skipping..."];
        return;
    }

    isLoading = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DebugLogger *logger = [DebugLogger sharedLogger];
        [logger log:@"[AppData] 🚀 Loading app list..."];

        // Initialize MCM (MCMFilzaSetUnrestrictedFilesystem đã gọi trong loadAppsImmediately)
        MCMFilzaStart();

        // Get virtual root
        NSString *virtualRoot = AppHiddenDataRoot();
        [logger log:@"[AppData] Virtual root: %@", virtualRoot];

        VirtualFileSystemBuilder *builder = [VirtualFileSystemBuilder sharedBuilder];
        NSError *error = nil;

        // Build virtual filesystem with symlinks
        [logger log:@"[AppData] 📁 Creating VFS..."];
        [builder createVirtualFileSystemAtRoot:virtualRoot error:&error];

        // First enumerate apps using LSApplicationWorkspace to populate containers
        [logger log:@"[AppData] 📦 Enumerating apps and creating symlinks..."];
        AppEnumerator *enumerator = [AppEnumerator sharedEnumerator];
        NSArray *allApps = [enumerator allApplicationIdentifiers];

        if (allApps.count > 0) {
            [logger log:@"[AppData] ✅ Enumerator found %lu apps, populating VFS...", (unsigned long)allApps.count];
            [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        } else {
            [logger log:@"[AppData] ⚠️  Enumerator returned 0 apps, trying to populate anyway..."];
            // Still try to populate in case there are containers from before
            [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        }

        // Now scan the virtual filesystem directory to get actual symlinked apps
        NSString *appDataPath = [virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"];
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appDataPath error:&error];

        if (error) {
            [logger log:@"[AppData] ❌ Error reading VFS directory: %@", error];
            dirContents = @[];
        }

        [logger log:@"[AppData] 📂 Found %lu items in VFS [MHA-C2] App Data", (unsigned long)dirContents.count];

        // Only show Free Fire apps
        NSArray *targetApps = @[@"com.dts.freefiremax", @"com.dts.freefireth"];
        NSMutableArray *appIDs = [NSMutableArray array];

        // Tập hợp nhanh để tra cứu O(1)
        NSSet *dirSet = [NSSet setWithArray:dirContents];

        for (NSString *targetApp in targetApps) {
            // [1] Kiểm tra trong VFS directory (symlink đã được tạo)
            if ([dirSet containsObject:targetApp]) {
                [appIDs addObject:targetApp];
                [logger log:@"[AppData]   📦 %@ (VFS symlink)", targetApp];
                continue;
            }

            // [2] VFS chưa có → kiểm tra trực tiếp container path
            //     (sau khi sandbox escaped, containerPathForBundleID: đọc metadata plist)
            NSString *directPath = [SandboxEscapeManager containerPathForBundleID:targetApp];
            if (directPath) {
                [appIDs addObject:targetApp];
                [logger log:@"[AppData]   📦 %@ (direct container: %@)", targetApp, directPath];
                continue;
            }

            [logger log:@"[AppData]   ⚠️  %@ not found (VFS + direct lookup both nil)", targetApp];
        }

        self.appIDs = appIDs;

        [logger log:@"[AppData] ✅ Ready to display %lu apps", (unsigned long)self.appIDs.count];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
            [self hideLoadingView];  // Fade out loading screen
            isLoading = NO;
        });
    });
}

- (void)createStatsView {
    // ── Synthwave Arcade: Device Info Card ────────────────────────────────
    // Solid dark card, border 1.5pt, hard shadow cyan
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = SW_CARD;
    card.layer.cornerRadius = 14;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    card.layer.borderWidth  = 1.5;
    card.layer.shadowColor  = SW_CYAN.CGColor;
    card.layer.shadowOpacity = 0.22;
    card.layer.shadowRadius  = 0;
    card.layer.shadowOffset  = CGSizeMake(3, 3);
    card.clipsToBounds = NO;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    // "DEVICE INFO" sticker label at top edge
    UILabel *stickerLabel = [[UILabel alloc] init];
    stickerLabel.text = @"  DEVICE INFO  ";
    stickerLabel.font = [UIFont monospacedSystemFontOfSize:7.5 weight:UIFontWeightBold];
    stickerLabel.textColor = [UIColor whiteColor];
    stickerLabel.backgroundColor = SW_PINK;
    stickerLabel.layer.cornerRadius = 3;
    stickerLabel.layer.masksToBounds = YES;
    stickerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.statsView = [[UIView alloc] init];
    self.statsView.backgroundColor = [UIColor clearColor];
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statsView];
    [self.statsView addSubview:card];
    [self.statsView addSubview:stickerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statsView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statsView.heightAnchor constraintEqualToConstant:106],

        [card.topAnchor constraintEqualToAnchor:self.statsView.topAnchor constant:6],
        [card.leadingAnchor constraintEqualToAnchor:self.statsView.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.statsView.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.statsView.bottomAnchor],

        [stickerLabel.centerYAnchor constraintEqualToAnchor:card.topAnchor],
        [stickerLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
    ]];

    UIView *cc = card;

    // iOS row
    UIView *iosRow = [self statRowText:[[UIDevice currentDevice] systemVersion]
                                  tag:@"iOS" tint:SW_CYAN labelTag:0];
    // Device row
    UIView *devRow = [self statRowText:[self deviceModelName]
                                  tag:@"DEV" tint:SW_CYAN labelTag:0];

    // Support row — Arcade STAT tag box
    BOOL supported = [self isIOSSupported];
    UIColor *supportTint = supported ? SW_YELLOW : [UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0];
    NSString *supportText = supported ? LS(@"✦ Có Hỗ Trợ ✦", @"✦ Supported ✦") : LS(@"✦ Chưa Hỗ Trợ ✦", @"✦ Not Supported ✦");
    UIView *supportRow = [self statRowText:supportText tag:@"STAT" tint:supportTint labelTag:998];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iosRow, devRow, supportRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cc addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:cc.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-18],
        [stack.centerYAnchor constraintEqualToAnchor:cc.centerYAnchor],
    ]];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleAdminLongPress:)];
    lp.minimumPressDuration = 1.2;
    self.statsView.userInteractionEnabled = YES;
    [self.statsView addGestureRecognizer:lp];
}

- (void)handleAdminLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        [self showAdminReset];
    }
}

// Synthwave Arcade stat row: [TAG BOX] value text
- (UIView *)statRowText:(NSString *)text tag:(NSString *)tagStr tint:(UIColor *)tint labelTag:(NSInteger)ltag {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    // Monospaced tag box (arcade sticker style)
    UILabel *tagBox = [[UILabel alloc] init];
    tagBox.text = tagStr;
    tagBox.font = [UIFont monospacedSystemFontOfSize:8 weight:UIFontWeightBold];
    tagBox.textColor = tint;
    tagBox.textAlignment = NSTextAlignmentCenter;
    tagBox.backgroundColor = [tint colorWithAlphaComponent:0.10];
    tagBox.layer.borderColor = [tint colorWithAlphaComponent:0.35].CGColor;
    tagBox.layer.borderWidth = 1;
    tagBox.layer.cornerRadius = 3;
    tagBox.layer.masksToBounds = YES;
    tagBox.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:tagBox];

    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightMedium];
    label.textColor = [UIColor colorWithRed:0.78 green:0.72 blue:1.0 alpha:1.0];  // soft lavender
    label.text = text;
    if (ltag) label.tag = ltag;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:20],
        [tagBox.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [tagBox.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [tagBox.widthAnchor constraintEqualToConstant:32],
        [tagBox.heightAnchor constraintEqualToConstant:16],
        [label.leadingAnchor constraintEqualToAnchor:tagBox.trailingAnchor constant:8],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
    ]];
    return row;
}

// ── Chính Sách ─────────────────────────────────────────────────────────────
- (void)showPolicy {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    PolicyViewController *pvc = [[PolicyViewController alloc] init];
    pvc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = pvc.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28;
    }
    [self presentViewController:pvc animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = SW_PINK;

    // Refresh license key state + start countdown ticker
    [self.keyBar update];
    if ([KeyManager shared].keyCode) {
        __weak typeof(self) weakSelf = self;
        [[KeyManager shared] refreshWithCompletion:^(BOOL success, NSString *message) {
            [weakSelf.keyBar update];
        }];
    }
    [self.keyTimer invalidate];
    self.keyTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self
                                                   selector:@selector(tickKeyBar)
                                                   userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.keyTimer invalidate];
    self.keyTimer = nil;
}

- (void)tickKeyBar {
    [self.keyBar update];
}



// Kiểm tra iOS có nằm trong danh sách hỗ trợ không:
//   ✅  iOS 17.0 → 26.0.x  (Cơ chế B: kexploit_opa334)
//   ✅  iOS 26.1+           (Cơ chế A: MCM trực tiếp)
//   ⚠️  iOS < 17, iOS 19–25, iOS 28+ : chưa hỗ trợ
- (BOOL)isIOSSupported {
    NSString *ver = [[UIDevice currentDevice] systemVersion];

    // iOS 16.0 → 17.x: toàn bộ
    if ([ver compare:@"16.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"18.0" options:NSNumericSearch] == NSOrderedAscending) return YES;

    // iOS 18.0 → 18.7.1 (18.7.2+ chưa hỗ trợ)
    if ([ver compare:@"18.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"18.7.2" options:NSNumericSearch] == NSOrderedAscending) return YES;

    // iOS 26.0 → 27.x (Beta 3 và các build 27.x sau)
    if ([ver compare:@"26.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"28.0" options:NSNumericSearch] == NSOrderedAscending) return YES;

    return NO;
}

// Trả về tên model thực (vd "iPhone 14 Pro Max") thay vì tên người dùng đặt
- (NSString *)deviceModelName {
    // Lấy machine identifier qua sysctl (vd "iPhone15,2")
    char machine[64] = {0};
    size_t ms = sizeof(machine);
    sysctlbyname("hw.machine", machine, &ms, NULL, 0);
    NSString *hw = [NSString stringWithUTF8String:machine];

    // Simulator
    if ([hw hasPrefix:@"x86_64"] || [hw hasPrefix:@"arm64"]) {
        hw = NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"] ?: hw;
    }

    // Bảng map identifier → tên đầy đủ
    NSDictionary<NSString *, NSString *> *map = @{
        // ── iPhone ──────────────────────────────────────────
        @"iPhone1,1": @"iPhone 2G",
        @"iPhone1,2": @"iPhone 3G",
        @"iPhone2,1": @"iPhone 3GS",
        @"iPhone3,1": @"iPhone 4",
        @"iPhone3,2": @"iPhone 4 (GSM Rev A)",
        @"iPhone3,3": @"iPhone 4 (CDMA)",
        @"iPhone4,1": @"iPhone 4S",
        @"iPhone5,1": @"iPhone 5 (GSM)",
        @"iPhone5,2": @"iPhone 5 (CDMA)",
        @"iPhone5,3": @"iPhone 5c (GSM)",
        @"iPhone5,4": @"iPhone 5c (Global)",
        @"iPhone6,1": @"iPhone 5s (GSM)",
        @"iPhone6,2": @"iPhone 5s (Global)",
        @"iPhone7,1": @"iPhone 6 Plus",
        @"iPhone7,2": @"iPhone 6",
        @"iPhone8,1": @"iPhone 6s",
        @"iPhone8,2": @"iPhone 6s Plus",
        @"iPhone8,4": @"iPhone SE (1st Gen)",
        @"iPhone9,1": @"iPhone 7",
        @"iPhone9,2": @"iPhone 7 Plus",
        @"iPhone9,3": @"iPhone 7",
        @"iPhone9,4": @"iPhone 7 Plus",
        @"iPhone10,1": @"iPhone 8",
        @"iPhone10,2": @"iPhone 8 Plus",
        @"iPhone10,3": @"iPhone X",
        @"iPhone10,4": @"iPhone 8",
        @"iPhone10,5": @"iPhone 8 Plus",
        @"iPhone10,6": @"iPhone X",
        @"iPhone11,2": @"iPhone XS",
        @"iPhone11,4": @"iPhone XS Max",
        @"iPhone11,6": @"iPhone XS Max",
        @"iPhone11,8": @"iPhone XR",
        @"iPhone12,1": @"iPhone 11",
        @"iPhone12,3": @"iPhone 11 Pro",
        @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPhone12,8": @"iPhone SE (2nd Gen)",
        @"iPhone13,1": @"iPhone 12 mini",
        @"iPhone13,2": @"iPhone 12",
        @"iPhone13,3": @"iPhone 12 Pro",
        @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,2": @"iPhone 13 Pro",
        @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini",
        @"iPhone14,5": @"iPhone 13",
        @"iPhone14,6": @"iPhone SE (3rd Gen)",
        @"iPhone14,7": @"iPhone 14",
        @"iPhone14,8": @"iPhone 14 Plus",
        @"iPhone15,2": @"iPhone 14 Pro",
        @"iPhone15,3": @"iPhone 14 Pro Max",
        @"iPhone15,4": @"iPhone 15",
        @"iPhone15,5": @"iPhone 15 Plus",
        @"iPhone16,1": @"iPhone 15 Pro",
        @"iPhone16,2": @"iPhone 15 Pro Max",
        @"iPhone16,3": @"iPhone 16e",
        @"iPhone17,1": @"iPhone 16 Pro",
        @"iPhone17,2": @"iPhone 16 Pro Max",
        @"iPhone17,3": @"iPhone 16",
        @"iPhone17,4": @"iPhone 16 Plus",
        @"iPhone17,5": @"iPhone 16e",
        // ── iPad ────────────────────────────────────────────
        @"iPad13,18": @"iPad (10th Gen)",
        @"iPad13,19": @"iPad (10th Gen)",
        @"iPad14,1":  @"iPad mini (6th Gen)",
        @"iPad14,2":  @"iPad mini (6th Gen)",
        @"iPad14,3":  @"iPad Pro 11\" (4th Gen)",
        @"iPad14,4":  @"iPad Pro 11\" (4th Gen)",
        @"iPad14,5":  @"iPad Pro 12.9\" (6th Gen)",
        @"iPad14,6":  @"iPad Pro 12.9\" (6th Gen)",
        @"iPad14,8":  @"iPad Air (5th Gen)",
        @"iPad14,9":  @"iPad Air (5th Gen)",
        @"iPad14,10": @"iPad Air 11\" (M2)",
        @"iPad14,11": @"iPad Air 13\" (M2)",
        @"iPad16,1":  @"iPad mini (7th Gen)",
        @"iPad16,2":  @"iPad mini (7th Gen)",
        @"iPad16,3":  @"iPad Pro 11\" (M4)",
        @"iPad16,4":  @"iPad Pro 11\" (M4)",
        @"iPad16,5":  @"iPad Pro 13\" (M4)",
        @"iPad16,6":  @"iPad Pro 13\" (M4)",
    };

    NSString *name = map[hw];
    if (name) return name;

    // Fallback: hiện identifier gốc (vd "iPhone18,1" — model mới chưa có trong bảng)
    return hw;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    self.bgGradient.frame = self.view.bounds;

    CGFloat ps = W * 1.5;   // quầng pink trên-trái
    self.purpleGlow.frame = CGRectMake(0.15 * W - ps / 2, -0.05 * H - ps / 2, ps, ps);

    CGFloat cs = W * 1.4;   // quầng cyan dưới-phải
    self.cyanGlow.frame = CGRectMake(0.90 * W - cs / 2, 1.02 * H - cs / 2, cs, cs);
}

- (UIColor *)gridPatternColor {
    CGFloat s = 26;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext, [UIColor colorWithWhite:1 alpha:0.045].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 0.5);
        CGContextMoveToPoint(ctx.CGContext, s, 0);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextMoveToPoint(ctx.CGContext, 0, s);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}

- (void)refreshApps {
    // Được gọi từ AppDelegate sau sandbox escape thành công
    [self loadApps];
}

- (void)openSettings {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    SettingsViewController *svc = [[SettingsViewController alloc] init];
    svc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = svc.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent],
        ];
        sheet.prefersGrabberVisible  = YES;
        sheet.preferredCornerRadius  = 28;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    }
    [self presentViewController:svc animated:YES completion:nil];
}

// ── Loading overlay ───────────────────────────────────────────────────────────

- (void)showLoadingView {
    if (self.loadingView) return;  // already shown

    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = SW_BG;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.alpha = 1.0;
    self.loadingView = overlay;

    // Gradient nền giống app
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[(id)SW_BG.CGColor,
                    (id)[UIColor colorWithRed:0.068 green:0.047 blue:0.118 alpha:1.0].CGColor];
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint   = CGPointMake(0.5, 1.0);
    grad.frame = overlay.bounds;
    [overlay.layer addSublayer:grad];

    // Logo / tên app
    UILabel *title = [[UILabel alloc] init];
    title.text = @"DELTA PROXY VN";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:title];

    // Spinner màu CYAN
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];  // BRAND_CYAN
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [overlay addSubview:spinner];

    // Subtitle
    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"Starting up...";
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    sub.textColor = [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:sub];

    [NSLayoutConstraint activateConstraints:@[
        // Spinner ở chính giữa màn hình
        [spinner.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        // Title phía trên spinner
        [title.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [title.bottomAnchor constraintEqualToAnchor:spinner.topAnchor constant:-20],
        // Subtitle phía dưới spinner
        [sub.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:14],
    ]];

    [self.view addSubview:overlay];
}

- (void)hideLoadingView {
    if (!self.loadingView) return;
    UIView *overlay = self.loadingView;
    self.loadingView = nil;
    [UIView animateWithDuration:0.4
                          delay:0.1
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ overlay.alpha = 0; }
                     completion:^(BOOL finished) { [overlay removeFromSuperview]; }];
}

// Load custom app image from documents or bundle
- (UIImage *)loadCustomImageForApp:(NSString *)appID {
    // Check if custom image name exists in mapping
    NSString *imageName = self.customAppImages[appID];
    if (!imageName) {
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];

    // Load from Caches/AppImages (khớp ImageDownloader, ngoài Documents)
    NSString *appImagesDir = [documentsPath stringByAppendingPathComponent:@"AppImages"];

    // Priority 1: Try PNG version first (FreeFireMax.png, FreeFireTH.png)
    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", imageName]];
    if ([fm fileExistsAtPath:imagePath]) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded custom image from: %@", imagePath];
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Priority 2: Try WEBP version
    imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.webp", imageName]];
    if ([fm fileExistsAtPath:imagePath]) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded custom image from: %@", imagePath];
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Priority 3: Try from bundle (if images are added to app)
    UIImage *bundledImage = [UIImage imageNamed:imageName];
    if (bundledImage) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded bundled image: %@", imageName];
        return bundledImage;
    }

    [[DebugLogger sharedLogger] log:@"[AppData] ⚠️  Custom image not found: %@", imageName];
    return nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.appIDs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AppDataCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];

    NSString *appID = self.appIDs[indexPath.item];

    // Synthwave Arcade accent: MAX = Pink, FF = Cyan
    BOOL isMax = [appID isEqualToString:@"com.dts.freefiremax"];
    UIColor *accent = isMax ? SW_PINK : SW_CYAN;

    // Hard drop shadow tinted to accent
    cell.cardView.layer.shadowColor  = accent.CGColor;
    cell.cardView.layer.shadowOffset = CGSizeMake(4, 4);
    cell.cardView.layer.shadowRadius = 0;

    // Sticker label (top-left corner): "MAX" or "FF"
    cell.bundleLabel.text = isMax ? @"  MAX  " : @"  FF  ";
    cell.bundleLabel.backgroundColor = accent;
    cell.bundleLabel.textColor = isMax ? [UIColor whiteColor] : [UIColor colorWithRed:0.04 green:0.04 blue:0.10 alpha:1.0];
    // Ambient glow tint for selected state
    cell.glowShadow.shadowColor = accent.CGColor;

    // Priority order:
    // 1. Downloaded cached images (FreeFireMax.png / FreeFireTH.png)
    // 2. Custom images via loadCustomImageForApp
    // 3. App icon from system
    // 4. Fallback to game controller icon

    ImageDownloader *downloader = [ImageDownloader sharedDownloader];

    // Try downloaded images first
    UIImage *downloadedImage = nil;
    if ([appID isEqualToString:@"com.dts.freefiremax"]) {
        downloadedImage = [downloader cachedImageNamed:@"FreeFireMax"];
    } else if ([appID isEqualToString:@"com.dts.freefireth"]) {
        downloadedImage = [downloader cachedImageNamed:@"FreeFireTH"];
    }

    if (downloadedImage) {
        cell.iconView.image = downloadedImage;
        cell.iconView.tintColor = [UIColor whiteColor];
    } else {
        // Try custom image
        UIImage *customImage = [self loadCustomImageForApp:appID];
        if (customImage) {
            cell.iconView.image = customImage;
            cell.iconView.tintColor = [UIColor whiteColor];
        } else {
            // Try to get app's actual icon
            AppStatusChecker *checker = [AppStatusChecker sharedChecker];
            UIImage *icon = [checker iconForApp:appID];
            if (icon) {
                cell.iconView.image = icon;
                cell.iconView.tintColor = [UIColor whiteColor];
            } else {
                // Fallback to game controller icon
                cell.iconView.image = [UIImage systemImageNamed:@"gamecontroller.fill"];
                cell.iconView.tintColor = [UIColor whiteColor];
            }
        }
    }

    // Set app name — uppercase Arcade style
    NSString *displayName = self.appDisplayNames[appID] ?: appID;
    cell.nameLabel.text = [displayName uppercaseString];

    // bundleLabel là sticker label — đã set ở trên ("  MAX  " / "  FF  ")
    // KHÔNG ghi đè bằng bundle ID

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    NSString *appID = self.appIDs[indexPath.item];
    NSString *displayName = self.appDisplayNames[appID] ?: appID;
    AppDataCell *cell = (AppDataCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [self openHUDForAppID:appID displayName:displayName icon:cell.iconView.image];
}

- (void)openHUDForAppID:(NSString *)appID displayName:(NSString *)displayName icon:(UIImage *)icon {
    HUDControlViewController *hud = [[HUDControlViewController alloc] initWithBundleID:appID
                                                                              appName:displayName
                                                                                 icon:icon];
    [self.navigationController pushViewController:hud animated:YES];
}

// Cập nhật layout khi xoay màn hình (portrait ↔ landscape)
// Không override viewWillTransition: trực tiếp để tránh lỗi super call
// trên một số Xcode version — dùng notification UIDeviceOrientationDidChangeNotification thay thế
- (void)_updateLayoutForSize:(CGSize)size {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]]) return;
    BOOL isLandscape = size.width > size.height;
    CGFloat inset   = isLandscape ? 20.0 : 16.0;
    CGFloat spacing = 12.0;
    CGFloat cardW   = (size.width - inset * 2 - spacing) / 2.0;
    CGFloat cardH   = isLandscape ? size.height * 0.65 : 178.0;
    layout.itemSize               = CGSizeMake(cardW, cardH);
    layout.minimumLineSpacing      = spacing;
    layout.minimumInteritemSpacing = spacing;
    layout.sectionInset            = UIEdgeInsetsMake(10, inset, 16, inset);
    [self.collectionView.collectionViewLayout invalidateLayout];
    // Update bg layers
    self.bgGradient.frame = CGRectMake(0, 0, size.width, size.height);
    CGFloat ps = size.width * 1.5;
    self.purpleGlow.frame = CGRectMake(0.15 * size.width - ps / 2, -0.05 * size.height - ps / 2, ps, ps);
    CGFloat cs = size.width * 1.4;
    self.cyanGlow.frame = CGRectMake(0.9 * size.width - cs / 2, 1.02 * size.height - cs / 2, cs, cs);
}

- (void)_orientationDidChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            [self _updateLayoutForSize:self.view.bounds.size];
        }];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
