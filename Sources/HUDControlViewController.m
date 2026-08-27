#import "HUDControlViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "SecurityGuard.h"
#import "Endpoints.h"
#import "LanguageManager.h"
#import "DinhViColorPickerViewController.h"

// ── Palette — Tactical Matrix Grid ──────────────────────
// Surface
#define HUD_BG_TOP      [UIColor colorWithRed:0.051 green:0.067 blue:0.102 alpha:1.0]  // #0D111A
#define HUD_BG_BOTTOM   [UIColor colorWithRed:0.035 green:0.047 blue:0.075 alpha:1.0]  // #090C13
#define HUD_CARD        [UIColor colorWithRed:0.086 green:0.114 blue:0.169 alpha:1.0]  // #161D2B
#define HUD_CARD_ON     [UIColor colorWithRed:0.110 green:0.149 blue:0.220 alpha:1.0]  // #1C2638
#define HUD_BORDER      [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1.0]  // #232E42
// Accents
#define HUD_CYAN        [UIColor colorWithRed:0.000 green:0.898 blue:1.000 alpha:1.0]  // #00E5FF
#define HUD_GREEN       [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1.0]  // #30D158
#define HUD_PURPLE      [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1.0]  // #BF5AF2
#define HUD_ORANGE      [UIColor colorWithRed:1.000 green:0.400 blue:0.122 alpha:1.0]  // #FF661F
#define HUD_PINK        [UIColor colorWithRed:1.000 green:0.216 blue:0.502 alpha:1.0]  // #FF3780
#define HUD_RED         [UIColor colorWithRed:1.000 green:0.271 blue:0.227 alpha:1.0]  // #FF453A
// Text
#define HUD_TEXT        [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:1.0]  // #FFFFFF
#define HUD_MUTED       [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1.0]  // #7C8BA1

// ── Tutorial video URLs — điền link YouTube thực tế ────────────────────────
static NSString *const kTutorialProxyURL = @"https://youtu.be/bchI1KaZhSI";
static NSString *const kTutorialDragURL  = @"https://youtube.com/shorts/WSZrdOsyg5Q";

static UIColor *HUDDarken(UIColor *c, CGFloat f) {
    CGFloat r,g,b,a; [c getRed:&r green:&g blue:&b alpha:&a];
    return [UIColor colorWithRed:r*f green:g*f blue:b*f alpha:a];
}
static UIColor *HUDLighten(UIColor *c, CGFloat t) {
    CGFloat r,g,b,a; [c getRed:&r green:&g blue:&b alpha:&a];
    return [UIColor colorWithRed:r+(1-r)*t green:g+(1-g)*t blue:b+(1-b)*t alpha:a];
}

#pragma mark - Feature model

@class HUDFeatureRow;
@class HUDControlViewController;

@interface HUDFeature : NSObject
@property (nonatomic, copy)   NSString *symbol;
@property (nonatomic, strong) UIColor  *tint;
@property (nonatomic, copy)   NSString *title;      // VI title (default)
@property (nonatomic, copy)   NSString *subtitle;   // VI subtitle (default)
@property (nonatomic, copy)   NSString *enTitle;    // EN title (nil = same as title)
@property (nonatomic, copy)   NSString *enSubtitle; // EN subtitle (nil = same as subtitle)
@property (nonatomic, copy)   NSString *featureKey;  // body/neck/drag/magic (gửi server)
@property (nonatomic, copy)   NSString *fileName;    // tên file cần tìm & ghi đè (single-file)
@property (nonatomic, copy)   NSString *searchRoot;  // thư mục gốc để tìm (tương đối Documents)
// Multi-file: khi set, mỗi entry là cả speedFile lẫn fileName trên device (fakedame, speed)
@property (nonatomic, copy)   NSArray<NSString *> *speedFiles;
@property (nonatomic, assign) BOOL exclusive;        // YES = radio trong group; NO = độc lập
@property (nonatomic, copy)   NSString *exclusiveGroup;   // nhóm radio: @"aim" / @"skin" / nil
@property (nonatomic, copy)   NSString *previewImageURL;  // nil = không có nút xem ảnh
// customAction: nếu set thì khi toggle ON sẽ mở UI riêng thay vì gọi AutoPasteManager
@property (nonatomic, copy)   void (^customAction)(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game);
// restoreFileName: nếu set, khi toggle OFF sẽ dán lại file gốc (mode=goc) thay vì không làm gì
@property (nonatomic, copy)   NSString *restoreFileName;
@property (nonatomic, readonly) BOOL configured;
@end

@implementation HUDFeature
- (BOOL)configured {
    return self.featureKey.length &&
           (self.fileName.length || self.speedFiles.count > 0 || self.customAction != nil);
}
@end

// ═══════════════════════════════════════════════════════════
// #pragma mark - Feature Tile (Tactical Matrix Grid — 2 col)
// ═══════════════════════════════════════════════════════════
//
// Thay thế HUDFeatureRow (list dọc) bằng tile hình chữ nhật
// dùng trong UICollectionView 2 cột. Khi ON toàn bộ tile sáng
// lên bằng tinted border + background. Không dùng blur.
//
// Layout trong tile (cao 84pt):
//   ┌──────────────────────────────────┐
//   │ [LED dot] [icon 22pt]   [toggle] │  ← top row
//   │ Title 12pt semibold              │
//   │ Subtitle 10pt muted              │  ← bottom area
//   └──────────────────────────────────┘

#pragma mark - Feature tile (grid cell)

@class HUDFeatureRow;

// HUDFeatureRow = alias cho HUDFeatureTile để không phải đổi handleRow: và mọi call-site
@interface HUDFeatureRow : UIView
@property (nonatomic, strong) HUDFeature *feature;
@property (nonatomic, assign) BOOL        isOn;      // replaces UISwitch — tap tile để toggle
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel    *statusDot;
@property (nonatomic, strong) UIButton   *previewButton;
@property (nonatomic, strong) UILabel    *rowTitleLabel;
@property (nonatomic, strong) UILabel    *rowSubtitleLabel;
@property (nonatomic, assign) BOOL        isLoading;
@property (nonatomic, copy)   void (^onChanged)(HUDFeatureRow *row, BOOL isOn);
@property (nonatomic, copy)   void (^onPreviewTapped)(void);
- (instancetype)initWithFeature:(HUDFeature *)feature;
- (void)setOn:(BOOL)on animated:(BOOL)animated;  // compat shim cho call-site cũ
- (void)setLoading:(BOOL)loading;
- (void)showResult:(BOOL)success;
- (void)setActive:(BOOL)active;
- (void)refreshLanguage;
@end

@implementation HUDFeatureRow {
    UIView *_ledDot;       // LED status indicator (top-left)
    UIView *_tileGlow;     // full-tile tinted background khi ON
    BOOL    _loadingLock;  // block tap khi đang loading
}

- (instancetype)initWithFeature:(HUDFeature *)feature {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _feature = feature;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Tile base styling ──────────────────────────────────
    self.backgroundColor    = HUD_CARD;
    self.layer.cornerRadius = 12;
    self.layer.cornerCurve  = kCACornerCurveContinuous;
    self.layer.borderWidth  = 1;
    self.layer.borderColor  = HUD_BORDER.CGColor;
    self.clipsToBounds      = YES;  // clip nội dung vào rounded corner

    // ── Tinted glow bg (fade-in khi ON) ───────────────────
    _tileGlow = [[UIView alloc] init];
    _tileGlow.backgroundColor    = [feature.tint colorWithAlphaComponent:0.12];
    _tileGlow.layer.cornerRadius = 12;
    _tileGlow.layer.cornerCurve  = kCACornerCurveContinuous;
    _tileGlow.alpha              = 0;
    _tileGlow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_tileGlow];

    // ── LED dot (top-left) ────────────────────────────────
    _ledDot = [[UIView alloc] init];
    _ledDot.layer.cornerRadius = 3.5;
    _ledDot.backgroundColor    = HUD_BORDER;
    _ledDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_ledDot];

    // ── SF Symbol icon ────────────────────────────────────
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    UIImageView *iconIV = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:feature.symbol withConfiguration:symCfg]];
    iconIV.tintColor    = feature.tint;
    iconIV.contentMode  = UIViewContentModeScaleAspectFit;
    iconIV.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:iconIV];

    // ── Tap gesture: ấn cả tile để toggle ON/OFF ─────────
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(tileTapped)];
    [self addGestureRecognizer:tap];
    self.userInteractionEnabled = YES;

    // ── Title ─────────────────────────────────────────────
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.font          = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    titleLbl.textColor     = HUD_TEXT;
    titleLbl.numberOfLines = 2;
    titleLbl.lineBreakMode = NSLineBreakByWordWrapping;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:titleLbl];
    self.rowTitleLabel = titleLbl;

    // ── Subtitle ──────────────────────────────────────────
    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.font          = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
    subLbl.textColor     = HUD_MUTED;
    subLbl.numberOfLines = 2;
    subLbl.lineBreakMode = NSLineBreakByWordWrapping;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:subLbl];
    self.rowSubtitleLabel = subLbl;

    // ── Status dot label (✓/✕) ────────────────────────────
    _statusDot = [[UILabel alloc] init];
    _statusDot.font      = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    _statusDot.textColor = HUD_GREEN;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_statusDot];

    // ── Spinner ───────────────────────────────────────────
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color         = feature.tint;
    _spinner.hidesWhenStopped = YES;
    _spinner.transform     = CGAffineTransformMakeScale(0.75, 0.75);
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_spinner];

    // ── Preview button (chỉ khi có previewImageURL) ───────
    if (feature.previewImageURL.length) {
        _previewButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImageSymbolConfiguration *pcfg = [UIImageSymbolConfiguration
            configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
        [_previewButton setImage:[UIImage systemImageNamed:@"photo.fill" withConfiguration:pcfg]
                        forState:UIControlStateNormal];
        _previewButton.tintColor       = [feature.tint colorWithAlphaComponent:0.85];
        _previewButton.backgroundColor = [feature.tint colorWithAlphaComponent:0.12];
        _previewButton.layer.cornerRadius = 6;
        _previewButton.layer.masksToBounds = YES;
        _previewButton.layer.borderColor   = [feature.tint colorWithAlphaComponent:0.3].CGColor;
        _previewButton.layer.borderWidth   = 1;
        _previewButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_previewButton];
        [_previewButton addTarget:self action:@selector(previewTapped)
                forControlEvents:UIControlEventTouchUpInside];
    }

    [self refreshLanguage];

    // ── Auto-Layout ───────────────────────────────────────
    // Tile height: 96pt priority High (750) — UIStackView FillEqually có thể override
    // khi cần để 2 cột cùng chiều cao. Tap toàn tile để toggle (không có UISwitch).
    NSLayoutConstraint *hc = [self.heightAnchor constraintEqualToConstant:96];
    hc.priority = UILayoutPriorityDefaultHigh;  // 750, không conflict với FillEqually
    [NSLayoutConstraint activateConstraints:@[
        hc,

        // tileGlow = full tile
        [_tileGlow.topAnchor    constraintEqualToAnchor:self.topAnchor],
        [_tileGlow.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_tileGlow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_tileGlow.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        // LED dot: top-left, 10pt inset
        [_ledDot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [_ledDot.topAnchor     constraintEqualToAnchor:self.topAnchor     constant:12],
        [_ledDot.widthAnchor   constraintEqualToConstant:7],
        [_ledDot.heightAnchor  constraintEqualToConstant:7],

        // Icon: right of LED dot, same vertical center
        [iconIV.leadingAnchor constraintEqualToAnchor:_ledDot.trailingAnchor constant:5],
        [iconIV.centerYAnchor constraintEqualToAnchor:_ledDot.centerYAnchor],
        [iconIV.widthAnchor   constraintEqualToConstant:20],
        [iconIV.heightAnchor  constraintEqualToConstant:20],

        // Status dot: top-right (✓/✕ feedback, ẩn lúc bình thường)
        [_statusDot.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [_statusDot.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:10],
        [_statusDot.widthAnchor    constraintEqualToConstant:16],

        // Spinner: đè lên status dot
        [_spinner.centerXAnchor constraintEqualToAnchor:_statusDot.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:_statusDot.centerYAnchor],

        // Title: below icon row, full width
        [titleLbl.leadingAnchor   constraintEqualToAnchor:self.leadingAnchor  constant:10],
        [titleLbl.trailingAnchor  constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [titleLbl.topAnchor       constraintEqualToAnchor:iconIV.bottomAnchor constant:7],

        // Subtitle: directly below title
        [subLbl.leadingAnchor  constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor constraintEqualToAnchor:titleLbl.trailingAnchor],
        [subLbl.topAnchor      constraintEqualToAnchor:titleLbl.bottomAnchor constant:2],
    ]];

    // Preview button: bottom-right nếu có — 26×26, 7pt inset
    if (_previewButton) {
        [NSLayoutConstraint activateConstraints:@[
            [_previewButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-7],
            [_previewButton.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor  constant:-7],
            [_previewButton.widthAnchor    constraintEqualToConstant:26],
            [_previewButton.heightAnchor   constraintEqualToConstant:26],
        ]];
    }

    return self;
}

- (void)tileTapped {
    if (![SecurityGuard isEnvironmentTrusted]) { [SecurityGuard bailOut]; return; }
    if (_loadingLock) return;  // đang xử lý, bỏ qua tap
    self.isOn = !self.isOn;
    [self setActive:self.isOn];
    // Haptic nhẹ khi tap
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    if (self.onChanged) self.onChanged(self, self.isOn);
}

// Compat shim: call-site cũ dùng [row setOn:NO animated:YES]
// → thay bằng [row setOn:NO animated:YES]
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    self.isOn = on;
    if (animated) {
        [self setActive:on];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self setActive:on];
        [CATransaction commit];
    }
}

- (void)previewTapped {
    if (self.onPreviewTapped) self.onPreviewTapped();
}

- (void)setActive:(BOOL)active {
    UIColor *tint = self.feature.tint;
    [UIView animateWithDuration:0.22 delay:0
         usingSpringWithDamping:0.8 initialSpringVelocity:0.3
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_tileGlow.alpha       = active ? 1 : 0;
        self.layer.borderColor      = active
            ? [tint colorWithAlphaComponent:0.55].CGColor
            : HUD_BORDER.CGColor;
        self->_ledDot.backgroundColor = active ? tint : HUD_BORDER;
    } completion:nil];
}

- (void)setLoading:(BOOL)loading {
    _loadingLock = loading;  // block tap khi đang xử lý
    self.isLoading = loading;
    if (loading) {
        self.statusDot.text = @"";
        [self.spinner startAnimating];
        // Dim tile nhẹ khi loading
        [UIView animateWithDuration:0.15 animations:^{ self.alpha = 0.65; }];
    } else {
        [self.spinner stopAnimating];
        [UIView animateWithDuration:0.15 animations:^{ self.alpha = 1.0; }];
    }
}

- (void)showResult:(BOOL)success {
    self.statusDot.text      = success ? @"✓" : @"✕";
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
// ── Tab UI (Tactical Matrix Grid — chip bar) ──
@property (nonatomic, strong) NSArray<UIButton *>             *tabButtons;   // 3 chip buttons
@property (nonatomic, strong) NSArray<UIColor *>              *tabTints;     // per-tab accent
@property (nonatomic, strong) NSArray<NSArray<HUDFeature *> *> *tabFeatures; // [tab][feature]
@property (nonatomic, assign) NSInteger activeTab;
// Panel cards (solid UIView, no blur)
@property (nonatomic, strong) UIView  *panelProxy;
@property (nonatomic, strong) UIView  *panelDinhVi;
@property (nonatomic, strong) UIView  *panelModNV;
@property (nonatomic, strong) UIView  *panelDrag;
@property (nonatomic, strong) UILabel *panelDinhViTitleLabel;
@property (nonatomic, strong) UILabel *panelModNVTitleLabel;
// Chip bar container + compat stub
@property (nonatomic, strong) UIView    *segmentBar;
@property (nonatomic, assign) NSInteger  pendingThumbTab;  // compat stub; no-op
@property (nonatomic, strong) NSMutableArray<UILabel *> *segLabels;
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
    self.activeTab = 0;
    self.title = self.appName;

    // ── Background: solid dark (NO blur, performance-safe) ──
    self.view.backgroundColor = HUD_BG_TOP;

    self.bgGradient = [CAGradientLayer layer];
    self.bgGradient.colors = @[(id)HUD_BG_TOP.CGColor, (id)HUD_BG_BOTTOM.CGColor];
    self.bgGradient.startPoint = CGPointMake(0.5, 0.0);
    self.bgGradient.endPoint   = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:self.bgGradient atIndex:0];

    // Subtle purple radial glow (top-center) — static, không animate
    self.radialGlow = [CAGradientLayer layer];
    self.radialGlow.type = kCAGradientLayerRadial;
    self.radialGlow.colors = @[(id)[HUD_PURPLE colorWithAlphaComponent:0.20].CGColor,
                               (id)[HUD_PURPLE colorWithAlphaComponent:0.0].CGColor];
    self.radialGlow.startPoint = CGPointMake(0.5, 0.5);
    self.radialGlow.endPoint   = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:self.radialGlow above:self.bgGradient];

    // Dot-grid texture (very subtle)
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
    // ══════════════════════════════════════════════════════════
    // TACTICAL MATRIX GRID — buildUI
    // Layout:
    //   • Header: icon (68pt) + name + bundle (compact, horizontal)
    //   • Chip Tab Bar: 3 pill chips, solid color, no blur
    //   • Panel cards: solid UIView (#161D2B), NO UIVisualEffectView
    //   • Features: UICollectionView 2-column grid of HUDFeatureTile
    //   • Status label + sticky MỞ GAME button
    // ══════════════════════════════════════════════════════════

    // ── Scroll + content ────────────────────────────────────
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.backgroundColor = [UIColor clearColor];
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor    constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [content.topAnchor    constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor  constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor  constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    // ── Header (horizontal compact) ────────────────────────
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:headerView];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:self.icon];
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.clipsToBounds = YES;
    iconView.layer.cornerRadius = 14;
    iconView.layer.cornerCurve  = kCACornerCurveContinuous;
    iconView.layer.borderColor  = [HUD_CYAN colorWithAlphaComponent:0.4].CGColor;
    iconView.layer.borderWidth  = 1.5;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text      = self.appName;
    nameLabel.font      = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    nameLabel.textColor = HUD_TEXT;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:nameLabel];

    UILabel *bundleLabel = [[UILabel alloc] init];
    bundleLabel.text      = self.bundleID;
    bundleLabel.font      = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    bundleLabel.textColor = HUD_MUTED;
    bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:bundleLabel];

    // Online indicator dot
    UIView *onlineDot = [[UIView alloc] init];
    onlineDot.backgroundColor    = HUD_GREEN;
    onlineDot.layer.cornerRadius = 4;
    onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:onlineDot];

    UILabel *onlineLbl = [[UILabel alloc] init];
    onlineLbl.text      = @"ONLINE";
    onlineLbl.font      = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
    onlineLbl.textColor = HUD_GREEN;
    onlineLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:onlineLbl];

    [NSLayoutConstraint activateConstraints:@[
        [headerView.topAnchor    constraintEqualToAnchor:content.topAnchor constant:18],
        [headerView.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:16],
        [headerView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [headerView.heightAnchor constraintEqualToConstant:68],

        [iconView.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        [iconView.widthAnchor   constraintEqualToConstant:56],
        [iconView.heightAnchor  constraintEqualToConstant:56],

        [nameLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [nameLabel.topAnchor     constraintEqualToAnchor:iconView.topAnchor constant:4],

        [bundleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [bundleLabel.topAnchor     constraintEqualToAnchor:nameLabel.bottomAnchor constant:3],

        [onlineDot.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [onlineDot.topAnchor     constraintEqualToAnchor:bundleLabel.bottomAnchor constant:5],
        [onlineDot.widthAnchor   constraintEqualToConstant:8],
        [onlineDot.heightAnchor  constraintEqualToConstant:8],

        [onlineLbl.leadingAnchor constraintEqualToAnchor:onlineDot.trailingAnchor constant:5],
        [onlineLbl.centerYAnchor constraintEqualToAnchor:onlineDot.centerYAnchor],
    ]];

    // ── Chip Tab Bar ───────────────────────────────────────
    // 3 pill chips — solid fill, no blur, no sliding thumb
    NSArray<NSString *> *tabSyms   = @[@"bolt.fill", @"location.fill", @"person.fill.badge.plus"];
    NSArray<NSString *> *tabLabels = @[
        LS(@"Proxy",   @"Proxy"),
        LS(@"Định Vị", @"Aim Bot"),
        LS(@"Mod NV",  @"Mod Skin"),
    ];
    NSArray<NSString *> *tabBadges = @[@"AUTO", @"LIVE", @"SOON"];
    self.tabTints = @[HUD_CYAN, HUD_GREEN, HUD_PURPLE];

    UIView *chipBar = [[UIView alloc] init];
    chipBar.translatesAutoresizingMaskIntoConstraints = NO;
    chipBar.backgroundColor = [UIColor colorWithRed:0.055 green:0.075 blue:0.118 alpha:1.0]; // #0E1330
    chipBar.layer.cornerRadius = 14;
    chipBar.layer.cornerCurve  = kCACornerCurveContinuous;
    chipBar.layer.borderColor  = HUD_BORDER.CGColor;
    chipBar.layer.borderWidth  = 1;
    [content addSubview:chipBar];
    self.segmentBar = chipBar;

    UIStackView *chipStack = [[UIStackView alloc] init];
    chipStack.axis         = UILayoutConstraintAxisHorizontal;
    chipStack.distribution = UIStackViewDistributionFillEqually;
    chipStack.spacing      = 4;
    chipStack.translatesAutoresizingMaskIntoConstraints = NO;
    [chipBar addSubview:chipStack];

    NSMutableArray<UIButton *> *btns = [NSMutableArray array];
    NSMutableArray<UILabel *>  *lbls = [NSMutableArray array];

    for (NSInteger i = 0; i < 3; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
        chip.tag = i;
        chip.layer.cornerRadius = 10;
        chip.layer.cornerCurve  = kCACornerCurveContinuous;
        chip.layer.masksToBounds = YES;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        [chip addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        // Icon
        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
            configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        UIImageView *iconIV = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:tabSyms[(NSUInteger)i] withConfiguration:symCfg]];
        iconIV.contentMode           = UIViewContentModeScaleAspectFit;
        iconIV.translatesAutoresizingMaskIntoConstraints = NO;
        iconIV.userInteractionEnabled = NO;
        iconIV.tag = 10 + i;
        [chip addSubview:iconIV];

        // Label
        UILabel *lbl = [[UILabel alloc] init];
        lbl.text           = tabLabels[(NSUInteger)i];
        lbl.font           = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        lbl.textAlignment  = NSTextAlignmentCenter;
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        lbl.userInteractionEnabled = NO;
        lbl.tag = 20 + i;
        [chip addSubview:lbl];
        [lbls addObject:lbl];

        // Badge pill
        UILabel *badge = [[UILabel alloc] init];
        badge.text          = [NSString stringWithFormat:@" %@ ", tabBadges[(NSUInteger)i]];
        badge.font          = [UIFont systemFontOfSize:7.5 weight:UIFontWeightBold];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius  = 4;
        badge.layer.masksToBounds = YES;
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.tag = 30 + i;
        [chip addSubview:badge];

        [NSLayoutConstraint activateConstraints:@[
            [iconIV.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
            [iconIV.topAnchor     constraintEqualToAnchor:chip.topAnchor constant:9],
            [iconIV.widthAnchor   constraintEqualToConstant:14],
            [iconIV.heightAnchor  constraintEqualToConstant:14],
            [lbl.centerXAnchor    constraintEqualToAnchor:chip.centerXAnchor],
            [lbl.topAnchor        constraintEqualToAnchor:iconIV.bottomAnchor constant:3],
            [badge.centerXAnchor  constraintEqualToAnchor:chip.centerXAnchor],
            [badge.topAnchor      constraintEqualToAnchor:lbl.bottomAnchor constant:3],
        ]];

        [chipStack addArrangedSubview:chip];
        [btns addObject:chip];
    }
    self.tabButtons = [btns copy];
    self.segLabels  = lbls;

    [NSLayoutConstraint activateConstraints:@[
        [chipBar.topAnchor     constraintEqualToAnchor:headerView.bottomAnchor constant:16],
        [chipBar.leadingAnchor   constraintEqualToAnchor:content.leadingAnchor   constant:16],
        [chipBar.trailingAnchor  constraintEqualToAnchor:content.trailingAnchor  constant:-16],
        [chipBar.heightAnchor  constraintEqualToConstant:64],
        [chipStack.topAnchor     constraintEqualToAnchor:chipBar.topAnchor     constant:4],
        [chipStack.leadingAnchor   constraintEqualToAnchor:chipBar.leadingAnchor   constant:4],
        [chipStack.trailingAnchor  constraintEqualToAnchor:chipBar.trailingAnchor  constant:-4],
        [chipStack.bottomAnchor  constraintEqualToAnchor:chipBar.bottomAnchor  constant:-4],
    ]];

    [self selectTab:0];

    // ── Build feature data + rows array ───────────────────
    self.rows = [NSMutableArray array];

    NSArray<HUDFeature *> *proxyFeats = [self proxyFeaturesForBundle:self.bundleID];
    NSArray<HUDFeature *> *dvFeats    = [self dinhViFeaturesForBundle:self.bundleID];
    NSArray<HUDFeature *> *modFeats   = [self modNVFeaturesForBundle:self.bundleID];
    NSArray<HUDFeature *> *dragFeats  = [self dragFeaturesForBundle:self.bundleID];
    self.tabFeatures = @[proxyFeats, dvFeats, modFeats];

    // Pre-create HUDFeatureRow objects for ALL features (so handleRow: / radio logic works)
    __weak typeof(self) weakSelf = self;
    for (NSArray<HUDFeature *> *featSet in @[proxyFeats, dvFeats, modFeats, dragFeats]) {
        for (HUDFeature *f in featSet) {
            HUDFeatureRow *row = [[HUDFeatureRow alloc] initWithFeature:f];
            row.onChanged = ^(HUDFeatureRow *r, BOOL isOn) { [weakSelf handleRow:r on:isOn]; };
            if (f.previewImageURL.length) {
                NSString *url = f.previewImageURL;
                row.onPreviewTapped = ^{ [weakSelf showPreviewURL:url]; };
            }
            [self.rows addObject:row];
        }
    }

    // ── Panel cards (solid, no blur) ───────────────────────
    self.panelProxy  = [self buildPanelWithTitle:@"PROXY DELTA VIP"
                                          symbol:@"bolt.fill"     tint:HUD_CYAN   badge:@"AUTO"
                                        features:proxyFeats
                                     tutorialURL:kTutorialProxyURL ?: @""
                                  outTitleLabel:nil];
    self.panelDinhVi = [self buildPanelWithTitle:LS(@"ĐỊNH VỊ SÚNG", @"AIM BOT")
                                          symbol:@"location.fill" tint:HUD_GREEN  badge:@"LIVE"
                                        features:dvFeats
                                     tutorialURL:nil
                                  outTitleLabel:&_panelDinhViTitleLabel];
    self.panelModNV  = [self buildPanelWithTitle:LS(@"MOD NHÂN VẬT", @"CHARACTER MOD")
                                          symbol:@"person.fill.badge.plus" tint:HUD_PURPLE badge:@"SOON"
                                        features:modFeats
                                     tutorialURL:nil
                                  outTitleLabel:&_panelModNVTitleLabel];
    self.panelDrag   = [self buildPanelWithTitle:@"PROXY DELTA VIP V2"
                                          symbol:@"hand.draw.fill" tint:HUD_ORANGE badge:@"V2"
                                        features:dragFeats
                                     tutorialURL:kTutorialDragURL ?: @""
                                  outTitleLabel:nil];

    self.panelDinhVi.hidden = YES;
    self.panelModNV.hidden  = YES;

    UIStackView *panelsStack = [[UIStackView alloc] init];
    panelsStack.axis    = UILayoutConstraintAxisVertical;
    panelsStack.spacing = 0;
    panelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:panelsStack];
    [panelsStack addArrangedSubview:self.panelProxy];
    [panelsStack addArrangedSubview:self.panelDrag];
    [panelsStack addArrangedSubview:self.panelDinhVi];
    [panelsStack addArrangedSubview:self.panelModNV];
    [panelsStack setCustomSpacing:14 afterView:self.panelProxy];

    // ── Status label ───────────────────────────────────────
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text      = LS(@"Đã Sẵn Sàng - Bạn Đã Có Thể Bắt Đầu Kích Hoạt Proxy",
                                   @"Ready — Activate Proxy Now");
    self.statusLabel.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textColor = HUD_MUTED;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    // ── MỞ GAME sticky button ──────────────────────────────
    self.openGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openGameButton setTitle:LS(@"▶  MỞ GAME", @"▶  OPEN GAME") forState:UIControlStateNormal];
    [self.openGameButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0]
                               forState:UIControlStateNormal];
    self.openGameButton.titleLabel.font   = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    self.openGameButton.layer.cornerRadius = 16;
    self.openGameButton.layer.cornerCurve  = kCACornerCurveContinuous;
    self.openGameButton.clipsToBounds      = YES;
    self.openGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openGameButton addTarget:self action:@selector(launchGame) forControlEvents:UIControlEventTouchUpInside];

    self.openGameGradient = [CAGradientLayer layer];
    self.openGameGradient.colors = @[(id)HUD_PURPLE.CGColor, (id)HUD_CYAN.CGColor];
    self.openGameGradient.startPoint = CGPointMake(0, 0.5);
    self.openGameGradient.endPoint   = CGPointMake(1, 0.5);
    self.openGameGradient.cornerRadius = 16;
    [self.openGameButton.layer insertSublayer:self.openGameGradient atIndex:0];

    // ── Constraints ────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [panelsStack.topAnchor    constraintEqualToAnchor:chipBar.bottomAnchor    constant:16],
        [panelsStack.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor   constant:16],
        [panelsStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor  constant:-16],

        [self.statusLabel.topAnchor    constraintEqualToAnchor:panelsStack.bottomAnchor constant:18],
        [self.statusLabel.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor   constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor  constant:-24],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
    ]];

    [self.view addSubview:self.openGameButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.openGameButton.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor  constant:20],
        [self.openGameButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.openGameButton.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.openGameButton.heightAnchor   constraintEqualToConstant:56],
    ]];
    scroll.contentInset          = UIEdgeInsetsMake(0, 0, 88, 0);
    scroll.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 88, 0);
}

// Tạo 1 panel card (Tactical Matrix Grid) với title bar + 2-column tile grid.
// buildPanelWithTitle: — Tactical Matrix Grid edition
// Solid UIView card (NO UIVisualEffectView blur).
// Feature tiles laid out as 2-column UIStackView grid (2 tiles per row).
// Rows are NOT re-created here — buildUI pre-creates them into self.rows
// and passes them in via the `features` array which maps to indices in self.rows.
// tutorialURL: @"" = hiện "sắp có"; @"https://…" = mở YouTube; nil = ẩn row
- (UIView *)buildPanelWithTitle:(NSString *)title
                         symbol:(NSString *)symbol
                           tint:(UIColor *)tint
                          badge:(NSString *)badge
                       features:(NSArray<HUDFeature *> *)features
                    tutorialURL:(NSString * _Nullable)tutorialURL
                 outTitleLabel:(UILabel * __strong *)outTitleLabel {

    // ── Outer shadow wrapper ────────────────────────────────
    UIView *panelWrap = [[UIView alloc] init];
    panelWrap.backgroundColor = [UIColor clearColor];
    panelWrap.layer.shadowColor   = [tint colorWithAlphaComponent:0.5].CGColor;
    panelWrap.layer.shadowOpacity = 0.22;
    panelWrap.layer.shadowRadius  = 14;
    panelWrap.layer.shadowOffset  = CGSizeMake(0, 4);
    panelWrap.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Solid card (no blur) ────────────────────────────────
    UIView *pc = [[UIView alloc] init];
    pc.backgroundColor    = HUD_CARD;
    pc.clipsToBounds      = YES;
    pc.layer.cornerRadius = 18;
    pc.layer.cornerCurve  = kCACornerCurveContinuous;
    pc.layer.borderColor  = [tint colorWithAlphaComponent:0.40].CGColor;
    pc.layer.borderWidth  = 1;
    pc.translatesAutoresizingMaskIntoConstraints = NO;
    [panelWrap addSubview:pc];

    // ── Title bar ───────────────────────────────────────────
    UIView *titleBar = [[UIView alloc] init];
    titleBar.backgroundColor = [tint colorWithAlphaComponent:0.08];
    titleBar.translatesAutoresizingMaskIntoConstraints = NO;
    [pc addSubview:titleBar];

    // Left accent rail
    UIView *accent = [[UIView alloc] init];
    accent.backgroundColor    = tint;
    accent.layer.cornerRadius = 2;
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:accent];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    UIImageView *icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:symbol withConfiguration:symCfg]];
    icon.tintColor   = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:icon];

    UILabel *menuTitle = [[UILabel alloc] init];
    menuTitle.text      = title;
    menuTitle.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    menuTitle.textColor = tint;
    menuTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:menuTitle];
    if (outTitleLabel) *outTitleLabel = menuTitle;

    UILabel *hint = [[UILabel alloc] init];
    hint.text             = [NSString stringWithFormat:@" %@ ", badge];
    hint.font             = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    hint.textColor        = tint;
    hint.backgroundColor  = [tint colorWithAlphaComponent:0.14];
    hint.layer.cornerRadius   = 7;
    hint.layer.masksToBounds  = YES;
    hint.layer.borderColor    = [tint colorWithAlphaComponent:0.45].CGColor;
    hint.layer.borderWidth    = 1;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [titleBar addSubview:hint];

    // ── 2-column tile grid ──────────────────────────────────
    // Build rows of 2 tiles each using nested UIStackViews.
    // HUDFeatureRow tiles are already in self.rows — find them by featureKey match.
    UIStackView *gridStack = [[UIStackView alloc] init];
    gridStack.axis      = UILayoutConstraintAxisVertical;
    gridStack.spacing   = 8;
    gridStack.translatesAutoresizingMaskIntoConstraints = NO;
    [pc addSubview:gridStack];

    NSUInteger count = features.count;
    NSUInteger i = 0;
    while (i < count) {
        // Find matching HUDFeatureRow for features[i]
        HUDFeatureRow *tileA = nil;
        HUDFeatureRow *tileB = nil;
        NSString *keyA = features[i].featureKey;
        for (HUDFeatureRow *r in self.rows) {
            if ([r.feature.featureKey isEqualToString:keyA]) { tileA = r; break; }
        }

        if (i + 1 < count) {
            NSString *keyB = features[i+1].featureKey;
            for (HUDFeatureRow *r in self.rows) {
                if ([r.feature.featureKey isEqualToString:keyB]) { tileB = r; break; }
            }
        }

        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis         = UILayoutConstraintAxisHorizontal;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.alignment    = UIStackViewAlignmentFill;  // stretch to same height
        rowStack.spacing      = 8;
        rowStack.translatesAutoresizingMaskIntoConstraints = NO;

        if (tileA) [rowStack addArrangedSubview:tileA];
        if (tileB) {
            [rowStack addArrangedSubview:tileB];
        } else {
            // Odd tile: add spacer so single tile doesn't stretch full width
            UIView *spacer = [[UIView alloc] init];
            spacer.backgroundColor = [UIColor clearColor];
            [rowStack addArrangedSubview:spacer];
        }

        [gridStack addArrangedSubview:rowStack];
        i += (tileB ? 2 : 1);
    }

    // ── Tutorial row (optional) ─────────────────────────────
    NSLayoutYAxisAnchor *gridBottomAnchor = pc.bottomAnchor;
    CGFloat gridBottomConst = -10;

    if (tutorialURL != nil) {
        BOOL hasURL = tutorialURL.length > 0;
        UIColor *ytRed    = [UIColor colorWithRed:1.0 green:0.22 blue:0.18 alpha:1.0];
        UIColor *tutColor = hasURL ? ytRed : HUD_MUTED;

        UIView *sep = [[UIView alloc] init];
        sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        [pc addSubview:sep];

        UIView *tutRow = [[UIView alloc] init];
        tutRow.translatesAutoresizingMaskIntoConstraints = NO;
        [pc addSubview:tutRow];

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
            [sep.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor  constant:12],
            [sep.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor constant:-12],
            [sep.heightAnchor   constraintEqualToConstant:0.5],
            [tutRow.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor],
            [tutRow.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor],
            [tutRow.heightAnchor   constraintEqualToConstant:50],
            [tutRow.bottomAnchor   constraintEqualToAnchor:pc.bottomAnchor],
            [sep.bottomAnchor      constraintEqualToAnchor:tutRow.topAnchor],
            [playIcon.leadingAnchor constraintEqualToAnchor:tutRow.leadingAnchor constant:16],
            [playIcon.centerYAnchor constraintEqualToAnchor:tutRow.centerYAnchor],
            [playIcon.widthAnchor   constraintEqualToConstant:20],
            [playIcon.heightAnchor  constraintEqualToConstant:20],
            [tutTitle.leadingAnchor constraintEqualToAnchor:playIcon.trailingAnchor constant:12],
            [tutTitle.bottomAnchor  constraintEqualToAnchor:tutRow.centerYAnchor constant:-1],
            [tutSub.leadingAnchor   constraintEqualToAnchor:tutTitle.leadingAnchor],
            [tutSub.topAnchor       constraintEqualToAnchor:tutRow.centerYAnchor constant:3],
        ]];

        if (hasURL) {
            UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            tapBtn.backgroundColor             = [UIColor clearColor];
            tapBtn.translatesAutoresizingMaskIntoConstraints = NO;
            tapBtn.accessibilityIdentifier     = tutorialURL;
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

        gridBottomAnchor = sep.topAnchor;
        gridBottomConst  = 0;
    }

    [NSLayoutConstraint activateConstraints:@[
        // Card fills wrapper
        [pc.topAnchor    constraintEqualToAnchor:panelWrap.topAnchor],
        [pc.leadingAnchor  constraintEqualToAnchor:panelWrap.leadingAnchor],
        [pc.trailingAnchor constraintEqualToAnchor:panelWrap.trailingAnchor],
        [pc.bottomAnchor constraintEqualToAnchor:panelWrap.bottomAnchor],

        // Title bar
        [titleBar.topAnchor    constraintEqualToAnchor:pc.topAnchor],
        [titleBar.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor],
        [titleBar.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor],
        [titleBar.heightAnchor constraintEqualToConstant:44],

        // Accent rail
        [accent.leadingAnchor constraintEqualToAnchor:titleBar.leadingAnchor constant:14],
        [accent.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [accent.widthAnchor   constraintEqualToConstant:3],
        [accent.heightAnchor  constraintEqualToConstant:18],

        // Icon
        [icon.leadingAnchor constraintEqualToAnchor:accent.trailingAnchor constant:9],
        [icon.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],
        [icon.widthAnchor   constraintEqualToConstant:15],
        [icon.heightAnchor  constraintEqualToConstant:15],

        // Title text
        [menuTitle.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:7],
        [menuTitle.centerYAnchor constraintEqualToAnchor:titleBar.centerYAnchor],

        // Badge
        [hint.trailingAnchor constraintEqualToAnchor:titleBar.trailingAnchor constant:-14],
        [hint.centerYAnchor  constraintEqualToAnchor:titleBar.centerYAnchor],
        [hint.heightAnchor   constraintEqualToConstant:18],

        // Grid
        [gridStack.topAnchor    constraintEqualToAnchor:titleBar.bottomAnchor constant:10],
        [gridStack.leadingAnchor  constraintEqualToAnchor:pc.leadingAnchor   constant:10],
        [gridStack.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor  constant:-10],
        [gridStack.bottomAnchor constraintEqualToAnchor:gridBottomAnchor constant:gridBottomConst],
    ]];

    return panelWrap;
}


- (void)tutorialButtonTapped:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:sender.accessibilityIdentifier];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

#pragma mark - Tab switching

// Chip Tab Bar: highlight active chip with tint background + border.
// No sliding thumb — just swap chip bg/border colors.
- (void)selectTab:(NSInteger)tab {
    self.activeTab = tab;
    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        UIColor *tint  = self.tabTints[(NSUInteger)i];
        BOOL    active = (i == tab);
        UIButton *chip = self.tabButtons[(NSUInteger)i];

        UIImageView *iconV = (UIImageView *)[chip viewWithTag:10 + i];
        UILabel     *lblV  = (UILabel     *)[chip viewWithTag:20 + i];
        UILabel     *badgeV = (UILabel    *)[chip viewWithTag:30 + i];

        [UIView animateWithDuration:0.20 delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            chip.backgroundColor   = active ? [tint colorWithAlphaComponent:0.18] : [UIColor clearColor];
            chip.layer.borderColor = active ? [tint colorWithAlphaComponent:0.55].CGColor
                                            : [UIColor clearColor].CGColor;
            chip.layer.borderWidth = active ? 1.0 : 0.0;

            if (iconV)  iconV.tintColor   = active ? tint : HUD_MUTED;
            if (lblV)   lblV.textColor    = active ? tint : HUD_MUTED;
            if (badgeV) {
                badgeV.textColor       = active ? tint : HUD_MUTED;
                badgeV.backgroundColor = active ? [tint colorWithAlphaComponent:0.14]
                                                : [HUD_MUTED colorWithAlphaComponent:0.10];
            }
        } completion:nil];
    }
}

// updateThumbForTab: kept as no-op stub so viewDidLayoutSubviews doesn't crash.
// Chip tab bar doesn't use a sliding thumb.
- (void)updateThumbForTab:(NSInteger)tab animated:(BOOL)animated {
    // No-op: chip highlight is applied entirely in selectTab:
    (void)tab; (void)animated;
}

// Bấm tab → cập nhật pills + fade crossfade giữa 2 panel
- (void)tabButtonTapped:(UIButton *)sender {
    [self selectTab:sender.tag];
    [self switchToPanel:sender.tag];
}

// Crossfade mượt theo cả hai chiều.
// Dùng BeginFromCurrentState để handle mid-animation tap (bấm ngược lại không bị khựng).
- (void)switchToPanel:(NSInteger)tab {
    NSArray<UIView *> *panels = @[self.panelProxy, self.panelDinhVi, self.panelModNV];
    UIView *toShow = panels[(NSUInteger)tab];
    BOOL dragShouldShow = (tab == 0);

    // Cancel animation đang chạy bằng cách collect trạng thái hiện tại của tất cả panels.
    // BeginFromCurrentState sẽ tiếp tục từ alpha hiện tại (kể cả đang mid-fade).
    NSMutableArray<UIView *> *toHideAll = [NSMutableArray array];
    for (UIView *p in panels) {
        if (p != toShow) {
            // Unhide để BeginFromCurrentState có thể fade từ alpha hiện tại về 0
            p.hidden = NO;
            [toHideAll addObject:p];
        }
    }
    // panelDrag luôn unhide trước để animation từ current alpha
    self.panelDrag.hidden = NO;

    // Đảm bảo toShow bắt đầu visible (alpha có thể đang 0 nếu mới unhide)
    toShow.hidden = NO;

    [UIView animateWithDuration:0.22 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                               | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        // Fade-in panel cần show
        toShow.alpha = 1.0;
        self.panelDrag.alpha = dragShouldShow ? 1.0 : 0.0;
        // Fade-out tất cả panel còn lại
        for (UIView *p in toHideAll) {
            p.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        // Ẩn hẳn các panel đã fade về 0
        for (UIView *p in toHideAll) {
            if (p.alpha < 0.01) {
                p.hidden = YES;
                p.alpha  = 1.0;  // reset để lần sau fade từ 1
            }
        }
        if (!dragShouldShow && self.panelDrag.alpha < 0.01) {
            self.panelDrag.hidden = YES;
            self.panelDrag.alpha  = 1.0;
        }
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

// ── AimDrag + FakeDame — panel riêng bên dưới tab ───────────────────────────
- (NSArray<HUDFeature *> *)dragFeaturesForBundle:(NSString *)bundleID {
    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    NSString *assetIdx = @"assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D";
    NSString *root     = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *fn = supported ? assetIdx : nil;
    NSString *rt = supported ? root : nil;
    NSString *(^k)(NSString *) = ^NSString *(NSString *key) { return supported ? key : nil; };

    HUDFeature *drag = [self featureWithSymbol:@"hand.draw.fill" tint:HUD_ORANGE
        title:LS(@"Aim Drag", @"Aim Drag")
        subtitle:LS(@"Kéo Nhẹ Tâm Lên Đỉnh Đầu", @"Soft Pull — Aim Rises to Head")
        featureKey:k(@"drag") fileName:fn searchRoot:rt];
    drag.enTitle    = @"Aim Drag";
    drag.enSubtitle = @"Soft Pull — Aim Rises to Head";

    // FakeDame — paste TẤT CẢ 12 file (khớp với $KNOWN_SPEED_FILES trên server)
    HUDFeature *fakeDame = [self featureWithSymbol:@"flame.fill" tint:HUD_RED
        title:LS(@"Fake Dame", @"Fake Dame")
        subtitle:LS(@"Hiển Thị Số Dame Ảo Lên Màn Hình", @"Show Fake Damage Numbers")
        featureKey:k(@"fakedame") fileName:nil searchRoot:rt];
    fakeDame.enTitle    = @"Fake Dame";
    fakeDame.enSubtitle = @"Show Fake Damage Numbers";
    if (supported) {
        fakeDame.speedFiles = @[
            @"assembly-csharp-patch.9~2FHZTlufvnrWfync7WczZNS9AXI~3D",
            @"buffeca_54295235.7xh42QWuR~2BU9mqJeXhWD~2FKGJtiY~3D",
            @"clothes_0f0a401f.eRw7Wj969f~2BpD27BK~2FZ7DHRHZ14~3D",
            @"clothesrecipesbytes.OLt~2BOQ4IWVhkbzurhciya6GXnoU~3D",
            @"clothesslotoverlays.6NSQ2XCBi32h~2FZ072hBKOPWgjMc~3D",
            @"clothessetid_ff0b2c80.ALjp2Q5YLAIk2inKSd~2F97bjNm9E~3D",
            @"collectionemote_b0f7ddf9.ruXyNy2oV02EjLLwo0opXi~2BYgPI~3D",
            @"collectionweapon_0a06ebc1.7IJ2~2FWIyOIz8QwH~2BvrL8n2oOlWI~3D",
            @"gameassetbundles.Uq9GZIiGsLcjcj0JtQBPfvF22SQ~3D",
            @"itemhotfix_90e164c0.Y4cPeTfuwnGf6yje8j1jebNjCeA~3D",
            @"lochotfix.bHrijH~2Fa85tole6aa0VxWZxBO~2Bw~3D",
            @"resconfhotupdate.sQAN5lHYts~2FR9i1ZKU4q07p1gwE~3D",
        ];
    }

    return @[drag, fakeDame];
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

    // Định Vị Súng Đen Viền Đỏ — chỉ FF Thường
    HUDFeature *dvDo = [self featureWithSymbol:@"location.fill.viewfinder" tint:HUD_RED
                                         title:@"Định Vị Súng Đen Viền Đỏ" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                    featureKey:kTH(@"dinhvido") fileName:(isTH ? sfTH : nil) searchRoot:rtTH];
    dvDo.exclusive = NO;
    dvDo.enTitle = @"Black Red-Bordered Gun Locator"; dvDo.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Súng Đỏ — chỉ FF Max
    HUDFeature *dvDoMax = [self featureWithSymbol:@"location.fill.viewfinder" tint:HUD_RED
                                            title:@"Định Vị Súng Đỏ" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                       featureKey:kMax(@"dinhvido") fileName:(isMax ? sfMax : nil) searchRoot:rtMax];
    dvDoMax.exclusive = NO;
    dvDoMax.enTitle = @"Red Gun Locator"; dvDoMax.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Súng Màu Tự Chọn — FF Thường
    HUDFeature *dvCustomTH = [HUDFeature new];
    dvCustomTH.symbol     = @"paintpalette.fill";
    dvCustomTH.tint       = HUD_RED;
    dvCustomTH.title      = @"Định Vị Súng Màu Tự Chọn";
    dvCustomTH.subtitle   = @"Tùy Chỉnh Màu X-Ray & Viền Súng";
    dvCustomTH.enTitle    = @"Custom Color Gun Locator";
    dvCustomTH.enSubtitle = @"Customize X-Ray & Outline Colors";
    dvCustomTH.featureKey       = kTH(@"dinhvi_custom");
    dvCustomTH.fileName         = nil;
    dvCustomTH.restoreFileName  = @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D";
    dvCustomTH.searchRoot       = rtTH;
    dvCustomTH.exclusive        = NO;
    __weak typeof(self) weakSelf = self;
    dvCustomTH.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        DinhViColorPickerViewController *picker =
            [DinhViColorPickerViewController pickerForGame:@"th"
                                                searchRoot:rtTH
                                                completion:^(BOOL success, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [row setLoading:NO];
                [row showResult:success];
                if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
                [weakSelf setStatus:msg color:(success ? HUD_GREEN : HUD_RED)];
            });
        }];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [row setLoading:YES];
        [vc setStatus:LS(@"⏳ Đang mở bộ chọn màu...", @"⏳ Opening color picker...") color:HUD_MUTED];
        [vc presentViewController:nav animated:YES completion:nil];
    };

    // Định Vị Súng Màu Tự Chọn — FF Max
    HUDFeature *dvCustomMax = [HUDFeature new];
    dvCustomMax.symbol     = @"paintpalette.fill";
    dvCustomMax.tint       = HUD_RED;
    dvCustomMax.title      = @"Định Vị Súng Màu Tự Chọn";
    dvCustomMax.subtitle   = @"Tùy Chỉnh Màu X-Ray & Viền Súng";
    dvCustomMax.enTitle    = @"Custom Color Gun Locator";
    dvCustomMax.enSubtitle = @"Customize X-Ray & Outline Colors";
    dvCustomMax.featureKey       = kMax(@"dinhvi_custom");
    dvCustomMax.fileName         = nil;
    dvCustomMax.restoreFileName  = @"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D";
    dvCustomMax.searchRoot       = rtMax;
    dvCustomMax.exclusive        = NO;
    dvCustomMax.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        DinhViColorPickerViewController *picker =
            [DinhViColorPickerViewController pickerForGame:@"max"
                                                searchRoot:rtMax
                                                completion:^(BOOL success, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [row setLoading:NO];
                [row showResult:success];
                if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
                [weakSelf setStatus:msg color:(success ? HUD_GREEN : HUD_RED)];
            });
        }];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [row setLoading:YES];
        [vc setStatus:LS(@"⏳ Đang mở bộ chọn màu...", @"⏳ Opening color picker...") color:HUD_MUTED];
        [vc presentViewController:nav animated:YES completion:nil];
    };

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
    for (HUDFeature *f in @[dvXanh, dvDo, dvDoMax, dvCustomTH, dvCustomMax, dvXanhLa, dvHong]) {
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
        [row setOn:!isOn animated:YES];
        [row setActive:NO];
        [self setStatus:LS(@"⛔ Phát hiện can thiệp — đã khoá chức năng",
                          @"⛔ Tampering detected — feature locked") color:HUD_RED];
        return;
    }

    // Khoá chức năng sau license key hợp lệ (đã bind đúng máy)
    if ([KeyManager shared].state != KeyStateActive) {
        [row setOn:!isOn animated:YES];
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
        [row setOn:!isOn animated:YES];
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
                && other.isOn) {
                [other setOn:NO animated:YES];   // programmatic → không kích hoạt paste
                [other setActive:NO];
                other.statusDot.text = @"";
            }
        }
    }

    NSString *game = [self.bundleID isEqualToString:@"com.dts.freefiremax"] ? @"max" : @"th";

    // ── customAction: mở UI riêng (vd. color picker) thay vì paste trực tiếp ──────
    if (f.customAction) {
        if (!isOn) {
            [row setActive:NO];
            // Nếu có restoreFileName → dán lại file gốc (mode=goc) để tắt hiệu ứng
            if (f.restoreFileName.length > 0) {
                [row setLoading:YES];
                [self setStatus:LS(@"⏳ Đang khôi phục...", @"⏳ Restoring...") color:HUD_MUTED];
                __weak typeof(self) weakSelf = self;
                [[AutoPasteManager sharedManager]
                    pasteFeature:f.featureKey
                             mod:NO
                            game:game
                       fileNamed:f.restoreFileName
                       underRoot:f.searchRoot ?: @""
                      completion:^(BOOL ok, NSString *msg) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [row setLoading:NO];
                        NSString *status = ok
                            ? LS(@"✅ Đã Tắt Định Vị Súng Màu Tự Chọn", @"✅ Custom Color Gun Locator Disabled")
                            : msg;
                        [weakSelf setStatus:status color:(ok ? HUD_GREEN : HUD_RED)];
                    });
                }];
            }
            return;
        }
        f.customAction(row, self, game);
        return;
    }

    [row setLoading:YES];
    [self setStatus:LS(@"⏳ Đang Kích Hoạt", @"⏳ Activating") color:HUD_MUTED];

    __weak typeof(self) weakSelf = self;

    // ── Multi-file path (fakedame, speed): paste tuần tự từng file ──────────────
    if (f.speedFiles.count > 0) {
        NSArray<NSString *> *files = [f.speedFiles copy];
        NSInteger total = (NSInteger)files.count;

        __block void (^pasteNext)(NSInteger);
        pasteNext = ^(NSInteger i) {
            if (i >= total) {
                // Tất cả file xong — báo thành công
                pasteNext = nil; // phá cycle
                dispatch_async(dispatch_get_main_queue(), ^{
                    [row setLoading:NO];
                    [row showResult:YES];
                    NSString *done = isOn
                        ? [NSString stringWithFormat:LS(@"✅ Kích Hoạt Thành Công %@", @"✅ Activated %@"), f.title]
                        : [NSString stringWithFormat:LS(@"✅ Đã Tắt Thành Công %@",    @"✅ Deactivated %@"), f.title];
                    [weakSelf setStatus:done color:HUD_GREEN];
                    UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
                    [nfb notificationOccurred:UINotificationFeedbackTypeSuccess];
                });
                return;
            }

            NSString *sf = files[(NSUInteger)i];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setStatus:[NSString stringWithFormat:
                    LS(@"⏳ Đang Paste %ld/%ld...", @"⏳ Patching %ld/%ld..."),
                    (long)(i + 1), (long)total] color:HUD_MUTED];
            });

            [[AutoPasteManager sharedManager] pasteFeature:f.featureKey
                                                       mod:isOn
                                                      game:game
                                                 fileNamed:sf
                                                 underRoot:f.searchRoot
                                                 speedFile:sf
                                                completion:^(BOOL success, NSString *message) {
                if (!success) {
                    pasteNext = nil; // phá cycle
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [row setLoading:NO];
                        [row showResult:NO];
                        [row setOn:NO animated:YES];
                        [row setActive:NO];
                        [weakSelf setStatus:message color:HUD_RED];
                        UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
                        [nfb notificationOccurred:UINotificationFeedbackTypeError];
                    });
                    return;
                }
                pasteNext(i + 1);
            }];
        };
        pasteNext(0);
        return;
    }

    // ── Single-file path (tất cả feature khác) ──────────────────────────────────
    [[AutoPasteManager sharedManager] pasteFeature:f.featureKey
                                               mod:isOn
                                              game:game
                                         fileNamed:f.fileName
                                         underRoot:f.searchRoot
                                        completion:^(BOOL success, NSString *message) {
        [row setLoading:NO];
        [row showResult:success];
        if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
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
