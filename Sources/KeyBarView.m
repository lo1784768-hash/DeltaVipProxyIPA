#import "KeyBarView.h"
#import "KeyManager.h"
#import "BrandTheme.h"
#import "LanguageManager.h"

#define KB_GREEN  [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define KB_RED    [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define KB_ORANGE [UIColor colorWithRed:1.000 green:0.58  blue:0.0   alpha:1.0]
#define KB_CYAN   BRAND_CYAN
#define KB_MUTED  BRAND_MUTED
#define KB_TEXT   BRAND_TEXT

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
    // Floating pill: glassmorphism blur + subtle border
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:blur];
    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor constraintEqualToAnchor:self.topAnchor],
        [blur.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    self.backgroundColor = [UIColor clearColor];
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    self.layer.borderWidth = 1;
    self.layer.cornerRadius = 24;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;

    // Neon stroke gradient overlay (top line tím→cyan)
    _topLine = [[UIView alloc] init];
    _topLine.backgroundColor = [UIColor clearColor];
    _topLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_topLine];
    _lineGradient = [CAGradientLayer layer];
    _lineGradient.colors = @[
        (id)[BRAND_PURPLE colorWithAlphaComponent:0.0].CGColor,
        (id)BRAND_PURPLE.CGColor,
        (id)BRAND_CYAN.CGColor,
        (id)[BRAND_CYAN colorWithAlphaComponent:0.0].CGColor
    ];
    _lineGradient.startPoint = CGPointMake(0, 0.5);
    _lineGradient.endPoint   = CGPointMake(1, 0.5);
    [_topLine.layer addSublayer:_lineGradient];

    // Pulsing dot
    _dot = [[PulsingDot alloc] init];
    _dot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_dot];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _titleLabel.textColor = KB_TEXT;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];

    _subLabel = [[UILabel alloc] init];
    _subLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _subLabel.textColor = KB_MUTED;
    _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_subLabel];

    // Shield / policy button
    _policyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *shCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [_policyButton setImage:[UIImage systemImageNamed:@"shield.lefthalf.filled" withConfiguration:shCfg]
                   forState:UIControlStateNormal];
    _policyButton.tintColor = [KB_CYAN colorWithAlphaComponent:0.75];
    _policyButton.backgroundColor = [KB_CYAN colorWithAlphaComponent:0.10];
    _policyButton.layer.cornerRadius = 14;
    _policyButton.layer.cornerCurve = kCACornerCurveContinuous;
    _policyButton.layer.borderColor = [KB_CYAN colorWithAlphaComponent:0.25].CGColor;
    _policyButton.layer.borderWidth = 1;
    _policyButton.layer.masksToBounds = YES;
    _policyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_policyButton addTarget:self action:@selector(policyTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_policyButton];

    // Add key button (gradient capsule)
    _addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    [_addButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0]
                     forState:UIControlStateNormal];
    _addButton.layer.cornerRadius = 12;
    _addButton.layer.cornerCurve = kCACornerCurveContinuous;
    _addButton.clipsToBounds = YES;
    _addButton.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_addButton];

    _addGradient = BrandGradient();
    _addGradient.cornerRadius = 12;
    [_addButton.layer insertSublayer:_addGradient atIndex:0];

    // Info button (i)
    UIButton *infoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *iCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [infoBtn setImage:[UIImage systemImageNamed:@"info.circle" withConfiguration:iCfg] forState:UIControlStateNormal];
    infoBtn.tintColor = KB_MUTED;
    infoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [infoBtn addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:infoBtn];

    [NSLayoutConstraint activateConstraints:@[
        // Top neon line
        [_topLine.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_topLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [_topLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [_topLine.heightAnchor constraintEqualToConstant:1],

        // Dot — căn giữa theo chiều dọc cùng khối 2 dòng text
        [_dot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
        [_dot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_dot.widthAnchor constraintEqualToConstant:16],
        [_dot.heightAnchor constraintEqualToConstant:16],

        // Labels — 2 dòng chia đều quanh centerY
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_dot.trailingAnchor constant:10],
        [_titleLabel.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-2],
        [_subLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subLabel.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:3],

        // Add button — min width để "Thêm Key" / "Gia hạn" không bị cắt
        [_addButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_addButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_addButton.heightAnchor constraintEqualToConstant:34],
        [_addButton.widthAnchor constraintGreaterThanOrEqualToConstant:78],

        // Info button
        [infoBtn.trailingAnchor constraintEqualToAnchor:_addButton.leadingAnchor constant:-6],
        [infoBtn.centerYAnchor constraintEqualToAnchor:_addButton.centerYAnchor],
        [infoBtn.widthAnchor constraintEqualToConstant:28],
        [infoBtn.heightAnchor constraintEqualToConstant:28],

        // Policy shield button
        [_policyButton.trailingAnchor constraintEqualToAnchor:infoBtn.leadingAnchor constant:-6],
        [_policyButton.centerYAnchor constraintEqualToAnchor:_addButton.centerYAnchor],
        [_policyButton.widthAnchor constraintEqualToConstant:34],
        [_policyButton.heightAnchor constraintEqualToConstant:34],

        // Clamp labels before buttons
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_policyButton.leadingAnchor constant:-8],
        [_subLabel.trailingAnchor   constraintLessThanOrEqualToAnchor:_policyButton.leadingAnchor constant:-8],
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _addGradient.frame = _addButton.bounds;
    _lineGradient.frame = _topLine.bounds;
}

- (void)update {
    KeyManager *km = [KeyManager shared];
    switch (km.state) {
        case KeyStateActive:
            [_dot startPulsingWithColor:KB_GREEN];
            _titleLabel.text    = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _subLabel.text      = km.formattedRemaining;
            _subLabel.textColor = KB_GREEN;
            [_addButton setTitle:LS(@"Đổi Key", @"Change Key") forState:UIControlStateNormal];
            break;
        case KeyStateExpired:
            [_dot startPulsingWithColor:KB_RED];
            _titleLabel.text    = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _subLabel.text      = LS(@"Đã hết hạn — vui lòng gia hạn", @"Expired — please renew");
            _subLabel.textColor = KB_RED;
            [_addButton setTitle:LS(@"Gia hạn", @"Renew") forState:UIControlStateNormal];
            break;
        default:
            [_dot stopPulsing];
            _titleLabel.text    = LS(@"License Key", @"License Key");
            _subLabel.text      = LS(@"Chưa kích hoạt — nhấn Thêm Key", @"Not activated — tap Add Key");
            _subLabel.textColor = KB_MUTED;
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
