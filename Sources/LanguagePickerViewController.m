#import "LanguagePickerViewController.h"
#import "LanguageManager.h"
#import "BrandTheme.h"

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - LangCard

@interface LangCard : UIView
- (instancetype)initWithFlag:(NSString *)flag name:(NSString *)name;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
@end

@implementation LangCard {
    CAGradientLayer *_glowBorder;
    CAShapeLayer    *_glowMask;
    CALayer         *_glowShadow;
    UIView          *_checkDot;
    BOOL             _selected;
}

- (instancetype)initWithFlag:(NSString *)flag name:(NSString *)name {
    self = [super init];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;

    // Outer glow shadow
    _glowShadow = [CALayer layer];
    _glowShadow.cornerRadius  = 20;
    _glowShadow.shadowColor   = BRAND_CYAN.CGColor;
    _glowShadow.shadowOpacity = 0;
    _glowShadow.shadowRadius  = 18;
    _glowShadow.shadowOffset  = CGSizeZero;
    [self.layer insertSublayer:_glowShadow atIndex:0];

    // Glass fill
    UIVisualEffectView *glass = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.layer.cornerRadius  = 20;
    glass.layer.cornerCurve   = kCACornerCurveContinuous;
    glass.layer.masksToBounds = YES;
    [self addSubview:glass];

    UIView *dim = [[UIView alloc] init];
    dim.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.14 alpha:0.55];
    dim.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:dim];

    // Gradient stroke border
    _glowBorder = [CAGradientLayer layer];
    _glowBorder.colors = @[(id)BRAND_PURPLE.CGColor, (id)BRAND_CYAN.CGColor, (id)BRAND_PURPLE.CGColor];
    _glowBorder.startPoint = CGPointMake(0, 0);
    _glowBorder.endPoint   = CGPointMake(1, 1);
    _glowBorder.opacity    = 0;
    _glowMask = [CAShapeLayer layer];
    _glowMask.fillColor   = [UIColor clearColor].CGColor;
    _glowMask.strokeColor = [UIColor whiteColor].CGColor;
    _glowMask.lineWidth   = 2;
    _glowBorder.mask = _glowMask;
    [self.layer addSublayer:_glowBorder];

    // Default idle border
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    self.layer.borderWidth = 1;
    self.layer.cornerRadius = 20;
    self.layer.cornerCurve  = kCACornerCurveContinuous;

    // Flag
    UILabel *flagLbl = [[UILabel alloc] init];
    flagLbl.text = flag;
    flagLbl.font = [UIFont systemFontOfSize:54];
    flagLbl.textAlignment = NSTextAlignmentCenter;
    flagLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:flagLbl];

    // Name
    UILabel *nameLbl = [[UILabel alloc] init];
    nameLbl.text = name;
    nameLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    nameLbl.textColor = BRAND_TEXT;
    nameLbl.textAlignment = NSTextAlignmentCenter;
    nameLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:nameLbl];

    // Check dot
    _checkDot = [[UIView alloc] init];
    _checkDot.backgroundColor    = BRAND_CYAN;
    _checkDot.layer.cornerRadius = 10;
    _checkDot.layer.masksToBounds = YES;
    _checkDot.translatesAutoresizingMaskIntoConstraints = NO;
    _checkDot.alpha     = 0;
    _checkDot.transform = CGAffineTransformMakeScale(0.4, 0.4);
    [glass.contentView addSubview:_checkDot];

    UIImageSymbolConfiguration *chkCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    UIImageView *chkIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"checkmark" withConfiguration:chkCfg]];
    chkIcon.tintColor   = [UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1];
    chkIcon.contentMode = UIViewContentModeScaleAspectFit;
    chkIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [_checkDot addSubview:chkIcon];

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

        [flagLbl.centerXAnchor constraintEqualToAnchor:glass.contentView.centerXAnchor],
        [flagLbl.centerYAnchor constraintEqualToAnchor:glass.contentView.centerYAnchor constant:-12],

        [nameLbl.centerXAnchor constraintEqualToAnchor:glass.contentView.centerXAnchor],
        [nameLbl.topAnchor     constraintEqualToAnchor:flagLbl.bottomAnchor constant:8],

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
    _glowMask.frame   = b;
    _glowMask.path    = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 1, 1)
                                                   cornerRadius:19].CGPath;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    _selected = selected;
    if (animated) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.25];
        _glowBorder.opacity       = selected ? 1.0f : 0.0f;
        _glowShadow.shadowOpacity = selected ? 0.65f : 0.0f;
        [CATransaction commit];

        [UIView animateWithDuration:0.22 delay:0
             usingSpringWithDamping:0.55 initialSpringVelocity:5
                            options:0
                         animations:^{
            self->_checkDot.alpha     = selected ? 1.0f : 0.0f;
            self->_checkDot.transform = selected ? CGAffineTransformIdentity
                                                 : CGAffineTransformMakeScale(0.4, 0.4);
            self.layer.borderColor = selected ? [UIColor clearColor].CGColor
                                             : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        } completion:nil];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _glowBorder.opacity       = selected ? 1.0f : 0.0f;
        _glowShadow.shadowOpacity = selected ? 0.65f : 0.0f;
        _checkDot.alpha     = selected ? 1.0f : 0.0f;
        _checkDot.transform = selected ? CGAffineTransformIdentity
                                       : CGAffineTransformMakeScale(0.4, 0.4);
        self.layer.borderColor = selected ? [UIColor clearColor].CGColor
                                         : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        [CATransaction commit];
    }
}
@end

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - LanguagePickerViewController

@implementation LanguagePickerViewController {
    LangCard        *_viCard;
    LangCard        *_enCard;
    UIButton        *_confirmBtn;
    CAGradientLayer *_btnGrad;      // gradient confirm button
    CAGradientLayer *_chipGrad;     // gradient globe chip
    UIView          *_globeChip;    // chip wrapper (để set frame chipGrad)
    CAGradientLayer *_divGrad;      // neon divider
    UIView          *_divLine;      // divider wrapper
    AppLanguage      _pending;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:1.0];
    _pending = [LanguageManager shared].language;
    [self buildUI];
}

- (void)buildUI {
    // ── Background blur ───────────────────────────────────────────────────────
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:blur];

    UIView *overlay = [[UIView alloc] init];
    overlay.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:0.60];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [blur.contentView addSubview:overlay];

    // Dùng self.view làm gốc layout (đơn giản hơn blur.contentView)
    UIView *R = self.view;

    [NSLayoutConstraint activateConstraints:@[
        [blur.topAnchor    constraintEqualToAnchor:R.topAnchor],
        [blur.leadingAnchor  constraintEqualToAnchor:R.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:R.trailingAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:R.bottomAnchor],
        [overlay.topAnchor    constraintEqualToAnchor:blur.contentView.topAnchor],
        [overlay.leadingAnchor  constraintEqualToAnchor:blur.contentView.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
    ]];

    // ── Globe chip (gradient purple→cyan) ─────────────────────────────────────
    _globeChip = [[UIView alloc] init];
    _globeChip.layer.cornerRadius  = 14;
    _globeChip.layer.cornerCurve   = kCACornerCurveContinuous;
    _globeChip.layer.masksToBounds = YES;
    _globeChip.translatesAutoresizingMaskIntoConstraints = NO;
    [R addSubview:_globeChip];

    _chipGrad = [CAGradientLayer layer];
    _chipGrad.colors      = @[(id)BRAND_PURPLE.CGColor, (id)BRAND_CYAN.CGColor];
    _chipGrad.startPoint  = CGPointMake(0, 0);
    _chipGrad.endPoint    = CGPointMake(1, 1);
    _chipGrad.cornerRadius = 14;
    [_globeChip.layer insertSublayer:_chipGrad atIndex:0];

    UIImageSymbolConfiguration *gCfg = [UIImageSymbolConfiguration
        configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImageView *globeIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:gCfg]];
    globeIcon.tintColor   = [UIColor whiteColor];
    globeIcon.contentMode = UIViewContentModeScaleAspectFit;
    globeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [_globeChip addSubview:globeIcon];

    // ── Titles ────────────────────────────────────────────────────────────────
    UILabel *title1 = [[UILabel alloc] init];
    title1.text      = @"Chọn Ngôn Ngữ";
    title1.font      = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    title1.textColor = BRAND_TEXT;
    title1.translatesAutoresizingMaskIntoConstraints = NO;
    [R addSubview:title1];

    UILabel *title2 = [[UILabel alloc] init];
    title2.text      = @"Choose Your Language";
    title2.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    title2.textColor = BRAND_MUTED;
    title2.translatesAutoresizingMaskIntoConstraints = NO;
    [R addSubview:title2];

    // ── Neon divider purple→cyan ──────────────────────────────────────────────
    _divLine = [[UIView alloc] init];
    _divLine.translatesAutoresizingMaskIntoConstraints = NO;
    [R addSubview:_divLine];

    _divGrad = [CAGradientLayer layer];
    _divGrad.colors = @[
        (id)[BRAND_PURPLE colorWithAlphaComponent:0.0].CGColor,
        (id)BRAND_PURPLE.CGColor,
        (id)BRAND_CYAN.CGColor,
        (id)[BRAND_CYAN colorWithAlphaComponent:0.0].CGColor,
    ];
    _divGrad.startPoint = CGPointMake(0, 0.5);
    _divGrad.endPoint   = CGPointMake(1, 0.5);
    [_divLine.layer addSublayer:_divGrad];

    // ── Language cards ────────────────────────────────────────────────────────
    _viCard = [[LangCard alloc] initWithFlag:@"🇻🇳" name:@"Tiếng Việt"];
    _enCard = [[LangCard alloc] initWithFlag:@"🇺🇸" name:@"English"];
    [R addSubview:_viCard];
    [R addSubview:_enCard];

    [_viCard setSelected:(_pending == AppLanguageVietnamese) animated:NO];
    [_enCard setSelected:(_pending == AppLanguageEnglish)    animated:NO];

    UITapGestureRecognizer *viTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(tappedVI)];
    UITapGestureRecognizer *enTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(tappedEN)];
    [_viCard addGestureRecognizer:viTap];
    [_enCard addGestureRecognizer:enTap];

    // ── Confirm button (gradient) ─────────────────────────────────────────────
    _confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _confirmBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _confirmBtn.layer.cornerRadius  = 16;
    _confirmBtn.layer.cornerCurve   = kCACornerCurveContinuous;
    _confirmBtn.layer.masksToBounds = YES;
    [_confirmBtn setTitle:@"Xác Nhận  /  Confirm" forState:UIControlStateNormal];
    _confirmBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    [_confirmBtn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1]
                      forState:UIControlStateNormal];
    [_confirmBtn addTarget:self action:@selector(confirmTapped)
          forControlEvents:UIControlEventTouchUpInside];
    [R addSubview:_confirmBtn];

    _btnGrad = BrandGradient();
    _btnGrad.cornerRadius = 16;
    [_confirmBtn.layer insertSublayer:_btnGrad atIndex:0];

    // ── Layout constraints ────────────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        // Globe chip: top-left
        [_globeChip.topAnchor    constraintEqualToAnchor:R.safeAreaLayoutGuide.topAnchor constant:28],
        [_globeChip.leadingAnchor  constraintEqualToAnchor:R.leadingAnchor constant:20],
        [_globeChip.widthAnchor  constraintEqualToConstant:52],
        [_globeChip.heightAnchor constraintEqualToConstant:52],

        [globeIcon.centerXAnchor constraintEqualToAnchor:_globeChip.centerXAnchor],
        [globeIcon.centerYAnchor constraintEqualToAnchor:_globeChip.centerYAnchor],

        // Titles: vertically stacked, pinned to chip's center
        [title1.leadingAnchor constraintEqualToAnchor:_globeChip.trailingAnchor constant:14],
        [title1.trailingAnchor constraintLessThanOrEqualToAnchor:R.trailingAnchor constant:-16],
        [title1.bottomAnchor  constraintEqualToAnchor:_globeChip.centerYAnchor  constant:-1],

        [title2.leadingAnchor constraintEqualToAnchor:title1.leadingAnchor],
        [title2.topAnchor     constraintEqualToAnchor:_globeChip.centerYAnchor constant:3],

        // Divider
        [_divLine.topAnchor    constraintEqualToAnchor:_globeChip.bottomAnchor constant:20],
        [_divLine.leadingAnchor  constraintEqualToAnchor:R.leadingAnchor constant:16],
        [_divLine.trailingAnchor constraintEqualToAnchor:R.trailingAnchor constant:-16],
        [_divLine.heightAnchor constraintEqualToConstant:1],

        // Cards
        [_viCard.topAnchor    constraintEqualToAnchor:_divLine.bottomAnchor constant:20],
        [_viCard.leadingAnchor  constraintEqualToAnchor:R.leadingAnchor constant:16],
        [_viCard.trailingAnchor constraintEqualToAnchor:R.centerXAnchor constant:-8],

        [_enCard.topAnchor    constraintEqualToAnchor:_viCard.topAnchor],
        [_enCard.leadingAnchor  constraintEqualToAnchor:R.centerXAnchor constant:8],
        [_enCard.trailingAnchor constraintEqualToAnchor:R.trailingAnchor constant:-16],

        // Confirm button
        [_confirmBtn.topAnchor    constraintEqualToAnchor:_viCard.bottomAnchor constant:20],
        [_confirmBtn.leadingAnchor  constraintEqualToAnchor:R.leadingAnchor constant:16],
        [_confirmBtn.trailingAnchor constraintEqualToAnchor:R.trailingAnchor constant:-16],
        [_confirmBtn.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Set frame cho các CAGradientLayer theo bounds thực sau layout
    _chipGrad.frame = _globeChip.bounds;
    _divGrad.frame  = _divLine.bounds;
    _btnGrad.frame  = _confirmBtn.bounds;
}

// ── Tap handlers ─────────────────────────────────────────────────────────────

- (void)tappedVI { [self selectCard:_viCard language:AppLanguageVietnamese]; }
- (void)tappedEN { [self selectCard:_enCard language:AppLanguageEnglish]; }

- (void)selectCard:(LangCard *)card language:(AppLanguage)lang {
    if (_pending == lang) return;
    _pending = lang;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    // Scale bounce
    [UIView animateWithDuration:0.12 animations:^{
        card.transform = CGAffineTransformMakeScale(0.93, 0.93);
    } completion:^(BOOL _) {
        [UIView animateWithDuration:0.22 delay:0
             usingSpringWithDamping:0.50 initialSpringVelocity:6
                            options:0
                         animations:^{ card.transform = CGAffineTransformIdentity; }
                         completion:nil];
    }];

    [_viCard setSelected:(lang == AppLanguageVietnamese) animated:YES];
    [_enCard setSelected:(lang == AppLanguageEnglish)    animated:YES];
}

- (void)confirmTapped {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    [LanguageManager shared].language = _pending;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"delta_lang_chosen"];

    // Capture callback và dùng weakSelf để tránh crash nếu VC bị deallocate
    __weak typeof(self) weakSelf = self;
    void (^dismissBlock)(void) = self.onDismiss ? [self.onDismiss copy] : nil;

    [UIView animateWithDuration:0.10 animations:^{
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return;
        s->_confirmBtn.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL _) {
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) { if (dismissBlock) dismissBlock(); return; }
        [UIView animateWithDuration:0.14 animations:^{
            s->_confirmBtn.transform = CGAffineTransformIdentity;
        } completion:^(BOOL __) {
            [s dismissViewControllerAnimated:YES completion:^{
                if (dismissBlock) dismissBlock();
            }];
        }];
    }];
}

@end
