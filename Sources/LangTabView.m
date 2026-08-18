#import "LangTabView.h"
#import "LanguageManager.h"

// Colors (duplicated from BrandTheme to avoid import cycle)
#define LT_CYAN  [UIColor colorWithRed:0.000 green:0.831 blue:1.000 alpha:1.0]
#define LT_GREEN [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define LT_BG    [UIColor colorWithRed:0.078 green:0.086 blue:0.157 alpha:0.94]

@implementation LangTabView {
    UILabel *_textLabel;
    UIView  *_accentLine; // left-edge color stripe
}

// ── Public install API ───────────────────────────────────────────────────────

+ (void)installOnWindow:(UIWindow *)window {
    LangTabView *tab = [[LangTabView alloc] initWithFrame:CGRectZero];
    tab.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:tab];

    [NSLayoutConstraint activateConstraints:@[
        // Flush against the right edge of the window
        [tab.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
        // Vertically centered, shifted slightly above center
        [tab.centerYAnchor constraintEqualToAnchor:window.centerYAnchor constant:-50],
        [tab.widthAnchor  constraintEqualToConstant:38],
        [tab.heightAnchor constraintEqualToConstant:68],
    ]];
}

// ── Init ─────────────────────────────────────────────────────────────────────

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    // Background — dark glass, rounded on the left only
    self.backgroundColor = LT_BG;
    self.layer.cornerRadius = 12;
    self.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;

    // Subtle border (left + top + bottom only; right is flush with screen edge)
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    self.layer.borderWidth = 1;

    // Drop-shadow towards the left
    self.layer.shadowColor  = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.45;
    self.layer.shadowOffset  = CGSizeMake(-3, 0);
    self.layer.shadowRadius  = 8;

    // Colored accent stripe on the left edge
    _accentLine = [[UIView alloc] init];
    _accentLine.layer.cornerRadius = 2;
    _accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_accentLine];

    // Language label
    _textLabel = [[UILabel alloc] init];
    _textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_textLabel];

    [NSLayoutConstraint activateConstraints:@[
        // Accent stripe: 3pt wide, inset 4pt from left, 12pt from top/bottom
        [_accentLine.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:4],
        [_accentLine.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:12],
        [_accentLine.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-12],
        [_accentLine.widthAnchor    constraintEqualToConstant:3],

        // Label fills remaining width
        [_textLabel.leadingAnchor   constraintEqualToAnchor:_accentLine.trailingAnchor constant:2],
        [_textLabel.trailingAnchor  constraintEqualToAnchor:self.trailingAnchor],
        [_textLabel.centerYAnchor   constraintEqualToAnchor:self.centerYAnchor],
    ]];

    // Touch
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(_tapped)];
    [self addGestureRecognizer:tap];

    // Language change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(_refresh)
        name:LMLanguageChangedNotification object:nil];

    [self _refresh];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ── Private ───────────────────────────────────────────────────────────────────

- (void)_refresh {
    BOOL isVI = ([LanguageManager shared].language == AppLanguageVietnamese);
    _textLabel.text       = isVI ? @"VI" : @"EN";
    _textLabel.textColor  = isVI ? LT_CYAN : LT_GREEN;
    _accentLine.backgroundColor = isVI ? LT_CYAN : LT_GREEN;
}

- (void)_tapped {
    LanguageManager *lm = [LanguageManager shared];
    lm.language = (lm.language == AppLanguageVietnamese)
        ? AppLanguageEnglish
        : AppLanguageVietnamese;

    // Brief scale bounce for feedback
    [UIView animateWithDuration:0.10 animations:^{
        self.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL _) {
        [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.5
            initialSpringVelocity:6 options:0 animations:^{
                self.transform = CGAffineTransformIdentity;
            } completion:nil];
    }];
}

// Pass-through touches outside this view's bounds so content below isn't blocked
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [super pointInside:point withEvent:event];
}

@end
