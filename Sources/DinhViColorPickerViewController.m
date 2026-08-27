//
//  DinhViColorPickerViewController.m
//  IMGUIDELTA — Tactical Matrix Grid edition
//
//  Present dạng bottom sheet (UISheetPresentationController, iOS 15+).
//  Palette đồng bộ với HUDControlViewController.
//

#import "DinhViColorPickerViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "Endpoints.h"
#import "LanguageManager.h"
#import "SecurityPinning.h"

// ── Palette (mirror HUDControlViewController) ─────────────────────────────────
#define DV_BG       [UIColor colorWithRed:0.051 green:0.067 blue:0.102 alpha:1.0]  // #0D111A
#define DV_CARD     [UIColor colorWithRed:0.086 green:0.114 blue:0.169 alpha:1.0]  // #161D2B
#define DV_CARD2    [UIColor colorWithRed:0.110 green:0.149 blue:0.220 alpha:1.0]  // #1C2638
#define DV_BORDER   [UIColor colorWithRed:0.137 green:0.180 blue:0.259 alpha:1.0]  // #232E42
#define DV_CYAN     [UIColor colorWithRed:0.000 green:0.898 blue:1.000 alpha:1.0]  // #00E5FF
#define DV_GREEN    [UIColor colorWithRed:0.188 green:0.820 blue:0.345 alpha:1.0]  // #30D158
#define DV_PURPLE   [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1.0]  // #BF5AF2
#define DV_INK      [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:1.0]
#define DV_MUTED    [UIColor colorWithRed:0.486 green:0.545 blue:0.631 alpha:1.0]  // #7C8BA1

// ── Màu mặc định ──────────────────────────────────────────────────────────────
static UIColor *kDefaultXray = nil;
static UIColor *kDefaultLine = nil;
static UIColor *kDefaultDim  = nil;
static const CGFloat kDefaultWidth     = 4.0f;
static const CGFloat kDefaultXrayAlpha = 1.0f;

typedef NS_ENUM(NSInteger, DVSlot) { DVSlotXray = 0, DVSlotLine, DVSlotDim, DVSlotCount };

// ─────────────────────────────────────────────────────────────────────────────
@interface DinhViColorPickerViewController () <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray<UIColor *> *colors;
@property (nonatomic, assign) CGFloat xrayAlpha;
@property (nonatomic, assign) CGFloat lineWidth;

@property (nonatomic, strong) NSMutableArray<UIButton *> *swatches;
@property (nonatomic, strong) UISlider  *alphaSlider;
@property (nonatomic, strong) UISlider  *widthSlider;
@property (nonatomic, strong) UILabel   *alphaValueLabel;
@property (nonatomic, strong) UILabel   *widthValueLabel;
@property (nonatomic, strong) UIButton  *applyButton;
@property (nonatomic, strong) CAGradientLayer *applyGradient;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView    *previewCard;

@property (nonatomic, assign) DVSlot editingSlot;
@end

// ─────────────────────────────────────────────────────────────────────────────
@implementation DinhViColorPickerViewController

+ (void)initialize {
    if (self == [DinhViColorPickerViewController class]) {
        kDefaultXray = [UIColor colorWithRed:0.067 green:0.067 blue:0.067 alpha:1.0];
        kDefaultLine = [UIColor whiteColor];
        kDefaultDim  = [UIColor colorWithRed:0.067 green:0.067 blue:0.067 alpha:1.0];
    }
}

+ (instancetype)pickerForGame:(NSString *)game
                   searchRoot:(NSString *)searchRoot
                   completion:(DinhViColorCompletion)completion {
    DinhViColorPickerViewController *vc = [self new];
    vc.game       = game;
    vc.searchRoot = searchRoot;
    vc.completion = completion;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _colors    = [@[kDefaultXray, kDefaultLine, kDefaultDim] mutableCopy];
    _xrayAlpha = kDefaultXrayAlpha;
    _lineWidth  = kDefaultWidth;
    _swatches   = [NSMutableArray array];

    self.view.backgroundColor = DV_BG;

    [self _buildUI];
}

// ─── Bottom sheet detents (iOS 15+) ──────────────────────────────────────────
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent],
            ];
            sheet.prefersGrabberVisible         = YES;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
            sheet.preferredCornerRadius          = 24;
        }
    }
}

// ─── Build UI ─────────────────────────────────────────────────────────────────
- (void)_buildUI {
    // ── Drag handle (manual, iOS 14 compat) ──────────────────────────────────
    UIView *handle = [UIView new];
    handle.backgroundColor    = [DV_MUTED colorWithAlphaComponent:0.45];
    handle.layer.cornerRadius = 2.5;
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:handle];

    // ── Header row: icon + title + close ─────────────────────────────────────
    UIView *headerRow = [UIView new];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:headerRow];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
    UIImageView *headerIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"paintpalette.fill" withConfiguration:symCfg]];
    headerIcon.tintColor   = DV_CYAN;
    headerIcon.contentMode = UIViewContentModeScaleAspectFit;
    headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [headerRow addSubview:headerIcon];

    UILabel *titleLbl = [UILabel new];
    titleLbl.text      = LS(@"Định Vị Súng Màu Tự Chọn", @"Custom Color");
    titleLbl.font      = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    titleLbl.textColor = DV_INK;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [headerRow addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImageSymbolConfiguration *closeCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:closeCfg]
              forState:UIControlStateNormal];
    closeBtn.tintColor       = DV_MUTED;
    closeBtn.backgroundColor = [DV_BORDER colorWithAlphaComponent:0.6];
    closeBtn.layer.cornerRadius = 13;
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(_close) forControlEvents:UIControlEventTouchUpInside];
    [headerRow addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [headerIcon.leadingAnchor constraintEqualToAnchor:headerRow.leadingAnchor],
        [headerIcon.centerYAnchor constraintEqualToAnchor:headerRow.centerYAnchor],
        [headerIcon.widthAnchor   constraintEqualToConstant:20],
        [headerIcon.heightAnchor  constraintEqualToConstant:20],
        [titleLbl.leadingAnchor   constraintEqualToAnchor:headerIcon.trailingAnchor constant:10],
        [titleLbl.centerYAnchor   constraintEqualToAnchor:headerRow.centerYAnchor],
        [closeBtn.trailingAnchor  constraintEqualToAnchor:headerRow.trailingAnchor],
        [closeBtn.centerYAnchor   constraintEqualToAnchor:headerRow.centerYAnchor],
        [closeBtn.widthAnchor     constraintEqualToConstant:26],
        [closeBtn.heightAnchor    constraintEqualToConstant:26],
        [headerRow.heightAnchor   constraintEqualToConstant:44],
    ]];

    // ── Scroll content ────────────────────────────────────────────────────────
    UIScrollView *scroll = [UIScrollView new];
    scroll.showsVerticalScrollIndicator = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    // ── Apply button (sticky bottom, outside scroll) ──────────────────────────
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [applyBtn setTitle:LS(@"Áp Dụng Màu", @"Apply Colors") forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0]
                  forState:UIControlStateNormal];
    [applyBtn setTitleColor:[[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0]
                             colorWithAlphaComponent:0.4] forState:UIControlStateDisabled];
    applyBtn.titleLabel.font   = [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy];
    applyBtn.layer.cornerRadius = 16;
    applyBtn.layer.cornerCurve  = kCACornerCurveContinuous;
    applyBtn.clipsToBounds      = YES;
    applyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [applyBtn addTarget:self action:@selector(_apply) forControlEvents:UIControlEventTouchUpInside];
    self.applyButton = applyBtn;

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors      = @[(id)DV_PURPLE.CGColor, (id)DV_CYAN.CGColor];
    grad.startPoint  = CGPointMake(0, 0.5);
    grad.endPoint    = CGPointMake(1, 0.5);
    grad.cornerRadius = 16;
    [applyBtn.layer insertSublayer:grad atIndex:0];
    self.applyGradient = grad;

    if (@available(iOS 13, *))
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    else
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _spinner.color = [UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    _spinner.hidesWhenStopped = YES;
    [applyBtn addSubview:_spinner];

    [self.view addSubview:applyBtn];

    // ── Root layout constraints ───────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        // Drag handle
        [handle.topAnchor    constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.widthAnchor  constraintEqualToConstant:36],
        [handle.heightAnchor constraintEqualToConstant:5],

        // Header
        [headerRow.topAnchor    constraintEqualToAnchor:handle.bottomAnchor constant:10],
        [headerRow.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor  constant:20],
        [headerRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // Scroll
        [scroll.topAnchor    constraintEqualToAnchor:headerRow.bottomAnchor constant:12],
        [scroll.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:applyBtn.topAnchor constant:-12],

        // Content in scroll
        [content.topAnchor    constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.leadingAnchor  constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor  constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],

        // Apply button
        [applyBtn.leadingAnchor   constraintEqualToAnchor:self.view.leadingAnchor  constant:20],
        [applyBtn.trailingAnchor  constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [applyBtn.bottomAnchor    constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [applyBtn.heightAnchor    constraintEqualToConstant:54],

        [_spinner.centerYAnchor constraintEqualToAnchor:applyBtn.centerYAnchor],
        [_spinner.trailingAnchor constraintEqualToAnchor:applyBtn.trailingAnchor constant:-16],
    ]];

    // ── Build scroll content ──────────────────────────────────────────────────
    [self _buildScrollContent:content];
}

- (void)_buildScrollContent:(UIView *)content {
    UIStackView *root = [UIStackView new];
    root.axis      = UILayoutConstraintAxisVertical;
    root.spacing   = 12;
    root.layoutMargins = UIEdgeInsetsMake(0, 16, 20, 16);
    root.layoutMarginsRelativeArrangement = YES;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor    constraintEqualToAnchor:content.topAnchor],
        [root.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [root.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    ]];

    // ── Section label helper ──────────────────────────────────────────────────
    // ── Màu sắc section ──────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"MÀU SẮC", @"COLORS")]];

    // 3 color swatch cards (1 per row, large tap area)
    NSArray *slotTitles = @[
        LS(@"Màu Súng (X-Ray)", @"Gun Color (X-Ray)"),
        LS(@"Màu Viền Súng",    @"Outline Color"),
        LS(@"Màu Nền (Dim)",    @"Background Dim"),
    ];
    NSArray *slotSubs = @[@"_XRayColor", @"_OutLineColor", @"_DimColor"];
    NSArray *slotTints = @[DV_CYAN, DV_GREEN, DV_PURPLE];

    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UIView *row = [self _colorCardTitle:slotTitles[i]
                                   subtitle:slotSubs[i]
                                       tint:slotTints[i]
                                       slot:(DVSlot)i];
        [root addArrangedSubview:row];
    }

    // ── Thông số section ──────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"THÔNG SỐ", @"PARAMETERS")]];

    UIView *paramCard = [self _card];
    UIStackView *paramStack = [UIStackView new];
    paramStack.axis    = UILayoutConstraintAxisVertical;
    paramStack.spacing = 0;
    paramStack.translatesAutoresizingMaskIntoConstraints = NO;
    [paramCard addSubview:paramStack];
    [NSLayoutConstraint activateConstraints:@[
        [paramStack.topAnchor    constraintEqualToAnchor:paramCard.topAnchor],
        [paramStack.leadingAnchor  constraintEqualToAnchor:paramCard.leadingAnchor],
        [paramStack.trailingAnchor constraintEqualToAnchor:paramCard.trailingAnchor],
        [paramStack.bottomAnchor constraintEqualToAnchor:paramCard.bottomAnchor],
    ]];

    _alphaValueLabel = [UILabel new];
    _alphaValueLabel.font      = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
    _alphaValueLabel.textColor = DV_CYAN;
    [self _updateAlphaLabel];
    _alphaSlider = [self _sliderMin:0 max:1 value:_xrayAlpha tint:DV_CYAN action:@selector(_alphaChanged:)];

    [paramStack addArrangedSubview:[self _sliderRowTitle:LS(@"Độ đục màu súng", @"Gun opacity")
                                               subtitle:@"alpha"
                                                 slider:_alphaSlider
                                             valueLabel:_alphaValueLabel]];

    UIView *div = [UIView new];
    div.backgroundColor = DV_BORDER;
    div.translatesAutoresizingMaskIntoConstraints = NO;
    [paramStack addArrangedSubview:div];
    [div.heightAnchor constraintEqualToConstant:0.5].active = YES;

    _widthValueLabel = [UILabel new];
    _widthValueLabel.font      = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
    _widthValueLabel.textColor = DV_GREEN;
    [self _updateWidthLabel];
    _widthSlider = [self _sliderMin:0 max:20 value:_lineWidth tint:DV_GREEN action:@selector(_widthChanged:)];

    [paramStack addArrangedSubview:[self _sliderRowTitle:LS(@"Độ dày viền", @"Outline width")
                                               subtitle:@"_OutLineWidth"
                                                 slider:_widthSlider
                                             valueLabel:_widthValueLabel]];
    [root addArrangedSubview:paramCard];

    // ── Preview section ───────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"XEM TRƯỚC", @"PREVIEW")]];
    self.previewCard = [self _buildPreviewCard];
    [root addArrangedSubview:self.previewCard];
}

// ─── UI Helpers ───────────────────────────────────────────────────────────────

- (UIView *)_sectionLabel:(NSString *)text {
    UILabel *lbl = [UILabel new];
    lbl.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName:            [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: DV_MUTED,
        NSKernAttributeName:            @(1.2),
    }];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *wrap = [UIView new];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:lbl];
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor  constraintEqualToAnchor:wrap.leadingAnchor constant:4],
        [lbl.topAnchor      constraintEqualToAnchor:wrap.topAnchor],
        [lbl.bottomAnchor   constraintEqualToAnchor:wrap.bottomAnchor],
    ]];
    return wrap;
}

- (UIView *)_card {
    UIView *v = [UIView new];
    v.backgroundColor     = DV_CARD;
    v.layer.cornerRadius  = 14;
    v.layer.cornerCurve   = kCACornerCurveContinuous;
    v.layer.borderColor   = DV_BORDER.CGColor;
    v.layer.borderWidth   = 1;
    v.layer.masksToBounds = YES;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

// Color card: full-width card with large swatch circle + title/subtitle
- (UIView *)_colorCardTitle:(NSString *)title subtitle:(NSString *)sub
                       tint:(UIColor *)tint slot:(DVSlot)slot {
    UIView *card = [self _card];

    // Left accent bar
    UIView *accent = [UIView new];
    accent.backgroundColor    = tint;
    accent.layer.cornerRadius = 1.5;
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:accent];

    UILabel *titleLbl = [UILabel new];
    titleLbl.text      = title;
    titleLbl.font      = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLbl.textColor = DV_INK;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLbl];

    UILabel *subLbl = [UILabel new];
    subLbl.text      = sub;
    subLbl.font      = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    subLbl.textColor = DV_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:subLbl];

    // Swatch circle — large, easy to tap
    UIButton *swatch = [UIButton buttonWithType:UIButtonTypeCustom];
    swatch.backgroundColor    = self.colors[slot];
    swatch.layer.cornerRadius = 22;
    swatch.layer.masksToBounds = YES;
    swatch.layer.borderColor  = [tint colorWithAlphaComponent:0.5].CGColor;
    swatch.layer.borderWidth  = 2;
    swatch.tag = slot;
    swatch.translatesAutoresizingMaskIntoConstraints = NO;
    [swatch addTarget:self action:@selector(_swatchTapped:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:swatch];
    [self.swatches addObject:swatch];

    // Pencil icon overlay on swatch
    UIImageSymbolConfiguration *pencilCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
    UIImageView *pencil = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"pencil" withConfiguration:pencilCfg]];
    pencil.tintColor              = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    pencil.contentMode            = UIViewContentModeScaleAspectFit;
    pencil.userInteractionEnabled = NO;
    pencil.translatesAutoresizingMaskIntoConstraints = NO;
    [swatch addSubview:pencil];

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintEqualToConstant:64],

        [accent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [accent.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [accent.widthAnchor   constraintEqualToConstant:3],
        [accent.heightAnchor  constraintEqualToConstant:28],

        [titleLbl.leadingAnchor constraintEqualToAnchor:accent.trailingAnchor constant:12],
        [titleLbl.topAnchor     constraintEqualToAnchor:card.centerYAnchor constant:-14],

        [subLbl.leadingAnchor constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.topAnchor     constraintEqualToAnchor:titleLbl.bottomAnchor constant:2],

        [swatch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [swatch.centerYAnchor  constraintEqualToAnchor:card.centerYAnchor],
        [swatch.widthAnchor    constraintEqualToConstant:44],
        [swatch.heightAnchor   constraintEqualToConstant:44],

        [pencil.centerXAnchor constraintEqualToAnchor:swatch.centerXAnchor],
        [pencil.centerYAnchor constraintEqualToAnchor:swatch.centerYAnchor],
        [pencil.widthAnchor   constraintEqualToConstant:14],
        [pencil.heightAnchor  constraintEqualToConstant:14],

        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:swatch.leadingAnchor constant:-12],
    ]];

    return card;
}

- (UISlider *)_sliderMin:(float)mn max:(float)mx value:(float)val
                    tint:(UIColor *)tint action:(SEL)action {
    UISlider *sl = [UISlider new];
    sl.minimumValue       = mn;
    sl.maximumValue       = mx;
    sl.value              = val;
    sl.minimumTrackTintColor = tint;
    sl.translatesAutoresizingMaskIntoConstraints = NO;
    [sl addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return sl;
}

- (UIView *)_sliderRowTitle:(NSString *)title subtitle:(NSString *)sub
                     slider:(UISlider *)slider valueLabel:(UILabel *)valLbl {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLbl = [UILabel new];
    titleLbl.text      = title;
    titleLbl.font      = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    titleLbl.textColor = DV_INK;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *subLbl = [UILabel new];
    subLbl.text      = sub;
    subLbl.font      = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    subLbl.textColor = DV_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;

    valLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [valLbl.widthAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;

    UIStackView *sliderRow = [[UIStackView alloc] initWithArrangedSubviews:@[slider, valLbl]];
    sliderRow.spacing   = 10;
    sliderRow.alignment = UIStackViewAlignmentCenter;
    sliderRow.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *inner = [[UIStackView alloc] initWithArrangedSubviews:@[titleLbl, subLbl, sliderRow]];
    inner.axis    = UILayoutConstraintAxisVertical;
    inner.spacing = 4;
    inner.translatesAutoresizingMaskIntoConstraints = NO;

    [row addSubview:inner];
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor    constraintEqualToAnchor:row.topAnchor    constant:14],
        [inner.leadingAnchor  constraintEqualToAnchor:row.leadingAnchor  constant:16],
        [inner.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [inner.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-14],
    ]];
    return row;
}

// Preview: 3-segment color band + hex labels bên dưới
- (UIView *)_buildPreviewCard {
    UIView *card = [self _card];
    card.clipsToBounds = YES;

    // Color band — 3 equal segments
    UIStackView *band = [UIStackView new];
    band.distribution = UIStackViewDistributionFillEqually;
    band.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UIView *seg = [UIView new];
        seg.backgroundColor = self.colors[i];
        seg.tag = 200 + i;
        [band addArrangedSubview:seg];
    }

    // Labels row below band
    NSArray *bandLabels = @[
        LS(@"Súng", @"Gun"),
        LS(@"Viền", @"Outline"),
        LS(@"Nền",  @"Dim"),
    ];
    UIStackView *labelRow = [UIStackView new];
    labelRow.distribution = UIStackViewDistributionFillEqually;
    labelRow.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UILabel *l = [UILabel new];
        l.text          = bandLabels[i];
        l.font          = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        l.textColor     = DV_MUTED;
        l.textAlignment = NSTextAlignmentCenter;
        l.tag           = 300 + i;
        [labelRow addArrangedSubview:l];
    }

    [card addSubview:band];
    [card addSubview:labelRow];
    [NSLayoutConstraint activateConstraints:@[
        [band.topAnchor    constraintEqualToAnchor:card.topAnchor],
        [band.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor],
        [band.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [band.heightAnchor constraintEqualToConstant:44],

        [labelRow.topAnchor    constraintEqualToAnchor:band.bottomAnchor constant:6],
        [labelRow.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor],
        [labelRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [labelRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8],
    ]];

    return card;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.applyGradient.frame = self.applyButton.bounds;
}

// ─── Actions ──────────────────────────────────────────────────────────────────

- (void)_swatchTapped:(UIButton *)btn {
    self.editingSlot = (DVSlot)btn.tag;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.selectedColor = self.colors[self.editingSlot];
    picker.supportsAlpha = NO;
    picker.delegate      = self;
    NSArray *names = @[
        LS(@"Màu Súng (X-Ray)", @"Gun Color"),
        LS(@"Màu Viền Súng",    @"Outline Color"),
        LS(@"Màu Nền (Dim)",    @"Dim Color"),
    ];
    picker.title = names[self.editingSlot];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)_alphaChanged:(UISlider *)sl {
    _xrayAlpha = sl.value;
    [self _updateAlphaLabel];
}
- (void)_widthChanged:(UISlider *)sl {
    _lineWidth = sl.value;
    [self _updateWidthLabel];
}
- (void)_updateAlphaLabel {
    _alphaValueLabel.text = [NSString stringWithFormat:@"%.2f", _xrayAlpha];
}
- (void)_updateWidthLabel {
    _widthValueLabel.text = [NSString stringWithFormat:@"%.1f", _lineWidth];
}
- (void)_close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// ─── UIColorPickerViewControllerDelegate ─────────────────────────────────────

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc {
    [vc dismissViewControllerAnimated:YES completion:nil];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)vc
                   didSelectColor:(UIColor *)color
                     continuously:(BOOL)continuously {
    NSInteger slot = self.editingSlot;
    self.colors[slot] = color;

    // Update swatch circle
    self.swatches[slot].backgroundColor = color;

    // Update preview band
    UIView *seg = [self.previewCard viewWithTag:200 + slot];
    if (seg) seg.backgroundColor = color;
}

// ─── Áp dụng ─────────────────────────────────────────────────────────────────

- (void)_apply {
    self.applyButton.enabled = NO;
    [self.spinner startAnimating];
    [self.applyButton setTitle:LS(@"Đang tạo file…", @"Generating…") forState:UIControlStateNormal];

    NSString *xrayHex = [self _hexFromColor:self.colors[DVSlotXray]];
    NSString *lineHex = [self _hexFromColor:self.colors[DVSlotLine]];
    NSString *dimHex  = [self _hexFromColor:self.colors[DVSlotDim]];

    NSString *shaderFileName = [self.game isEqualToString:@"max"]
        ? @"shaders.RXqs706xmtWYhbN9TqDzP8LDRzk~3D"
        : @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D";

    NSDictionary *colorParams = @{
        @"xray_hex"   : xrayHex,
        @"xray_alpha" : [NSString stringWithFormat:@"%.4f", (double)_xrayAlpha],
        @"line_hex"   : lineHex,
        @"dim_hex"    : dimHex,
        @"width"      : [NSString stringWithFormat:@"%.2f", (double)_lineWidth],
    };

    __weak typeof(self) weak = self;
    [[AutoPasteManager sharedManager] pasteCustomDinhVi:colorParams
                                                   game:self.game
                                              fileNamed:shaderFileName
                                              underRoot:self.searchRoot
                                             completion:^(BOOL success, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weak _applyDone:success message:message];
        });
    }];
}

- (void)_applyDone:(BOOL)success message:(NSString *)msg {
    self.applyButton.enabled = YES;
    [self.spinner stopAnimating];
    [self.applyButton setTitle:LS(@"Áp Dụng Màu", @"Apply Colors") forState:UIControlStateNormal];

    NSString *finalMsg = success
        ? LS(@"✅ Định Vị Súng Màu Tự Chọn Đã Kích Hoạt", @"✅ Custom Color Gun Locator Activated")
        : msg;
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) self.completion(success, finalMsg);
    }];
}

- (NSString *)_hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X",
            (int)(r * 255 + 0.5), (int)(g * 255 + 0.5), (int)(b * 255 + 0.5)];
}

@end
