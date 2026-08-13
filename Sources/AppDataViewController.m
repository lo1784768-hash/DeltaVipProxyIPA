#import "AppDataViewController.h"
#import "FileManagerViewController.h"
#import "AppEnumerator.h"
#import "AppStatusChecker.h"
#import "MCMFilzaIntegration.h"
#import "VirtualFileSystemBuilder.h"
#import "DebugLogger.h"

@interface AppDataCell : UICollectionViewCell
@property (nonatomic, strong) UIView *cardView;
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

    // Beautiful card background with gradient
    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.95];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.cardView.layer.shadowOpacity = 0.12;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 4);
    self.cardView.layer.shadowRadius = 8;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4]
    ]];

    // Large app icon
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.layer.cornerRadius = 12;
    self.iconView.clipsToBounds = YES;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.iconView];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],
        [self.iconView.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:72],
        [self.iconView.heightAnchor constraintEqualToConstant:72]
    ]];

    // App name - Large and bold
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
    self.nameLabel.textColor = [UIColor blackColor];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:12],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:8],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-8]
    ]];

    // Bundle ID - Small gray text
    self.bundleLabel = [[UILabel alloc] init];
    self.bundleLabel.font = [UIFont systemFontOfSize:10];
    self.bundleLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.bundleLabel.textAlignment = NSTextAlignmentCenter;
    self.bundleLabel.numberOfLines = 1;
    self.bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.bundleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.bundleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.bundleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:8],
        [self.bundleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-8],
        [self.bundleLabel.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-12]
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
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Delta Proxy VN";

    // Display name mapping
    self.appDisplayNames = @{
        @"com.dts.freefiremax": @"Free Fire Max",
        @"com.dts.freefireth": @"Free Fire Thường"
    };

    // Custom image mapping - these should be bundled in app or in documents
    // For now, we'll use display names as keys
    self.customAppImages = @{
        @"com.dts.freefiremax": @"freefire_max",
        @"com.dts.freefireth": @"freefire_normal"
    };
    self.view.backgroundColor = [UIColor colorWithRed:0.98 green:0.98 blue:0.99 alpha:1.0];

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

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    // Refresh button
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"🔄 Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(refreshApps)];

    [self loadApps];
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
    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.webp", imageName]];

    if ([fm fileExistsAtPath:imagePath]) {
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Try PNG version
    imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", imageName]];
    if ([fm fileExistsAtPath:imagePath]) {
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    // Try from bundle (if images are added to app)
    UIImage *bundledImage = [UIImage imageNamed:imageName];
    if (bundledImage) {
        return bundledImage;
    }

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

    // Try custom image first, then fall back to app icon, then system image
    UIImage *customImage = [self loadCustomImageForApp:appID];
    if (customImage) {
        cell.iconView.image = customImage;
    } else {
        AppStatusChecker *checker = [AppStatusChecker sharedChecker];
        UIImage *icon = [checker iconForApp:appID];
        cell.iconView.image = icon ?: [UIImage systemImageNamed:@"square.and.pencil"];
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
    NSString *appID = self.appIDs[indexPath.item];

    // Navigate to file browser
    NSString *virtualRoot = MCMFilzaVirtualRoot();
    NSString *appDataPath = [virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"];
    NSString *containerPath = [appDataPath stringByAppendingPathComponent:appID];

    FileManagerViewController *nextVC = [[FileManagerViewController alloc] init];
    nextVC.currentPath = containerPath;
    nextVC.sectionName = appID;

    [self.navigationController pushViewController:nextVC animated:YES];
}

@end
