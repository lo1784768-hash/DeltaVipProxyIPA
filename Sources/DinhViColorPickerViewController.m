//
//  DinhViColorPickerViewController.m
//  IMGUIDELTA
//

#import "DinhViColorPickerViewController.h"
#import "AutoPasteManager.h"
#import "KeyManager.h"
#import "Endpoints.h"
#import "LanguageManager.h"
#import "SecurityPinning.h"

// ── Palette ───────────────────────────────────────────────────────────────────
#define DV_BG       [UIColor colorWithRed:0.07 green:0.07 blue:0.10 alpha:1.0]
#define DV_CARD     [UIColor colorWithRed:0.12 green:0.12 blue:0.17 alpha:1.0]
#define DV_ACCENT   [UIColor colorWithRed:0.25 green:0.55 blue:1.00 alpha:1.0]
#define DV_MUTED    [UIColor colorWithRed:0.55 green:0.58 blue:0.65 alpha:1.0]
#define DV_INK      [UIColor colorWithRed:0.92 green:0.93 blue:0.95 alpha:1.0]
#define DV_BORDER   [UIColor colorWithRed:0.25 green:0.27 blue:0.33 alpha:1.0]

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
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView    *previewBar;

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

    self.title = LS(@"Định Vị Súng Màu Tự Chọn", @"Custom Color Gun Locator");
    self.view.backgroundColor = DV_BG;

    // Navigation bar style
    if (@available(iOS 13, *)) {
        UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
        [ap configureWithOpaqueBackground];
        ap.backgroundColor = DV_CARD;
        ap.titleTextAttributes = @{ NSForegroundColorAttributeName: DV_INK };
        self.navigationController.navigationBar.standardAppearance   = ap;
        self.navigationController.navigationBar.scrollEdgeAppearance = ap;
        self.navigationController.navigationBar.tintColor = DV_ACCENT;
    }

    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self action:@selector(_close)];
    self.navigationItem.rightBarButtonItem = closeBtn;

    [self _buildUI];
}

// ─── Build UI ─────────────────────────────────────────────────────────────────
- (void)_buildUI {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIStackView *root = [UIStackView new];
    root.axis      = UILayoutConstraintAxisVertical;
    root.spacing   = 14;
    root.layoutMargins = UIEdgeInsetsMake(20, 16, 40, 16);
    root.layoutMarginsRelativeArrangement = YES;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [root.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [root.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [root.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];

    // ── Section: Màu ──────────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"MÀU SẮC", @"COLORS")]];

    UIView *colorCard = [self _card];
    UIStackView *colorStack = [UIStackView new];
    colorStack.axis    = UILayoutConstraintAxisVertical;
    colorStack.spacing = 0;
    colorStack.translatesAutoresizingMaskIntoConstraints = NO;
    [colorCard addSubview:colorStack];
    [NSLayoutConstraint activateConstraints:@[
        [colorStack.topAnchor constraintEqualToAnchor:colorCard.topAnchor],
        [colorStack.leadingAnchor constraintEqualToAnchor:colorCard.leadingAnchor],
        [colorStack.trailingAnchor constraintEqualToAnchor:colorCard.trailingAnchor],
        [colorStack.bottomAnchor constraintEqualToAnchor:colorCard.bottomAnchor],
    ]];

    NSArray *slotKeys = @[
        LS(@"Màu súng", @"Gun color"),
        LS(@"Màu viền súng", @"Outline color"),
        LS(@"Màu keo", @"Dim color"),
    ];
    NSArray *slotSubs = @[
        @"_XRayColor",
        @"_OutLineColor",
        @"_DimColor",
    ];

    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UIView *row = [self _colorRowWithTitle:slotKeys[i]
                                      subtitle:slotSubs[i]
                                          slot:(DVSlot)i];
        [colorStack addArrangedSubview:row];
        if (i < DVSlotCount - 1) {
            UIView *div = [UIView new];
            div.backgroundColor = DV_BORDER;
            div.translatesAutoresizingMaskIntoConstraints = NO;
            [colorStack addArrangedSubview:div];
            [div.heightAnchor constraintEqualToConstant:0.5].active = YES;
        }
    }
    [root addArrangedSubview:colorCard];

    // ── Section: Thông số ─────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"THÔNG SỐ", @"PARAMETERS")]];

    UIView *paramCard = [self _card];
    UIStackView *paramStack = [UIStackView new];
    paramStack.axis    = UILayoutConstraintAxisVertical;
    paramStack.spacing = 0;
    paramStack.translatesAutoresizingMaskIntoConstraints = NO;
    [paramCard addSubview:paramStack];
    [NSLayoutConstraint activateConstraints:@[
        [paramStack.topAnchor constraintEqualToAnchor:paramCard.topAnchor],
        [paramStack.leadingAnchor constraintEqualToAnchor:paramCard.leadingAnchor],
        [paramStack.trailingAnchor constraintEqualToAnchor:paramCard.trailingAnchor],
        [paramStack.bottomAnchor constraintEqualToAnchor:paramCard.bottomAnchor],
    ]];

    // Alpha slider row
    _alphaValueLabel = [UILabel new];
    _alphaValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    _alphaValueLabel.textColor = DV_ACCENT;
    [self _updateAlphaLabel];
    _alphaSlider = [self _sliderMin:0 max:1 value:_xrayAlpha action:@selector(_alphaChanged:)];

    [paramStack addArrangedSubview:[self _sliderRowTitle:LS(@"Độ đục màu súng", @"Gun opacity")
                                                subtitle:@"alpha"
                                                  slider:_alphaSlider
                                              valueLabel:_alphaValueLabel]];

    UIView *paramDiv = [UIView new];
    paramDiv.backgroundColor = DV_BORDER;
    paramDiv.translatesAutoresizingMaskIntoConstraints = NO;
    [paramStack addArrangedSubview:paramDiv];
    [paramDiv.heightAnchor constraintEqualToConstant:0.5].active = YES;

    // Width slider row
    _widthValueLabel = [UILabel new];
    _widthValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    _widthValueLabel.textColor = DV_ACCENT;
    [self _updateWidthLabel];
    _widthSlider = [self _sliderMin:0 max:20 value:_lineWidth action:@selector(_widthChanged:)];

    [paramStack addArrangedSubview:[self _sliderRowTitle:LS(@"Độ dày viền", @"Outline width")
                                                subtitle:@"_OutLineWidth"
                                                  slider:_widthSlider
                                              valueLabel:_widthValueLabel]];
    [root addArrangedSubview:paramCard];

    // ── Preview bar ───────────────────────────────────────────────────────────
    [root addArrangedSubview:[self _sectionLabel:LS(@"XEM TRƯỚC", @"PREVIEW")]];
    _previewBar = [self _buildPreviewBar];
    [root addArrangedSubview:_previewBar];

    // ── Apply button ──────────────────────────────────────────────────────────
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:LS(@"Áp dụng", @"Apply") forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];

    // Gradient background
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[
        (id)[UIColor colorWithRed:0.18 green:0.48 blue:1.00 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.32 blue:0.90 alpha:1.0].CGColor,
    ];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint   = CGPointMake(1, 1);
    grad.cornerRadius = 14;
    grad.frame = CGRectMake(0, 0, 300, 52); // estimado, se actualiza en layoutSubviews
    [btn.layer insertSublayer:grad atIndex:0];

    btn.layer.cornerRadius = 14;
    btn.layer.masksToBounds = YES;
    [btn.heightAnchor constraintEqualToConstant:52].active = YES;
    [btn addTarget:self action:@selector(_apply) forControlEvents:UIControlEventTouchUpInside];
    self.applyButton = btn;

    if (@available(iOS 13, *))
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    else
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _spinner.color = [UIColor whiteColor];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addSubview:_spinner];
    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [_spinner.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-16],
    ]];

    [root addArrangedSubview:btn];
}

// ─── Helpers UI ───────────────────────────────────────────────────────────────

- (UIView *)_sectionLabel:(NSString *)text {
    UILabel *lbl = [UILabel new];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:text
        attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: DV_MUTED,
            NSKernAttributeName: @(0.8),
        }];
    lbl.attributedText = as;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *wrap = [UIView new];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:lbl];
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:4],
        [lbl.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [lbl.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
        [lbl.trailingAnchor constraintLessThanOrEqualToAnchor:wrap.trailingAnchor],
    ]];
    return wrap;
}

- (UIView *)_card {
    UIView *v = [UIView new];
    v.backgroundColor     = DV_CARD;
    v.layer.cornerRadius  = 14;
    v.layer.masksToBounds = YES;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

- (UIView *)_colorRowWithTitle:(NSString *)title subtitle:(NSString *)sub slot:(DVSlot)slot {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    // Title
    UILabel *titleLbl = [UILabel new];
    titleLbl.text = title;
    titleLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLbl.textColor = DV_INK;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;

    // Subtitle (property name)
    UILabel *subLbl = [UILabel new];
    subLbl.text = sub;
    subLbl.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    subLbl.textColor = DV_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;

    // Swatch button
    UIButton *swatch = [UIButton buttonWithType:UIButtonTypeCustom];
    swatch.translatesAutoresizingMaskIntoConstraints = NO;
    swatch.backgroundColor = self.colors[slot];
    swatch.layer.cornerRadius = 10;
    swatch.layer.masksToBounds = YES;
    swatch.layer.borderWidth = 2;
    swatch.layer.borderColor = DV_BORDER.CGColor;
    swatch.tag = slot;
    [swatch addTarget:self action:@selector(_swatchTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.swatches addObject:swatch];

    UIStackView *labelStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLbl, subLbl]];
    labelStack.axis    = UILayoutConstraintAxisVertical;
    labelStack.spacing = 2;
    labelStack.translatesAutoresizingMaskIntoConstraints = NO;

    [row addSubview:labelStack];
    [row addSubview:swatch];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:60],
        [labelStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [labelStack.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [swatch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [swatch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [swatch.widthAnchor constraintEqualToConstant:40],
        [swatch.heightAnchor constraintEqualToConstant:40],
        [labelStack.trailingAnchor constraintLessThanOrEqualToAnchor:swatch.leadingAnchor constant:-12],
    ]];

    return row;
}

- (UISlider *)_sliderMin:(float)mn max:(float)mx value:(float)val action:(SEL)action {
    UISlider *sl = [UISlider new];
    sl.minimumValue = mn;
    sl.maximumValue = mx;
    sl.value = val;
    sl.minimumTrackTintColor = DV_ACCENT;
    sl.translatesAutoresizingMaskIntoConstraints = NO;
    [sl addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return sl;
}

- (UIView *)_sliderRowTitle:(NSString *)title subtitle:(NSString *)sub
                     slider:(UISlider *)slider valueLabel:(UILabel *)valLbl {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLbl = [UILabel new];
    titleLbl.text = title;
    titleLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLbl.textColor = DV_INK;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *subLbl = [UILabel new];
    subLbl.text = sub;
    subLbl.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    subLbl.textColor = DV_MUTED;
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;

    valLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [valLbl.widthAnchor constraintGreaterThanOrEqualToConstant:38].active = YES;

    UIStackView *sliderRow = [[UIStackView alloc] initWithArrangedSubviews:@[slider, valLbl]];
    sliderRow.spacing = 10;
    sliderRow.alignment = UIStackViewAlignmentCenter;
    sliderRow.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *inner = [[UIStackView alloc] initWithArrangedSubviews:@[titleLbl, subLbl, sliderRow]];
    inner.axis    = UILayoutConstraintAxisVertical;
    inner.spacing = 4;
    inner.translatesAutoresizingMaskIntoConstraints = NO;

    [row addSubview:inner];
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:row.topAnchor constant:14],
        [inner.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [inner.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [inner.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-14],
    ]];
    return row;
}

- (UIView *)_buildPreviewBar {
    UIView *card = [self _card];
    card.clipsToBounds = YES;

    // 3-segment color band
    UIStackView *band = [UIStackView new];
    band.distribution = UIStackViewDistributionFillEqually;
    band.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UIView *seg = [UIView new];
        seg.backgroundColor = self.colors[i];
        seg.tag = 100 + i;
        [band addArrangedSubview:seg];
    }

    // Label overlay
    UILabel *hint = [UILabel new];
    hint.text = LS(@"Xem trước màu", @"Color preview");
    hint.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    hint.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:band];
    [card addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [band.topAnchor constraintEqualToAnchor:card.topAnchor],
        [band.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [band.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [band.heightAnchor constraintEqualToConstant:48],
        [band.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [hint.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [hint.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    card.tag = 999;
    return card;
}

// ─── Actions ──────────────────────────────────────────────────────────────────
- (void)_swatchTapped:(UIButton *)btn {
    self.editingSlot = (DVSlot)btn.tag;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.selectedColor = self.colors[self.editingSlot];
    picker.supportsAlpha = NO;
    picker.delegate      = self;
    NSArray *names = @[
        LS(@"Màu súng", @"Gun color"),
        LS(@"Màu viền súng", @"Outline color"),
        LS(@"Màu keo", @"Dim color"),
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
    self.swatches[slot].backgroundColor = color;

    // Update preview bar segment
    UIView *bar = [self.view viewWithTag:999];
    UIStackView *band = (UIStackView *)bar.subviews.firstObject;
    if ([band isKindOfClass:[UIStackView class]]) {
        UIView *seg = band.arrangedSubviews[slot];
        seg.backgroundColor = color;
    }
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
    [self.applyButton setTitle:LS(@"Áp dụng", @"Apply") forState:UIControlStateNormal];

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
