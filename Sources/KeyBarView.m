#import "KeyBarView.h"
#import "KeyManager.h"
#import "BrandTheme.h"
#import "LanguageManager.h"

// ── Synthwave Arcade palette ─────────────────────────────────────────────────
#define KB_GREEN  [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define KB_RED    [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define KB_ORANGE [UIColor colorWithRed:1.000 green:0.58  blue:0.0   alpha:1.0]
#define KB_PINK   [UIColor colorWithRed:1.0   green:0.0   blue:0.498 alpha:1.0]
#define KB_CYAN   [UIColor colorWithRed:0.0   green:0.941 blue:1.0   alpha:1.0]
#define KB_YELLOW [UIColor colorWithRed:1.0   green:0.902 blue:0.0   alpha:1.0]
#define KB_CARD   [UIColor colorWithRed:0.106 green:0.082 blue:0.157 alpha:1.0]
#define KB_MUTED  [UIColor colorWithWhite:1.0 alpha:0.45]
#define KB_TEXT   [UIColor whiteColor]

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
    // ── Synthwave Arcade card: solid dark bg + pink hard shadow ────────────
    self.backgroundColor = KB_CARD;
    self.layer.cornerRadius = 14;
    self.layer.cornerCurve  = kCACornerCurveContinuous;
    self.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.layer.borderWidth  = 1.5;
    self.layer.masksToBounds = NO;  // allow shadow
    // Hard arcade drop-shadow
    self.layer.shadowColor   = KB_PINK.CGColor;
    self.layer.shadowOpacity = 0.45;
    self.layer.shadowOffset  = CGSizeMake(3, 3);
    self.layer.shadowRadius  = 0;

    // Top accent line: SW_PINK solid strip
    _topLine = [[UIView alloc] init];
    _topLine.backgroundColor = KB_PINK;
    _topLine.translatesAutoresizingMaskIntoConstraints = NO;
    _topLine.layer.cornerRadius = 1;
    [self addSubview:_topLine];
    // _lineGradient kept as nil — layoutSubviews guard: frame set only if non-nil
    _lineGradient = nil;

    // Pulsing dot
    _dot = [[PulsingDot alloc] init];
    _dot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_dot];

    // Key code: monospaced, cyan
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    _titleLabel.textColor = KB_CYAN;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleLabel];

    // Subtitle: small muted
    _subLabel = [[UILabel alloc] init];
    _subLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    _subLabel.textColor = KB_MUTED;
    _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_subLabel];

    // Policy button: cyan outline, circular
    _policyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *shCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
    [_policyButton setImage:[UIImage systemImageNamed:@"shield.lefthalf.filled"
                                    withConfiguration:shCfg]
                   forState:UIControlStateNormal];
    _policyButton.tintColor = KB_CYAN;
    _policyButton.backgroundColor = [KB_CYAN colorWithAlphaComponent:0.08];
    _policyButton.layer.cornerRadius = 14;
    _policyButton.layer.cornerCurve = kCACornerCurveContinuous;
    _policyButton.layer.borderColor = [KB_CYAN colorWithAlphaComponent:0.35].CGColor;
    _policyButton.layer.borderWidth = 1.5;
    _policyButton.layer.masksToBounds = YES;
    _policyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_policyButton addTarget:self action:@selector(policyTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_policyButton];

    // Add/Change key button: solid SW_PINK, square Arcade style
    _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _addButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [_addButton setTitleColor:[UIColor colorWithRed:0.06 green:0.04 blue:0.10 alpha:1.0]
                     forState:UIControlStateNormal];
    _addButton.backgroundColor = KB_PINK;
    _addButton.layer.cornerRadius = 8;
    _addButton.layer.cornerCurve = kCACornerCurveContinuous;
    _addButton.layer.masksToBounds = YES;
    _addButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton addTarget:self action:@selector(addTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_addButton];
    // No gradient needed — solid pink
    _addGradient = nil;

    // Info button
    UIButton *infoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *iCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [infoBtn setImage:[UIImage systemImageNamed:@"info.circle"
                             withConfiguration:iCfg]
             forState:UIControlStateNormal];
    infoBtn.tintColor = KB_MUTED;
    infoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [infoBtn addTarget:self action:@selector(infoTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:infoBtn];

    [NSLayoutConstraint activateConstraints:@[
        // Top accent stripe
        [_topLine.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_topLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_topLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_topLine.heightAnchor constraintEqualToConstant:2],

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

        // Add button
        [_addButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_addButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_addButton.heightAnchor constraintEqualToConstant:32],
        [_addButton.widthAnchor constraintGreaterThanOrEqualToConstant:76],

        // Info button
        [infoBtn.trailingAnchor constraintEqualToAnchor:_addButton.leadingAnchor constant:-4],
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
    if (_lineGradient) _lineGradient.frame = _topLine.bounds;
}

- (void)update {
    KeyManager *km = [KeyManager shared];
    switch (km.state) {
        case KeyStateActive:
            [_dot startPulsingWithColor:KB_GREEN];
            _titleLabel.text      = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _titleLabel.textColor = KB_CYAN;
            _subLabel.text        = km.formattedRemaining;
            _subLabel.textColor   = KB_GREEN;
            _addButton.backgroundColor = KB_PINK;
            [_addButton setTitle:LS(@"Đổi Key", @"Change Key") forState:UIControlStateNormal];
            break;
        case KeyStateExpired:
            [_dot startPulsingWithColor:KB_RED];
            _titleLabel.text      = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _titleLabel.textColor = KB_RED;
            _subLabel.text        = LS(@"Đã hết hạn — vui lòng gia hạn", @"Expired — please renew");
            _subLabel.textColor   = KB_RED;
            _addButton.backgroundColor = KB_ORANGE;
            [_addButton setTitle:LS(@"Gia hạn", @"Renew") forState:UIControlStateNormal];
            break;
        default:
            [_dot stopPulsing];
            _titleLabel.text      = LS(@"License Key", @"License Key");
            _titleLabel.textColor = KB_MUTED;
            _subLabel.text        = LS(@"Chưa kích hoạt — nhấn Thêm Key", @"Not activated — tap Add Key");
            _subLabel.textColor   = KB_MUTED;
            _addButton.backgroundColor = KB_PINK;
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
