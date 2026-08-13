#import "HUDPanelView.h"

@interface HUDPanelView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSString *bundleID;
@end

@implementation HUDPanelView

- (instancetype)initWithFrame:(CGRect)frame appName:(NSString *)appName bundleID:(NSString *)bundleID {
    self = [super initWithFrame:frame];
    if (self) {
        self.appName = appName;
        self.bundleID = bundleID;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // Background with glassmorphism
    self.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
    self.layer.cornerRadius = 16;
    self.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.3].CGColor;
    self.layer.borderWidth = 1;

    // Shadow
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.3;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;

    // Blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:blurView];
    [self sendSubviewToBack:blurView];

    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = [NSString stringWithFormat:@"🎛️ %@", self.appName];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.titleLabel.textColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12]
    ]];

    // Divider
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.2];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:divider];

    [NSLayoutConstraint activateConstraints:@[
        [divider.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [divider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [divider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [divider.heightAnchor constraintEqualToConstant:0.5]
    ]];

    // Server label
    UILabel *serverLabel = [[UILabel alloc] init];
    serverLabel.text = @"📡 Server Mode";
    serverLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    serverLabel.textColor = [UIColor colorWithRed:0.56 green:0.56 blue:0.66 alpha:1];
    serverLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:serverLabel];

    [NSLayoutConstraint activateConstraints:@[
        [serverLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12],
        [serverLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12]
    ]];

    // Toggle Switch
    self.serverToggle = [[UISwitch alloc] init];
    self.serverToggle.onTintColor = [UIColor colorWithRed:1 green:0.36 blue:0.17 alpha:1]; // Orange
    self.serverToggle.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.serverToggle];

    [NSLayoutConstraint activateConstraints:@[
        [self.serverToggle.topAnchor constraintEqualToAnchor:serverLabel.topAnchor],
        [self.serverToggle.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12]
    ]];

    // Server state label
    UILabel *stateLabel = [[UILabel alloc] init];
    stateLabel.font = [UIFont systemFontOfSize:11];
    stateLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1];
    stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [stateLabel.topAnchor constraintEqualToAnchor:self.serverToggle.bottomAnchor constant:4],
        [stateLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12]
    ]];

    // Update state label based on toggle
    [self.serverToggle addTarget:self action:@selector(toggleChanged) forControlEvents:UIControlEventValueChanged];

    __weak UILabel *weakStateLabel = stateLabel;
    [self.serverToggle addTarget:^{
        weakStateLabel.text = self.serverToggle.isOn ? @"✅ Server 1 (Pastebody)" : @"⚫ Server 2 (Pastebodygoc)";
    } action:@selector(toggleChanged) forControlEvents:UIControlEventValueChanged];

    // Initial state
    stateLabel.text = @"⚫ Server 2 (Pastebodygoc)";

    // Loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.color = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.topAnchor constraintEqualToAnchor:stateLabel.bottomAnchor constant:12],
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor]
    ]];

    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Ready";
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = [UIColor colorWithRed:0.56 green:0.56 blue:0.66 alpha:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loadingIndicator.bottomAnchor constant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12]
    ]];

    // Manual Paste button
    self.pasteButton = [[UIButton alloc] init];
    [self.pasteButton setTitle:@"📋 Paste Now" forState:UIControlStateNormal];
    [self.pasteButton setTitleColor:[UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1] forState:UIControlStateNormal];
    self.pasteButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.pasteButton.backgroundColor = [UIColor colorWithRed:1 green:0.36 blue:0.17 alpha:0.8];
    self.pasteButton.layer.cornerRadius = 8;
    self.pasteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.pasteButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.pasteButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
        [self.pasteButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.pasteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.pasteButton.heightAnchor constraintEqualToConstant:32],
        [self.pasteButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];

    [self.pasteButton addTarget:self action:@selector(pasteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)toggleChanged {
    BOOL isOn = self.serverToggle.isOn;
    if (self.onToggleChanged) {
        self.onToggleChanged(isOn);
    }
}

- (void)pasteButtonTapped {
    if (self.onToggleChanged) {
        [self setLoading:YES];
        self.onToggleChanged(self.serverToggle.isOn);
    }
}

- (void)updateStatus:(NSString *)status {
    self.statusLabel.text = status;
    [UIView animateWithDuration:0.3 animations:^{
        self.statusLabel.alpha = 1.0;
    }];
}

- (void)setLoading:(BOOL)isLoading {
    if (isLoading) {
        [self.loadingIndicator startAnimating];
        self.pasteButton.alpha = 0.5;
        self.pasteButton.userInteractionEnabled = NO;
    } else {
        [self.loadingIndicator stopAnimating];
        self.pasteButton.alpha = 1.0;
        self.pasteButton.userInteractionEnabled = YES;
    }
}

@end
