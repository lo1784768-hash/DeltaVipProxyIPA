#import "KeyBarView.h"
#import "KeyManager.h"
#import "BrandTheme.h"
#import "LanguageManager.h"

// ── Quantum Aura palette (matches AppDataViewController) ─────────────────────
#define KB_GREEN  [UIColor colorWithRed:0.0   green:1.0   blue:0.612 alpha:1.0]  // #00FF9C
#define KB_RED    [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define KB_ORANGE [UIColor colorWithRed:1.000 green:0.58  blue:0.0   alpha:1.0]
#define KB_CYAN   [UIColor colorWithRed:0.0   green:0.941 blue:1.0   alpha:1.0]  // #00F0FF
#define KB_PURPLE [UIColor colorWithRed:0.275 green:0.0   blue:1.0   alpha:1.0]  // #7000FF
#define KB_MUTED  [UIColor colorWithWhite:1.0 alpha:0.45]
#define KB_TEXT   [UIColor colorWithWhite:1.0 alpha:0.92]
#define KB_BORDER [UIColor colorWithWhite:1.0 alpha:0.08]

// ── Pulsing dot (live status) ────────────────────────────────────────────────
@interface PulsingDot : UIView
- (void)startPulsingWithColor:(UIColor *)color;
- (void)stopPulsing;
@end
@implementation PulsingDot {
    UIColor *_color;
    UIView  *_ring;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        // Inner solid dot
        UIView *inner = [[UIView alloc] init];
        inner.translatesAutoresizingMaskIntoConstraints = NO;
        inner.tag = 1;
        [self addSubview:inner];
        [NSLayoutConstraint activateConstraints:@[
            [inner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [inner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [inner.widthAnchor constraintEqualToConstant:8],
            [inner.heightAnchor constraintEqualToConstant:8],
        ]];
        inner.layer.cornerRadius = 4;
        // Outer pulse ring
        _ring = [[UIView alloc] init];
        _ring.translatesAutoresizingMaskIntoConstraints = NO;
        _ring.tag = 2;
        [self insertSubview:_ring belowSubview:inner];
        [NSLayoutConstraint activateConstraints:@[
            [_ring.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_ring.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_ring.widthAnchor constraintEqualToConstant:16],
            [_ring.heightAnchor constraintEqualToConstant:16],
        ]];
        _ring.layer.cornerRadius = 8;
        _ring.alpha = 0;
    }
    return self;
}
- (void)startPulsingWithColor:(UIColor *)color {
    _color = color;
    UIView *inner = [self viewWithTag:1];
    inner.backgroundColor = color;
    _ring.backgroundColor = [color colorWithAlphaComponent:0.3];
    _ring.layer.borderColor = [color colorWithAlphaComponent:0.5].CGColor;
    _ring.layer.borderWidth = 1;
    inner.layer.shadowColor = color.CGColor;
    inner.layer.shadowOpacity = 0.9;
    inner.layer.shadowRadius = 5;
    inner.layer.shadowOffset = CGSizeZero;
    [self animatePulse];
}
- (void)stopPulsing {
    [_ring.layer removeAllAnimations];
    _ring.alpha = 0;
    UIView *inner = [self viewWithTag:1];
    inner.backgroundColor = KB_MUTED;
    inner.layer.shadowOpacity = 0;
}
- (void)animatePulse {
    _ring.transform = CGAffineTransformIdentity;
    _ring.alpha = 0.9;
    [UIView animateWithDuration:1.4 delay:0
                          options:UIViewAnimationOptionCurveEaseOut
                       animations:^{
        self->_ring.transform = CGAffineTransformMakeScale(2.0, 2.0);
        self->_ring.alpha = 0;
    } completion:^(BOOL f) {
        if (self->_color) [self performSelector:@selector(animatePulse) withObject:nil afterDelay:0.4];
    }];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
@interface KeyBarView ()
@property (nonatomic, strong) PulsingDot *dot;
@property (nonatomic, strong) UILabel    *titleLabel;
@property (nonatomic, strong) UILabel    *subLabel;
@property (nonatomic, strong) UIButton   *addButton;
@property (nonatomic, strong) UIButton   *policyButton; // shield icon
@property (nonatomic, strong) CAGradientLayer *addGradient;
@property (nonatomic, strong) CAGradientLayer *lineGradient;
@property (nonatomic, strong) UIView     *topLine;
@end

@implementation KeyBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self build];
        [self update];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(onLanguageChanged)
            name:LMLanguageChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)onLanguageChanged { [self update]; }

- (void)build {
    // ── Quantum Aura floating bar ─────────────────────────────────────────────
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 22;
    self.layer.cornerCurve  = kCACornerCurveContinuous;
    self.layer.masksToBounds = NO;
    self.layer.borderWidth  = 0;  // border do gradient CAShapeLayer xử lý
    // Shadow: tím ambient
    self.layer.shadowColor   = KB_PURPLE.CGColor;
    self.layer.shadowOpacity = 0.35;
    self.layer.shadowRadius  = 22;
    self.layer.shadowOffset  = CGSizeMake(0, 6);

    // Frosted glass background (inside clip, radius matching)
    UIView *glassContainer = [[UIView alloc] init];
    glassContainer.layer.cornerRadius = 22;
    glassContainer.layer.cornerCurve  = kCACornerCurveContinuous;
    glassContainer.layer.masksToBounds = YES;
    glassContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:glassContainer];

    UIVisualEffectView *blurBg = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blurBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [glassContainer addSubview:blurBg];

    // Tint đen vũ trụ
    UIView *tintBg = [[UIView alloc] init];
    tintBg.backgroundColor = [UIColor colorWithRed:0.024 green:0.027 blue:0.035 alpha:0.72];
    tintBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [glassContainer addSubview:tintBg];

    [NSLayoutConstraint activateConstraints:@[
        [glassContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [glassContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [glassContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [glassContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    // Gradient border tím→cyan: dùng CAGradientLayer + CAShapeLayer mask
    // Sẽ frame trong layoutSubviews
    _lineGradient = [CAGradientLayer layer];
    _lineGradient.colors = @[
        (id)KB_PURPLE.CGColor,
        (id)KB_CYAN.CGColor,
    ];
    _lineGradient.startPoint = CGPointMake(0, 0.5);
    _lineGradient.endPoint   = CGPointMake(1, 0.5);
    // _lineGradient được dùng như border; mask bằng stroke path trong layoutSubviews
    [self.layer addSublayer:_lineGradient];

    // _topLine: hidden placeholder
    _topLine = [[UIView alloc] init];
    _topLine.hidden = YES;
    [self addSubview:_topLine];

    // Pulsing dot
    _dot = [[PulsingDot alloc] init];
    _dot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_dot];

    // Key label: medium weight (không monospaced)
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _titleLabel.textColor = KB_TEXT;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];

    // Subtitle
    _subLabel = [[UILabel alloc] init];
    _subLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _subLabel.textColor = KB_MUTED;
    _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_subLabel];

    // Policy button: glass circle
    _policyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *shCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
    [_policyButton setImage:[UIImage systemImageNamed:@"shield.lefthalf.filled"
                                    withConfiguration:shCfg]
                   forState:UIControlStateNormal];
    _policyButton.tintColor = KB_MUTED;
    _policyButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07];
    _policyButton.layer.cornerRadius = 14;
    _policyButton.layer.cornerCurve = kCACornerCurveContinuous;
    _policyButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    _policyButton.layer.borderWidth = 1;
    _policyButton.layer.masksToBounds = YES;
    _policyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_policyButton addTarget:self action:@selector(policyTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_policyButton];

    // Add button: gradient capsule Cyan→Purple
    _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _addButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [_addButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _addButton.layer.cornerRadius = 16;   // full capsule
    _addButton.layer.cornerCurve = kCACornerCurveContinuous;
    _addButton.layer.masksToBounds = YES;
    _addButton.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton addTarget:self action:@selector(addTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_addButton];

    // Gradient layer cyan→purple for the capsule button
    _addGradient = [CAGradientLayer layer];
    _addGradient.colors = @[
        (id)[UIColor colorWithRed:0.0 green:0.949 blue:0.996 alpha:1.0].CGColor,  // #00F2FE cyan
        (id)[UIColor colorWithRed:0.278 green:0.173 blue:0.655 alpha:1.0].CGColor, // #4732A7 purple
    ];
    _addGradient.startPoint = CGPointMake(0, 0.5);
    _addGradient.endPoint   = CGPointMake(1, 0.5);
    _addGradient.cornerRadius = 16;
    [_addButton.layer insertSublayer:_addGradient atIndex:0];

    // Info button
    UIButton *infoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *iCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [infoBtn setImage:[UIImage systemImageNamed:@"info.circle" withConfiguration:iCfg]
             forState:UIControlStateNormal];
    infoBtn.tintColor = KB_MUTED;
    infoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [infoBtn addTarget:self action:@selector(infoTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:infoBtn];

    [NSLayoutConstraint activateConstraints:@[
        // Dot
        [_dot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_dot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_dot.widthAnchor constraintEqualToConstant:16],
        [_dot.heightAnchor constraintEqualToConstant:16],

        // Labels
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_dot.trailingAnchor constant:10],
        [_titleLabel.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-1],
        [_subLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subLabel.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:2],

        // Add button (capsule)
        [_addButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_addButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_addButton.heightAnchor constraintEqualToConstant:34],
        [_addButton.widthAnchor constraintGreaterThanOrEqualToConstant:82],

        // Info button
        [infoBtn.trailingAnchor constraintEqualToAnchor:_addButton.leadingAnchor constant:-6],
        [infoBtn.centerYAnchor constraintEqualToAnchor:_addButton.centerYAnchor],
        [infoBtn.widthAnchor constraintEqualToConstant:26],
        [infoBtn.heightAnchor constraintEqualToConstant:26],

        // Policy button
        [_policyButton.trailingAnchor constraintEqualToAnchor:infoBtn.leadingAnchor constant:-4],
        [_policyButton.centerYAnchor constraintEqualToAnchor:_addButton.centerYAnchor],
        [_policyButton.widthAnchor constraintEqualToConstant:32],
        [_policyButton.heightAnchor constraintEqualToConstant:32],

        // Clamp labels
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_policyButton.leadingAnchor constant:-8],
        [_subLabel.trailingAnchor   constraintLessThanOrEqualToAnchor:_policyButton.leadingAnchor constant:-8],
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_addGradient) _addGradient.frame = _addButton.bounds;

    // Gradient border: stroke path dạng capsule quanh bar
    if (_lineGradient) {
        _lineGradient.frame = self.bounds;
        CGFloat r = self.layer.cornerRadius;
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(self.bounds, 0.5, 0.5) cornerRadius:r - 0.5];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path        = path.CGPath;
        mask.fillColor   = [UIColor clearColor].CGColor;
        mask.strokeColor = [UIColor whiteColor].CGColor;
        mask.lineWidth   = 1.0;
        _lineGradient.mask = mask;
    }
}

- (void)update {
    KeyManager *km = [KeyManager shared];
    switch (km.state) {
        case KeyStateActive:
            [_dot startPulsingWithColor:KB_GREEN];
            _titleLabel.text      = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _titleLabel.textColor = KB_TEXT;
            _subLabel.text        = km.formattedRemaining;
            _subLabel.textColor   = KB_GREEN;
            // Gradient button: cyan→purple (gradient đã cố định, chỉ cần ensure title đúng)
            [_addButton setTitle:LS(@"Đổi Key", @"Change Key") forState:UIControlStateNormal];
            break;
        case KeyStateExpired:
            [_dot startPulsingWithColor:KB_RED];
            _titleLabel.text      = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _titleLabel.textColor = KB_RED;
            _subLabel.text        = LS(@"Đã hết hạn — vui lòng gia hạn", @"Expired — please renew");
            _subLabel.textColor   = KB_RED;
            [_addButton setTitle:LS(@"Gia hạn", @"Renew") forState:UIControlStateNormal];
            break;
        default:
            [_dot stopPulsing];
            _titleLabel.text      = LS(@"License Key", @"License Key");
            _titleLabel.textColor = KB_MUTED;
            _subLabel.text        = LS(@"Chưa kích hoạt — nhấn Thêm Key", @"Not activated — tap Add Key");
            _subLabel.textColor   = KB_MUTED;
            [_addButton setTitle:LS(@"Thêm Key", @"Add Key") forState:UIControlStateNormal];
            break;
    }
}

- (NSString *)maskKey:(NSString *)key {
    if (key.length <= 8) return key ?: @"";
    return [NSString stringWithFormat:@"%@••••%@",
            [key substringToIndex:4],
            [key substringFromIndex:key.length - 4]];
}

- (void)addTapped    { if (self.onAddTapped)    self.onAddTapped(); }
- (void)infoTapped   { if (self.onInfoTapped)   self.onInfoTapped(); }
- (void)policyTapped { if (self.onPolicyTapped) self.onPolicyTapped(); }

@end
