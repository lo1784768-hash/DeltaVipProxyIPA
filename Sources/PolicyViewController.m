#import "PolicyViewController.h"
#import "BrandTheme.h"
#import "LanguageManager.h"

// ── Palette ──────────────────────────────────────────────────────────────────
#define PV_BG       [UIColor colorWithRed:0.032 green:0.036 blue:0.063 alpha:1.0]
#define PV_CYAN     BRAND_CYAN
#define PV_PURPLE   BRAND_PURPLE
#define PV_GREEN    BRAND_GREEN
#define PV_TEXT     BRAND_TEXT
#define PV_MUTED    BRAND_MUTED
#define PV_CARD     [UIColor colorWithRed:0.055 green:0.06 blue:0.11 alpha:0.65]

static NSString *const kPolicyAcceptedKey = @"policy_accepted";

// ── Accordion Section Model ──────────────────────────────────────────────────
@interface PVSection : NSObject
@property (nonatomic, copy)   NSString *icon;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *body;
@property (nonatomic, strong) UIColor  *accentColor;
@property (nonatomic, assign) BOOL      expanded;
@end
@implementation PVSection @end

// ── Accordion Row View ────────────────────────────────────────────────────────
@interface PVAccordionRow : UIView
@property (nonatomic, strong) PVSection *section;
@property (nonatomic, strong) UILabel   *bodyLabel;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, copy)   void (^onToggle)(PVAccordionRow *);
- (instancetype)initWithSection:(PVSection *)section;
- (void)applyExpandedState:(BOOL)animated;
@end

@implementation PVAccordionRow {
    UIView *_headerRow;
    NSLayoutConstraint *_bodyHeight;
}

- (instancetype)initWithSection:(PVSection *)section {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _section = section;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.clipsToBounds = YES;

    // ── Header ──────────────────────────────────────────────────────────────
    _headerRow = [[UIView alloc] init];
    _headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    _headerRow.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped)];
    [_headerRow addGestureRecognizer:tap];
    [self addSubview:_headerRow];

    // Icon chip
    UIView *chip = [[UIView alloc] init];
    chip.backgroundColor = [section.accentColor colorWithAlphaComponent:0.18];
    chip.layer.cornerRadius = 10;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    chip.layer.borderColor = [section.accentColor colorWithAlphaComponent:0.40].CGColor;
    chip.layer.borderWidth = 1;
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerRow addSubview:chip];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:section.icon withConfiguration:cfg]];
    iconView.tintColor = section.accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = section.title;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLabel.textColor = PV_TEXT;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerRow addSubview:titleLabel];

    // Chevron
    UIImageSymbolConfiguration *chCfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:chCfg]];
    _chevron.tintColor = PV_MUTED;
    _chevron.contentMode = UIViewContentModeScaleAspectFit;
    _chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerRow addSubview:_chevron];

    // ── Body ─────────────────────────────────────────────────────────────────
    _bodyLabel = [[UILabel alloc] init];
    _bodyLabel.text = section.body;
    _bodyLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _bodyLabel.textColor = [PV_TEXT colorWithAlphaComponent:0.80];
    _bodyLabel.numberOfLines = 0;
    _bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_bodyLabel];

    // Separator
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:sep];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Header row
        [_headerRow.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_headerRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_headerRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_headerRow.heightAnchor constraintEqualToConstant:54],

        // Chip
        [chip.leadingAnchor constraintEqualToAnchor:_headerRow.leadingAnchor constant:16],
        [chip.centerYAnchor constraintEqualToAnchor:_headerRow.centerYAnchor],
        [chip.widthAnchor constraintEqualToConstant:34],
        [chip.heightAnchor constraintEqualToConstant:34],

        [iconView.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],

        [titleLabel.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
        [titleLabel.centerYAnchor constraintEqualToAnchor:_headerRow.centerYAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevron.leadingAnchor constant:-8],

        [_chevron.trailingAnchor constraintEqualToAnchor:_headerRow.trailingAnchor constant:-16],
        [_chevron.centerYAnchor constraintEqualToAnchor:_headerRow.centerYAnchor],
        [_chevron.widthAnchor constraintEqualToConstant:14],
        [_chevron.heightAnchor constraintEqualToConstant:14],

        // Body
        [_bodyLabel.topAnchor constraintEqualToAnchor:_headerRow.bottomAnchor constant:0],
        [_bodyLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_bodyLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],

        // Separator
        [sep.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [sep.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [sep.heightAnchor constraintEqualToConstant:0.5],
    ]];

    // Dynamically track collapsed / expanded bottom
    // collapsed: bottom = header bottom; expanded: bottom = bodyLabel bottom + padding
    _bodyHeight = [self.bottomAnchor constraintEqualToAnchor:_headerRow.bottomAnchor];
    _bodyHeight.active = YES;

    return self;
}

- (void)headerTapped {
    _section.expanded = !_section.expanded;
    if (self.onToggle) self.onToggle(self);
}

- (void)applyExpandedState:(BOOL)animated {
    BOOL open = _section.expanded;
    void (^changes)(void) = ^{
        self->_chevron.transform = open
            ? CGAffineTransformMakeRotation(M_PI_2)
            : CGAffineTransformIdentity;
        self->_bodyLabel.alpha = open ? 1 : 0;

        [self->_bodyHeight setActive:NO];
        if (open) {
            // Need body to show: pin bottom below bodyLabel
            self->_bodyHeight = [self.bottomAnchor
                constraintEqualToAnchor:self->_bodyLabel.bottomAnchor constant:16];
        } else {
            self->_bodyHeight = [self.bottomAnchor
                constraintEqualToAnchor:self->_headerRow.bottomAnchor];
        }
        [self->_bodyHeight setActive:YES];
        [self layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.30
                              delay:0
             usingSpringWithDamping:0.80
              initialSpringVelocity:0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
#pragma mark - PolicyViewController
// ═══════════════════════════════════════════════════════════════════════════════

@interface PolicyViewController ()
@property (nonatomic, strong) NSArray<PVSection *> *sections;
@property (nonatomic, strong) NSMutableArray<PVAccordionRow *> *rows;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView  *accordionStack;
@property (nonatomic, strong) UIButton     *agreeButton;
@property (nonatomic, strong) CAGradientLayer *agreeGradient;
@end

@implementation PolicyViewController

+ (BOOL)hasAccepted {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPolicyAcceptedKey];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupData];
    [self buildUI];
}

- (void)setupData {
    PVSection *s1 = [PVSection new];
    s1.icon = @"key.fill";
    s1.accentColor = PV_CYAN;
    s1.title = LS(@"Quy Định License Key & HWID", @"License Key & HWID Policy");
    s1.body  = LS(
        @"• Mỗi License Key chỉ được bind với 1 thiết bị duy nhất (HWID).\n"
        @"• Sau khi kích hoạt, key sẽ bị khóa vào thiết bị và không thể chuyển sang thiết bị khác.\n"
        @"• Nếu muốn chuyển thiết bị, liên hệ Admin để reset — phí chuyển thiết bị có thể áp dụng.\n"
        @"• Key hết hạn sẽ tự động vô hiệu hóa tính năng — gia hạn qua kênh chính thức.\n"
        @"• Nghiêm cấm chia sẻ, bán lại hoặc cho mượn key.",

        @"• Each License Key is bound to 1 device only (HWID).\n"
        @"• Once activated, the key is locked to your device and cannot be transferred.\n"
        @"• To transfer devices, contact Admin — a transfer fee may apply.\n"
        @"• Expired keys will automatically disable features — renew through official channels.\n"
        @"• Sharing, reselling or lending keys is strictly prohibited."
    );
    s1.expanded = YES;   // mặc định section 1 mở

    PVSection *s2 = [PVSection new];
    s2.icon = @"exclamationmark.shield.fill";
    s2.accentColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0];
    s2.title = LS(@"Tuyên Bố Miễn Trừ Trách Nhiệm", @"Disclaimer");
    s2.body  = LS(
        @"• DELTA IPA VN được cung cấp 'như hiện tại' (as-is) — không có bất kỳ bảo hành nào.\n"
        @"• Chúng tôi không chịu trách nhiệm về bất kỳ thiệt hại nào phát sinh từ việc sử dụng ứng dụng.\n"
        @"• Ứng dụng có thể bị gián đoạn do cập nhật game — trong trường hợp này không hoàn tiền.\n"
        @"• Người dùng hoàn toàn chịu trách nhiệm về việc sử dụng tool, bao gồm mọi hệ quả từ nhà phát hành game.\n"
        @"• Chúng tôi có quyền thay đổi tính năng hoặc ngừng dịch vụ bất kỳ lúc nào.",

        @"• DELTA IPA VN is provided 'as-is' — without any warranty.\n"
        @"• We are not responsible for any damages arising from the use of this application.\n"
        @"• The app may be interrupted due to game updates — no refunds in such cases.\n"
        @"• Users are solely responsible for their use of the tool, including any consequences from the game publisher.\n"
        @"• We reserve the right to change features or discontinue the service at any time."
    );

    PVSection *s3 = [PVSection new];
    s3.icon = @"lock.shield.fill";
    s3.accentColor = PV_GREEN;
    s3.title = LS(@"Hướng Dẫn An Toàn & Bảo Mật", @"Safety & Privacy Guidelines");
    s3.body  = LS(
        @"• Không bao giờ cung cấp thông tin tài khoản game hoặc mật khẩu cho bất kỳ ai.\n"
        @"• Chỉ tải ứng dụng từ kênh chính thức của DELTA IPA VN — tránh bản clone/giả mạo.\n"
        @"• DELTA IPA VN KHÔNG thu thập mật khẩu, tài khoản game hoặc thông tin thanh toán.\n"
        @"• Thông tin duy nhất được lưu: HWID (để bind key) và trạng thái key.\n"
        @"• Khi phát hiện bất thường (key bị dùng nơi khác, v.v.), liên hệ Admin ngay lập tức.",

        @"• Never share your game account or password with anyone.\n"
        @"• Only download the app from official DELTA IPA VN channels — avoid clones/fakes.\n"
        @"• DELTA IPA VN does NOT collect passwords, game accounts, or payment information.\n"
        @"• The only information stored: HWID (for key binding) and key status.\n"
        @"• If you notice anything unusual (key being used elsewhere, etc.), contact Admin immediately."
    );

    self.sections = @[s1, s2, s3];
    self.rows = [NSMutableArray array];
}

- (void)buildUI {
    // ── Background blur + gradient ─────────────────────────────────────────
    UIVisualEffectView *blurBg = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blurBg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:blurBg];
    [NSLayoutConstraint activateConstraints:@[
        [blurBg.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [blurBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [blurBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [blurBg.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Subtle dark overlay
    UIView *overlay = [[UIView alloc] init];
    overlay.backgroundColor = [UIColor colorWithRed:0.032 green:0.036 blue:0.063 alpha:0.72];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Radial glow top
    CAGradientLayer *radial = [CAGradientLayer layer];
    radial.type = kCAGradientLayerRadial;
    radial.colors = @[(id)[PV_PURPLE colorWithAlphaComponent:0.28].CGColor,
                      (id)[PV_PURPLE colorWithAlphaComponent:0.0].CGColor];
    radial.startPoint = CGPointMake(0.5, 0.5);
    radial.endPoint   = CGPointMake(1.0, 1.0);
    radial.frame = CGRectMake(self.view.bounds.size.width/2 - 200, -40, 400, 400);
    [overlay.layer addSublayer:radial];

    // ── Top handle ────────────────────────────────────────────────────────
    UIView *handle = [[UIView alloc] init];
    handle.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25];
    handle.layer.cornerRadius = 2.5;
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:handle];

    // ── Header ────────────────────────────────────────────────────────────
    UIImageSymbolConfiguration *shieldCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImageView *shieldIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shield.lefthalf.filled" withConfiguration:shieldCfg]];
    shieldIcon.tintColor = PV_CYAN;
    shieldIcon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *headerTitle = [[UILabel alloc] init];
    headerTitle.text = LS(@"CHÍNH SÁCH & ĐIỀU KHOẢN\nSỬ DỤNG", @"TERMS & POLICY");
    headerTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    headerTitle.textColor = PV_TEXT;
    headerTitle.textAlignment = NSTextAlignmentCenter;
    headerTitle.numberOfLines = 2;
    headerTitle.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *headerSub = [[UILabel alloc] init];
    headerSub.text = LS(@"Vui lòng đọc kỹ trước khi sử dụng dịch vụ",
                        @"Please read carefully before using the service");
    headerSub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    headerSub.textColor = PV_MUTED;
    headerSub.textAlignment = NSTextAlignmentCenter;
    headerSub.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:shieldIcon];
    [self.view addSubview:headerTitle];
    [self.view addSubview:headerSub];

    // ── Scroll + Accordion ────────────────────────────────────────────────
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    // Glass card container
    UIVisualEffectView *card = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    card.clipsToBounds = YES;
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    card.layer.borderWidth = 1;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:card];

    self.accordionStack = [[UIStackView alloc] init];
    self.accordionStack.axis = UILayoutConstraintAxisVertical;
    self.accordionStack.spacing = 0;
    self.accordionStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card.contentView addSubview:self.accordionStack];

    for (PVSection *sec in self.sections) {
        PVAccordionRow *row = [[PVAccordionRow alloc] initWithSection:sec];
        __weak typeof(self) weakSelf = self;
        row.onToggle = ^(PVAccordionRow *r) { [weakSelf rowToggled:r]; };
        [self.rows addObject:row];
        [self.accordionStack addArrangedSubview:row];
        [row applyExpandedState:NO]; // set initial state without animation
    }

    // ── Agree Button ──────────────────────────────────────────────────────
    self.agreeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.agreeButton setTitle:LS(@"✓  Tôi Đã Hiểu và Đồng Ý", @"✓  I Understand and Agree")
                      forState:UIControlStateNormal];
    [self.agreeButton setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0]
                           forState:UIControlStateNormal];
    self.agreeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy];
    self.agreeButton.layer.cornerRadius = 16;
    self.agreeButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.agreeButton.clipsToBounds = YES;
    self.agreeButton.layer.shadowColor = PV_CYAN.CGColor;
    self.agreeButton.layer.shadowOpacity = 0.45;
    self.agreeButton.layer.shadowRadius = 12;
    self.agreeButton.layer.shadowOffset = CGSizeZero;
    self.agreeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.agreeButton addTarget:self action:@selector(agreeTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.agreeButton];

    self.agreeGradient = BrandGradient();
    self.agreeGradient.cornerRadius = 16;
    [self.agreeButton.layer insertSublayer:self.agreeGradient atIndex:0];

    // ── Constraints ───────────────────────────────────────────────────────
    [NSLayoutConstraint activateConstraints:@[
        // Handle
        [handle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        // Shield icon
        [shieldIcon.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:20],
        [shieldIcon.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        // Header title
        [headerTitle.topAnchor constraintEqualToAnchor:shieldIcon.bottomAnchor constant:10],
        [headerTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [headerTitle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        // Header subtitle
        [headerSub.topAnchor constraintEqualToAnchor:headerTitle.bottomAnchor constant:6],
        [headerSub.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [headerSub.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        // Scroll
        [self.scrollView.topAnchor constraintEqualToAnchor:headerSub.bottomAnchor constant:20],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.agreeButton.topAnchor constant:-16],

        // Card inside scroll
        [card.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [card.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        // Accordion stack inside card
        [self.accordionStack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor],
        [self.accordionStack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor],
        [self.accordionStack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor],
        [self.accordionStack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor],

        // Agree button
        [self.agreeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.agreeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.agreeButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.agreeButton.heightAnchor constraintEqualToConstant:54],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.agreeGradient.frame = self.agreeButton.bounds;
}

- (void)rowToggled:(PVAccordionRow *)toggled {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    [toggled applyExpandedState:YES];
    // Trigger layout so the scroll view content size updates
    [UIView animateWithDuration:0.30 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)agreeTapped {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPolicyAcceptedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
