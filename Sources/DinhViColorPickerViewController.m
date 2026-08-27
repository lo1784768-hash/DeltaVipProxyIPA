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

// ── Màu mặc định ──────────────────────────────────────────────────────────────
static UIColor *kDefaultXray = nil;   // #111111
static UIColor *kDefaultLine = nil;   // #FFFFFF
static UIColor *kDefaultDim  = nil;   // #111111
static const CGFloat kDefaultWidth     = 4.0f;
static const CGFloat kDefaultXrayAlpha = 1.0f;

typedef NS_ENUM(NSInteger, DVSlot) { DVSlotXray = 0, DVSlotLine, DVSlotDim, DVSlotCount };
static NSString * const kSlotTitle[] = {
    [DVSlotXray] = @"Màu súng (_XRayColor)",
    [DVSlotLine] = @"Màu viền súng (_OutLineColor)",
    [DVSlotDim]  = @"Màu keo (_DimColor)",
};

// ─────────────────────────────────────────────────────────────────────────────
@interface DinhViColorPickerViewController () <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray<UIColor *> *colors;
@property (nonatomic, assign) CGFloat xrayAlpha;
@property (nonatomic, assign) CGFloat lineWidth;

@property (nonatomic, strong) NSMutableArray<UIButton *> *swatches;
@property (nonatomic, strong) UISlider *alphaSlider;
@property (nonatomic, strong) UISlider *widthSlider;
@property (nonatomic, strong) UILabel  *alphaLabel;
@property (nonatomic, strong) UILabel  *widthLabel;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

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
    vc.game = game;
    vc.searchRoot = searchRoot;
    vc.completion = completion;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _colors   = [@[kDefaultXray, kDefaultLine, kDefaultDim] mutableCopy];
    _xrayAlpha = kDefaultXrayAlpha;
    _lineWidth  = kDefaultWidth;
    _swatches   = [NSMutableArray array];

    self.title = LS(@"Tùy chỉnh màu định vị", @"Customize Locator Colors");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self action:@selector(_close)];
    [self _buildUI];
}

// ─── Build UI ─────────────────────────────────────────────────────────────────
- (void)_buildUI {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIView *safe = self.view.safeAreaLayoutGuide.topAnchor.accessibilityElement
        ? (UIView *)self.view : self.view;  // fallback
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.layoutMargins = UIEdgeInsetsMake(20, 20, 40, 20);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];

    for (NSInteger i = 0; i < DVSlotCount; i++) {
        [stack addArrangedSubview:[self _swatchRowForSlot:(DVSlot)i]];
        [stack addArrangedSubview:[self _separator]];
    }

    // Alpha slider
    UIStackView *alphaCol = [UIStackView new];
    alphaCol.axis = UILayoutConstraintAxisVertical; alphaCol.spacing = 6;
    UILabel *alphaTitle = [UILabel new];
    alphaTitle.text = LS(@"Độ đục màu súng (alpha)", @"Gun color opacity (alpha)");
    alphaTitle.font = [UIFont systemFontOfSize:13]; alphaTitle.textColor = [UIColor secondaryLabelColor];
    _alphaSlider = [UISlider new];
    _alphaSlider.minimumValue = 0; _alphaSlider.maximumValue = 1; _alphaSlider.value = _xrayAlpha;
    [_alphaSlider addTarget:self action:@selector(_alphaChanged:) forControlEvents:UIControlEventValueChanged];
    _alphaLabel = [UILabel new];
    _alphaLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    _alphaLabel.textColor = [UIColor secondaryLabelColor]; [self _updateAlphaLabel];
    UIStackView *alphaRow = [[UIStackView alloc] initWithArrangedSubviews:@[_alphaSlider, _alphaLabel]];
    alphaRow.spacing = 8; [_alphaLabel.widthAnchor constraintEqualToConstant:36].active = YES;
    [alphaCol addArrangedSubview:alphaTitle]; [alphaCol addArrangedSubview:alphaRow];
    [stack addArrangedSubview:alphaCol];
    [stack addArrangedSubview:[self _separator]];

    // Width slider
    UIStackView *widthCol = [UIStackView new];
    widthCol.axis = UILayoutConstraintAxisVertical; widthCol.spacing = 6;
    UILabel *widthTitle = [UILabel new];
    widthTitle.text = LS(@"Độ dày viền (_OutLineWidth)", @"Outline width (_OutLineWidth)");
    widthTitle.font = [UIFont systemFontOfSize:13]; widthTitle.textColor = [UIColor secondaryLabelColor];
    _widthSlider = [UISlider new];
    _widthSlider.minimumValue = 0; _widthSlider.maximumValue = 20; _widthSlider.value = _lineWidth;
    [_widthSlider addTarget:self action:@selector(_widthChanged:) forControlEvents:UIControlEventValueChanged];
    _widthLabel = [UILabel new];
    _widthLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    _widthLabel.textColor = [UIColor secondaryLabelColor]; [self _updateWidthLabel];
    UIStackView *widthRow = [[UIStackView alloc] initWithArrangedSubviews:@[_widthSlider, _widthLabel]];
    widthRow.spacing = 8; [_widthLabel.widthAnchor constraintEqualToConstant:36].active = YES;
    [widthCol addArrangedSubview:widthTitle]; [widthCol addArrangedSubview:widthRow];
    [stack addArrangedSubview:widthCol];
    [stack addArrangedSubview:[self _separator]];

    // Preview strip
    [stack addArrangedSubview:[self _previewStrip]];

    // Áp dụng button
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:LS(@"Áp dụng", @"Apply") forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    btn.backgroundColor = [UIColor systemBlueColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 12; btn.layer.masksToBounds = YES;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(_apply) forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:50].active = YES;
    self.applyButton = btn;

    if (@available(iOS 13, *))
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    else
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addSubview:_spinner];
    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [_spinner.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-16],
    ]];
    [stack addArrangedSubview:btn];
}

- (UIView *)_swatchRowForSlot:(DVSlot)slot {
    UIView *row = [UIView new];
    UILabel *lbl = [UILabel new];
    lbl.text = kSlotTitle[slot];
    lbl.font = [UIFont systemFontOfSize:14];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:lbl];

    UIButton *swatch = [UIButton buttonWithType:UIButtonTypeCustom];
    swatch.translatesAutoresizingMaskIntoConstraints = NO;
    swatch.layer.cornerRadius = 8; swatch.layer.masksToBounds = YES;
    swatch.layer.borderWidth = 1.5; swatch.layer.borderColor = [UIColor separatorColor].CGColor;
    swatch.backgroundColor = self.colors[slot];
    swatch.tag = slot;
    [swatch addTarget:self action:@selector(_swatchTapped:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:swatch];
    [self.swatches addObject:swatch];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:44],
        [lbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [lbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [swatch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [swatch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [swatch.widthAnchor constraintEqualToConstant:44],
        [swatch.heightAnchor constraintEqualToConstant:32],
        [lbl.trailingAnchor constraintLessThanOrEqualToAnchor:swatch.leadingAnchor constant:-8],
    ]];
    return row;
}

- (UIView *)_previewStrip {
    UIView *strip = [UIView new];
    strip.layer.cornerRadius = 6; strip.layer.masksToBounds = YES;
    strip.translatesAutoresizingMaskIntoConstraints = NO;
    [strip.heightAnchor constraintEqualToConstant:20].active = YES;
    UIStackView *sv = [[UIStackView alloc] init];
    sv.distribution = UIStackViewDistributionFillEqually;
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSInteger i = 0; i < DVSlotCount; i++) {
        UIView *seg = [UIView new];
        seg.backgroundColor = self.colors[i];
        seg.tag = 100 + i;
        [sv addArrangedSubview:seg];
    }
    [strip addSubview:sv];
    sv.frame = strip.bounds;
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    strip.tag = 999;
    return strip;
}

- (UIView *)_separator {
    UIView *v = [UIView new];
    v.backgroundColor = [UIColor separatorColor];
    [v.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return v;
}

// ─── Actions ──────────────────────────────────────────────────────────────────
- (void)_swatchTapped:(UIButton *)btn {
    self.editingSlot = (DVSlot)btn.tag;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.selectedColor = self.colors[self.editingSlot];
    picker.supportsAlpha = NO;
    picker.delegate = self;
    picker.title = kSlotTitle[self.editingSlot];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)_alphaChanged:(UISlider *)sl { _xrayAlpha = sl.value; [self _updateAlphaLabel]; }
- (void)_widthChanged:(UISlider *)sl { _lineWidth  = sl.value; [self _updateWidthLabel]; }
- (void)_updateAlphaLabel { _alphaLabel.text = [NSString stringWithFormat:@"%.2f", _xrayAlpha]; }
- (void)_updateWidthLabel { _widthLabel.text = [NSString stringWithFormat:@"%.1f", _lineWidth]; }
- (void)_close { [self dismissViewControllerAnimated:YES completion:nil]; }

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
    UIView *strip = [self.view viewWithTag:999];
    [[strip viewWithTag:100 + slot] setBackgroundColor:color];
}

// ─── Áp dụng ─────────────────────────────────────────────────────────────────
- (void)_apply {
    self.applyButton.enabled = NO;
    [self.spinner startAnimating];
    [self.applyButton setTitle:LS(@"Đang tạo file…", @"Generating…") forState:UIControlStateNormal];

    NSString *xrayHex = [self _hexFromColor:self.colors[DVSlotXray]];
    NSString *lineHex = [self _hexFromColor:self.colors[DVSlotLine]];
    NSString *dimHex  = [self _hexFromColor:self.colors[DVSlotDim]];

    // Tên file shader (để AutoPasteManager tìm & ghi đè)
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

    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) self.completion(success, msg);
    }];
}

- (NSString *)_hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X",
            (int)(r * 255 + 0.5), (int)(g * 255 + 0.5), (int)(b * 255 + 0.5)];
}

@end
