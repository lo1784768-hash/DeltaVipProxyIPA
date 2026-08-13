#import "AppDataViewController.h"
#import "FileManagerViewController.h"
#import "AppEnumerator.h"
#import "AppStatusChecker.h"
#import "MCMFilzaIntegration.h"
#import "VirtualFileSystemBuilder.h"
#import "DebugLogger.h"
#import "ImageDownloader.h"
#import "HUDControlViewController.h"

@interface AppDataCell : UICollectionViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@end

@implementation AppDataCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];

    // Dark neon card
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor colorWithRed:0.086 green:0.094 blue:0.169 alpha:1.0];
    self.cardView.layer.cornerRadius = 20;
    self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.cardView.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.28].CGColor;
    self.cardView.layer.borderWidth = 1;
    self.cardView.layer.shadowColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1].CGColor;
    self.cardView.layer.shadowOpacity = 0.28;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 6);
    self.cardView.layer.shadowRadius = 16;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    // Top colored banner section
    UIView *bannerView = [[UIView alloc] init];
    bannerView.layer.cornerRadius = 20;
    bannerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    bannerView.clipsToBounds = YES;
    bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:bannerView];
    self.bannerView = bannerView;

    [NSLayoutConstraint activateConstraints:@[
        [bannerView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [bannerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [bannerView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [bannerView.heightAnchor constraintEqualToConstant:100]
    ]];

    // Large app icon in banner - rounded like a real app icon
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.clipsToBounds = YES;
    self.iconView.layer.cornerRadius = 16;
    self.iconView.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    self.iconView.layer.borderWidth = 1;
    self.iconView.layer.magnificationFilter = kCAFilterTrilinear;
    self.iconView.layer.minificationFilter = kCAFilterTrilinear;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [bannerView addSubview:self.iconView];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.centerXAnchor constraintEqualToAnchor:bannerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:bannerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:72],
        [self.iconView.heightAnchor constraintEqualToConstant:72]
    ]];

    // App name - Bold
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    self.nameLabel.textColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:bannerView.bottomAnchor constant:16],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12]
    ]];

    // Bundle ID
    self.bundleLabel = [[UILabel alloc] init];
    self.bundleLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.bundleLabel.textColor = [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0];
    self.bundleLabel.textAlignment = NSTextAlignmentCenter;
    self.bundleLabel.numberOfLines = 1;
    self.bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.bundleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.bundleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:6],
        [self.bundleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.bundleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.bundleLabel.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-16]
    ]];
}

// Smooth touch animation
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(0.95, 0.95);
    }];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.1 animations:^{
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

@end

@interface AppDataViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *appIDs;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *appDisplayNames;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *customAppImages;
@property (nonatomic, strong) UIView *statsView;
@property (nonatomic, strong) CAGradientLayer *bgGradient;
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Delta Proxy VN";
    self.navigationItem.titleView = nil; // Center title by default

    // Display name mapping
    self.appDisplayNames = @{
        @"com.dts.freefiremax": @"Free Fire Max",
        @"com.dts.freefireth": @"Free Fire Thường"
    };

    // Custom image mapping - specific filenames
    self.customAppImages = @{
        @"com.dts.freefiremax": @"FreeFireMax",
        @"com.dts.freefireth": @"FreeFireTH"
    };
    self.view.backgroundColor = [UIColor colorWithRed:0.047 green:0.047 blue:0.086 alpha:1.0];

    // Dark gradient background
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[UIColor colorWithRed:0.047 green:0.047 blue:0.086 alpha:1.0].CGColor,
                  (id)[UIColor colorWithRed:0.063 green:0.094 blue:0.196 alpha:1.0].CGColor];
    bg.startPoint = CGPointMake(0.5, 0.0);
    bg.endPoint   = CGPointMake(0.5, 1.0);
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];
    self.bgGradient = bg;

    // Faint grid overlay
    UIView *grid = [[UIView alloc] initWithFrame:self.view.bounds];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    grid.backgroundColor = [self gridPatternColor];
    grid.userInteractionEnabled = NO;
    [self.view addSubview:grid];

    // Dark nav bar with white title + cyan Refresh
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithTransparentBackground];
    ap.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0],
                               NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]};
    self.navigationItem.standardAppearance = ap;
    self.navigationItem.scrollEdgeAppearance = ap;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];

    // Refresh button
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(refreshApps)];

    // Create stats view
    [self createStatsView];

    // Setup collection view with flow layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 32) / 2, 200);
    layout.minimumLineSpacing = 16;
    layout.minimumInteritemSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                              collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[AppDataCell class] forCellWithReuseIdentifier:@"AppCell"];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.collectionView];

    // Position collection view below stats view
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.statsView.bottomAnchor constant:16],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    // Load apps immediately without waiting
    [self loadAppsImmediately];
}

// Load apps immediately on first view
- (void)loadAppsImmediately {
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"[AppData] 🚀 Quick loading app list..."];

    // Initialize MCM
    MCMFilzaStart();

    // Get virtual root
    NSString *virtualRoot = MCMFilzaVirtualRoot();
    [logger log:@"[AppData] Virtual root: %@", virtualRoot];

    // Scan the virtual filesystem directory immediately
    NSString *appDataPath = [virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appDataPath error:nil];

    if (dirContents && dirContents.count > 0) {
        // Only show target apps
        NSArray *targetApps = @[@"com.dts.freefiremax", @"com.dts.freefireth"];
        NSMutableArray *appIDs = [NSMutableArray array];

        for (NSString *targetApp in targetApps) {
            for (NSString *item in dirContents) {
                if ([item isEqualToString:targetApp]) {
                    [appIDs addObject:targetApp];
                    [logger log:@"[AppData]   📦 %@", targetApp];
                    break;
                }
            }
        }

        self.appIDs = appIDs;
        [logger log:@"[AppData] ✅ Found %lu apps immediately", (unsigned long)self.appIDs.count];
        [self updateStatsKeysCount];
        [self.collectionView reloadData];
    } else {
        [logger log:@"[AppData] ⚠️  No apps in VFS yet, loading in background..."];
        // If no apps in VFS, load them in background
        [self loadApps];
    }
}

- (void)updateStatsKeysCount {
    UILabel *keysLabel = [self.statsView viewWithTag:999];
    if (keysLabel) {
        keysLabel.text = [NSString stringWithFormat:@"Active Keys  %lu", (unsigned long)self.appIDs.count];
    }
}

- (void)loadApps {
    static BOOL isLoading = NO;

    if (isLoading) {
        [[DebugLogger sharedLogger] log:@"[AppData] ⚠️  Already loading, skipping..."];
        return;
    }

    isLoading = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DebugLogger *logger = [DebugLogger sharedLogger];
        [logger log:@"[AppData] 🚀 Loading app list..."];

        // Initialize MCM
        MCMFilzaStart();

        // Get virtual root
        NSString *virtualRoot = MCMFilzaVirtualRoot();
        [logger log:@"[AppData] Virtual root: %@", virtualRoot];

        VirtualFileSystemBuilder *builder = [VirtualFileSystemBuilder sharedBuilder];
        NSError *error = nil;

        // Build virtual filesystem with symlinks
        [logger log:@"[AppData] 📁 Creating VFS..."];
        [builder createVirtualFileSystemAtRoot:virtualRoot error:&error];

        // First enumerate apps using LSApplicationWorkspace to populate containers
        [logger log:@"[AppData] 📦 Enumerating apps and creating symlinks..."];
        AppEnumerator *enumerator = [AppEnumerator sharedEnumerator];
        NSArray *allApps = [enumerator allApplicationIdentifiers];

        if (allApps.count > 0) {
            [logger log:@"[AppData] ✅ Enumerator found %lu apps, populating VFS...", (unsigned long)allApps.count];
            [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        } else {
            [logger log:@"[AppData] ⚠️  Enumerator returned 0 apps, trying to populate anyway..."];
            // Still try to populate in case there are containers from before
            [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        }

        // Now scan the virtual filesystem directory to get actual symlinked apps
        NSString *appDataPath = [virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"];
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appDataPath error:&error];

        if (error) {
            [logger log:@"[AppData] ❌ Error reading VFS directory: %@", error];
            dirContents = @[];
        }

        [logger log:@"[AppData] 📂 Found %lu items in VFS [MHA-C2] App Data", (unsigned long)dirContents.count];

        // Only show Free Fire apps
        NSArray *targetApps = @[@"com.dts.freefiremax", @"com.dts.freefireth"];
        NSMutableArray *appIDs = [NSMutableArray array];

        for (NSString *targetApp in targetApps) {
            // Check if the app exists in VFS or in all available apps
            BOOL exists = NO;

            // Check in VFS directory
            for (NSString *item in dirContents) {
                if ([item isEqualToString:targetApp]) {
                    exists = YES;
                    break;
                }
            }

            // If exists, add it
            if (exists) {
                [appIDs addObject:targetApp];
                [logger log:@"[AppData]   📦 %@", targetApp];
            } else {
                [logger log:@"[AppData]   ⚠️  %@ not found in VFS", targetApp];
            }
        }

        self.appIDs = appIDs;

        [logger log:@"[AppData] ✅ Ready to display %lu apps", (unsigned long)self.appIDs.count];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
            isLoading = NO;
        });
    });
}

- (void)createStatsView {
    // Dark neon stats card
    self.statsView = [[UIView alloc] init];
    self.statsView.backgroundColor = [UIColor colorWithRed:0.086 green:0.094 blue:0.169 alpha:0.85];
    self.statsView.layer.cornerRadius = 16;
    self.statsView.layer.cornerCurve = kCACornerCurveContinuous;
    self.statsView.layer.borderColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:0.28].CGColor;
    self.statsView.layer.borderWidth = 1;
    self.statsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.statsView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.statsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statsView.heightAnchor constraintEqualToConstant:104]
    ]];

    UIColor *muted = [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0];
    UIColor *cyan  = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];
    UIColor *green = [UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0];

    UIView *iosRow  = [self statRowText:[NSString stringWithFormat:@"iOS  %@", [[UIDevice currentDevice] systemVersion]]
                                 symbol:@"applelogo" tint:cyan valueColor:muted labelTag:0];
    UIView *devRow  = [self statRowText:[NSString stringWithFormat:@"Device  %@", [[UIDevice currentDevice] name]]
                                 symbol:@"iphone" tint:cyan valueColor:muted labelTag:0];
    UIView *keysRow = [self statRowText:@"Active Keys  0"
                                 symbol:@"key.fill" tint:green valueColor:green labelTag:999];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iosRow, devRow, keysRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statsView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.statsView.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:self.statsView.trailingAnchor constant:-18],
        [stack.centerYAnchor constraintEqualToAnchor:self.statsView.centerYAnchor],
    ]];
}

// A stat row: [symbol] label. Returns the row container.
- (UIView *)statRowText:(NSString *)text symbol:(NSString *)symbol tint:(UIColor *)tint
             valueColor:(UIColor *)valueColor labelTag:(NSInteger)tag {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]];
    icon.tintColor = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = valueColor;
    label.text = text;
    if (tag) label.tag = tag;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:18],
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
    ]];
    return row;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgGradient.frame = self.view.bounds;
}

- (UIColor *)gridPatternColor {
    CGFloat s = 26;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGContextSetStrokeColorWithColor(ctx.CGContext, [UIColor colorWithWhite:1 alpha:0.045].CGColor);
        CGContextSetLineWidth(ctx.CGContext, 0.5);
        CGContextMoveToPoint(ctx.CGContext, s, 0);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextMoveToPoint(ctx.CGContext, 0, s);  CGContextAddLineToPoint(ctx.CGContext, s, s);
        CGContextStrokePath(ctx.CGContext);
    }];
    return [UIColor colorWithPatternImage:img];
}

- (void)refreshApps {
    [self loadApps];
}

// Load custom app image from documents or bundle
- (UIImage *)loadCustomImageForApp:(NSString *)appID {
    // Check if custom image name exists in mapping
    NSString *imageName = self.customAppImages[appID];
    if (!imageName) {
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    // Try to load from documents/AppImages directory
    NSString *appImagesDir = [documentsPath stringByAppendingPathComponent:@"AppImages"];

    // Priority 1: Try PNG version first (FreeFireMax.png, FreeFireTH.png)
    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", imageName]];
    if ([fm fileExistsAtPath:imagePath]) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded custom image from: %@", imagePath];
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Priority 2: Try WEBP version
    imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.webp", imageName]];
    if ([fm fileExistsAtPath:imagePath]) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded custom image from: %@", imagePath];
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Priority 3: Try from bundle (if images are added to app)
    UIImage *bundledImage = [UIImage imageNamed:imageName];
    if (bundledImage) {
        [[DebugLogger sharedLogger] log:@"[AppData] ✅ Loaded bundled image: %@", imageName];
        return bundledImage;
    }

    [[DebugLogger sharedLogger] log:@"[AppData] ⚠️  Custom image not found: %@", imageName];
    return nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.appIDs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AppDataCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];

    NSString *appID = self.appIDs[indexPath.item];

    // Banner color + matching neon glow based on app
    UIColor *accent;
    if ([appID isEqualToString:@"com.dts.freefiremax"]) {
        accent = [UIColor colorWithRed:0.1 green:0.6 blue:1.0 alpha:1.0]; // blue
    } else if ([appID isEqualToString:@"com.dts.freefireth"]) {
        accent = [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0]; // orange
    } else {
        accent = [UIColor colorWithRed:0 green:0.831 blue:1 alpha:1.0]; // cyan
    }
    cell.bannerView.backgroundColor = accent;
    cell.cardView.layer.shadowColor = accent.CGColor;
    cell.cardView.layer.borderColor = [accent colorWithAlphaComponent:0.35].CGColor;

    // Priority order:
    // 1. Downloaded cached images (FreeFireMax.png / FreeFireTH.png)
    // 2. Custom images via loadCustomImageForApp
    // 3. App icon from system
    // 4. Fallback to game controller icon

    ImageDownloader *downloader = [ImageDownloader sharedDownloader];

    // Try downloaded images first
    UIImage *downloadedImage = nil;
    if ([appID isEqualToString:@"com.dts.freefiremax"]) {
        downloadedImage = [downloader cachedImageNamed:@"FreeFireMax"];
    } else if ([appID isEqualToString:@"com.dts.freefireth"]) {
        downloadedImage = [downloader cachedImageNamed:@"FreeFireTH"];
    }

    if (downloadedImage) {
        cell.iconView.image = downloadedImage;
        cell.iconView.tintColor = [UIColor whiteColor];
    } else {
        // Try custom image
        UIImage *customImage = [self loadCustomImageForApp:appID];
        if (customImage) {
            cell.iconView.image = customImage;
            cell.iconView.tintColor = [UIColor whiteColor];
        } else {
            // Try to get app's actual icon
            AppStatusChecker *checker = [AppStatusChecker sharedChecker];
            UIImage *icon = [checker iconForApp:appID];
            if (icon) {
                cell.iconView.image = icon;
                cell.iconView.tintColor = [UIColor whiteColor];
            } else {
                // Fallback to game controller icon
                cell.iconView.image = [UIImage systemImageNamed:@"gamecontroller.fill"];
                cell.iconView.tintColor = [UIColor whiteColor];
            }
        }
    }

    // Set app name - use custom display names
    NSString *displayName = self.appDisplayNames[appID] ?: appID;
    cell.nameLabel.text = displayName;

    // Set bundle ID
    cell.bundleLabel.text = appID;

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    NSString *appID = self.appIDs[indexPath.item];
    NSString *displayName = self.appDisplayNames[appID] ?: appID;

    // Grab the already-loaded icon from the tapped cell for a crisp HUD header
    AppDataCell *cell = (AppDataCell *)[collectionView cellForItemAtIndexPath:indexPath];
    UIImage *icon = cell.iconView.image;

    HUDControlViewController *hud = [[HUDControlViewController alloc] initWithBundleID:appID
                                                                              appName:displayName
                                                                                 icon:icon];
    [self.navigationController pushViewController:hud animated:YES];
}

@end
