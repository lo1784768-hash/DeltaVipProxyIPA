#import "LanguagePickerViewController.h"
#import "LanguageManager.h"
#import "BrandTheme.h"

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - LangCard (internal)

@interface LangCard : UIView
@property (nonatomic, assign) BOOL selected;
- (instancetype)initWithFlag:(NSString *)flag name:(NSString *)name;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
@end

@implementation LangCard {
    UILabel *_flagLabel;
    UILabel *_nameLabel;
    CAGradientLayer *_glowBorder;   // gradient stroke
    CAShapeLayer    *_glowMask;     // stroke path
    CALayer         *_glowShadow;   // outer glow
    UIView          *_checkDot;
}

- (instancetype)initWithFlag:(NSString *)flag name:(NSString *)name {
    self = [super init];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 20;
    self.layer.cornerCurve  = kCACornerCurveContinuous;

    // ── Glow shadow (outer halo) ─────────────────────────────────────────────
    _glowShadow = [CALayer layer];
    _glowShadow.cornerRadius  = 20;
    _glowShadow.shadowColor   = BRAND_PURPLE.CGColor;
    _glowShadow.shadowOpacity = 0;
    _glowShadow.shadowRadius  = 18;
    _glowShadow.shadowOffset  = CGSizeZero;
    [self.layer insertSublayer:_glowShadow atIndex:0];

    // ── Glass fill ───────────────────────────────────────────────────────────
    UIVisualEffectView *glass = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.layer.cornerRadius  = 20;
    glass.layer.cornerCurve   = kCACornerCurveContinuous;
    glass.layer.masksToBounds = YES;
    [self addSubview:glass];

    // Dim overlay inside glass
    UIView *dim = [[UIView alloc] init];
    dim.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.14 alpha:0.55];
    dim.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:dim];

    // ── Gradient border stroke ────────────────────────────────────────────────
    _glowBorder = [CAGradientLayer layer];
    _glowBorder.colors = @[
        (id)BRAND_PURPLE.CGColor,
        (id)BRAND_CYAN.CGColor,
        (id)BRAND_PURPLE.CGColor,
    ];
    _glowBorder.startPoint = CGPointMake(0, 0);
    _glowBorder.endPoint   = CGPointMake(1, 1);
    _glowBorder.opacity    = 0;

    _glowMask = [CAShapeLayer layer];
    _glowMask.fillColor   = [UIColor clearColor].CGColor;
    _glowMask.strokeColor = [UIColor whiteColor].CGColor;
    _glowMask.lineWidth   = 2;
    _glowBorder.mask = _glowMask;
    [self.layer addSublayer:_glowBorder];

    // ── Idle border ───────────────────────────────────────────────────────────
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    self.layer.borderWidth = 1;

    // ── Flag ─────────────────────────────────────────────────────────────────
    _flagLabel = [[UILabel alloc] init];
    _flagLabel.text      = flag;
    _flagLabel.font      = [UIFont systemFontOfSize:54];
    _flagLabel.textAlignment = NSTextAlignmentCenter;
    _flagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:_flagLabel];

    // ── Name ─────────────────────────────────────────────────────────────────
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.text      = name;
    _nameLabel.font      = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _nameLabel.textColor = BRAND_TEXT;
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:_nameLabel];

    // ── Check dot (shown when selected) ──────────────────────────────────────
    _checkDot = [[UIView alloc] init];
    _checkDot.backgroundColor = BRAND_CYAN;
    _checkDot.layer.cornerRadius = 10;
    _checkDot.layer.masksToBounds = YES;
    _checkDot.translatesAutoresizingMaskIntoConstraints = NO;
    _checkDot.alpha = 0;
    [glass.contentView addSubview:_checkDot];

    UIImageSymbolConfiguration *chkCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    UIImageView *chkIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"checkmark" withConfiguration:chkCfg]];
    chkIcon.tintColor   = [UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1];
    chkIcon.contentMode = UIViewContentModeScaleAspectFit;
    chkIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [_checkDot addSubview:chkIcon];

    // ── Constraints ───────────────────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:160],

        [glass.topAnchor    constraintEqualToAnchor:self.topAnchor],
        [glass.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [dim.topAnchor    constraintEqualToAnchor:glass.contentView.topAnchor],
        [dim.leadingAnchor  constraintEqualToAnchor:glass.contentView.leadingAnchor],
        [dim.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor],
        [dim.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor],

        [_flagLabel.centerXAnchor constraintEqualToAnchor:glass.contentView.centerXAnchor],
        [_flagLabel.centerYAnchor constraintEqualToAnchor:glass.contentView.centerYAnchor constant:-14],

        [_nameLabel.centerXAnchor constraintEqualToAnchor:glass.contentView.centerXAnchor],
        [_nameLabel.topAnchor     constraintEqualToAnchor:_flagLabel.bottomAnchor constant:8],

        [_checkDot.topAnchor     constraintEqualToAnchor:glass.contentView.topAnchor constant:12],
        [_checkDot.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-12],
        [_checkDot.widthAnchor   constraintEqualToConstant:20],
        [_checkDot.heightAnchor  constraintEqualToConstant:20],

        [chkIcon.centerXAnchor constraintEqualToAnchor:_checkDot.centerXAnchor],
        [chkIcon.centerYAnchor constraintEqualToAnchor:_checkDot.centerYAnchor],
    ]];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    _glowShadow.frame = b;
    _glowBorder.frame = b;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
        CGRectInset(b, 1, 1) cornerRadius:19];
    _glowMask.path  = path.CGPath;
    _glowMask.frame = b;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    _selected = selected;

    void (^applyState)(void) = ^{
        self->_glowBorder.opacity    = selected ? 1.0f : 0.0f;
        self->_glowShadow.shadowOpacity = selected ? 0.70f : 0.0f;
        self->_glowShadow.shadowColor   = selected
            ? BRAND_CYAN.CGColor : BRAND_PURPLE.CGColor;
        self->_checkDot.alpha        = selected ? 1.0f : 0.0f;
        self->_checkDot.transform    = selected
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.4, 0.4);
        self.layer.borderColor = selected
            ? [UIColor clearColor].CGColor
            : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    };

    if (animated) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.25];
        _glowBorder.opacity         = selected ? 1.0f : 0.0f;
        _glowShadow.shadowOpacity   = selected ? 0.70f : 0.0f;
        _glowShadow.shadowColor     = selected ? BRAND_CYAN.CGColor : BRAND_PURPLE.CGColor;
        [CATransaction commit];

        [UIView animateWithDuration:0.22 delay:0
             usingSpringWithDamping:0.6 initialSpringVelocity:4
                            options:0
                         animations:^{
            self->_checkDot.alpha     = selected ? 1.0f : 0.0f;
            self->_checkDot.transform = selected
                ? CGAffineTransformIdentity
                : CGAffineTransformMakeScale(0.4, 0.4);
            self.layer.borderColor = selected
                ? [UIColor clearColor].CGColor
                : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        } completion:nil];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        applyState();
        [CATransaction commit];
    }
}

@end

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - LanguagePickerViewController

@implementation LanguagePickerViewController {
    LangCard   *_viCard;
    LangCard   *_enCard;
    AppLanguage _pending;      // đang hover/chọn
    UIButton   *_confirmBtn;
    CAGradientLayer *_btnGrad;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _pending = [LanguageManager shared].language;
    [self buildUI];
}

- (void)buildUI {
    // ── Glassmorphic background ───────────────────────────────────────────────
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:blur];

    UIView *overlay = [[UIView alloc] init];
    overlay.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:0.60];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [blur.contentView addSubview:overlay];

    UIView *root = blur.contentView;

    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor    constraintEqualToAnchor:self.view.topAnchor],
        [blur.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [overlay.topAnchor    constraintEqualToAnchor:root.topAnchor],
        [overlay.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];

    // ── Grabber ───────────────────────────────────────────────────────────────
    UIView *grabber = [[UIView alloc] init];
    grabber.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25];
    grabber.layer.cornerRadius = 2.5;
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:grabber];

    // ── Globe chip ────────────────────────────────────────────────────────────
    UIView *globeChip = [[UIView alloc] init];
    globeChip.layer.cornerRadius = 14;
    globeChip.layer.cornerCurve  = kCACornerCurveContinuous;
    globeChip.layer.masksToBounds = YES;
    globeChip.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:globeChip];

    CAGradientLayer *chipGrad = [CAGradientLayer layer];
    chipGrad.colors      = @[(id)BRAND_PURPLE.CGColor, (id)BRAND_CYAN.CGColor];
    chipGrad.startPoint  = CGPointMake(0, 0);
    chipGrad.endPoint    = CGPointMake(1, 1);
    chipGrad.cornerRadius = 14;
    [globeChip.layer insertSublayer:chipGrad atIndex:0];

    UIImageSymbolConfiguration *gCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:24 weight:UIImageSymbolWeightBold];
    UIImageView *globeIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:gCfg]];
    globeIcon.tintColor   = [UIColor whiteColor];
    globeIcon.contentMode = UIViewContentModeScaleAspectFit;
    globeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [globeChip addSubview:globeIcon];

    // ── Titles ────────────────────────────────────────────────────────────────
    UILabel *title1 = [[UILabel alloc] init];
    title1.text      = @"Chọn Ngôn Ngữ";
    title1.font      = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    title1.textColor = BRAND_TEXT;
    title1.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:title1];

    UILabel *title2 = [[UILabel alloc] init];
    title2.text      = @"Choose Your Language";
    title2.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    title2.textColor = BRAND_MUTED;
    title2.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:title2];

    // ── Neon divider ─────────────────────────────────────────────────────────
    UIView *divLine = [[UIView alloc] init];
    divLine.backgroundColor = [UIColor clearColor];
    divLine.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:divLine];

    CAGradientLayer *divGrad = [CAGradientLayer layer];
    divGrad.colors = @[
        (id)[BRAND_PURPLE colorWithAlphaComponent:0.0].CGColor,
        (id)BRAND_PURPLE.CGColor,
        (id)BRAND_CYAN.CGColor,
        (id)[BRAND_CYAN colorWithAlphaComponent:0.0].CGColor,
    ];
    divGrad.startPoint = CGPointMake(0, 0.5);
    divGrad.endPoint   = CGPointMake(1, 0.5);
    divGrad.name = @"divider";
    [divLine.layer addSublayer:divGrad];

    // ── Language cards ────────────────────────────────────────────────────────
    _viCard = [[LangCard alloc] initWithFlag:@"🇻🇳" name:@"Tiếng Việt"];
    _enCard = [[LangCard alloc] initWithFlag:@"🇺🇸" name:@"English"];
    [root addSubview:_viCard];
    [root addSubview:_enCard];

    // Set initial selection without animation
    [_viCard setSelected:(_pending == AppLanguageVietnamese) animated:NO];
    [_enCard setSelected:(_pending == AppLanguageEnglish)    animated:NO];

    UITapGestureRecognizer *viTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(tappedVI)];
    UITapGestureRecognizer *enTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(tappedEN)];
    [_viCard addGestureRecognizer:viTap];
    [_enCard addGestureRecognizer:enTap];

    // ── Confirm button ────────────────────────────────────────────────────────
    _confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _confirmBtn.layer.cornerRadius  = 16;
    _confirmBtn.layer.cornerCurve   = kCACornerCurveContinuous;
    _confirmBtn.layer.masksToBounds = YES;
    _confirmBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmBtn setTitle:@"Xác Nhận  /  Confirm" forState:UIControlStateNormal];
    _confirmBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    [_confirmBtn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1]
                      forState:UIControlStateNormal];
    [_confirmBtn addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:_confirmBtn];

    _btnGrad = BrandGradient();
    _btnGrad.cornerRadius = 16;
    [_confirmBtn.layer insertSublayer:_btnGrad atIndex:0];

    // ── Layout ────────────────────────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor    constraintEqualToAnchor:root.topAnchor constant:10],
        [grabber.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [grabber.widthAnchor  constraintEqualToConstant:36],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [globeChip.topAnchor    constraintEqualToAnchor:grabber.bottomAnchor constant:20],
        [globeChip.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor constant:20],
        [globeChip.widthAnchor  constraintEqualToConstant:52],
        [globeChip.heightAnchor constraintEqualToConstant:52],

        [globeIcon.centerXAnchor constraintEqualToAnchor:globeChip.centerXAnchor],
        [globeIcon.centerYAnchor constraintEqualToAnchor:globeChip.centerYAnchor],

        [title1.leadingAnchor constraintEqualToAnchor:globeChip.trailingAnchor constant:14],
        [title1.bottomAnchor  constraintEqualToAnchor:globeChip.centerYAnchor constant:-1],

        [title2.leadingAnchor constraintEqualToAnchor:title1.leadingAnchor],
        [title2.topAnchor     constraintEqualToAnchor:globeChip.centerYAnchor constant:3],

        [divLine.topAnchor    constraintEqualToAnchor:globeChip.bottomAnchor constant:18],
        [divLine.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor  constant:20],
        [divLine.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],
        [divLine.heightAnchor constraintEqualToConstant:1],

        [_viCard.topAnchor    constraintEqualToAnchor:divLine.bottomAnchor constant:20],
        [_viCard.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor constant:16],
        [_viCard.trailingAnchor constraintEqualToAnchor:root.centerXAnchor constant:-8],

        [_enCard.topAnchor    constraintEqualToAnchor:_viCard.topAnchor],
        [_enCard.leadingAnchor  constraintEqualToAnchor:root.centerXAnchor constant:8],
        [_enCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],

        [_confirmBtn.topAnchor    constraintEqualToAnchor:_viCard.bottomAnchor constant:20],
        [_confirmBtn.leadingAnchor  constraintEqualToAnchor:root.leadingAnchor constant:16],
        [_confirmBtn.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [_confirmBtn.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _btnGrad.frame = _confirmBtn.bounds;
    // chipGrad là sublayer của globeChip — set frame
    for (CALayer *lay in self.view.layer.sublayers) { /* skip */ }
    // Cập nhật chipGrad qua tag khác: dùng vòng lặp subview
    [self updateChipGradFrames:self.view];
    // Divider gradient frame
    for (UIView *sub in [self.view.subviews.firstObject.subviews.firstObject subviews]) {
        // root subviews
        for (CALayer *lay in sub.layer.sublayers) {
            if ([lay.name isEqualToString:@"divider"]) {
                lay.frame = sub.bounds;
            }
        }
    }
}

- (void)updateChipGradFrames:(UIView *)parent {
    for (UIView *v in parent.subviews) {
        for (CALayer *lay in v.layer.sublayers) {
            if ([lay isKindOfClass:[CAGradientLayer class]] && !lay.name) {
                if (v.layer.cornerRadius > 0 && lay.cornerRadius > 0) {
                    lay.frame = v.bounds;
                }
            }
        }
        [self updateChipGradFrames:v];
    }
}

// ── Tap handlers ─────────────────────────────────────────────────────────────

- (void)tappedVI {
    [self selectCard:_viCard language:AppLanguageVietnamese];
}
- (void)tappedEN {
    [self selectCard:_enCard language:AppLanguageEnglish];
}

- (void)selectCard:(LangCard *)card language:(AppLanguage)lang {
    if (_pending == lang) return;  // đã chọn rồi

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    _pending = lang;

    // Scale bounce trên card được chọn
    [UIView animateWithDuration:0.12 animations:^{
        card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL _) {
        [UIView animateWithDuration:0.22 delay:0
             usingSpringWithDamping:0.50 initialSpringVelocity:6
                            options:0 animations:^{
            card.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    // Cập nhật glow
    [_viCard setSelected:(lang == AppLanguageVietnamese) animated:YES];
    [_enCard setSelected:(lang == AppLanguageEnglish)    animated:YES];
}

- (void)confirmTapped {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    // Lưu
    [LanguageManager shared].language = _pending;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"delta_lang_chosen"];

    // Scale-down button → dismiss
    [UIView animateWithDuration:0.10 animations:^{
        self->_confirmBtn.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL _) {
        [UIView animateWithDuration:0.12 animations:^{
            self->_confirmBtn.transform = CGAffineTransformIdentity;
        } completion:^(BOOL __) {
            [self dismissViewControllerAnimated:YES completion:^{
                if (self.onDismiss) self.onDismiss();
            }];
        }];
    }];
}

@end
