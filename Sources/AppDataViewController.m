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

#pragma mark - GlassView (frosted card khớp web)

@interface GlassView : UIView
@end
@implementation GlassView {
    CAGradientLayer *_sheen;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.055 green:0.06 blue:0.11 alpha:0.55];
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.11].CGColor;
        self.layer.borderWidth = 1;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        _sheen = [CAGradientLayer layer];
        _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.075].CGColor,
                          (id)[UIColor colorWithWhite:1 alpha:0.015].CGColor];
        _sheen.startPoint = CGPointMake(0.5, 0.0);
        _sheen.endPoint   = CGPointMake(0.5, 1.0);
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

    // Frosted glass card (khớp web)
    self.cardView = [[GlassView alloc] init];
    self.cardView.layer.cornerRadius = 24;
    self.cardView.layer.shadowColor = BRAND_PURPLE.CGColor;
    self.cardView.layer.shadowOpacity = 0.30;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 8);
    self.cardView.layer.shadowRadius = 18;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    // Top colored banner section
    UIView *bannerView = [[UIView alloc] init];
    bannerView.layer.cornerRadius = 24;
    bannerView.layer.cornerCurve = kCACornerCurveContinuous;
    bannerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    bannerView.clipsToBounds = YES;
    bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:bannerView];
    self.bannerView = bannerView;

    [NSLayoutConstraint activateConstraints:@[
        [bannerView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [bannerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [bannerView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [bannerView.heightAnchor constraintEqualToConstant:100]
    ]];

    // Large app icon in banner - rounded like a real app icon
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.clipsToBounds = YES;
    self.iconView.layer.cornerRadius = 16;
    self.iconView.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    self.iconView.layer.borderWidth = 1;
    self.iconView.layer.magnificationFilter = kCAFilterTrilinear;
    self.iconView.layer.minificationFilter = kCAFilterTrilinear;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [bannerView addSubview:self.iconView];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.centerXAnchor constraintEqualToAnchor:bannerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:bannerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:72],
        [self.iconView.heightAnchor constraintEqualToConstant:72]
    ]];

    // App name - Bold
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    self.nameLabel.textColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:bannerView.bottomAnchor constant:16],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12]
    ]];

    // Bundle ID
    self.bundleLabel = [[UILabel alloc] init];
    self.bundleLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.bundleLabel.textColor = [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0];
    self.bundleLabel.textAlignment = NSTextAlignmentCenter;
    self.bundleLabel.numberOfLines = 1;
    self.bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.bundleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.bundleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:6],
        [self.bundleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.bundleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.bundleLabel.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-16]
    ]];

    // ── Neon glow border (shown when selected) ────────────────────────────
    // Shadow layer for card ambient glow
    self.glowShadow = [CALayer layer];
    self.glowShadow.shadowColor  = BRAND_CYAN.CGColor;
    self.glowShadow.shadowOpacity = 0;
    self.glowShadow.shadowRadius  = 20;
    self.glowShadow.shadowOffset  = CGSizeZero;
    self.glowShadow.backgroundColor = [UIColor clearColor].CGColor;
    [self.layer insertSublayer:self.glowShadow atIndex:0];

    // Gradient border stroke (purple → cyan → purple)
    self.glowBorder = [CAGradientLayer layer];
    self.glowBorder.colors = @[
        (id)BRAND_PURPLE.CGColor,
        (id)BRAND_CYAN.CGColor,
        (id)BRAND_PURPLE.CGColor,
    ];
    self.glowBorder.startPoint = CGPointMake(0, 0);
    self.glowBorder.endPoint   = CGPointMake(1, 1);
    self.glowBorder.opacity    = 0;

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.fillColor   = [UIColor clearColor].CGColor;
    mask.strokeColor = [UIColor whiteColor].CGColor;
    mask.lineWidth   = 2.0;
    self.glowBorder.mask = mask;
    [self.cardView.layer addSublayer:self.glowBorder];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect r = self.cardView.bounds;
    self.glowBorder.frame = r;
    self.glowShadow.frame = self.bounds;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
        CGRectInset(r, 1, 1) cornerRadius:self.cardView.layer.cornerRadius - 1];
    ((CAShapeLayer *)self.glowBorder.mask).path = path.CGPath;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self applyGlow:selected animated:YES];
}

- (void)applyGlow:(BOOL)on animated:(BOOL)animated {
    void (^change)(void) = ^{
        self.glowBorder.opacity   = on ? 1.0f : 0.0f;
        self.glowShadow.shadowOpacity = on ? 0.55f : 0.0f;
        // Intensify card purple shadow while selected
        self.cardView.layer.shadowColor   = on ? BRAND_CYAN.CGColor : BRAND_PURPLE.CGColor;
        self.cardView.layer.shadowOpacity = on ? 0.50f : 0.30f;
        self.cardView.layer.shadowRadius  = on ? 24.0f : 18.0f;
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

// Smooth touch animation
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(0.95, 0.95);
    }];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformIdentity;
    }];
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
#if DEBUG
@property (nonatomic, strong) UITextView *debugView;
@property (nonatomic, strong) UIStackView *debugButtons;
#endif
@property (nonatomic, strong) UIView *loadingView;   // Loading overlay
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // ── Gradient title "DELTA IPA VN" ─────────────────────────────────────
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"DELTA IPA VN";
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    titleLabel.textColor = [UIColor whiteColor];
    [titleLabel sizeToFit];
    // Gradient mask: purple → cyan
    CAGradientLayer *tg = [CAGradientLayer layer];
    tg.colors = @[(id)BRAND_PURPLE.CGColor, (id)BRAND_CYAN.CGColor];
    tg.startPoint = CGPointMake(0, 0.5);
    tg.endPoint   = CGPointMake(1, 0.5);
    tg.frame = titleLabel.bounds;
    UIGraphicsBeginImageContextWithOptions(titleLabel.bounds.size, NO, 0);
    [tg renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *gradImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    titleLabel.textColor = [UIColor colorWithPatternImage:gradImg];

    // Version badge
    UILabel *badge = [[UILabel alloc] init];
    badge.text = [NSString stringWithFormat:@"  v1.3.7  "];
    badge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    badge.textColor = BRAND_CYAN;
    badge.backgroundColor = [BRAND_CYAN colorWithAlphaComponent:0.12];
    badge.layer.cornerRadius = 7;
    badge.layer.masksToBounds = YES;
    badge.layer.borderColor = [BRAND_CYAN colorWithAlphaComponent:0.35].CGColor;
    badge.layer.borderWidth = 1;

    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, badge]];
    titleStack.axis = UILayoutConstraintAxisHorizontal;
    titleStack.spacing = 7;
    titleStack.alignment = UIStackViewAlignmentCenter;
    self.navigationItem.titleView = titleStack;

    // ── Settings → glass gear button ────────────────────────────────────────
    // Wrap trong UIView cố định 34×34 để iOS không auto-resize shape thành marquise
    UIView *gearContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
    gearContainer.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    gearContainer.layer.cornerRadius = 17;   // 34/2 → tròn hoàn toàn
    gearContainer.layer.cornerCurve = kCACornerCurveContinuous;
    gearContainer.layer.masksToBounds = YES;

    UIButton *settingsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    settingsBtn.frame = gearContainer.bounds;
    UIImageSymbolConfiguration *rCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [settingsBtn setImage:[UIImage systemImageNamed:@"gearshape.fill" withConfiguration:rCfg]
                 forState:UIControlStateNormal];
    settingsBtn.tintColor = BRAND_CYAN;
    settingsBtn.backgroundColor = [UIColor clearColor];
    settingsBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [settingsBtn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    [gearContainer addSubview:settingsBtn];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:gearContainer];

    // ── Tap 5 lần vào badge version → mở debug panel (hoạt động cả Release) ──
    UITapGestureRecognizer *debugTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(_debugPanelTapped)];
    debugTap.numberOfTapsRequired = 5;
    [titleStack addGestureRecognizer:debugTap];
    titleStack.userInteractionEnabled = YES;

    // Display name mapping
    self.appDisplayNames = @{
        @"com.dts.freefiremax": @"Free Fire Max",
        @"com.dts.freefireth": @"Free Fire"
    };
    self.customAppImages = @{
        @"com.dts.freefiremax": @"FreeFireMax",
        @"com.dts.freefireth": @"FreeFireTH"
    };
    self.view.backgroundColor = BRAND_BG;

    // Gradient nền
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[UIColor colorWithRed:0.032 green:0.036 blue:0.063 alpha:1.0].CGColor,
                  (id)[UIColor colorWithRed:0.035 green:0.043 blue:0.078 alpha:1.0].CGColor];
    bg.startPoint = CGPointMake(0.5, 0.0);
    bg.endPoint   = CGPointMake(0.5, 1.0);
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];
    self.bgGradient = bg;

    // Glow layers
    self.purpleGlow = BrandRadialGlow([BRAND_PURPLE colorWithAlphaComponent:0.30]);
    self.cyanGlow   = BrandRadialGlow([BRAND_CYAN   colorWithAlphaComponent:0.20]);
    [self.view.layer insertSublayer:self.purpleGlow above:bg];
    [self.view.layer insertSublayer:self.cyanGlow above:self.purpleGlow];

    UIView *grid = [[UIView alloc] initWithFrame:self.view.bounds];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = BrandGridPattern();
    grid.userInteractionEnabled = NO;
    [self.view addSubview:grid];

    // Nav bar transparent
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithTransparentBackground];
    self.navigationItem.standardAppearance = ap;
    self.navigationItem.scrollEdgeAppearance = ap;
    self.navigationController.navigationBar.tintColor = BRAND_CYAN;

    // Stats (device info card)
    [self createStatsView];

    // Collection view
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 48) / 2, 210);
    layout.minimumLineSpacing      = 16;
    layout.minimumInteritemSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(12, 16, 16, 16);

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
    self.keyBar.layer.shadowColor  = BRAND_PURPLE.CGColor;
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
}

- (void)refreshLocalizedStrings {
    // Cập nhật label "Supported" / "Not Supported" (tag 998)
    BOOL supported = [self isIOSSupported];
    UILabel *supportLabel = (UILabel *)[self.statsView viewWithTag:998];
    if (supportLabel) {
        supportLabel.text = supported
            ? LS(@"Có Hỗ Trợ", @"Supported")
            : LS(@"Chưa Hỗ Trợ", @"Not Supported");
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
    [alert addAction:[UIAlertAction actionWithTitle:LS(@"Kích hoạt", @"Activate") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *key = alert.textFields.firstObject.text;
        [[KeyManager shared] activateKey:key completion:^(BOOL success, NSString *message) {
            KeyManager *km = [KeyManager shared];
            if (!success && km.pendingConfirmKey) {
                UIAlertController *confirm = [UIAlertController
                    alertControllerWithTitle:LS(@"⚠️ Thông Báo Quan Trọng", @"⚠️ Important Notice")
                                    message:km.pendingConfirmMessage
                             preferredStyle:UIAlertControllerStyleAlert];
                [confirm addAction:[UIAlertAction actionWithTitle:LS(@"Đồng Ý", @"Agree")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *ca) {
                    [[KeyManager shared] confirmPendingActivationWithCompletion:^(BOOL ok, NSString *msg) {
                        [weakSelf.keyBar update];
                        [weakSelf toast:msg success:ok];
                    }];
                }]];
                [confirm addAction:[UIAlertAction actionWithTitle:LS(@"Huỷ", @"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil]];
                [weakSelf presentViewController:confirm animated:YES completion:nil];
            } else {
                [weakSelf.keyBar update];
                [weakSelf toast:message success:success];
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
    [self presentViewController:a animated:YES completion:nil];
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
#if DEBUG
        [self updateInlineDebug];
#endif
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
#if DEBUG
            [self updateInlineDebug];
#endif
            [self hideLoadingView];  // Fade out loading screen
            isLoading = NO;
        });
    });
}

- (void)createStatsView {
    // ── Glassmorphic Device Info Card ─────────────────────────────────────
    UIVisualEffectView *glassCard = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    glassCard.clipsToBounds = YES;
    glassCard.layer.cornerRadius = 20;
    glassCard.layer.cornerCurve  = kCACornerCurveContinuous;
    glassCard.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.11].CGColor;
    glassCard.layer.borderWidth  = 1;
    glassCard.layer.shadowColor  = BRAND_PURPLE.CGColor;
    glassCard.layer.shadowOpacity = 0.28;
    glassCard.layer.shadowRadius  = 16;
    glassCard.layer.shadowOffset  = CGSizeMake(0, 4);
    glassCard.translatesAutoresizingMaskIntoConstraints = NO;

    // Wrap in non-clipping container so shadow shows
    self.statsView = [[UIView alloc] init];
    self.statsView.backgroundColor = [UIColor clearColor];
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statsView];
    [self.statsView addSubview:glassCard];

    [NSLayoutConstraint activateConstraints:@[
        [self.statsView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statsView.heightAnchor constraintEqualToConstant:106],

        [glassCard.topAnchor constraintEqualToAnchor:self.statsView.topAnchor],
        [glassCard.leadingAnchor constraintEqualToAnchor:self.statsView.leadingAnchor],
        [glassCard.trailingAnchor constraintEqualToAnchor:self.statsView.trailingAnchor],
        [glassCard.bottomAnchor constraintEqualToAnchor:self.statsView.bottomAnchor],
    ]];

    UIView *cc = glassCard.contentView;

    // iOS row
    UIView *iosRow = [self statRowText:[NSString stringWithFormat:@"iOS  %@", [[UIDevice currentDevice] systemVersion]]
                                symbol:@"applelogo" tint:BRAND_PURPLE valueColor:BRAND_MUTED labelTag:0];
    // Device row
    UIView *devRow = [self statRowText:[NSString stringWithFormat:@"Device  %@", [self deviceModelName]]
                                symbol:@"iphone" tint:BRAND_CYAN valueColor:BRAND_MUTED labelTag:0];

    // Support row — pulsing dot variant
    BOOL supported = [self isIOSSupported];
    UIColor *supportTint = supported
        ? [UIColor colorWithRed:0.2 green:0.85 blue:0.4 alpha:1.0]
        : [UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0];

    UIView *supportRow = [[UIView alloc] init];
    supportRow.translatesAutoresizingMaskIntoConstraints = NO;

    // Pulsing dot indicator
    UIView *pulseWrap = [[UIView alloc] init];
    pulseWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [supportRow addSubview:pulseWrap];

    UIView *dotInner = [[UIView alloc] init];
    dotInner.backgroundColor = supportTint;
    dotInner.layer.cornerRadius  = 4;
    dotInner.layer.shadowColor   = supportTint.CGColor;
    dotInner.layer.shadowOpacity = 0.9;
    dotInner.layer.shadowRadius  = 5;
    dotInner.layer.shadowOffset  = CGSizeZero;
    dotInner.translatesAutoresizingMaskIntoConstraints = NO;
    [pulseWrap addSubview:dotInner];

    if (supported) {
        // Pulse ring animation
        UIView *dotRing = [[UIView alloc] init];
        dotRing.backgroundColor = [supportTint colorWithAlphaComponent:0.25];
        dotRing.layer.cornerRadius = 8;
        dotRing.layer.borderColor = [supportTint colorWithAlphaComponent:0.5].CGColor;
        dotRing.layer.borderWidth = 1;
        dotRing.translatesAutoresizingMaskIntoConstraints = NO;
        [pulseWrap insertSubview:dotRing belowSubview:dotInner];
        [NSLayoutConstraint activateConstraints:@[
            [dotRing.centerXAnchor constraintEqualToAnchor:pulseWrap.centerXAnchor],
            [dotRing.centerYAnchor constraintEqualToAnchor:pulseWrap.centerYAnchor],
            [dotRing.widthAnchor constraintEqualToConstant:16],
            [dotRing.heightAnchor constraintEqualToConstant:16],
        ]];
        // Infinite pulse
        [UIView animateWithDuration:1.4 delay:0.3
                              options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveEaseOut
                         animations:^{
            dotRing.transform = CGAffineTransformMakeScale(2.2, 2.2);
            dotRing.alpha = 0;
        } completion:nil];
    }

    [NSLayoutConstraint activateConstraints:@[
        [pulseWrap.widthAnchor constraintEqualToConstant:18],
        [pulseWrap.heightAnchor constraintEqualToConstant:18],
        [dotInner.centerXAnchor constraintEqualToAnchor:pulseWrap.centerXAnchor],
        [dotInner.centerYAnchor constraintEqualToAnchor:pulseWrap.centerYAnchor],
        [dotInner.widthAnchor constraintEqualToConstant:8],
        [dotInner.heightAnchor constraintEqualToConstant:8],
    ]];

    UILabel *supportLabel = [[UILabel alloc] init];
    supportLabel.tag = 998;
    supportLabel.text = supported ? LS(@"Có Hỗ Trợ", @"Supported") : LS(@"Chưa Hỗ Trợ", @"Not Supported");
    supportLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    supportLabel.textColor = supportTint;
    supportLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [supportRow addSubview:supportLabel];

    [NSLayoutConstraint activateConstraints:@[
        [supportRow.heightAnchor constraintEqualToConstant:18],
        [pulseWrap.leadingAnchor constraintEqualToAnchor:supportRow.leadingAnchor],
        [pulseWrap.centerYAnchor constraintEqualToAnchor:supportRow.centerYAnchor],
        [supportLabel.leadingAnchor constraintEqualToAnchor:pulseWrap.trailingAnchor constant:10],
        [supportLabel.centerYAnchor constraintEqualToAnchor:supportRow.centerYAnchor],
        [supportLabel.trailingAnchor constraintLessThanOrEqualToAnchor:supportRow.trailingAnchor],
    ]];

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

// A stat row: [symbol] label. Returns the row container.
- (UIView *)statRowText:(NSString *)text symbol:(NSString *)symbol tint:(UIColor *)tint
             valueColor:(UIColor *)valueColor labelTag:(NSInteger)tag {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]];
    icon.tintColor = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = valueColor;
    label.text = text;
    if (tag) label.tag = tag;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:18],
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
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
    self.navigationController.navigationBar.tintColor = BRAND_CYAN;

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

// Detect which mechanism would be used for the current iOS version
// (không #if DEBUG vì _debugPanelTapped dùng cả trong Release)
- (NSString *)_debugMechanismLabel {
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    NSComparisonResult c15lo = [ver compare:@"15.0" options:NSNumericSearch];
    NSComparisonResult c15hi = [ver compare:@"16.0" options:NSNumericSearch];
    NSComparisonResult c17lo = [ver compare:@"17.0" options:NSNumericSearch];
    NSComparisonResult c261  = [ver compare:@"26.1" options:NSNumericSearch];

    if (c261 != NSOrderedAscending)
        return @"Co che A (iOS >= 26.1 - MCM truc tiep)";
    if (c15lo != NSOrderedAscending && c15hi == NSOrderedAscending)
        return @"Co che C (iOS 15 - kfd puaf_landa)";
    if (c17lo != NSOrderedAscending && c261 == NSOrderedAscending)
        return @"Co che B (iOS 17-26.0 - kexploit_opa334)";
    return [NSString stringWithFormat:@"iOS %@ chua ho tro", ver];
}

#if DEBUG
// Hiện debug thẳng trên màn hình chính khi KHÔNG tìm thấy game
- (void)updateInlineDebug {
    [self.debugView removeFromSuperview];
    self.debugView = nil;
    [self.debugButtons removeFromSuperview];
    self.debugButtons = nil;
    if (self.appIDs.count > 0) return;   // có game rồi thì thôi

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"⚠️ KHÔNG THẤY GAME — DEBUG\n(chụp màn này gửi admin)\n\n"];

    char machine[64] = {0}; size_t ms = sizeof(machine);
    sysctlbyname("hw.machine", machine, &ms, NULL, 0);
    [s appendFormat:@"iOS: %@   Model: %s\n", [UIDevice currentDevice].systemVersion, machine];

    // Cơ chế đang dùng
    [s appendFormat:@"Cơ chế: %@\n", [self _debugMechanismLabel]];

    NSString *root = AppHiddenDataRoot();
    NSString *appData = [root stringByAppendingPathComponent:@"[MHA-C2] App Data"];
    BOOL adExists = [fm fileExistsAtPath:appData];
    [s appendFormat:@"\nVFS root: %@\n[MHA-C2] App Data tồn tại: %@\n", root, adExists ? @"CÓ" : @"KHÔNG"];

    NSError *err = nil;
    NSArray *items = [fm contentsOfDirectoryAtPath:appData error:&err];
    [s appendFormat:@"Số mục trong đó: %@\n", items ? @(items.count) : @"(lỗi đọc)"];
    if (err) [s appendFormat:@"  Lỗi: %@\n", err.localizedDescription];
    for (NSString *it in items) [s appendFormat:@"   • %@\n", it];

    // Sandbox escape status
    [s appendFormat:@"\nSandbox Escaped: %@\n", [SandboxEscapeManager escaped] ? @"✅ CÓ" : @"❌ CHƯA"];

    // SandboxEscapeManager.containerPathForBundleID: (trực tiếp đọc metadata plist)
    [s appendString:@"\n── Escape → metadata plist ──\n"];
    for (NSString *bid in @[@"com.dts.freefiremax", @"com.dts.freefireth"]) {
        NSString *cp = [SandboxEscapeManager containerPathForBundleID:bid];
        [s appendFormat:@"%@:\n  %@\n", bid, cp ?: @"nil"];
    }

    // MCM container test (có sandbox extension activation)
    [s appendString:@"\n── MCM + SandboxExt (fallback) ──\n"];
    NSString *e1 = nil, *e2 = nil;
    NSString *cp1 = MCMFilzaDataContainerPath(@"com.dts.freefiremax", &e1);
    NSString *cp2 = MCMFilzaDataContainerPath(@"com.dts.freefireth", &e2);
    [s appendFormat:@"FF Max: %@\n  (%@)\n", cp1 ?: @"nil", e1 ?: @"ok"];
    [s appendFormat:@"FF Thường: %@\n  (%@)\n", cp2 ?: @"nil", e2 ?: @"ok"];

    [s appendString:@"\n➡️ Escape=YES + metadata path → ✅ OK\n➡️ Escape=NO → exploit chưa chạy\n➡️ Cả hai nil → iOS này chưa hỗ trợ exploit"];

    UITextView *tv = [[UITextView alloc] init];
    tv.backgroundColor = [UIColor colorWithRed:0.086 green:0.094 blue:0.169 alpha:0.9];
    tv.textColor = [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0];
    tv.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    tv.editable = NO;
    tv.text = s;
    tv.layer.cornerRadius = 14;
    tv.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.4].CGColor;
    tv.layer.borderWidth = 1;
    tv.textContainerInset = UIEdgeInsetsMake(14, 14, 14, 14);
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tv];
    self.debugView = tv;

    // ── Debug buttons ──────────────────────────────────────────────────────
    UIButton *btnRefresh = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnRefresh setTitle:@"🔄  Refresh" forState:UIControlStateNormal];
    btnRefresh.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [btnRefresh setTitleColor:[UIColor colorWithRed:0 green:0.831 blue:1 alpha:1] forState:UIControlStateNormal];
    btnRefresh.backgroundColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.12];
    btnRefresh.layer.cornerRadius = 10;
    btnRefresh.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.4].CGColor;
    btnRefresh.layer.borderWidth = 1;
    btnRefresh.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
    [btnRefresh addTarget:self action:@selector(_debugRefreshTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnShareLog = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnShareLog setTitle:@"📤  Share Log" forState:UIControlStateNormal];
    btnShareLog.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [btnShareLog setTitleColor:[UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:1] forState:UIControlStateNormal];
    btnShareLog.backgroundColor = [UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:0.12];
    btnShareLog.layer.cornerRadius = 10;
    btnShareLog.layer.borderColor = [UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:0.4].CGColor;
    btnShareLog.layer.borderWidth = 1;
    btnShareLog.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
    [btnShareLog addTarget:self action:@selector(_debugShareLogTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *btnStack = [[UIStackView alloc] initWithArrangedSubviews:@[btnRefresh, btnShareLog]];
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.spacing = 10;
    btnStack.distribution = UIStackViewDistributionFill;
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:btnStack];
    self.debugButtons = btnStack;

    [NSLayoutConstraint activateConstraints:@[
        // Buttons — bottom strip above keyBar
        [btnStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.keyBar.topAnchor constant:-10],
        [btnStack.heightAnchor constraintEqualToConstant:38],

        // Text view — from statsView down to button stack
        [tv.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:16],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [tv.bottomAnchor constraintEqualToAnchor:btnStack.topAnchor constant:-10],
    ]];
}
#endif  // DEBUG (updateInlineDebug)

// Tap 5x vào title → mở debug panel (hoạt động cả Release)
// Nút 🐛 trên nav bar → mở debug panel dạng modal sheet (bất kỳ lúc nào)
- (void)_debugPanelTapped {
    UIViewController *sheet = [[UIViewController alloc] init];
    sheet.view.backgroundColor = [UIColor colorWithRed:0.072 green:0.079 blue:0.145 alpha:1.0];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sp = sheet.sheetPresentationController;
        sp.detents = @[UISheetPresentationControllerDetent.largeDetent];
        sp.prefersGrabberVisible = YES;
        sp.preferredCornerRadius = 20;
    }

    // Title bar
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = @"🐛  Debug Panel";
    titleLbl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLbl.textColor = [UIColor colorWithRed:1.0 green:0.76 blue:0.20 alpha:1.0];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [closeBtn setTitleColor:[UIColor colorWithRed:0 green:0.831 blue:1 alpha:1] forState:UIControlStateNormal];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:sheet action:@selector(dismissViewControllerAnimated:completion:) forControlEvents:UIControlEventTouchUpInside];
    // Wrap dismissal properly
    __weak UIViewController *weakSheet = sheet;
    [closeBtn addAction:[UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(UIAction *a) {
        [weakSheet dismissViewControllerAnimated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];

    // Debug text
    NSMutableString *s = [NSMutableString string];
    char machine[64] = {0}; size_t ms = sizeof(machine);
    sysctlbyname("hw.machine", machine, &ms, NULL, 0);
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    [s appendFormat:@"iOS: %@   Model: %s\n", ver, machine];
    [s appendFormat:@"Co che: %@\n", [self _debugMechanismLabel]];
    [s appendFormat:@"Sandbox Escaped: %@\n", [SandboxEscapeManager escaped] ? @"YES" : @"NO"];
    [s appendFormat:@"Apps found: %lu\n\n", (unsigned long)self.appIDs.count];

    [s appendString:@"── Container paths (SandboxEscapeManager) ──\n"];
    for (NSString *bid in @[@"com.dts.freefiremax", @"com.dts.freefireth"]) {
        NSString *cp = [SandboxEscapeManager containerPathForBundleID:bid];
        [s appendFormat:@"%@:\n  %@\n", bid, cp ?: @"nil"];
    }

    [s appendString:@"\n── MCM + SandboxExt ──\n"];
    NSString *e1 = nil, *e2 = nil;
    NSString *cp1 = MCMFilzaDataContainerPath(@"com.dts.freefiremax", &e1);
    NSString *cp2 = MCMFilzaDataContainerPath(@"com.dts.freefireth", &e2);
    [s appendFormat:@"FF Max: %@\n  (%@)\n", cp1 ?: @"nil", e1 ?: @"ok"];
    [s appendFormat:@"FF Thuong: %@\n  (%@)\n", cp2 ?: @"nil", e2 ?: @"ok"];

    NSString *root = AppHiddenDataRoot();
    NSString *appData = [root stringByAppendingPathComponent:@"[MHA-C2] App Data"];
    NSError *err = nil;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appData error:&err];
    [s appendFormat:@"\nVFS App Data (%lu muc):\n", (unsigned long)items.count];
    if (err) [s appendFormat:@"  Loi: %@\n", err.localizedDescription];
    for (NSString *it in items) [s appendFormat:@"  • %@\n", it];

    UITextView *tv = [[UITextView alloc] init];
    tv.backgroundColor = [UIColor colorWithRed:0.048 green:0.055 blue:0.110 alpha:1.0];
    tv.textColor = [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0];
    tv.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    tv.editable = NO;
    tv.text = s;
    tv.layer.cornerRadius = 14;
    tv.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.3].CGColor;
    tv.layer.borderWidth = 1;
    tv.textContainerInset = UIEdgeInsetsMake(14, 14, 14, 14);
    tv.translatesAutoresizingMaskIntoConstraints = NO;

    // Refresh + Share buttons
    UIButton *btnR = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnR setTitle:@"🔄  Refresh" forState:UIControlStateNormal];
    btnR.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [btnR setTitleColor:[UIColor colorWithRed:0 green:0.831 blue:1 alpha:1] forState:UIControlStateNormal];
    btnR.backgroundColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.10];
    btnR.layer.cornerRadius = 10;
    btnR.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.4].CGColor;
    btnR.layer.borderWidth = 1;
    btnR.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);

    UIButton *btnS = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnS setTitle:@"📤  Share Log" forState:UIControlStateNormal];
    btnS.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [btnS setTitleColor:[UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:1] forState:UIControlStateNormal];
    btnS.backgroundColor = [UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:0.10];
    btnS.layer.cornerRadius = 10;
    btnS.layer.borderColor = [UIColor colorWithRed:0.624 green:0.467 blue:1.0 alpha:0.4].CGColor;
    btnS.layer.borderWidth = 1;
    btnS.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);

    UIStackView *btnRow = [[UIStackView alloc] initWithArrangedSubviews:@[btnR, btnS]];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 10;
    btnRow.distribution = UIStackViewDistributionFillEqually;
    btnRow.translatesAutoresizingMaskIntoConstraints = NO;

    [sheet.view addSubview:titleLbl];
    [sheet.view addSubview:closeBtn];
    [sheet.view addSubview:tv];
    [sheet.view addSubview:btnRow];

    UIView *v = sheet.view;
    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.topAnchor constant:20],
        [titleLbl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:20],
        [closeBtn.centerYAnchor constraintEqualToAnchor:titleLbl.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-20],

        [tv.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:14],
        [tv.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [tv.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],
        [tv.bottomAnchor constraintEqualToAnchor:btnRow.topAnchor constant:-12],

        [btnRow.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [btnRow.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],
        [btnRow.bottomAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [btnRow.heightAnchor constraintEqualToConstant:40],
    ]];

    // Refresh — rebuild text và cập nhật tv.text trong sheet
    __weak UITextView *weakTV = tv;
    [btnR addAction:[UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(UIAction *a) {
        NSMutableString *rs = [NSMutableString string];
        char m2[64] = {0}; size_t ms2 = sizeof(m2);
        sysctlbyname("hw.machine", m2, &ms2, NULL, 0);
        NSString *v2 = [[UIDevice currentDevice] systemVersion];
        [rs appendFormat:@"iOS: %@   Model: %s\n", v2, m2];
        [rs appendFormat:@"Co che: %@\n", [self _debugMechanismLabel]];
        [rs appendFormat:@"Sandbox Escaped: %@\n", [SandboxEscapeManager escaped] ? @"YES" : @"NO"];
        [rs appendFormat:@"Apps found: %lu\n\n", (unsigned long)self.appIDs.count];
        [rs appendString:@"── Container paths ──\n"];
        for (NSString *bid in @[@"com.dts.freefiremax", @"com.dts.freefireth"]) {
            NSString *cp = [SandboxEscapeManager containerPathForBundleID:bid];
            [rs appendFormat:@"%@:\n  %@\n", bid, cp ?: @"nil"];
        }
        weakTV.text = rs;
    }] forControlEvents:UIControlEventTouchUpInside];

    // Share Log
    __weak UIViewController *weakSheet2 = sheet;
    [btnS addAction:[UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(UIAction *a) {
        [self _debugShareLogFromVC:weakSheet2];
    }] forControlEvents:UIControlEventTouchUpInside];

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)_debugShareLogFromVC:(UIViewController *)presenter {
    NSString *logPath = [[DebugLogger sharedLogger] logFilePath];
    NSURL *logURL = [NSURL fileURLWithPath:logPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Khong co log"
                                    message:@"File log chua ton tai."
                                    preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:a animated:YES completion:nil];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc]
        initWithActivityItems:@[logURL] applicationActivities:nil];
    share.popoverPresentationController.sourceView = presenter.view;
    [presenter presentViewController:share animated:YES completion:nil];
}

#if DEBUG
- (void)_debugRefreshTapped {
    [self updateInlineDebug];
}
#endif  // DEBUG (updateInlineDebug)

- (void)_debugShareLogTapped {
    [self _debugShareLogFromVC:self];
}

// Kiểm tra iOS có nằm trong danh sách hỗ trợ không:
//   ✅  iOS 15.0 → 15.x    (Cơ chế C: kfd puaf_landa)
//   ✅  iOS 16.0 → 18.7.1  (Cơ chế B: kexploit_opa334)
//   ✅  iOS 26.0 → 27.x    (Cơ chế A/B)
//   ⚠️  iOS 19–25, iOS 28+ : chưa hỗ trợ
- (BOOL)isIOSSupported {
    NSString *ver = [[UIDevice currentDevice] systemVersion];

    // iOS 15.0 → 15.x (Cơ chế C — kfd, landa patched iOS 17 nên safe toàn bộ 15.x)
    if ([ver compare:@"15.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"16.0" options:NSNumericSearch] == NSOrderedAscending) return YES;

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

    CGFloat ps = W * 1.5;   // quầng tím trên-trái
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
    overlay.backgroundColor = BRAND_BG;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.alpha = 1.0;
    self.loadingView = overlay;

    // Gradient nền giống app
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[(id)BRAND_BG.CGColor,
                    (id)[UIColor colorWithRed:0.035 green:0.043 blue:0.078 alpha:1.0].CGColor];
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

    // Banner color + matching neon glow based on app
    UIColor *accent;
    if ([appID isEqualToString:@"com.dts.freefiremax"]) {
        accent = [UIColor colorWithRed:0.1 green:0.6 blue:1.0 alpha:1.0]; // blue
    } else if ([appID isEqualToString:@"com.dts.freefireth"]) {
        accent = [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0]; // orange
    } else {
        accent = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0]; // cyan
    }
    cell.bannerView.backgroundColor = accent;
    cell.cardView.layer.shadowColor = accent.CGColor;
    cell.cardView.layer.borderColor = [accent colorWithAlphaComponent:0.35].CGColor;

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

    // Set app name - use custom display names
    NSString *displayName = self.appDisplayNames[appID] ?: appID;
    cell.nameLabel.text = displayName;

    // Set bundle ID
    cell.bundleLabel.text = appID;

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

@end
