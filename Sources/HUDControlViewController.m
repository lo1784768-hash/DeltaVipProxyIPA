#import "HUDControlViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "DNSBlockManager.h"
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
// ── DinhViColorPanel — floating overlay card ──────────────────────────────────
// Present trên vc.view như một modal overlay; không dùng UIViewController.
// Dismiss: tap backdrop hoặc nút ✕.

@interface DinhViColorPanel : UIView <UIColorPickerViewControllerDelegate>
+ (void)showInViewController:(UIViewController *)vc
                        game:(NSString *)game
                  searchRoot:(NSString *)searchRoot
                 restoreFile:(NSString *)restoreFile
                  completion:(void(^)(BOOL success, NSString *msg))completion;
@end

@implementation DinhViColorPanel {
    NSMutableArray<UIColor *>  *_colors;       // [xray, line, dim]
    NSMutableArray<UIButton *> *_swatchBtns;
    UISlider  *_alphaSlider;
    UISlider  *_widthSlider;
    UILabel   *_alphaLbl;
    UILabel   *_widthLbl;
    UIButton  *_applyBtn;
    NSInteger  _editingSlot;

    NSString  *_game;
    NSString  *_root;
    __weak UIViewController *_vc;
    void (^_completion)(BOOL, NSString *);
    BOOL _busy;
}

+ (void)showInViewController:(UIViewController *)vc
                        game:(NSString *)game
                  searchRoot:(NSString *)searchRoot
                 restoreFile:(NSString *)restoreFile
                  completion:(void(^)(BOOL success, NSString *msg))completion {
    DinhViColorPanel *panel = [[DinhViColorPanel alloc] initWithVC:vc
                                                              game:game
                                                        searchRoot:searchRoot
                                                       restoreFile:restoreFile
                                                        completion:completion];
    [panel presentAnimated:YES];
}

- (instancetype)initWithVC:(UIViewController *)vc
                      game:(NSString *)game
                searchRoot:(NSString *)searchRoot
               restoreFile:(NSString *)restoreFile
                completion:(void(^)(BOOL, NSString *))completion {
    self = [super initWithFrame:vc.view.bounds];
    if (!self) return nil;
    _vc         = vc;
    _game       = game;
    _root       = searchRoot;
    _completion = completion;
    (void)restoreFile; // lưu nếu cần sau

    _colors = [@[
        [UIColor colorWithRed:0.067 green:0.067 blue:0.067 alpha:1],
        [UIColor whiteColor],
        [UIColor colorWithRed:0.067 green:0.067 blue:0.067 alpha:1],
    ] mutableCopy];
    _swatchBtns = [NSMutableArray array];

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self _buildUI];
    return self;
}

- (void)_buildUI {
    // ── Backdrop dim ──────────────────────────────────────────
    UIView *backdrop = [[UIView alloc] initWithFrame:self.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    [self addSubview:backdrop];
    UITapGestureRecognizer *backdropTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(_dismiss)];
    [backdrop addGestureRecognizer:backdropTap];

    // ── Card ──────────────────────────────────────────────────
    UIView *card = [[UIView alloc] init];
    card.backgroundColor    = [UIColor colorWithRed:0.086 green:0.114 blue:0.169 alpha:1]; // HUD_CARD
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.layer.borderColor  = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1].CGColor; // HUD_BORDER
    card.layer.borderWidth  = 1;
    // Top glow line (cyan)
    CAGradientLayer *topLine = [CAGradientLayer layer];
    topLine.colors = @[(id)[UIColor colorWithRed:0 green:0.898 blue:1 alpha:0].CGColor,
                       (id)[UIColor colorWithRed:0 green:0.898 blue:1 alpha:0.6].CGColor,
                       (id)[UIColor colorWithRed:0 green:0.898 blue:1 alpha:0].CGColor];
    topLine.startPoint = CGPointMake(0, 0.5);
    topLine.endPoint   = CGPointMake(1, 0.5);
    topLine.frame = CGRectMake(40, 0, self.bounds.size.width - 120, 1);
    [card.layer addSublayer:topLine];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:card];

    // ── Header row ────────────────────────────────────────────
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImageView *headerIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"paintpalette.fill" withConfiguration:symCfg]];
    headerIcon.tintColor = [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1]; // HUD_CYAN
    headerIcon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *headerLbl = [[UILabel alloc] init];
    headerLbl.text = LS(@"ĐỊNH VỊ MÀU TỰ CHỌN", @"CUSTOM GUN COLOR");
    headerLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    headerLbl.textColor = [UIColor whiteColor];
    headerLbl.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *xcfg = [UIImageSymbolConfiguration
        configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:xcfg] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
    closeBtn.backgroundColor = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1];
    closeBtn.layer.cornerRadius = 13;
    closeBtn.layer.masksToBounds = YES;
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(_dismiss) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[headerIcon, headerLbl]];
    headerRow.axis    = UILayoutConstraintAxisHorizontal;
    headerRow.spacing = 8;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Divider ───────────────────────────────────────────────
    UIView *div = [[UIView alloc] init];
    div.backgroundColor = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:0.8];
    div.translatesAutoresizingMaskIntoConstraints = NO;

    // ── 3 swatch columns ──────────────────────────────────────
    NSArray<NSString *>  *labels = @[LS(@"Súng X-Ray", @"X-Ray"), LS(@"Viền Súng", @"Outline"), LS(@"Màu Keo", @"Glue Color")];
    NSArray<UIColor *>   *tints  = @[
        [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1],      // cyan
        [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1], // green
        [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1], // purple
    ];

    UIStackView *swatchRow = [[UIStackView alloc] init];
    swatchRow.axis         = UILayoutConstraintAxisHorizontal;
    swatchRow.distribution = UIStackViewDistributionFillEqually;
    swatchRow.spacing      = 12;
    swatchRow.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSInteger i = 0; i < 3; i++) {
        UIView *col = [[UIView alloc] init];
        col.translatesAutoresizingMaskIntoConstraints = NO;

        // Circle button 48pt
        UIButton *sw = [UIButton buttonWithType:UIButtonTypeCustom];
        sw.backgroundColor     = _colors[i];
        sw.layer.cornerRadius  = 24;
        sw.layer.masksToBounds = YES;
        sw.layer.borderColor   = [tints[i] colorWithAlphaComponent:0.7].CGColor;
        sw.layer.borderWidth   = 2.5;
        sw.tag = i;
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        [sw addTarget:self action:@selector(_swatchTapped:) forControlEvents:UIControlEventTouchUpInside];

        // Pencil icon overlay
        UIImageSymbolConfiguration *pcfg = [UIImageSymbolConfiguration
            configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        UIImageView *pencil = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:@"pencil" withConfiguration:pcfg]];
        pencil.tintColor = [tints[i] colorWithAlphaComponent:0.9];
        pencil.translatesAutoresizingMaskIntoConstraints = NO;
        [sw addSubview:pencil];

        // Label dưới
        UILabel *lb = [[UILabel alloc] init];
        lb.text          = labels[i];
        lb.font          = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        lb.textColor     = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
        lb.textAlignment = NSTextAlignmentCenter;
        lb.numberOfLines = 1;
        lb.adjustsFontSizeToFitWidth = YES;
        lb.minimumScaleFactor = 0.8;
        lb.translatesAutoresizingMaskIntoConstraints = NO;

        [col addSubview:sw];
        [col addSubview:pencil];
        [col addSubview:lb];
        [_swatchBtns addObject:sw];

        [NSLayoutConstraint activateConstraints:@[
            [sw.topAnchor    constraintEqualToAnchor:col.topAnchor],
            [sw.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [sw.widthAnchor  constraintEqualToConstant:48],
            [sw.heightAnchor constraintEqualToConstant:48],

            [pencil.trailingAnchor constraintEqualToAnchor:sw.trailingAnchor constant:-4],
            [pencil.bottomAnchor   constraintEqualToAnchor:sw.bottomAnchor   constant:-4],

            [lb.topAnchor     constraintEqualToAnchor:sw.bottomAnchor constant:6],
            [lb.leadingAnchor constraintEqualToAnchor:col.leadingAnchor],
            [lb.trailingAnchor constraintEqualToAnchor:col.trailingAnchor],
            [col.bottomAnchor constraintEqualToAnchor:lb.bottomAnchor],
        ]];

        [swatchRow addArrangedSubview:col];
    }

    // ── Sliders ───────────────────────────────────────────────
    _alphaLbl = [[UILabel alloc] init];
    _alphaLbl.text      = @"1.00";
    _alphaLbl.font      = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    _alphaLbl.textColor = [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1];
    _alphaLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [_alphaLbl.widthAnchor constraintEqualToConstant:38].active = YES;

    _alphaSlider = [[UISlider alloc] init];
    _alphaSlider.minimumValue          = 0;
    _alphaSlider.maximumValue          = 1;
    _alphaSlider.value                 = 1;
    _alphaSlider.minimumTrackTintColor = [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1];
    _alphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [_alphaSlider addTarget:self action:@selector(_alphaChanged:) forControlEvents:UIControlEventValueChanged];

    _widthLbl = [[UILabel alloc] init];
    _widthLbl.text      = @"4.0";
    _widthLbl.font      = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    _widthLbl.textColor = [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1];
    _widthLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [_widthLbl.widthAnchor constraintEqualToConstant:38].active = YES;

    _widthSlider = [[UISlider alloc] init];
    _widthSlider.minimumValue          = 0;
    _widthSlider.maximumValue          = 20;
    _widthSlider.value                 = 4;
    _widthSlider.minimumTrackTintColor = [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1];
    _widthSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [_widthSlider addTarget:self action:@selector(_widthChanged:) forControlEvents:UIControlEventValueChanged];

    UIStackView *alphaRow = [self _sliderRow:LS(@"Độ đục", @"Opacity") slider:_alphaSlider valLbl:_alphaLbl];
    UIStackView *widthRow = [self _sliderRow:LS(@"Viền dày", @"Outline W") slider:_widthSlider valLbl:_widthLbl];

    // ── Apply button — gradient baked into UIImage (tránh CALayer sublayer bị che) ──
    _applyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_applyBtn setTitle:LS(@"▶  ÁP DỤNG", @"▶  APPLY") forState:UIControlStateNormal];
    [_applyBtn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1] forState:UIControlStateNormal];
    [_applyBtn setTitleColor:[[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1] colorWithAlphaComponent:0.5]
                    forState:UIControlStateHighlighted];
    _applyBtn.titleLabel.font    = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    _applyBtn.layer.cornerRadius = 14;
    _applyBtn.layer.cornerCurve  = kCACornerCurveContinuous;
    _applyBtn.clipsToBounds      = YES;
    _applyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_applyBtn addTarget:self action:@selector(_apply) forControlEvents:UIControlEventTouchUpInside];
    // Render gradient → UIImage để không bị UIKit's internal layer hierarchy che
    {
        CGSize sz = CGSizeMake(320, 48);
        UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
        fmt.scale = 0;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:sz format:fmt];
        UIImage *gradImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            CGContextRef cg = ctx.CGContext;
            NSArray *colors = @[
                (__bridge id)[UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1].CGColor,
                (__bridge id)[UIColor colorWithRed:0 green:0.898 blue:1 alpha:1].CGColor,
            ];
            CGFloat locs[2] = {0, 1};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
            CGContextDrawLinearGradient(cg, grad,
                CGPointMake(0, sz.height/2), CGPointMake(sz.width, sz.height/2), 0);
            CGGradientRelease(grad);
            CGColorSpaceRelease(cs);
        }];
        UIImage *gradImgResizable = [gradImg resizableImageWithCapInsets:UIEdgeInsetsZero];
        [_applyBtn setBackgroundImage:gradImgResizable forState:UIControlStateNormal];
        // Pressed state: tối hơn
        UIImage *gradDark = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            CGContextRef cg = ctx.CGContext;
            NSArray *colors = @[
                (__bridge id)[UIColor colorWithRed:0.5 green:0.2 blue:0.7 alpha:1].CGColor,
                (__bridge id)[UIColor colorWithRed:0 green:0.6 blue:0.75 alpha:1].CGColor,
            ];
            CGFloat locs[2] = {0, 1};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
            CGContextDrawLinearGradient(cg, grad,
                CGPointMake(0, sz.height/2), CGPointMake(sz.width, sz.height/2), 0);
            CGGradientRelease(grad);
            CGColorSpaceRelease(cs);
        }];
        [_applyBtn setBackgroundImage:[gradDark resizableImageWithCapInsets:UIEdgeInsetsZero]
                             forState:UIControlStateHighlighted];
    }

    // ── Assemble card ─────────────────────────────────────────
    [card addSubview:headerRow];
    [card addSubview:closeBtn];
    [card addSubview:div];
    [card addSubview:swatchRow];
    [card addSubview:alphaRow];
    [card addSubview:widthRow];
    [card addSubview:_applyBtn];

    [NSLayoutConstraint activateConstraints:@[
        // Card: centered horizontally, bottom-anchored with padding
        [card.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:16],
        [card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [card.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-34],

        // Header
        [headerRow.topAnchor    constraintEqualToAnchor:card.topAnchor    constant:20],
        [headerRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],

        // Close button
        [closeBtn.centerYAnchor  constraintEqualToAnchor:headerRow.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [closeBtn.widthAnchor    constraintEqualToConstant:26],
        [closeBtn.heightAnchor   constraintEqualToConstant:26],

        // Divider
        [div.topAnchor      constraintEqualToAnchor:headerRow.bottomAnchor constant:14],
        [div.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:16],
        [div.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [div.heightAnchor   constraintEqualToConstant:0.5],

        // Swatches
        [swatchRow.topAnchor    constraintEqualToAnchor:div.bottomAnchor constant:20],
        [swatchRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [swatchRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        // Alpha slider
        [alphaRow.topAnchor    constraintEqualToAnchor:swatchRow.bottomAnchor constant:20],
        [alphaRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [alphaRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        // Width slider
        [widthRow.topAnchor    constraintEqualToAnchor:alphaRow.bottomAnchor constant:10],
        [widthRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [widthRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        // Apply button
        [_applyBtn.topAnchor    constraintEqualToAnchor:widthRow.bottomAnchor constant:20],
        [_applyBtn.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [_applyBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [_applyBtn.heightAnchor   constraintEqualToConstant:48],
        [_applyBtn.bottomAnchor   constraintEqualToAnchor:card.bottomAnchor   constant:-24],
    ]];
}

- (UIStackView *)_sliderRow:(NSString *)label slider:(UISlider *)sl valLbl:(UILabel *)vl {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text      = label;
    lbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [lbl.widthAnchor constraintEqualToConstant:64].active = YES;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[lbl, sl, vl]];
    row.spacing   = 10;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    return row;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // gradient baked into UIImage — không cần update frame
}

- (void)presentAnimated:(BOOL)animated {
    UIView *parentView = _vc.view;
    self.frame = parentView.bounds;
    self.alpha = 0;
    [parentView addSubview:self];
    [self transformForPresent:YES];
    if (animated) {
        [UIView animateWithDuration:0.32 delay:0
             usingSpringWithDamping:0.80 initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.alpha = 1;
            [self transformForPresent:NO];
        } completion:nil];
    } else {
        self.alpha = 1;
        [self transformForPresent:NO];
    }
}

- (void)transformForPresent:(BOOL)initial {
    // Card slides up from below
    if (initial) {
        self.transform = CGAffineTransformMakeTranslation(0, 80);
    } else {
        self.transform = CGAffineTransformIdentity;
    }
}

- (void)_dismiss {
    [UIView animateWithDuration:0.22 delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeTranslation(0, 40);
    } completion:^(BOOL f) {
        [self removeFromSuperview];
    }];
}

- (void)_swatchTapped:(UIButton *)btn {
    _editingSlot = btn.tag;
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [UIColorPickerViewController new];
        picker.selectedColor = _colors[_editingSlot];
        picker.supportsAlpha = NO;
        picker.delegate      = self;
        [_vc presentViewController:picker animated:YES completion:nil];
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc API_AVAILABLE(ios(14.0)) {
    [vc dismissViewControllerAnimated:YES completion:nil];
}
- (void)colorPickerViewController:(UIColorPickerViewController *)vc
                   didSelectColor:(UIColor *)color
                     continuously:(BOOL)cont API_AVAILABLE(ios(14.0)) {
    _colors[_editingSlot] = color;
    _swatchBtns[_editingSlot].backgroundColor = color;
}

- (void)_alphaChanged:(UISlider *)sl {
    _alphaLbl.text = [NSString stringWithFormat:@"%.2f", sl.value];
}
- (void)_widthChanged:(UISlider *)sl {
    _widthLbl.text = [NSString stringWithFormat:@"%.1f", sl.value];
}

- (void)_apply {
    if (_busy) return;
    _busy = YES;
    [_applyBtn setTitle:LS(@"⏳ Đang tạo...", @"⏳ Generating...") forState:UIControlStateNormal];

    NSString *shaderFile = [_game isEqualToString:@"max"]
        ? @"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D"
        : @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D";

    NSDictionary *params = @{
        @"xray_hex"   : [self _hex:_colors[0]],
        @"xray_alpha" : [NSString stringWithFormat:@"%.4f", (double)_alphaSlider.value],
        @"line_hex"   : [self _hex:_colors[1]],
        @"dim_hex"    : [self _hex:_colors[2]],
        @"width"      : [NSString stringWithFormat:@"%.2f", (double)_widthSlider.value],
    };

    void (^cb)(BOOL, NSString *) = _completion;
    [[AutoPasteManager sharedManager] pasteCustomDinhVi:params
                                                   game:_game
                                              fileNamed:shaderFile
                                              underRoot:_root ?: @""
                                             completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
            [fb notificationOccurred:ok ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
            if (cb) cb(ok, msg);
            // Reset button và dismiss nếu thành công
            [self->_applyBtn setTitle:LS(@"▶  ÁP DỤNG", @"▶  APPLY") forState:UIControlStateNormal];
            self->_busy = NO;
            if (ok) [self _dismiss];
        });
    }];
}

- (NSString *)_hex:(UIColor *)c {
    CGFloat r=0, g=0, b=0, a=0; [c getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X",
            (int)(r*255+0.5), (int)(g*255+0.5), (int)(b*255+0.5)];
}

@end

// ─────────────────────────────────────────────────────────────────────────────

@interface HUDFeatureRow : UIView
@property (nonatomic, strong) HUDFeature *feature;
@property (nonatomic, assign) BOOL        isOn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel    *statusDot;
@property (nonatomic, strong) UIButton   *previewButton;
@property (nonatomic, strong) UILabel    *rowTitleLabel;
@property (nonatomic, strong) UILabel    *rowSubtitleLabel;
@property (nonatomic, assign) BOOL        isLoading;
@property (nonatomic, copy)   void (^onChanged)(HUDFeatureRow *row, BOOL isOn);
@property (nonatomic, copy)   void (^onPreviewTapped)(void);
- (instancetype)initWithFeature:(HUDFeature *)feature;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
- (void)setLoading:(BOOL)loading;
- (void)showResult:(BOOL)success;
- (void)setActive:(BOOL)active;
- (void)refreshLanguage;
// collapseInlineColorPicker: no-op compat stub (panel tự dismiss)
- (void)collapseInlineColorPicker;
@end

@implementation HUDFeatureRow {
    UIView *_ledDot;
    UIView *_tileGlow;
    BOOL    _loadingLock;
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

- (void)collapseInlineColorPicker {
    // No-op: DinhViColorPanel tự dismiss khi áp dụng thành công hoặc tap backdrop/✕
}

@end

// ── DinhViNhanVatColorPanel — hologram character locator color picker ─────────
// Tương tự DinhViColorPanel nhưng dành cho preset 4 (nhân vật hologram).
// 3 màu: _TintColor (màu nhân vật), _RimColor (sáng mép), _ScanColor (đường quét).
// 3 alpha slider + 3 switch: xuyên tường, đường quét, nhiễu.

@interface DinhViNhanVatColorPanel : UIView <UIColorPickerViewControllerDelegate>
+ (void)showInViewController:(UIViewController *)vc
                        game:(NSString *)game
                  searchRoot:(NSString *)searchRoot
                  completion:(void(^)(BOOL success, NSString *msg))completion;
@end

@implementation DinhViNhanVatColorPanel {
    NSMutableArray<UIColor *>  *_colors;       // [tint, rim, scan]
    NSMutableArray<UIButton *> *_swatchBtns;
    UISlider  *_tintAlphaSlider;
    UISlider  *_rimAlphaSlider;
    UISlider  *_scanAlphaSlider;
    UILabel   *_tintAlphaLbl;
    UILabel   *_rimAlphaLbl;
    UILabel   *_scanAlphaLbl;
    UISwitch  *_xraySw;
    UISwitch  *_scanLineSw;
    UISwitch  *_glitchSw;
    UIButton  *_applyBtn;
    NSInteger  _editingSlot;

    NSString  *_game;
    NSString  *_root;
    NSString  *_nvFileName;
    __weak UIViewController *_vc;
    void (^_nvCompletion)(BOOL, NSString *);
    BOOL _busy;
}

+ (void)showInViewController:(UIViewController *)vc
                        game:(NSString *)game
                  searchRoot:(NSString *)searchRoot
                  completion:(void(^)(BOOL success, NSString *msg))completion {
    DinhViNhanVatColorPanel *panel = [[DinhViNhanVatColorPanel alloc]
        initWithVC:vc game:game searchRoot:searchRoot completion:completion];
    [panel presentAnimated:YES];
}

- (instancetype)initWithVC:(UIViewController *)vc
                      game:(NSString *)game
                searchRoot:(NSString *)searchRoot
                completion:(void(^)(BOOL, NSString *))completion {
    self = [super initWithFrame:vc.view.bounds];
    if (!self) return nil;
    _vc          = vc;
    _game        = game;
    _root        = searchRoot;
    _nvCompletion = completion;
    // Tên file shader nhân vật trên thiết bị (server sẽ trả file này, IPA tìm theo tên)
    _nvFileName  = [game isEqualToString:@"max"]
        ? @"optionalavatarres_commonab_shader.HPefpCzDMz~2Bho9rxn4EigjXA3~2Fg~3D"
        : @"optionalavatarres_commonab_shader.P6ptn~2F11cB9qve94hciM1I~2Bq0F0~3D";

    _colors = [@[
        [UIColor colorWithRed:0 green:1 blue:1 alpha:1],    // tint: cyan
        [UIColor colorWithRed:0 green:1 blue:1 alpha:1],    // rim: cyan
        [UIColor colorWithRed:0 green:0 blue:0 alpha:1],    // scan: đen
    ] mutableCopy];
    _swatchBtns = [NSMutableArray array];

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self _buildNVUI];
    return self;
}

- (void)_buildNVUI {
    // ── Backdrop dim ──────────────────────────────────────────
    UIView *backdrop = [[UIView alloc] initWithFrame:self.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    [self addSubview:backdrop];
    UITapGestureRecognizer *backdropTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(_nvDismiss)];
    [backdrop addGestureRecognizer:backdropTap];

    // ── Card ──────────────────────────────────────────────────
    UIView *card = [[UIView alloc] init];
    card.backgroundColor    = [UIColor colorWithRed:0.086 green:0.114 blue:0.169 alpha:1];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.layer.borderColor  = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1].CGColor;
    card.layer.borderWidth  = 1;
    CAGradientLayer *topLine = [CAGradientLayer layer];
    topLine.colors = @[(id)[UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:0].CGColor,
                       (id)[UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:0.6].CGColor,
                       (id)[UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:0].CGColor];
    topLine.startPoint = CGPointMake(0, 0.5);
    topLine.endPoint   = CGPointMake(1, 0.5);
    topLine.frame = CGRectMake(40, 0, self.bounds.size.width - 120, 1);
    [card.layer addSublayer:topLine];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:card];

    // ── Header ────────────────────────────────────────────────
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImageView *headerIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"figure.walk.circle.fill" withConfiguration:symCfg]];
    headerIcon.tintColor = [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1];
    headerIcon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *headerLbl = [[UILabel alloc] init];
    headerLbl.text = LS(@"ĐỊNH VỊ NHÂN VẬT", @"CHARACTER LOCATOR");
    headerLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    headerLbl.textColor = [UIColor whiteColor];
    headerLbl.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *xcfg = [UIImageSymbolConfiguration
        configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:xcfg] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
    closeBtn.backgroundColor = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1];
    closeBtn.layer.cornerRadius = 13;
    closeBtn.layer.masksToBounds = YES;
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(_nvDismiss) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[headerIcon, headerLbl]];
    headerRow.axis = UILayoutConstraintAxisHorizontal; headerRow.spacing = 8;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Divider ───────────────────────────────────────────────
    UIView *div = [[UIView alloc] init];
    div.backgroundColor = [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:0.8];
    div.translatesAutoresizingMaskIntoConstraints = NO;

    // ── 3 swatches ────────────────────────────────────────────
    NSArray<NSString *> *swatchLabels = @[
        LS(@"Màu NV", @"Body"), LS(@"Sáng Mép", @"Rim"), LS(@"Đường Quét", @"Scan"),
    ];
    UIColor *cyanColor   = [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1];
    UIColor *greenColor  = [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1];
    UIColor *purpleColor = [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1];
    NSArray<UIColor *> *swatchTints = @[cyanColor, greenColor, purpleColor];

    UIStackView *swatchRow = [[UIStackView alloc] init];
    swatchRow.axis = UILayoutConstraintAxisHorizontal;
    swatchRow.distribution = UIStackViewDistributionFillEqually;
    swatchRow.spacing = 12;
    swatchRow.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSInteger i = 0; i < 3; i++) {
        UIView *col = [[UIView alloc] init]; col.translatesAutoresizingMaskIntoConstraints = NO;
        UIButton *sw = [UIButton buttonWithType:UIButtonTypeCustom];
        sw.backgroundColor = _colors[i]; sw.layer.cornerRadius = 24;
        sw.layer.masksToBounds = YES;
        sw.layer.borderColor = [swatchTints[i] colorWithAlphaComponent:0.7].CGColor;
        sw.layer.borderWidth = 2.5; sw.tag = i;
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        [sw addTarget:self action:@selector(_nvSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
        UIImageSymbolConfiguration *pcfg = [UIImageSymbolConfiguration
            configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        UIImageView *pencil = [[UIImageView alloc]
            initWithImage:[UIImage systemImageNamed:@"pencil" withConfiguration:pcfg]];
        pencil.tintColor = [swatchTints[i] colorWithAlphaComponent:0.9];
        pencil.translatesAutoresizingMaskIntoConstraints = NO;
        [sw addSubview:pencil];
        UILabel *lb = [[UILabel alloc] init]; lb.text = swatchLabels[i];
        lb.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        lb.textColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
        lb.textAlignment = NSTextAlignmentCenter; lb.numberOfLines = 1;
        lb.adjustsFontSizeToFitWidth = YES; lb.minimumScaleFactor = 0.8;
        lb.translatesAutoresizingMaskIntoConstraints = NO;
        [col addSubview:sw]; [col addSubview:pencil]; [col addSubview:lb];
        [_swatchBtns addObject:sw];
        [NSLayoutConstraint activateConstraints:@[
            [sw.topAnchor constraintEqualToAnchor:col.topAnchor],
            [sw.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [sw.widthAnchor constraintEqualToConstant:48], [sw.heightAnchor constraintEqualToConstant:48],
            [pencil.trailingAnchor constraintEqualToAnchor:sw.trailingAnchor constant:-4],
            [pencil.bottomAnchor constraintEqualToAnchor:sw.bottomAnchor constant:-4],
            [lb.topAnchor constraintEqualToAnchor:sw.bottomAnchor constant:6],
            [lb.leadingAnchor constraintEqualToAnchor:col.leadingAnchor],
            [lb.trailingAnchor constraintEqualToAnchor:col.trailingAnchor],
            [col.bottomAnchor constraintEqualToAnchor:lb.bottomAnchor],
        ]];
        [swatchRow addArrangedSubview:col];
    }

    // ── 3 alpha sliders ───────────────────────────────────────
    _tintAlphaLbl    = [self _nvValLbl:@"1.00" color:cyanColor];
    _tintAlphaSlider = [self _nvSlider:1 color:cyanColor   action:@selector(_tintAlphaChanged:)];
    _rimAlphaLbl     = [self _nvValLbl:@"1.00" color:greenColor];
    _rimAlphaSlider  = [self _nvSlider:1 color:greenColor  action:@selector(_rimAlphaChanged:)];
    _scanAlphaLbl    = [self _nvValLbl:@"1.00" color:purpleColor];
    _scanAlphaSlider = [self _nvSlider:1 color:purpleColor action:@selector(_scanAlphaChanged:)];

    UIStackView *tintRow = [self _nvSliderRow:LS(@"Độ đục NV",  @"Body α") sl:_tintAlphaSlider vl:_tintAlphaLbl];
    UIStackView *rimRow  = [self _nvSliderRow:LS(@"Sáng mép α", @"Rim α")  sl:_rimAlphaSlider  vl:_rimAlphaLbl];
    UIStackView *scanRow = [self _nvSliderRow:LS(@"Quét α",     @"Scan α") sl:_scanAlphaSlider vl:_scanAlphaLbl];

    // ── 3 switches ────────────────────────────────────────────
    _xraySw     = [self _nvSwitch:YES];
    _scanLineSw = [self _nvSwitch:NO];
    _glitchSw   = [self _nvSwitch:NO];
    UIStackView *chkRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self _nvChk:LS(@"Xuyên tường", @"Wall Hack") sw:_xraySw],
        [self _nvChk:LS(@"Đường quét",  @"Scan Line") sw:_scanLineSw],
        [self _nvChk:LS(@"Nhiễu",       @"Glitch")    sw:_glitchSw],
    ]];
    chkRow.axis = UILayoutConstraintAxisHorizontal;
    chkRow.distribution = UIStackViewDistributionFillEqually;
    chkRow.spacing = 8;
    chkRow.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Apply button ──────────────────────────────────────────
    _applyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_applyBtn setTitle:LS(@"▶  ÁP DỤNG", @"▶  APPLY") forState:UIControlStateNormal];
    [_applyBtn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1]
                    forState:UIControlStateNormal];
    [_applyBtn setTitleColor:[[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1]
        colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    _applyBtn.titleLabel.font    = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    _applyBtn.layer.cornerRadius = 14;
    _applyBtn.layer.cornerCurve  = kCACornerCurveContinuous;
    _applyBtn.clipsToBounds      = YES;
    _applyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_applyBtn addTarget:self action:@selector(_nvApply) forControlEvents:UIControlEventTouchUpInside];
    {
        CGSize sz = CGSizeMake(320, 48);
        UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
        fmt.scale = 0;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:sz format:fmt];
        UIImage *gradImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            CGContextRef cg = ctx.CGContext;
            NSArray *gColors = @[(__bridge id)cyanColor.CGColor, (__bridge id)greenColor.CGColor];
            CGFloat locs[2] = {0, 1};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)gColors, locs);
            CGContextDrawLinearGradient(cg, grad,
                CGPointMake(0, sz.height/2), CGPointMake(sz.width, sz.height/2), 0);
            CGGradientRelease(grad); CGColorSpaceRelease(cs);
        }];
        [_applyBtn setBackgroundImage:[gradImg resizableImageWithCapInsets:UIEdgeInsetsZero]
                             forState:UIControlStateNormal];
        UIImage *gradDark = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            CGContextRef cg = ctx.CGContext;
            UIColor *c1 = [UIColor colorWithRed:0 green:0.6 blue:0.75 alpha:1];
            UIColor *c2 = [UIColor colorWithRed:0.1 green:0.55 blue:0.22 alpha:1];
            NSArray *gColors = @[(__bridge id)c1.CGColor, (__bridge id)c2.CGColor];
            CGFloat locs[2] = {0, 1};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)gColors, locs);
            CGContextDrawLinearGradient(cg, grad,
                CGPointMake(0, sz.height/2), CGPointMake(sz.width, sz.height/2), 0);
            CGGradientRelease(grad); CGColorSpaceRelease(cs);
        }];
        [_applyBtn setBackgroundImage:[gradDark resizableImageWithCapInsets:UIEdgeInsetsZero]
                             forState:UIControlStateHighlighted];
    }

    // ── Assemble card ─────────────────────────────────────────
    for (UIView *v in @[headerRow, closeBtn, div, swatchRow,
                        tintRow, rimRow, scanRow, chkRow, _applyBtn]) {
        [card addSubview:v];
    }
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:16],
        [card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [card.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-34],

        [headerRow.topAnchor     constraintEqualToAnchor:card.topAnchor    constant:20],
        [headerRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [closeBtn.centerYAnchor  constraintEqualToAnchor:headerRow.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [closeBtn.widthAnchor    constraintEqualToConstant:26],
        [closeBtn.heightAnchor   constraintEqualToConstant:26],

        [div.topAnchor      constraintEqualToAnchor:headerRow.bottomAnchor constant:14],
        [div.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:16],
        [div.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [div.heightAnchor   constraintEqualToConstant:0.5],

        [swatchRow.topAnchor      constraintEqualToAnchor:div.bottomAnchor    constant:20],
        [swatchRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [swatchRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        [tintRow.topAnchor      constraintEqualToAnchor:swatchRow.bottomAnchor constant:18],
        [tintRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [tintRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [rimRow.topAnchor      constraintEqualToAnchor:tintRow.bottomAnchor constant:8],
        [rimRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [rimRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [scanRow.topAnchor     constraintEqualToAnchor:rimRow.bottomAnchor constant:8],
        [scanRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [scanRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        [chkRow.topAnchor      constraintEqualToAnchor:scanRow.bottomAnchor constant:14],
        [chkRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [chkRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        [_applyBtn.topAnchor      constraintEqualToAnchor:chkRow.bottomAnchor constant:18],
        [_applyBtn.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor  constant:20],
        [_applyBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [_applyBtn.heightAnchor   constraintEqualToConstant:48],
        [_applyBtn.bottomAnchor   constraintEqualToAnchor:card.bottomAnchor   constant:-24],
    ]];
}

// ── Helper builders ───────────────────────────────────────────
- (UILabel *)_nvValLbl:(NSString *)text color:(UIColor *)color {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = text;
    lbl.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    lbl.textColor = color; lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [lbl.widthAnchor constraintEqualToConstant:38].active = YES;
    return lbl;
}
- (UISlider *)_nvSlider:(float)val color:(UIColor *)color action:(SEL)action {
    UISlider *sl = [[UISlider alloc] init];
    sl.minimumValue = 0; sl.maximumValue = 1; sl.value = val;
    sl.minimumTrackTintColor = color;
    sl.translatesAutoresizingMaskIntoConstraints = NO;
    [sl addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return sl;
}
- (UISwitch *)_nvSwitch:(BOOL)on {
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = on;
    sw.onTintColor = [UIColor colorWithRed:0 green:0.898 blue:1 alpha:1];
    sw.transform = CGAffineTransformMakeScale(0.72, 0.72);
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    return sw;
}
- (UIView *)_nvChk:(NSString *)text sw:(UISwitch *)sw {
    UILabel *lbl = [[UILabel alloc] init]; lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.adjustsFontSizeToFitWidth = YES; lbl.minimumScaleFactor = 0.75;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:@[sw, lbl]];
    col.axis = UILayoutConstraintAxisVertical; col.alignment = UIStackViewAlignmentCenter;
    col.spacing = 4; col.translatesAutoresizingMaskIntoConstraints = NO;
    return col;
}
- (UIStackView *)_nvSliderRow:(NSString *)label sl:(UISlider *)sl vl:(UILabel *)vl {
    UILabel *lbl = [[UILabel alloc] init]; lbl.text = label;
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [lbl.widthAnchor constraintEqualToConstant:72].active = YES;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[lbl, sl, vl]];
    row.spacing = 10; row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    return row;
}

// ── Animation ─────────────────────────────────────────────────
- (void)presentAnimated:(BOOL)animated {
    UIView *parentView = _vc.view;
    self.frame = parentView.bounds; self.alpha = 0;
    [parentView addSubview:self];
    self.transform = CGAffineTransformMakeTranslation(0, 80);
    if (animated) {
        [UIView animateWithDuration:0.32 delay:0
             usingSpringWithDamping:0.80 initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{ self.alpha = 1; self.transform = CGAffineTransformIdentity; }
                         completion:nil];
    } else {
        self.alpha = 1; self.transform = CGAffineTransformIdentity;
    }
}
- (void)_nvDismiss {
    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{ self.alpha = 0; self.transform = CGAffineTransformMakeTranslation(0, 40); }
                     completion:^(BOOL f) { [self removeFromSuperview]; }];
}

// ── Color picker delegate ─────────────────────────────────────
- (void)_nvSwatchTapped:(UIButton *)btn {
    _editingSlot = btn.tag;
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [UIColorPickerViewController new];
        picker.selectedColor = _colors[_editingSlot];
        picker.supportsAlpha = NO; picker.delegate = self;
        [_vc presentViewController:picker animated:YES completion:nil];
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc API_AVAILABLE(ios(14.0)) {
    [vc dismissViewControllerAnimated:YES completion:nil];
}
- (void)colorPickerViewController:(UIColorPickerViewController *)vc
                   didSelectColor:(UIColor *)color
                     continuously:(BOOL)cont API_AVAILABLE(ios(14.0)) {
    _colors[_editingSlot] = color;
    _swatchBtns[_editingSlot].backgroundColor = color;
}

// ── Slider callbacks ──────────────────────────────────────────
- (void)_tintAlphaChanged:(UISlider *)sl  { _tintAlphaLbl.text  = [NSString stringWithFormat:@"%.2f", sl.value]; }
- (void)_rimAlphaChanged:(UISlider *)sl   { _rimAlphaLbl.text   = [NSString stringWithFormat:@"%.2f", sl.value]; }
- (void)_scanAlphaChanged:(UISlider *)sl  { _scanAlphaLbl.text  = [NSString stringWithFormat:@"%.2f", sl.value]; }

// ── Apply ─────────────────────────────────────────────────────
- (void)_nvApply {
    if (_busy) return;
    _busy = YES;
    [_applyBtn setTitle:LS(@"⏳ Đang tạo...", @"⏳ Generating...") forState:UIControlStateNormal];

    NSDictionary *params = @{
        @"tint_hex"   : [self _nvHex:_colors[0]],
        @"tint_alpha" : [NSString stringWithFormat:@"%.4f", (double)_tintAlphaSlider.value],
        @"rim_hex"    : [self _nvHex:_colors[1]],
        @"rim_alpha"  : [NSString stringWithFormat:@"%.4f", (double)_rimAlphaSlider.value],
        @"scan_hex"   : [self _nvHex:_colors[2]],
        @"scan_alpha" : [NSString stringWithFormat:@"%.4f", (double)_scanAlphaSlider.value],
        @"xray"       : _xraySw.on     ? @"1" : @"0",
        @"scan_line"  : _scanLineSw.on ? @"1" : @"0",
        @"glitch"     : _glitchSw.on   ? @"1" : @"0",
    };

    void (^cb)(BOOL, NSString *) = _nvCompletion;
    NSString *fn = _nvFileName;
    __weak typeof(self) ws = self;
    [[AutoPasteManager sharedManager] pasteCustomDinhViNV:params
                                                     game:_game
                                                fileNamed:fn
                                                underRoot:_root ?: @""
                                               completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
            [fb notificationOccurred:ok ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
            if (cb) cb(ok, msg);
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            [ss->_applyBtn setTitle:LS(@"▶  ÁP DỤNG", @"▶  APPLY") forState:UIControlStateNormal];
            ss->_busy = NO;
            if (ok) [ss _nvDismiss];
        });
    }];
}

- (NSString *)_nvHex:(UIColor *)c {
    CGFloat r=0, g=0, b=0, a=0; [c getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X",
            (int)(r*255+0.5), (int)(g*255+0.5), (int)(b*255+0.5)];
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
@property (nonatomic, strong) UIView  *panelDNS;
@property (nonatomic, strong) UILabel *dnsStatusLabel;
@property (nonatomic, strong) UIButton *dnsToggleButton;
@property (nonatomic, strong) UILabel *panelDinhViTitleLabel;
@property (nonatomic, strong) UILabel *panelModNVTitleLabel;
// Chip bar container + compat stub
@property (nonatomic, strong) UIView    *segmentBar;
@property (nonatomic, assign) NSInteger  pendingThumbTab;  // compat stub; no-op
@property (nonatomic, strong) NSMutableArray<UILabel *> *segLabels;
// Toast
@property (nonatomic, strong) UIView    *toastView;
@property (nonatomic, strong) UILabel   *toastLabel;
@property (nonatomic, strong) UIView    *toastDot;
@property (nonatomic, strong) NSTimer   *toastTimer;
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
    [self buildToast];
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
    // Refresh DNS status mỗi lần HUD hiện lại
    [[DNSBlockManager shared] refreshStatusWithCompletion:^(BOOL installed, BOOL active) {
        [self _updateDNSCardUI:installed active:active];
    }];
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

        // UIStackView vertical: icon + label căn giữa chip
        [iconIV removeFromSuperview];
        [lbl    removeFromSuperview];

        // Wrap icon vào view cố định 14×14 để stackview không stretch nó
        UIView *iconWrap = [[UIView alloc] init];
        iconWrap.translatesAutoresizingMaskIntoConstraints = NO;
        iconWrap.userInteractionEnabled = NO;
        [iconWrap addSubview:iconIV];
        [NSLayoutConstraint activateConstraints:@[
            [iconWrap.widthAnchor   constraintEqualToConstant:14],
            [iconWrap.heightAnchor  constraintEqualToConstant:14],
            [iconIV.centerXAnchor   constraintEqualToAnchor:iconWrap.centerXAnchor],
            [iconIV.centerYAnchor   constraintEqualToAnchor:iconWrap.centerYAnchor],
            [iconIV.widthAnchor     constraintEqualToConstant:14],
            [iconIV.heightAnchor    constraintEqualToConstant:14],
        ]];

        UIStackView *vStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconWrap, lbl]];
        vStack.axis               = UILayoutConstraintAxisVertical;
        vStack.alignment          = UIStackViewAlignmentCenter;
        vStack.spacing            = 4;
        vStack.translatesAutoresizingMaskIntoConstraints = NO;
        vStack.userInteractionEnabled = NO;
        [chip addSubview:vStack];

        [NSLayoutConstraint activateConstraints:@[
            [vStack.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
            [vStack.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
            [vStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:chip.leadingAnchor constant:4],
            [vStack.trailingAnchor constraintLessThanOrEqualToAnchor:chip.trailingAnchor constant:-4],
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
                                     tutorialURL:kTutorialProxyURL
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
                                     tutorialURL:kTutorialDragURL
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
    [panelsStack addArrangedSubview:[self _buildDNSCard]];
    [panelsStack addArrangedSubview:self.panelDinhVi];
    [panelsStack addArrangedSubview:self.panelModNV];
    [panelsStack setCustomSpacing:14 afterView:self.panelProxy];
    [panelsStack setCustomSpacing:10 afterView:self.panelDrag];

    // Fetch aim list + skin list dynamic sau khi UI xong (delay nhỏ tránh block layout)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self _loadDynamicAimPanels];   // rebuild PROXY VIP + VIP V2
        [self _loadDynamicSkinsPanel];  // rebuild MOD NHÂN VẬT
    });

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

// ── Toast notification bar ──────────────────────────────────────────────────
// Hiện phía trên nút MỞ GAME, slide up/down, auto-dismiss 2s.
- (void)buildToast {
    // Outer pill
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor    = [UIColor colorWithRed:0.10 green:0.13 blue:0.20 alpha:0.96];
    toast.layer.cornerRadius = 14;
    toast.layer.cornerCurve  = kCACornerCurveContinuous;
    toast.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    toast.layer.borderWidth  = 1;
    // Shadow
    toast.layer.shadowColor   = [UIColor blackColor].CGColor;
    toast.layer.shadowOpacity = 0.35;
    toast.layer.shadowRadius  = 12;
    toast.layer.shadowOffset  = CGSizeMake(0, 4);
    toast.alpha               = 0;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toast];
    self.toastView = toast;

    // Color dot (thay đổi màu theo loại thông báo)
    UIView *dot = [[UIView alloc] init];
    dot.layer.cornerRadius = 4;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [toast addSubview:dot];
    self.toastDot = dot;

    // Message label
    UILabel *lbl = [[UILabel alloc] init];
    lbl.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    lbl.textColor     = HUD_TEXT;
    lbl.numberOfLines = 2;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [toast addSubview:lbl];
    self.toastLabel = lbl;

    [NSLayoutConstraint activateConstraints:@[
        // Toast nằm phía trên openGameButton 10pt, cùng horizontal inset
        [toast.leadingAnchor   constraintEqualToAnchor:self.view.leadingAnchor  constant:20],
        [toast.trailingAnchor  constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [toast.bottomAnchor    constraintEqualToAnchor:self.openGameButton.topAnchor constant:-10],

        // Dot: left, centered vertical
        [dot.leadingAnchor  constraintEqualToAnchor:toast.leadingAnchor constant:14],
        [dot.centerYAnchor  constraintEqualToAnchor:toast.centerYAnchor],
        [dot.widthAnchor    constraintEqualToConstant:8],
        [dot.heightAnchor   constraintEqualToConstant:8],

        // Label: right of dot, inset top/bottom 12pt
        [lbl.leadingAnchor  constraintEqualToAnchor:dot.trailingAnchor  constant:10],
        [lbl.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-14],
        [lbl.topAnchor      constraintEqualToAnchor:toast.topAnchor     constant:12],
        [lbl.bottomAnchor   constraintEqualToAnchor:toast.bottomAnchor  constant:-12],
    ]];
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
                          badge:(NSString * _Nullable)badge
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

    // Badge pill (AUTO / LIVE / SOON / V2 …)
    UILabel *hint = nil;
    if (badge.length) {
        hint = [[UILabel alloc] init];
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
    }


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
        gridBottomConst  = -10;
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
        [menuTitle.leadingAnchor  constraintEqualToAnchor:icon.trailingAnchor constant:7],
        [menuTitle.trailingAnchor constraintLessThanOrEqualToAnchor:titleBar.trailingAnchor constant:(hint ? -56 : -14)],
        [menuTitle.centerYAnchor  constraintEqualToAnchor:titleBar.centerYAnchor],

    ]];

    // Badge constraint (optional — chỉ khi có badge)
    if (hint) {
        [NSLayoutConstraint activateConstraints:@[
            [hint.trailingAnchor constraintEqualToAnchor:titleBar.trailingAnchor constant:-14],
            [hint.centerYAnchor  constraintEqualToAnchor:titleBar.centerYAnchor],
            [hint.heightAnchor   constraintEqualToConstant:18],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
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
    // panelDrag và panelDNS luôn theo tab Proxy (tab 0)
    self.panelDrag.hidden = NO;
    self.panelDNS.hidden  = NO;

    // Đảm bảo toShow bắt đầu visible (alpha có thể đang 0 nếu mới unhide)
    toShow.hidden = NO;

    [UIView animateWithDuration:0.22 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                               | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        // Fade-in panel cần show
        toShow.alpha = 1.0;
        self.panelDrag.alpha = dragShouldShow ? 1.0 : 0.0;
        self.panelDNS.alpha  = dragShouldShow ? 1.0 : 0.0;
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
    BOOL isMax = [bundleID isEqualToString:@"com.dts.freefiremax"];
    // TH và Max dùng file assetindexer khác nhau
    NSString *assetIdxTH  = @"assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D";
    NSString *assetIdxMax = @"assetindexer.PENojQAQf9a1l6Dzjs0n1Z3rtVU~3D";
    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];
    NSString *fn = supported ? (isMax ? assetIdxMax : assetIdxTH) : nil;
    NSString *rt = supported ? root : nil;
    NSString *(^k)(NSString *) = ^NSString *(NSString *key) { return supported ? key : nil; };

    HUDFeature *drag = [self featureWithSymbol:@"hand.draw.fill" tint:HUD_ORANGE
        title:LS(@"Aim Drag", @"Aim Drag")
        subtitle:LS(@"Kéo Nhẹ Tâm Lên Đỉnh Đầu", @"Soft Pull — Aim Rises to Head")
        featureKey:k(@"drag") fileName:fn searchRoot:rt];
    drag.enTitle    = @"Aim Drag";
    drag.enSubtitle = @"Soft Pull — Aim Rises to Head";

    HUDFeature *coditat = [self featureWithSymbol:@"scope" tint:HUD_ORANGE
        title:LS(@"Proxy Cổ Dị Tật", @"Proxy Neck Abnormal")
        subtitle:LS(@"Tâm Súng Được Ghim Thẳng Vào Cổ", @"Crosshair locked onto the neck")
        featureKey:k(@"coditat") fileName:fn searchRoot:rt];
    coditat.enTitle    = @"Proxy Neck Abnormal";
    coditat.enSubtitle = @"Crosshair locked onto the neck";

    return @[drag, coditat];
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
    dvXanh.exclusive = YES; dvXanh.exclusiveGroup = @"dinhvi";
    dvXanh.enTitle = @"Blue Gun Locator"; dvXanh.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Súng Đen Viền Đỏ — chỉ FF Thường
    HUDFeature *dvDo = [self featureWithSymbol:@"location.fill.viewfinder" tint:HUD_RED
                                         title:@"Định Vị Súng Đen Viền Đỏ" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                    featureKey:kTH(@"dinhvido") fileName:(isTH ? sfTH : nil) searchRoot:rtTH];
    dvDo.exclusive = YES; dvDo.exclusiveGroup = @"dinhvi";
    dvDo.enTitle = @"Black Red-Bordered Gun Locator"; dvDo.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Súng Đỏ — chỉ FF Max
    HUDFeature *dvDoMax = [self featureWithSymbol:@"location.fill.viewfinder" tint:HUD_RED
                                            title:@"Định Vị Súng Đỏ" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                       featureKey:kMax(@"dinhvido") fileName:(isMax ? sfMax : nil) searchRoot:rtMax];
    dvDoMax.exclusive = YES; dvDoMax.exclusiveGroup = @"dinhvi";
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
    dvCustomTH.exclusive        = YES;
    dvCustomTH.exclusiveGroup   = @"dinhvi";
    __weak typeof(self) weakSelf = self;
    dvCustomTH.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        [DinhViColorPanel showInViewController:vc
                                          game:@"th"
                                    searchRoot:rtTH
                                   restoreFile:@"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
                                    completion:^(BOOL success, NSString *msg) {
            [row showResult:success];
            if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
            NSString *status = success
                ? LS(@"✅ Đã Kích Hoạt Định Vị Súng Màu Tự Chọn", @"✅ Custom Color Gun Locator Activated")
                : msg;
            [weakSelf setStatus:status color:(success ? HUD_GREEN : HUD_RED)];
        }];
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
    dvCustomMax.exclusive        = YES;
    dvCustomMax.exclusiveGroup   = @"dinhvi";
    dvCustomMax.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        [DinhViColorPanel showInViewController:vc
                                          game:@"max"
                                    searchRoot:rtMax
                                   restoreFile:@"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D"
                                    completion:^(BOOL success, NSString *msg) {
            [row showResult:success];
            if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
            NSString *status = success
                ? LS(@"✅ Đã Kích Hoạt Định Vị Súng Màu Tự Chọn", @"✅ Custom Color Gun Locator Activated")
                : msg;
            [weakSelf setStatus:status color:(success ? HUD_GREEN : HUD_RED)];
        }];
    };

    // Định Vị Xanh Lá — chỉ FF Thường (folder dinhvihong, file TH)
    HUDFeature *dvXanhLa = [self featureWithSymbol:@"location.fill" tint:HUD_GREEN
                                             title:@"Định Vị Xanh Lá" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                        featureKey:kTH(@"dinhvihong") fileName:(isTH ? sfTH : nil) searchRoot:rtTH];
    dvXanhLa.exclusive = YES; dvXanhLa.exclusiveGroup = @"dinhvi";
    dvXanhLa.enTitle = @"Green Locator"; dvXanhLa.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Hồng — chỉ FF Max (folder dinhvihong, file Max)
    HUDFeature *dvHong = [self featureWithSymbol:@"location.fill" tint:HUD_PINK
                                           title:@"Định Vị Hồng" subtitle:@"Hiện Vị Trí Súng Trên Map"
                                      featureKey:kMax(@"dinhvihong") fileName:(isMax ? sfMax : nil) searchRoot:rtMax];
    dvHong.exclusive = YES; dvHong.exclusiveGroup = @"dinhvi";
    dvHong.enTitle = @"Pink Locator"; dvHong.enSubtitle = @"Show Gun Locations on Map";

    // Định Vị Nhân Vật Màu Tự Chọn — FF Thường
    HUDFeature *dvNVCustomTH = [HUDFeature new];
    dvNVCustomTH.symbol     = @"figure.walk.circle.fill";
    dvNVCustomTH.tint       = HUD_GREEN;
    dvNVCustomTH.title      = @"Định Vị Nhân Vật Tự Chọn";
    dvNVCustomTH.subtitle   = @"Hologram Xuyên Tường Màu Tự Chọn";
    dvNVCustomTH.enTitle    = @"Custom Character Locator";
    dvNVCustomTH.enSubtitle = @"Hologram Wall Hack, Custom Color";
    dvNVCustomTH.featureKey      = kTH(@"dinhvinv_custom");
    dvNVCustomTH.fileName        = nil;
    dvNVCustomTH.searchRoot      = rtTH;
    dvNVCustomTH.exclusive       = YES;
    dvNVCustomTH.exclusiveGroup  = @"dinhvi";
    dvNVCustomTH.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        [DinhViNhanVatColorPanel showInViewController:vc
                                                game:@"th"
                                          searchRoot:rtTH
                                          completion:^(BOOL success, NSString *msg) {
            [row showResult:success];
            if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
            NSString *status = success
                ? LS(@"✅ Đã Kích Hoạt Định Vị Nhân Vật Màu Tự Chọn",
                     @"✅ Custom Color Character Locator Activated")
                : msg;
            [weakSelf setStatus:status color:(success ? HUD_GREEN : HUD_RED)];
        }];
    };

    // Định Vị Nhân Vật Màu Tự Chọn — FF Max
    HUDFeature *dvNVCustomMax = [HUDFeature new];
    dvNVCustomMax.symbol     = @"figure.walk.circle.fill";
    dvNVCustomMax.tint       = HUD_GREEN;
    dvNVCustomMax.title      = @"Định Vị Nhân Vật Tự Chọn";
    dvNVCustomMax.subtitle   = @"Hologram Xuyên Tường Màu Tự Chọn";
    dvNVCustomMax.enTitle    = @"Custom Character Locator";
    dvNVCustomMax.enSubtitle = @"Hologram Wall Hack, Custom Color";
    dvNVCustomMax.featureKey      = kMax(@"dinhvinv_custom");
    dvNVCustomMax.fileName        = nil;
    dvNVCustomMax.searchRoot      = rtMax;
    dvNVCustomMax.exclusive       = YES;
    dvNVCustomMax.exclusiveGroup  = @"dinhvi";
    dvNVCustomMax.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        [DinhViNhanVatColorPanel showInViewController:vc
                                                game:@"max"
                                          searchRoot:rtMax
                                          completion:^(BOOL success, NSString *msg) {
            [row showResult:success];
            if (!success) { [row setOn:NO animated:YES]; [row setActive:NO]; }
            NSString *status = success
                ? LS(@"✅ Đã Kích Hoạt Định Vị Nhân Vật Màu Tự Chọn",
                     @"✅ Custom Color Character Locator Activated")
                : msg;
            [weakSelf setStatus:status color:(success ? HUD_GREEN : HUD_RED)];
        }];
    };

    // ── Tắt Toàn Bộ Định Vị (xóa fileinfo) ──────────────────────
    // Xóa Device Storage/[MHA-C2] App Data/{bundleID}/contentcache/Optional/ios/optionalavatarres/fileinfo
    // → game không còn biết shader nào để load → định vị & mod skin NV tắt hẳn.
    // Tile không phải radio (exclusive=NO), chỉ là action 1 lần → tự về OFF sau khi xong.
    HUDFeature *dvOff = [HUDFeature new];
    dvOff.symbol     = @"xmark.shield.fill";
    dvOff.tint       = HUD_RED;
    dvOff.title      = @"Tắt Định Vị & Mod Skin NV";
    dvOff.subtitle   = @"Khôi Phục Gốc Xoá Định Vị Và ModSkin";
    dvOff.enTitle    = @"Disable All & Skin Mod";
    dvOff.enSubtitle = @"Restore Original — Remove Locator & ModSkin";
    dvOff.featureKey = @"__off__";   // key ảo để configured = YES
    dvOff.fileName   = @"__off__";   // ảo
    dvOff.searchRoot = @"";
    dvOff.exclusive  = NO;
    dvOff.exclusiveGroup = nil;
    // Capture bundleID tại thời điểm build feature list (không capture self để tránh retain cycle)
    NSString *_dvOffBundleID = bundleID;
    dvOff.customAction = ^(HUDFeatureRow *row, HUDControlViewController *vc, NSString *game) {
        // Tìm folder "optionalavatarres" bằng cách duyệt đệ quy từ appDataRoot
        // (giống AutoPasteManager tìm file để paste) rồi xóa "fileinfo" bên trong.
        NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        NSString *appDataRoot = [docs stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", _dvOffBundleID]];

        NSFileManager *fm = [NSFileManager defaultManager];
        __weak HUDControlViewController *weakVC = vc;

        [row setLoading:YES];
        [vc setStatus:LS(@"⏳ Đang tìm và xóa fileinfo...", @"⏳ Searching fileinfo...") color:HUD_MUTED];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Duyệt đệ quy tìm tất cả folder tên "optionalavatarres"
            NSMutableArray<NSString *> *found = [NSMutableArray array];
            NSDirectoryEnumerator *en = [fm enumeratorAtPath:appDataRoot];
            for (NSString *sub in en) {
                // Kiểm tra component cuối là "optionalavatarres"
                if ([[sub lastPathComponent] isEqualToString:@"optionalavatarres"]) {
                    NSString *fullFolder = [appDataRoot stringByAppendingPathComponent:sub];
                    BOOL isDir = NO;
                    if ([fm fileExistsAtPath:fullFolder isDirectory:&isDir] && isDir) {
                        NSString *fi = [fullFolder stringByAppendingPathComponent:@"fileinfo"];
                        if ([fm fileExistsAtPath:fi]) {
                            [found addObject:fi];
                        }
                    }
                }
            }

            NSInteger deleted = 0;
            NSError *lastErr = nil;
            for (NSString *fi in found) {
                NSError *e = nil;
                if ([fm removeItemAtPath:fi error:&e]) {
                    deleted++;
                } else {
                    lastErr = e;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [row setLoading:NO];
                [row setOn:NO animated:YES];
                [row setActive:NO];

                NSString *status;
                BOOL ok;
                if (found.count == 0) {
                    // Không tìm thấy folder optionalavatarres hoặc không có fileinfo
                    ok = NO;
                    status = LS(@"❌ Không Tìm Thấy Hoặc Đã Tắt Từ Trước",
                                @"❌ Not Found Or Already Disabled");
                } else if (deleted > 0) {
                    ok = YES;
                    status = LS(@"✅ Đã Tắt Thành Công — Khởi Động Lại Game",
                                @"✅ Disabled Successfully — Restart Game");
                } else {
                    ok = NO;
                    status = [NSString stringWithFormat:
                        LS(@"❌ Xóa thất bại: %@", @"❌ Delete failed: %@"),
                        lastErr.localizedDescription ?: @"unknown"];
                }

                row.statusDot.text      = ok ? @"✓" : @"✕";
                row.statusDot.textColor = ok ? HUD_GREEN : HUD_RED;
                [weakVC setStatus:status color:(ok ? HUD_GREEN : HUD_RED)];
                UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
                [fb notificationOccurred:ok ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ row.statusDot.text = @""; });
            });
        });
    };

    // Lọc theo game (tránh hiện "Bảo Trì" cho feature sai game)
    NSMutableArray *result = [NSMutableArray array];
    // Nút TẮT luôn ở đầu nếu game được hỗ trợ
    if (supported) [result addObject:dvOff];
    for (HUDFeature *f in @[dvXanh, dvDo, dvDoMax, dvCustomTH, dvCustomMax,
                             dvXanhLa, dvHong, dvNVCustomTH, dvNVCustomMax]) {
        if (f.configured) [result addObject:f];
    }
    return result;
}

// ── Tab 3: Mod Nhân Vật — dynamic từ server ──────────────────
// Trả empty; _loadDynamicSkinsPanel sẽ fetch và rebuild sau khi UI load xong.
- (NSArray<HUDFeature *> *)modNVFeaturesForBundle:(NSString *)bundleID {
    return @[];
}

// Tạo HUDFeature từ 1 dict skin nhận từ server
- (HUDFeature * _Nullable)_buildSkinFeatureFromDict:(NSDictionary *)dict bundleID:(NSString *)bundleID {
    NSString *key      = dict[@"key"];
    NSString *name     = dict[@"name"]      ?: key;
    NSString *symbol   = dict[@"symbol"]    ?: @"person.fill";
    NSString *imgKey   = dict[@"img_key"]   ?: key;
    NSString *fileName = dict[@"file_name"] ?: @"";   // tên file thật trên thiết bị
    BOOL hasFile       = [dict[@"has_file"] boolValue] && fileName.length > 0;

    if (key.length == 0) return nil;

    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    if (!supported) return nil;

    BOOL isMax = [bundleID isEqualToString:@"com.dts.freefiremax"];
    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];

    HUDFeature *f   = [HUDFeature new];
    f.symbol        = symbol;
    f.tint          = HUD_PURPLE;
    f.title         = name;
    f.subtitle      = isMax ? @"Mod Skin Free Fire Max" : @"Mod Skin Free Fire Thường";
    f.enTitle       = name;
    f.enSubtitle    = isMax ? @"Skin — Free Fire Max" : @"Skin — Free Fire";
    f.featureKey    = key;
    // fileName = tên file thật từ server → AutoPasteManager tìm trên thiết bị
    // nil nếu server chưa upload file → tile hiện "Bảo Trì"
    f.fileName      = hasFile ? fileName : nil;
    f.searchRoot    = root;
    f.exclusive     = YES;
    f.exclusiveGroup = @"skin";
    if (imgKey.length) {
        f.previewImageURL = [NSString stringWithFormat:@"https://getuid.vip/skin_previews/%@.jpg", imgKey];
    }
    return f;
}

// Fetch danh sách skin từ server và rebuild panelModNV
- (void)_loadDynamicSkinsPanel {
    if ([KeyManager shared].state != KeyStateActive) return;

    NSString *game = [self.bundleID isEqualToString:@"com.dts.freefiremax"] ? @"max" : @"th";
    __weak typeof(self) weakSelf = self;

    [[AutoPasteManager sharedManager] fetchSkinListForGame:game
                                                completion:^(NSArray<NSDictionary *> *skins, NSString *errorMsg) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (!skins) {
            // Không fetch được — hiện trạng thái lỗi nhẹ
            [self setStatus:errorMsg ?: @"⚠️ Không tải được danh sách skin" color:HUD_MUTED];
            return;
        }

        // Xây HUDFeature từ dữ liệu server
        NSMutableArray<HUDFeature *> *modFeats = [NSMutableArray array];
        for (NSDictionary *dict in skins) {
            HUDFeature *f = [self _buildSkinFeatureFromDict:dict bundleID:self.bundleID];
            if (f) [modFeats addObject:f];
        }

        // Tạo HUDFeatureRow cho từng feature mới
        for (HUDFeature *f in modFeats) {
            // Tránh duplicate nếu đã có
            BOOL exists = NO;
            for (HUDFeatureRow *r in self.rows) {
                if ([r.feature.featureKey isEqualToString:f.featureKey]) { exists = YES; break; }
            }
            if (exists) continue;

            HUDFeatureRow *row = [[HUDFeatureRow alloc] initWithFeature:f];
            row.onChanged = ^(HUDFeatureRow *r, BOOL isOn) { [weakSelf handleRow:r on:isOn]; };
            if (f.previewImageURL.length) {
                NSString *url = f.previewImageURL;
                row.onPreviewTapped = ^{ [weakSelf showPreviewURL:url]; };
            }
            [self.rows addObject:row];
        }

        // Rebuild panelModNV
        UIView *oldPanel = self.panelModNV;
        UIStackView *panelsStack = (UIStackView *)oldPanel.superview;
        if (!panelsStack) return;

        BOOL wasHidden = oldPanel.isHidden;
        NSUInteger idx = [[panelsStack arrangedSubviews] indexOfObject:oldPanel];

        UILabel *newTitleLabel = nil;
        UIView *newPanel = [self buildPanelWithTitle:LS(@"MOD NHÂN VẬT", @"CHARACTER MOD")
                                              symbol:@"person.fill.badge.plus"
                                                tint:HUD_PURPLE
                                               badge:@"SOON"
                                            features:modFeats
                                         tutorialURL:nil
                                      outTitleLabel:&newTitleLabel];
        newPanel.hidden = wasHidden;
        newPanel.alpha  = wasHidden ? 0.0 : 1.0;

        if (idx != NSNotFound) {
            [panelsStack insertArrangedSubview:newPanel atIndex:idx];
        } else {
            [panelsStack addArrangedSubview:newPanel];
        }
        [panelsStack removeArrangedSubview:oldPanel];
        [oldPanel removeFromSuperview];

        self.panelModNV          = newPanel;
        self.panelModNVTitleLabel = newTitleLabel;

        // Update tabFeatures
        NSMutableArray *tabs = [self.tabFeatures mutableCopy];
        if (tabs.count >= 3) tabs[2] = modFeats;
        self.tabFeatures = tabs;

        // Nếu tab Mod NV đang active thì fade in panel mới
        if (self.activeTab == 2 && !modFeats.count) {
            [self setStatus:LS(@"Chưa có skin nào được kích hoạt", @"No skins available yet") color:HUD_MUTED];
        }
    }];
}


#pragma mark - Dynamic Aim Panels (config-driven từ server)

// Map tên tint string từ JSON → UIColor
static UIColor *_aimTintFromString(NSString *tint) {
    if ([tint isEqualToString:@"orange"]) return [UIColor colorWithRed:1.000 green:0.400 blue:0.122 alpha:1.0];
    if ([tint isEqualToString:@"pink"])   return [UIColor colorWithRed:1.000 green:0.216 blue:0.502 alpha:1.0];
    if ([tint isEqualToString:@"purple"]) return [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1.0];
    if ([tint isEqualToString:@"green"])  return [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1.0];
    if ([tint isEqualToString:@"red"])    return [UIColor colorWithRed:1.000 green:0.271 blue:0.227 alpha:1.0];
    if ([tint isEqualToString:@"yellow"]) return [UIColor colorWithRed:1.000 green:0.780 blue:0.250 alpha:1.0];
    return [UIColor colorWithRed:0.000 green:0.898 blue:1.000 alpha:1.0]; // cyan (default)
}

// Xây HUDFeature từ 1 dict aim nhận từ server
- (HUDFeature * _Nullable)_buildAimFeatureFromDict:(NSDictionary *)dict bundleID:(NSString *)bundleID {
    NSString *key       = dict[@"key"];
    if (key.length == 0) return nil;
    if ([key isEqualToString:@"_meta"]) return nil;  // entry metadata, không phải aim

    BOOL supported = [bundleID isEqualToString:@"com.dts.freefireth"] ||
                     [bundleID isEqualToString:@"com.dts.freefiremax"];
    if (!supported) return nil;

    BOOL isMax  = [bundleID isEqualToString:@"com.dts.freefiremax"];
    BOOL enabled = [dict[@"enabled"] boolValue];

    // Ưu tiên đọc file_th/file_max từ server response (aims_config.json)
    // Fallback về hardcode nếu server chưa cung cấp field này
    NSString *fileFromServer = isMax ? dict[@"file_max"] : dict[@"file_th"];
    NSString *fileName;
    if ([fileFromServer isKindOfClass:[NSString class]] && fileFromServer.length) {
        fileName = fileFromServer;
    } else {
        // Fallback hardcode (tương thích server cũ chưa có file_th/file_max)
        NSString *cacheRes    = @"cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";
        NSString *assetIdxTH  = @"assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D";
        NSString *assetIdxMax = @"assetindexer.PENojQAQf9a1l6Dzjs0n1Z3rtVU~3D";
        NSString *panel = dict[@"panel"] ?: @"vip";
        if ([panel isEqualToString:@"vip2"]) {
            fileName = isMax ? assetIdxMax : assetIdxTH;
        } else {
            fileName = cacheRes;
        }
    }

    NSString *root = [NSString stringWithFormat:@"Device Storage/[MHA-C2] App Data/%@", bundleID];

    HUDFeature *f    = [HUDFeature new];
    f.symbol         = dict[@"symbol"] ?: @"scope";
    f.tint           = _aimTintFromString(dict[@"tint"]);
    f.title          = dict[@"name"]        ?: key;
    f.subtitle       = dict[@"subtitle"]    ?: @"";
    f.enTitle        = dict[@"name_en"]     ?: f.title;
    f.enSubtitle     = dict[@"subtitle_en"] ?: f.subtitle;
    f.featureKey     = key;
    f.fileName       = enabled ? fileName : nil;  // nil → hiện "Bảo Trì"
    f.searchRoot     = root;
    f.exclusive      = YES;
    f.exclusiveGroup = @"aim";
    return f;
}

// Fetch aim list và rebuild cả 2 panel VIP + VIP V2
- (void)_loadDynamicAimPanels {
    if ([KeyManager shared].state != KeyStateActive) return;

    NSString *game = [self.bundleID isEqualToString:@"com.dts.freefiremax"] ? @"max" : @"th";
    __weak typeof(self) weakSelf = self;

    [[AutoPasteManager sharedManager] fetchAimListForGame:game
                                               completion:^(NSArray<NSDictionary *> *aims, NSString *errorMsg) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !aims) return;  // lỗi network — giữ nguyên panel cũ (hardcoded)

        // Video URLs từ server (key "video_vip"/"video_vip2" nằm trong aims[0] metadata
        // được truyền qua fetchAimListForGame: dưới dạng entry đặc biệt key="_meta")
        NSString *tutVip  = kTutorialProxyURL;
        NSString *tutVip2 = kTutorialDragURL;
        for (NSDictionary *d in aims) {
            if ([@"_meta" isEqualToString:d[@"key"]]) {
                NSString *vv  = d[@"video_vip"];
                NSString *vv2 = d[@"video_vip2"];
                if ([vv  isKindOfClass:[NSString class]] && vv.length)  tutVip  = vv;
                if ([vv2 isKindOfClass:[NSString class]] && vv2.length) tutVip2 = vv2;
                break;
            }
        }

        // Phân loại vip vs vip2
        NSMutableArray<HUDFeature *> *vipFeats  = [NSMutableArray array];
        NSMutableArray<HUDFeature *> *vip2Feats = [NSMutableArray array];

        for (NSDictionary *dict in aims) {
            HUDFeature *f = [self _buildAimFeatureFromDict:dict bundleID:self.bundleID];
            if (!f) continue;
            NSString *panel = dict[@"panel"] ?: @"vip";
            if ([panel isEqualToString:@"vip2"]) {
                [vip2Feats addObject:f];
            } else {
                [vipFeats addObject:f];
            }
            // Đăng ký row nếu chưa có
            BOOL exists = NO;
            for (HUDFeatureRow *r in self.rows) {
                if ([r.feature.featureKey isEqualToString:f.featureKey]) { exists = YES; break; }
            }
            if (!exists) {
                HUDFeatureRow *row = [[HUDFeatureRow alloc] initWithFeature:f];
                row.onChanged = ^(HUDFeatureRow *r, BOOL isOn) { [weakSelf handleRow:r on:isOn]; };
                [self.rows addObject:row];
            } else {
                // Cập nhật feature (enabled/title có thể thay đổi) trên row đã có
                for (HUDFeatureRow *r in self.rows) {
                    if ([r.feature.featureKey isEqualToString:f.featureKey]) {
                        r.feature.fileName  = f.fileName;
                        r.feature.title     = f.title;
                        r.feature.subtitle  = f.subtitle;
                        r.feature.enTitle   = f.enTitle;
                        r.feature.enSubtitle = f.enSubtitle;
                        [r refreshLanguage];
                        break;
                    }
                }
            }
        }

        UIStackView *panelsStack = (UIStackView *)self.panelProxy.superview;
        if (!panelsStack) return;

        // Rebuild panelProxy (VIP)
        if (vipFeats.count > 0) {
            UIView *old = self.panelProxy;
            NSUInteger idx = [[panelsStack arrangedSubviews] indexOfObject:old];
            UIView *newPanel = [self buildPanelWithTitle:@"PROXY DELTA VIP"
                                                  symbol:@"bolt.fill" tint:HUD_CYAN badge:@"AUTO"
                                                features:vipFeats
                                             tutorialURL:tutVip ?: @""
                                          outTitleLabel:nil];
            newPanel.hidden = old.isHidden;
            newPanel.alpha  = old.isHidden ? 0.0 : 1.0;
            if (idx != NSNotFound) [panelsStack insertArrangedSubview:newPanel atIndex:idx];
            else [panelsStack addArrangedSubview:newPanel];
            [panelsStack removeArrangedSubview:old]; [old removeFromSuperview];
            self.panelProxy = newPanel;
            [panelsStack setCustomSpacing:14 afterView:newPanel];

            // Cập nhật tabFeatures[0]
            NSMutableArray *tabs = [self.tabFeatures mutableCopy];
            if (tabs.count >= 1) tabs[0] = vipFeats;
            self.tabFeatures = tabs;
        }

        // Rebuild panelDrag (VIP V2)
        if (vip2Feats.count > 0) {
            UIView *old = self.panelDrag;
            NSUInteger idx = [[panelsStack arrangedSubviews] indexOfObject:old];
            UIView *newPanel = [self buildPanelWithTitle:@"PROXY DELTA VIP V2"
                                                  symbol:@"hand.draw.fill" tint:HUD_ORANGE badge:@"V2"
                                                features:vip2Feats
                                             tutorialURL:tutVip2 ?: @""
                                          outTitleLabel:nil];
            newPanel.hidden = old.isHidden;
            newPanel.alpha  = old.isHidden ? 0.0 : 1.0;
            if (idx != NSNotFound) [panelsStack insertArrangedSubview:newPanel atIndex:idx];
            else [panelsStack addArrangedSubview:newPanel];
            [panelsStack setCustomSpacing:14 afterView:newPanel];
            [panelsStack removeArrangedSubview:old]; [old removeFromSuperview];
            self.panelDrag = newPanel;
        }
    }];
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
            [row collapseInlineColorPicker];  // đóng expand nếu đang mở
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
    // Cập nhật statusLabel ở scroll (vẫn giữ làm source of truth)
    self.statusLabel.textColor = color;
    self.statusLabel.text      = text;

    // ── Toast overlay ────────────────────────────────────────
    if (!self.toastView) return;

    // Cancel timer cũ nếu đang đếm
    [self.toastTimer invalidate];
    self.toastTimer = nil;

    // Cập nhật nội dung
    self.toastLabel.text        = text;
    self.toastDot.backgroundColor = color;

    // Border màu nhẹ theo loại thông báo
    self.toastView.layer.borderColor = [color colorWithAlphaComponent:0.25].CGColor;

    // Slide up + fade in (từ trạng thái hiện tại để handle rapid calls)
    self.toastView.transform = CGAffineTransformMakeTranslation(0, 12);
    [UIView animateWithDuration:0.28
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.toastView.alpha     = 1.0;
        self.toastView.transform = CGAffineTransformIdentity;
    } completion:nil];

    // Auto-dismiss sau 2.2s
    __weak typeof(self) weakSelf = self;
    self.toastTimer = [NSTimer scheduledTimerWithTimeInterval:2.2
                                                      target:weakSelf
                                                    selector:@selector(dismissToast)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)dismissToast {
    [UIView animateWithDuration:0.22 delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.toastView.alpha     = 0;
        self.toastView.transform = CGAffineTransformMakeTranslation(0, 8);
    } completion:^(BOOL f) {
        self.toastView.transform = CGAffineTransformIdentity;
    }];
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ── DNS Block Card ─────────────────────────────────────────────────────────────

- (UIView *)_buildDNSCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve  = kCACornerCurveContinuous;
    card.backgroundColor    = [UIColor colorWithRed:0.07 green:0.10 blue:0.18 alpha:1.0];
    card.layer.borderColor  = HUD_BORDER.CGColor;
    card.layer.borderWidth  = 1;
    self.panelDNS = card;

    // Status dot + label top
    UIView *dotView = [[UIView alloc] init];
    dotView.translatesAutoresizingMaskIntoConstraints = NO;
    dotView.backgroundColor = HUD_MUTED;
    dotView.layer.cornerRadius = 4;
    [card addSubview:dotView];

    self.dnsStatusLabel = [[UILabel alloc] init];
    self.dnsStatusLabel.text      = LS(@"Đang dùng DNS mặc định", @"Using default DNS");
    self.dnsStatusLabel.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.dnsStatusLabel.textColor = HUD_MUTED;
    self.dnsStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.dnsStatusLabel];

    // Separator
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = HUD_BORDER;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:sep];

    // Icon
    UIView *iconBg = [[UIView alloc] init];
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    iconBg.layer.cornerRadius = 12;
    iconBg.layer.cornerCurve  = kCACornerCurveContinuous;
    iconBg.backgroundColor    = [UIColor colorWithRed:0.04 green:0.56 blue:0.78 alpha:0.18];
    [card addSubview:iconBg];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold];
    UIImageView *iconImg = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shield.lefthalf.filled" withConfiguration:symCfg]];
    iconImg.tintColor   = HUD_CYAN;
    iconImg.contentMode = UIViewContentModeScaleAspectFit;
    iconImg.translatesAutoresizingMaskIntoConstraints = NO;
    [iconBg addSubview:iconImg];

    // Title + subtitle
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text      = LS(@"Chặn Quảng Cáo & Tracker", @"Block Ads & Trackers");
    titleLbl.font      = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    titleLbl.textColor = HUD_TEXT;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.text      = @"DNS NextDNS · Chống Game Quét";
    subLbl.font      = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    subLbl.textColor = HUD_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:subLbl];

    // DoH badge
    UILabel *badge = [[UILabel alloc] init];
    badge.text            = @"DNS-over-HTTPS";
    badge.font            = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    badge.textColor       = HUD_CYAN;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:badge];

    // Toggle button
    self.dnsToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dnsToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dnsToggleButton.layer.cornerRadius = 14;
    self.dnsToggleButton.layer.cornerCurve  = kCACornerCurveContinuous;
    self.dnsToggleButton.clipsToBounds      = YES;
    [self.dnsToggleButton addTarget:self action:@selector(_dnsToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.dnsToggleButton];

    // Button gradient layer
    CAGradientLayer *btnGrad = [CAGradientLayer layer];
    btnGrad.colors     = @[(id)[UIColor colorWithRed:0.06 green:0.58 blue:0.78 alpha:1].CGColor,
                           (id)[UIColor colorWithRed:0.04 green:0.36 blue:0.56 alpha:1].CGColor];
    btnGrad.startPoint = CGPointMake(0, 0);
    btnGrad.endPoint   = CGPointMake(1, 1);
    btnGrad.cornerRadius = 14;
    btnGrad.name       = @"dnsGrad";
    [self.dnsToggleButton.layer insertSublayer:btnGrad atIndex:0];

    UIImageSymbolConfiguration *btnSym = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
    UIImageView *btnIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"power" withConfiguration:btnSym]];
    btnIcon.tintColor   = [UIColor whiteColor];
    btnIcon.contentMode = UIViewContentModeScaleAspectFit;
    btnIcon.translatesAutoresizingMaskIntoConstraints = NO;
    btnIcon.tag = 991;
    [self.dnsToggleButton addSubview:btnIcon];

    UILabel *btnLbl = [[UILabel alloc] init];
    btnLbl.text      = LS(@"Bật", @"Enable");
    btnLbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    btnLbl.textColor = [UIColor whiteColor];
    btnLbl.translatesAutoresizingMaskIntoConstraints = NO;
    btnLbl.tag = 992;
    [self.dnsToggleButton addSubview:btnLbl];

    [NSLayoutConstraint activateConstraints:@[
        // Status top row
        [dotView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [dotView.centerYAnchor constraintEqualToAnchor:self.dnsStatusLabel.centerYAnchor],
        [dotView.widthAnchor  constraintEqualToConstant:8],
        [dotView.heightAnchor constraintEqualToConstant:8],

        [self.dnsStatusLabel.topAnchor    constraintEqualToAnchor:card.topAnchor constant:12],
        [self.dnsStatusLabel.leadingAnchor constraintEqualToAnchor:dotView.trailingAnchor constant:8],

        // Separator
        [sep.topAnchor     constraintEqualToAnchor:self.dnsStatusLabel.bottomAnchor constant:10],
        [sep.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [sep.heightAnchor  constraintEqualToConstant:0.5],

        // Icon
        [iconBg.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [iconBg.topAnchor     constraintEqualToAnchor:sep.bottomAnchor   constant:14],
        [iconBg.widthAnchor   constraintEqualToConstant:48],
        [iconBg.heightAnchor  constraintEqualToConstant:48],
        [iconBg.bottomAnchor  constraintEqualToAnchor:card.bottomAnchor  constant:-14],

        [iconImg.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [iconImg.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],

        // Title + sub
        [titleLbl.leadingAnchor constraintEqualToAnchor:iconBg.trailingAnchor constant:12],
        [titleLbl.topAnchor     constraintEqualToAnchor:iconBg.topAnchor      constant:2],

        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.topAnchor     constraintEqualToAnchor:titleLbl.bottomAnchor   constant:3],

        [badge.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [badge.topAnchor     constraintEqualToAnchor:subLbl.bottomAnchor      constant:4],

        // Toggle button
        [self.dnsToggleButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [self.dnsToggleButton.centerYAnchor  constraintEqualToAnchor:iconBg.centerYAnchor],
        [self.dnsToggleButton.widthAnchor    constraintEqualToConstant:72],
        [self.dnsToggleButton.heightAnchor   constraintEqualToConstant:44],

        [btnIcon.centerXAnchor constraintEqualToAnchor:self.dnsToggleButton.centerXAnchor constant:-18],
        [btnIcon.centerYAnchor constraintEqualToAnchor:self.dnsToggleButton.centerYAnchor],

        [btnLbl.leadingAnchor  constraintEqualToAnchor:btnIcon.trailingAnchor constant:5],
        [btnLbl.centerYAnchor  constraintEqualToAnchor:self.dnsToggleButton.centerYAnchor],
    ]];

    // Load trạng thái DNS
    [[DNSBlockManager shared] refreshStatusWithCompletion:^(BOOL installed, BOOL active) {
        [self _updateDNSCardUI:installed active:active];
    }];

    return card;
}

- (void)_updateDNSCardUI:(BOOL)installed active:(BOOL)active {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *btnLbl  = (UILabel  *)[self.dnsToggleButton viewWithTag:992];
        UIImageView *btnIcon = (UIImageView *)[self.dnsToggleButton viewWithTag:991];
        CAGradientLayer *grad = nil;
        for (CALayer *l in self.dnsToggleButton.layer.sublayers) {
            if ([l.name isEqualToString:@"dnsGrad"]) { grad = (CAGradientLayer *)l; break; }
        }

        if (active) {
            self.dnsStatusLabel.text      = LS(@"● Đang chặn quảng cáo", @"● Blocking ads & trackers");
            self.dnsStatusLabel.textColor = HUD_CYAN;
            btnLbl.text  = LS(@"Tắt", @"Off");
            btnIcon.image = [UIImage systemImageNamed:@"power" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]];
            grad.colors = @[(id)[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1].CGColor,
                            (id)[UIColor colorWithRed:0.5 green:0.1 blue:0.1 alpha:1].CGColor];
        } else if (installed) {
            self.dnsStatusLabel.text      = LS(@"Đã cài · Chọn trong Cài Đặt > DNS", @"Installed · Select in Settings > DNS");
            self.dnsStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.0 alpha:1.0];
            btnLbl.text  = LS(@"Bật", @"Enable");
            btnIcon.image = [UIImage systemImageNamed:@"power" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]];
            grad.colors = @[(id)[UIColor colorWithRed:0.06 green:0.58 blue:0.78 alpha:1].CGColor,
                            (id)[UIColor colorWithRed:0.04 green:0.36 blue:0.56 alpha:1].CGColor];
        } else {
            self.dnsStatusLabel.text      = LS(@"Đang dùng DNS mặc định", @"Using default DNS");
            self.dnsStatusLabel.textColor = HUD_MUTED;
            btnLbl.text  = LS(@"Bật", @"Enable");
            btnIcon.image = [UIImage systemImageNamed:@"power" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]];
            grad.colors = @[(id)[UIColor colorWithRed:0.06 green:0.58 blue:0.78 alpha:1].CGColor,
                            (id)[UIColor colorWithRed:0.04 green:0.36 blue:0.56 alpha:1].CGColor];
        }
        // Update gradient frame
        grad.frame = self.dnsToggleButton.bounds;
    });
}

- (void)_dnsToggleTapped {
    self.dnsToggleButton.enabled = NO;
    BOOL currentlyActive = [DNSBlockManager shared].isEnabled;

    if (currentlyActive) {
        // Tắt
        [[DNSBlockManager shared] disableWithCompletion:^(BOOL success, NSError *err) {
            self.dnsToggleButton.enabled = YES;
            [self _updateDNSCardUI:NO active:NO];
        }];
    } else {
        // Bật — cài profile rồi hướng dẫn
        [[DNSBlockManager shared] enableWithCompletion:^(BOOL success, NSError *err) {
            self.dnsToggleButton.enabled = YES;
            if (success) {
                [self _updateDNSCardUI:YES active:NO];
                // Alert hướng dẫn
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:LS(@"✅ Profile Đã Cài", @"✅ Profile Installed")
                    message:LS(
                        @"Vào:\nCài Đặt → Chung → VPN & Quản Lý Thiết Bị → DNS\n\nChọn \"Delta Proxy — DNS Filter\" để bật.",
                        @"Go to:\nSettings → General → VPN & Device Management → DNS\n\nSelect \"Delta Proxy — DNS Filter\" to enable.")
                    preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction
                    actionWithTitle:LS(@"Mở Cài Đặt", @"Open Settings")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *a) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                            options:@{} completionHandler:nil];
                    }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                NSString *msg = err.localizedDescription ?: LS(@"Không thể cài DNS.", @"Could not install DNS.");
                UIAlertController *errAlert = [UIAlertController
                    alertControllerWithTitle:LS(@"Lỗi DNS", @"DNS Error")
                    message:msg preferredStyle:UIAlertControllerStyleAlert];
                [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errAlert animated:YES completion:nil];
            }
        }];
    }
}

@end
