#import "HUDControlViewController.h"
#import "AutoPasteManager.h"

// ── Palette ─────────────────────────────────────────────
#define HUD_BG_TOP      [UIColor colorWithRed:0.059 green:0.059 blue:0.102 alpha:1.0]  // #0F0F1A
#define HUD_BG_BOTTOM   [UIColor colorWithRed:0.086 green:0.129 blue:0.243 alpha:1.0]  // #16213E
#define HUD_PANEL       [UIColor colorWithRed:0.102 green:0.102 blue:0.180 alpha:1.0]  // #1A1A2E
#define HUD_ORANGE      [UIColor colorWithRed:1.000 green:0.361 blue:0.169 alpha:1.0]  // #FF5C2B
#define HUD_RED         [UIColor colorWithRed:1.000 green:0.169 blue:0.306 alpha:1.0]  // #FF2B4E
#define HUD_CYAN        [UIColor colorWithRed:0.000 green:0.831 blue:1.000 alpha:1.0]  // #00D4FF
#define HUD_MUTED       [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0]  // #8F8FA8
#define HUD_GREEN       [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]  // #34C759
#define HUD_TEXT        [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0]

@interface HUDControlViewController ()
@property (nonatomic, copy)   NSString *bundleID;
@property (nonatomic, copy)   NSString *appName;
@property (nonatomic, strong) UIImage  *icon;

@property (nonatomic, strong) CAGradientLayer *bgGradient;
@property (nonatomic, strong) UISwitch  *serverSwitch;
@property (nonatomic, strong) UIView    *pill1;
@property (nonatomic, strong) UIView    *pill2;
@property (nonatomic, strong) UILabel   *pill1Label;
@property (nonatomic, strong) UILabel   *pill2Label;
@property (nonatomic, strong) UIButton  *pasteButton;
@property (nonatomic, strong) CAGradientLayer *buttonGradient;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel   *statusLabel;
@property (nonatomic, weak)   UIView    *headerBottomAnchorView;
@end

@implementation HUDControlViewController

- (instancetype)initWithBundleID:(NSString *)bundleID appName:(NSString *)appName icon:(UIImage *)icon {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _bundleID = [bundleID copy];
        _appName  = [appName copy];
        _icon     = icon;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.appName;

    // Background gradient
    self.bgGradient = [CAGradientLayer layer];
    self.bgGradient.colors = @[(id)HUD_BG_TOP.CGColor, (id)HUD_BG_BOTTOM.CGColor];
    self.bgGradient.startPoint = CGPointMake(0.5, 0.0);
    self.bgGradient.endPoint   = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:self.bgGradient atIndex:0];

    [self buildHeader];
    [self buildPanel];
    [self buildPasteButton];
    [self buildStatus];
    [self refreshPills];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgGradient.frame = self.view.bounds;
    self.buttonGradient.frame = self.pasteButton.bounds;
}

#pragma mark - Header (icon + name + bundle)

- (void)buildHeader {
    UIImageView *iconView = [[UIImageView alloc] initWithImage:self.icon];
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.clipsToBounds = YES;
    iconView.layer.cornerRadius = 22;
    iconView.layer.cornerCurve = kCACornerCurveContinuous;
    iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    iconView.layer.borderWidth = 1;
    iconView.layer.magnificationFilter = kCAFilterTrilinear;
    // soft glow
    iconView.layer.shadowColor = HUD_CYAN.CGColor;
    iconView.layer.shadowOpacity = 0.5;
    iconView.layer.shadowRadius = 16;
    iconView.layer.shadowOffset = CGSizeMake(0, 4);
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = self.appName;
    nameLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    nameLabel.textColor = HUD_TEXT;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:nameLabel];

    UILabel *bundleLabel = [[UILabel alloc] init];
    bundleLabel.text = self.bundleID;
    bundleLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    bundleLabel.textColor = HUD_MUTED;
    bundleLabel.textAlignment = NSTextAlignmentCenter;
    bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bundleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:96],
        [iconView.heightAnchor constraintEqualToConstant:96],

        [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:16],
        [nameLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [nameLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [bundleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [bundleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [bundleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];

    self.headerBottomAnchorView = bundleLabel;
}

#pragma mark - Config panel

- (void)buildPanel {
    UIView *panel = [[UIView alloc] init];
    panel.backgroundColor = HUD_PANEL;
    panel.layer.cornerRadius = 20;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.borderColor = [HUD_CYAN colorWithAlphaComponent:0.25].CGColor;
    panel.layer.borderWidth = 1;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:panel];

    // Section title
    UILabel *header = [[UILabel alloc] init];
    header.text = @"⚙️  Paste Configuration";
    header.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    header.textColor = HUD_TEXT;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:header];

    // Server mode row
    UILabel *modeLabel = [[UILabel alloc] init];
    modeLabel.text = @"📡  Server Mode";
    modeLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    modeLabel.textColor = HUD_TEXT;
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:modeLabel];

    self.serverSwitch = [[UISwitch alloc] init];
    self.serverSwitch.onTintColor = HUD_ORANGE;
    self.serverSwitch.on = NO; // default → Server 2 (gốc)
    [self.serverSwitch addTarget:self action:@selector(toggleChanged) forControlEvents:UIControlEventValueChanged];
    self.serverSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.serverSwitch];

    // Two server pills
    self.pill1 = [self makePillInto:panel labelOut:&_pill1Label];
    self.pill2 = [self makePillInto:panel labelOut:&_pill2Label];
    self.pill1Label.text = @"Server 1 · Pastebody (MOD)";
    self.pill2Label.text = @"Server 2 · Pastebodygoc (GỐC)";

    [NSLayoutConstraint activateConstraints:@[
        [panel.topAnchor constraintEqualToAnchor:self.headerBottomAnchorView.bottomAnchor constant:28],
        [panel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [panel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [header.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [header.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],

        [modeLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18],
        [modeLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [self.serverSwitch.centerYAnchor constraintEqualToAnchor:modeLabel.centerYAnchor],
        [self.serverSwitch.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],

        [self.pill1.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:16],
        [self.pill1.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [self.pill1.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
        [self.pill1.heightAnchor constraintEqualToConstant:40],

        [self.pill2.topAnchor constraintEqualToAnchor:self.pill1.bottomAnchor constant:10],
        [self.pill2.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [self.pill2.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
        [self.pill2.heightAnchor constraintEqualToConstant:40],
        [self.pill2.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18],
    ]];
}

- (UIView *)makePillInto:(UIView *)parent labelOut:(UILabel * __strong *)labelOut {
    UIView *pill = [[UIView alloc] init];
    pill.layer.cornerRadius = 12;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.borderWidth = 1;
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:pill];

    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [pill addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:14],
        [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-14],
    ]];

    *labelOut = label;
    return pill;
}

- (void)refreshPills {
    BOOL server1 = self.serverSwitch.on;
    [self stylePill:self.pill1 label:self.pill1Label active:server1];
    [self stylePill:self.pill2 label:self.pill2Label active:!server1];
}

- (void)stylePill:(UIView *)pill label:(UILabel *)label active:(BOOL)active {
    if (active) {
        pill.backgroundColor = [HUD_CYAN colorWithAlphaComponent:0.18];
        pill.layer.borderColor = HUD_CYAN.CGColor;
        label.textColor = HUD_CYAN;
        label.text = [@"✓  " stringByAppendingString:[self stripMark:label.text]];
    } else {
        pill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.04];
        pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        label.textColor = HUD_MUTED;
        label.text = [@"○  " stringByAppendingString:[self stripMark:label.text]];
    }
}

- (NSString *)stripMark:(NSString *)s {
    NSString *r = s ?: @"";
    r = [r stringByReplacingOccurrencesOfString:@"✓  " withString:@""];
    r = [r stringByReplacingOccurrencesOfString:@"○  " withString:@""];
    return r;
}

#pragma mark - Paste button

- (void)buildPasteButton {
    self.pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.pasteButton setTitle:@"📋   PASTE NOW" forState:UIControlStateNormal];
    [self.pasteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.pasteButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.pasteButton.layer.cornerRadius = 16;
    self.pasteButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.pasteButton.clipsToBounds = YES;
    self.pasteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pasteButton addTarget:self action:@selector(pasteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.pasteButton];

    self.buttonGradient = [CAGradientLayer layer];
    self.buttonGradient.colors = @[(id)HUD_ORANGE.CGColor, (id)HUD_RED.CGColor];
    self.buttonGradient.startPoint = CGPointMake(0, 0.5);
    self.buttonGradient.endPoint   = CGPointMake(1, 0.5);
    self.buttonGradient.cornerRadius = 16;
    [self.pasteButton.layer insertSublayer:self.buttonGradient atIndex:0];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pasteButton addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.pasteButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.pasteButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.pasteButton.heightAnchor constraintEqualToConstant:56],
        [self.pasteButton.topAnchor constraintEqualToAnchor:self.pill2.superview.bottomAnchor constant:28],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.pasteButton.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.pasteButton.centerYAnchor],
    ]];
}

#pragma mark - Status

- (void)buildStatus {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Ready — chọn server rồi bấm Paste";
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.statusLabel.textColor = HUD_MUTED;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.pasteButton.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];
}

#pragma mark - Actions

- (void)toggleChanged {
    [self refreshPills];
    UISelectionFeedbackGenerator *fb = [[UISelectionFeedbackGenerator alloc] init];
    [fb selectionChanged];
    NSString *name = self.serverSwitch.on ? @"Server 1 (MOD)" : @"Server 2 (GỐC)";
    [self setStatus:[NSString stringWithFormat:@"Đã chọn %@", name] color:HUD_CYAN];
}

- (void)pasteTapped {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    [self setLoading:YES];
    [self setStatus:@"Đang tải file từ server…" color:HUD_MUTED];

    BOOL server1 = self.serverSwitch.on;
    __weak typeof(self) weakSelf = self;
    [[AutoPasteManager sharedManager] pasteFileWithServerMode:server1
                                                      bundleID:self.bundleID
                                                    completion:^(BOOL success, NSString *message) {
        [weakSelf setLoading:NO];
        [weakSelf setStatus:message color:(success ? HUD_GREEN : HUD_RED)];
        UINotificationFeedbackGenerator *nfb = [[UINotificationFeedbackGenerator alloc] init];
        [nfb notificationOccurred:(success ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError)];
    }];
}

- (void)setLoading:(BOOL)loading {
    if (loading) {
        [self.spinner startAnimating];
        [self.pasteButton setTitle:@"" forState:UIControlStateNormal];
        self.pasteButton.userInteractionEnabled = NO;
        self.pasteButton.alpha = 0.85;
    } else {
        [self.spinner stopAnimating];
        [self.pasteButton setTitle:@"📋   PASTE NOW" forState:UIControlStateNormal];
        self.pasteButton.userInteractionEnabled = YES;
        self.pasteButton.alpha = 1.0;
    }
}

- (void)setStatus:(NSString *)text color:(UIColor *)color {
    self.statusLabel.textColor = color;
    self.statusLabel.text = text;
    self.statusLabel.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.statusLabel.alpha = 1; }];
}

@end
