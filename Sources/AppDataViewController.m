#import "AppDataViewController.h"
#import "FileManagerViewController.h"
#import "AppEnumerator.h"
#import "AppStatusChecker.h"
#import "MCMFilzaIntegration.h"
#import "SandboxEscapeManager.h"
#import "BadQueryManager.h"
#import "SEPKeyStoreProbe.h"
#import "SEPExploit.h"
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
#endif
@property (nonatomic, strong) UIView *loadingView;   // Loading overlay
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"DELTA PROXY VN";
    self.navigationItem.titleView = nil;

    // Display name mapping
    self.appDisplayNames = @{
        @"com.dts.freefiremax": @"Free Fire Max",
        @"com.dts.freefireth": @"Free Fire"
    };

    // Custom image mapping - specific filenames
    self.customAppImages = @{
        @"com.dts.freefiremax": @"FreeFireMax",
        @"com.dts.freefireth": @"FreeFireTH"
    };
    self.view.backgroundColor = BRAND_BG;

    // Nền đen + gradient rất nhẹ
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)BRAND_BG.CGColor,
                  (id)[UIColor colorWithRed:0.035 green:0.043 blue:0.078 alpha:1.0].CGColor];
    bg.startPoint = CGPointMake(0.5, 0.0);
    bg.endPoint   = CGPointMake(0.5, 1.0);
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];
    self.bgGradient = bg;

    // Quầng sáng tím (trên-trái) + cyan (dưới-phải) — như web
    self.purpleGlow = BrandRadialGlow([BRAND_PURPLE colorWithAlphaComponent:0.30]);
    self.cyanGlow   = BrandRadialGlow([BRAND_CYAN   colorWithAlphaComponent:0.20]);
    [self.view.layer insertSublayer:self.purpleGlow above:bg];
    [self.view.layer insertSublayer:self.cyanGlow above:self.purpleGlow];

    // Lưới mờ
    UIView *grid = [[UIView alloc] initWithFrame:self.view.bounds];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = BrandGridPattern();
    grid.userInteractionEnabled = NO;
    [self.view addSubview:grid];

    // Dark nav bar with white title + cyan Refresh
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithTransparentBackground];
    ap.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0],
                               NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]};
    self.navigationItem.standardAppearance = ap;
    self.navigationItem.scrollEdgeAppearance = ap;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];

    // Refresh button
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(refreshApps)];

    // Create stats view
    [self createStatsView];

    // Setup collection view with flow layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 32) / 2, 200);
    layout.minimumLineSpacing = 16;
    layout.minimumInteritemSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                              collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[AppDataCell class] forCellWithReuseIdentifier:@"AppCell"];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.collectionView];

    // License key bottom bar
    self.keyBar = [[KeyBarView alloc] init];
    self.keyBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.keyBar];

    __weak typeof(self) weakSelf = self;
    self.keyBar.onAddTapped = ^{ [weakSelf promptAddKey]; };
    self.keyBar.onInfoTapped = ^{ [weakSelf showUDIDInfo]; };

    // Nút test Cơ chế C (bad_query) — luôn hiển thị kể cả khi iOS "Chưa Hỗ Trợ"
    UIButton *bqBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [bqBtn setTitle:@"🔓  Test Cơ Chế C (bad_query)" forState:UIControlStateNormal];
    bqBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [bqBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.831 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    bqBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.831 blue:1.0 alpha:0.08];
    bqBtn.layer.cornerRadius = 10;
    bqBtn.layer.borderWidth = 0.5;
    bqBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.831 blue:1.0 alpha:0.3].CGColor;
    bqBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [bqBtn addTarget:self action:@selector(testBadQueryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:bqBtn];

    // Nút SEP Probe — kiểm tra CVE-2026-20637 access
    UIButton *sepBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [sepBtn setTitle:@"🔬  SEP KeyStore Probe (CVE-2026-20637)" forState:UIControlStateNormal];
    sepBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [sepBtn setTitleColor:[UIColor colorWithRed:0.6 green:1.0 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    sepBtn.backgroundColor = [UIColor colorWithRed:0.6 green:1.0 blue:0.4 alpha:0.08];
    sepBtn.layer.cornerRadius = 10;
    sepBtn.layer.borderWidth = 0.5;
    sepBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:1.0 blue:0.4 alpha:0.3].CGColor;
    sepBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [sepBtn addTarget:self action:@selector(testSEPProbeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sepBtn];

    // Nút Panic PoC — amber/cam, cảnh báo nguy hiểm (device có thể reboot)
    UIButton *panicBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [panicBtn setTitle:@"⚡  CVE-2026-20637 Panic PoC (30s)" forState:UIControlStateNormal];
    panicBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [panicBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.7 blue:0.0 alpha:1.0] forState:UIControlStateNormal];
    panicBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.7 blue:0.0 alpha:0.08];
    panicBtn.layer.cornerRadius = 10;
    panicBtn.layer.borderWidth = 0.5;
    panicBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.7 blue:0.0 alpha:0.4].CGColor;
    panicBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [panicBtn addTarget:self action:@selector(panicPoCTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:panicBtn];

    // Position collection view below stats view, above the key bar
    [NSLayoutConstraint activateConstraints:@[
        [bqBtn.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:8],
        [bqBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [bqBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [bqBtn.heightAnchor constraintEqualToConstant:36],
        [sepBtn.topAnchor constraintEqualToAnchor:bqBtn.bottomAnchor constant:6],
        [sepBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [sepBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [sepBtn.heightAnchor constraintEqualToConstant:36],
        [panicBtn.topAnchor constraintEqualToAnchor:sepBtn.bottomAnchor constant:6],
        [panicBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [panicBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [panicBtn.heightAnchor constraintEqualToConstant:36],
        [self.collectionView.topAnchor constraintEqualToAnchor:panicBtn.bottomAnchor constant:8],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.keyBar.topAnchor],

        // Bar starts 64pt above the safe-area bottom and fills to the screen edge
        [self.keyBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-64],
        [self.keyBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.keyBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keyBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
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

#pragma mark - bad_query diagnostic

- (void)testBadQueryTapped {
    [self showBadQueryTerminalWithLog:nil];
}

- (void)testSEPProbeTapped {
    [self showTerminalLog:nil
                   title:@"⚠️  SEP KeyStore Probe (CVE-2026-20637)"
              runnerBlock:^NSString *{
        return [SEPKeyStoreProbe runProbe];
    }];
}

- (void)panicPoCTapped {
    // Cảnh báo trước: device có thể reboot
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"⚡ Panic PoC"
        message:@"Race IOCommandGate UAF trong 30 giây.\n\nDevice CÓ THỂ REBOOT — đó là dấu hiệu UAF confirmed.\n\nTiếp tục?"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Chạy PoC" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self showTerminalLog:nil
                       title:@"⚡  CVE-2026-20637 — Panic PoC"
                  runnerBlock:^NSString *{
            return [SEPExploit runPanicPoC];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

/** Hiển thị terminal-style debug panel, chạy runnerBlock async để lấy log. */
- (void)showTerminalLog:(NSString *)preloadedLog
                  title:(NSString *)title
            runnerBlock:(NSString *(^)(void))runner {
    [self _showTerminalPanelTitle:title preloaded:preloadedLog runner:runner];
}

/** Wrapper cũ cho bad_query. */
- (void)showBadQueryTerminalWithLog:(NSString *)preloadedLog {
    [self _showTerminalPanelTitle:@"⚠️  CƠ CHẾ C — DEBUG (bad_query)"
                        preloaded:preloadedLog
                           runner:^{ return [BadQueryManager runDiagnostic]; }];
}

/** Hiển thị terminal-style debug panel (giống màn debug trong app). */
- (void)_showTerminalPanelTitle:(NSString *)panelTitle
                       preloaded:(NSString *)preloadedLog
                          runner:(NSString *(^)(void))runner {
    // Alias cho backwards compat — tái sử dụng implementation cũ
    NSString *preload = preloadedLog;
    NSString *ios   = [[UIDevice currentDevice] systemVersion];
    NSString *model = [[UIDevice currentDevice] model];

    // ── Container view controller ─────────────────────────────────────────────
    UIViewController *vc = [[UIViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;

    UIColor *bg      = [UIColor colorWithRed:0.03 green:0.03 blue:0.09 alpha:1.0];
    UIColor *amber   = [UIColor colorWithRed:1.00 green:0.80 blue:0.00 alpha:1.0];
    UIColor *green   = [UIColor colorWithRed:0.20 green:1.00 blue:0.50 alpha:1.0];
    UIColor *cyan    = [UIColor colorWithRed:0.00 green:0.83 blue:1.00 alpha:1.0];
    UIColor *border  = [UIColor colorWithRed:1.00 green:0.80 blue:0.00 alpha:0.55];
    UIFont  *mono    = [UIFont fontWithName:@"Menlo" size:12]
                    ?: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    UIFont  *monoSm  = [UIFont fontWithName:@"Menlo" size:11]
                    ?: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];

    vc.view.backgroundColor = bg;

    // ── Panel container ───────────────────────────────────────────────────────
    UIView *panel = [[UIView alloc] init];
    panel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.13 alpha:1.0];
    panel.layer.cornerRadius = 14;
    panel.layer.borderWidth  = 1.0;
    panel.layer.borderColor  = border.CGColor;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:panel];

    // ── Header row ────────────────────────────────────────────────────────────
    UILabel *headerLbl = [[UILabel alloc] init];
    headerLbl.text = panelTitle ?: @"⚠️  DEBUG";
    headerLbl.textColor = amber;
    headerLbl.font = [UIFont boldSystemFontOfSize:13];
    headerLbl.numberOfLines = 1;
    headerLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:headerLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.text = [NSString stringWithFormat:@"iOS: %@    Model: %@", ios, model];
    subLbl.textColor = [amber colorWithAlphaComponent:0.75];
    subLbl.font = monoSm;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:subLbl];

    // Separator line
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = border;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:sep];

    // ── Scrollable log text view ──────────────────────────────────────────────
    UITextView *tv = [[UITextView alloc] init];
    tv.editable  = NO;
    tv.selectable = YES;
    tv.backgroundColor = [UIColor clearColor];
    tv.textColor = green;
    tv.font = mono;
    tv.text = preload ? preload : @"Đang chạy...";
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:tv];

    // ── Close button ──────────────────────────────────────────────────────────
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"✕  Đóng" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [closeBtn setTitleColor:cyan forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.83 blue:1.0 alpha:0.10];
    closeBtn.layer.cornerRadius = 10;
    closeBtn.layer.borderWidth  = 0.5;
    closeBtn.layer.borderColor  = [UIColor colorWithRed:0.0 green:0.83 blue:1.0 alpha:0.4].CGColor;
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:closeBtn];

    // Action: dismiss
    void (^doDismiss)(void) = ^{ [vc dismissViewControllerAnimated:YES completion:nil]; };
    UIAction *closeAction = [UIAction actionWithHandler:^(__kindof UIAction *a) { doDismiss(); }];
    [closeBtn addAction:closeAction forControlEvents:UIControlEventTouchUpInside];

    // ── Layout ────────────────────────────────────────────────────────────────
    UILayoutGuide *safe = vc.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [panel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:14],
        [panel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-14],
        [panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],

        [headerLbl.topAnchor constraintEqualToAnchor:panel.topAnchor constant:14],
        [headerLbl.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],
        [headerLbl.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],

        [subLbl.topAnchor constraintEqualToAnchor:headerLbl.bottomAnchor constant:4],
        [subLbl.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],
        [subLbl.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],

        [sep.topAnchor constraintEqualToAnchor:subLbl.bottomAnchor constant:10],
        [sep.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],
        [sep.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],
        [sep.heightAnchor constraintEqualToConstant:0.5],

        [tv.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:8],
        [tv.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:10],
        [tv.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-10],
        [tv.bottomAnchor constraintEqualToAnchor:closeBtn.topAnchor constant:-10],

        [closeBtn.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],
        [closeBtn.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],
        [closeBtn.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-14],
        [closeBtn.heightAnchor constraintEqualToConstant:44],
    ]];

    // ── Present immediately, run diagnostic async ─────────────────────────────
    [self presentViewController:vc animated:YES completion:^{
        if (preload) return;  // đã có log rồi, không cần chạy lại

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *log = runner ? runner() : @"(no runner)";
            dispatch_async(dispatch_get_main_queue(), ^{
                tv.text = log;
                [tv scrollRangeToVisible:NSMakeRange(0, 0)];
            });
        });
    }];
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
    // Frosted glass stats card
    self.statsView = [[GlassView alloc] init];
    self.statsView.layer.cornerRadius = 20;
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.statsView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statsView.heightAnchor constraintEqualToConstant:110]
    ]];

    UIView *iosRow  = [self statRowText:[NSString stringWithFormat:@"iOS  %@", [[UIDevice currentDevice] systemVersion]]
                                 symbol:@"applelogo" tint:BRAND_PURPLE valueColor:BRAND_MUTED labelTag:0];
    UIView *devRow  = [self statRowText:[NSString stringWithFormat:@"Device  %@", [self deviceModelName]]
                                 symbol:@"iphone" tint:BRAND_CYAN valueColor:BRAND_MUTED labelTag:0];

    BOOL supported = [self isIOSSupported];
    NSString *supportText   = supported ? LS(@"Có Hỗ Trợ", @"Supported") : LS(@"Chưa Hỗ Trợ", @"Not Supported");
    NSString *supportSymbol = supported ? @"checkmark.shield.fill" : @"xmark.shield.fill";
    UIColor  *supportTint   = supported
        ? [UIColor colorWithRed:0.2 green:0.85 blue:0.4 alpha:1.0]   // xanh lá
        : [UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0];  // cam
    UIView *supportRow = [self statRowText:supportText symbol:supportSymbol tint:supportTint valueColor:supportTint labelTag:998];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iosRow, devRow, supportRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statsView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.statsView.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:self.statsView.trailingAnchor constant:-18],
        [stack.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
    ]];

    // Nhấn giữ thẻ thông tin ~1.2s để mở bảng Admin (reset khoá thiết bị)
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];

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

#if DEBUG
// Hiện debug thẳng trên màn hình chính khi KHÔNG tìm thấy game
- (void)updateInlineDebug {
    [self.debugView removeFromSuperview];
    self.debugView = nil;
    if (self.appIDs.count > 0) return;   // có game rồi thì thôi

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"⚠️ KHÔNG THẤY GAME — DEBUG\n(chụp màn này gửi admin)\n\n"];

    char machine[64] = {0}; size_t ms = sizeof(machine);
    sysctlbyname("hw.machine", machine, &ms, NULL, 0);
    [s appendFormat:@"iOS: %@   Model: %s\n", [UIDevice currentDevice].systemVersion, machine];

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

    [NSLayoutConstraint activateConstraints:@[
        [tv.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:16],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [tv.bottomAnchor constraintEqualToAnchor:self.keyBar.topAnchor constant:-16],
    ]];
}
#endif  // DEBUG (updateInlineDebug)

// Kiểm tra iOS có nằm trong danh sách hỗ trợ không:
//   ✅  iOS 16.7.16 (chính xác)
//   ✅  iOS 17.0 → 18.7.1
//   ✅  iOS 26.0 → 27.0 (Beta 1)
//   ⚠️  Tất cả phiên bản khác
- (BOOL)isIOSSupported {
    NSString *ver = [[UIDevice currentDevice] systemVersion];

    // iOS 16.7.16 chính xác
    if ([ver isEqualToString:@"16.7.16"]) return YES;

    // iOS 17.0 → 18.x (bao gồm 18.7.2–18.7.10, upper exclusive: 19.0)
    if ([ver compare:@"17.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"19.0" options:NSNumericSearch] == NSOrderedAscending) return YES;

    // iOS 26.0 → 27.0 Beta 1 (upper exclusive: 27.1)
    if ([ver compare:@"26.0" options:NSNumericSearch] != NSOrderedAscending &&
        [ver compare:@"27.1" options:NSNumericSearch] == NSOrderedAscending) return YES;

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
    // refreshApps được gọi sau khi sandbox escape thành công (từ AppDelegate)
    // Nếu loading view đang hiện (VFS chưa xong) thì giữ nguyên, hideLoadingView sẽ tự chạy sau loadApps
    [self loadApps];
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
