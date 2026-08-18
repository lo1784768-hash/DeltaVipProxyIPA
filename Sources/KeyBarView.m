#import "KeyBarView.h"
#import "KeyManager.h"
#import "BrandTheme.h"
#import "LanguageManager.h"

#define KB_GREEN [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]
#define KB_RED   [UIColor colorWithRed:1.000 green:0.231 blue:0.322 alpha:1.0]
#define KB_CYAN  [UIColor colorWithRed:0.000 green:0.831 blue:1.000 alpha:1.0]
#define KB_MUTED [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0]
#define KB_TEXT  [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0]

@interface KeyBarView ()
@property (nonatomic, strong) UIView   *dot;
@property (nonatomic, strong) UILabel  *titleLabel;
@property (nonatomic, strong) UILabel  *subLabel;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UIView   *topLine;
@property (nonatomic, strong) CAGradientLayer *addGradient;
@property (nonatomic, strong) CAGradientLayer *lineGradient;
@end

@implementation KeyBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self build];
        [self update];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(onLanguageChanged)
            name:LMLanguageChangedNotification
            object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLanguageChanged {
    [self update];
}

- (void)build {
    self.backgroundColor = [UIColor colorWithRed:0.078 green:0.086 blue:0.157 alpha:0.98];

    // vạch trên gradient tím→cyan
    _topLine = [[UIView alloc] init];
    _topLine.backgroundColor = [UIColor clearColor];
    _topLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_topLine];
    _lineGradient = [CAGradientLayer layer];
    _lineGradient.colors = @[(id)[BRAND_PURPLE colorWithAlphaComponent:0.0].CGColor,
                             (id)BRAND_PURPLE.CGColor,
                             (id)BRAND_CYAN.CGColor,
                             (id)[BRAND_CYAN colorWithAlphaComponent:0.0].CGColor];
    _lineGradient.startPoint = CGPointMake(0, 0.5);
    _lineGradient.endPoint   = CGPointMake(1, 0.5);
    [_topLine.layer addSublayer:_lineGradient];

    _dot = [[UIView alloc] init];
    _dot.layer.cornerRadius = 5;
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

    _addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    [_addButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0] forState:UIControlStateNormal];
    _addButton.layer.cornerRadius = 11;
    _addButton.layer.cornerCurve = kCACornerCurveContinuous;
    _addButton.clipsToBounds = YES;
    _addButton.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    _addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addButton addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_addButton];

    _addGradient = BrandGradient();
    _addGradient.cornerRadius = 11;
    [_addButton.layer insertSublayer:_addGradient atIndex:0];

    // Info button — xem/copy UDID
    _infoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_infoButton setImage:[UIImage systemImageNamed:@"info.circle"] forState:UIControlStateNormal];
    _infoButton.tintColor = KB_MUTED;
    _infoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_infoButton addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_infoButton];

    [NSLayoutConstraint activateConstraints:@[
        [_topLine.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_topLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_topLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_topLine.heightAnchor constraintEqualToConstant:1],

        [_dot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
        [_dot.topAnchor constraintEqualToAnchor:self.topAnchor constant:22],
        [_dot.widthAnchor constraintEqualToConstant:10],
        [_dot.heightAnchor constraintEqualToConstant:10],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_dot.trailingAnchor constant:10],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],

        [_subLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],

        [_addButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_addButton.centerYAnchor constraintEqualToAnchor:self.topAnchor constant:31],
        [_addButton.heightAnchor constraintEqualToConstant:36],

        [_infoButton.trailingAnchor constraintEqualToAnchor:_addButton.leadingAnchor constant:-4],
        [_infoButton.centerYAnchor constraintEqualToAnchor:_addButton.centerYAnchor],
        [_infoButton.widthAnchor constraintEqualToConstant:32],
        [_infoButton.heightAnchor constraintEqualToConstant:36],

        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_infoButton.leadingAnchor constant:-8],
        [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_infoButton.leadingAnchor constant:-8],
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
        case KeyStateActive: {
            _dot.backgroundColor = KB_GREEN;
            [self glowDot:KB_GREEN];
            _titleLabel.text = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _subLabel.text = km.formattedRemaining;
            _subLabel.textColor = KB_GREEN;
            [_addButton setTitle:LS(@"Đổi Key", @"Change Key") forState:UIControlStateNormal];
            break;
        }
        case KeyStateExpired: {
            _dot.backgroundColor = KB_RED;
            [self glowDot:KB_RED];
            _titleLabel.text = [NSString stringWithFormat:@"KEY  %@", [self maskKey:km.keyCode]];
            _subLabel.text = LS(@"Đã hết hạn — vui lòng gia hạn", @"Expired — please renew");
            _subLabel.textColor = KB_RED;
            [_addButton setTitle:LS(@"Gia hạn", @"Renew") forState:UIControlStateNormal];
            break;
        }
        default: {
            _dot.backgroundColor = KB_MUTED;
            [self glowDot:nil];
            _titleLabel.text = LS(@"License Key", @"License Key");
            _subLabel.text = LS(@"Chưa kích hoạt — nhấn Thêm Key", @"Not activated — tap Add Key");
            _subLabel.textColor = KB_MUTED;
            [_addButton setTitle:LS(@"Thêm Key", @"Add Key") forState:UIControlStateNormal];
            break;
        }
    }
}

- (void)glowDot:(UIColor *)color {
    if (color) {
        _dot.layer.shadowColor = color.CGColor;
        _dot.layer.shadowOpacity = 0.9;
        _dot.layer.shadowRadius = 5;
        _dot.layer.shadowOffset = CGSizeZero;
    } else {
        _dot.layer.shadowOpacity = 0;
    }
}

- (NSString *)maskKey:(NSString *)key {
    if (key.length <= 8) return key ?: @"";
    NSString *head = [key substringToIndex:4];
    NSString *tail = [key substringFromIndex:key.length - 4];
    return [NSString stringWithFormat:@"%@••••%@", head, tail];
}

- (void)addTapped {
    if (self.onAddTapped) self.onAddTapped();
}

- (void)infoTapped {
    if (self.onInfoTapped) self.onInfoTapped();
}

@end
