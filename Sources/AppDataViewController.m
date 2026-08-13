#import "AppDataViewController.h"
#import "FileManagerViewController.h"
#import "AppEnumerator.h"
#import "AppStatusChecker.h"
#import "MCMFilzaIntegration.h"
#import "VirtualFileSystemBuilder.h"
#import "DebugLogger.h"

@interface AppDataCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *idLabel;
@property (nonatomic, strong) UIView *statusIndicator;
@property (nonatomic, strong) UILabel *statusLabel;
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
    self.layer.cornerRadius = 12;

    // Card background
    UIView *cardView = [[UIView alloc] init];
    cardView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0];
    cardView.layer.cornerRadius = 12;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOpacity = 0.1;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 4;
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:cardView];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    // App icon
    self.iconView = [[UIImageView alloc] init];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.layer.cornerRadius = 8;
    self.iconView.clipsToBounds = YES;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:self.iconView];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:12],
        [self.iconView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:12],
        [self.iconView.widthAnchor constraintEqualToConstant:50],
        [self.iconView.heightAnchor constraintEqualToConstant:50]
    ]];

    // Status indicator (green dot)
    self.statusIndicator = [[UIView alloc] init];
    self.statusIndicator.layer.cornerRadius = 6;
    self.statusIndicator.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:0.5];
    self.statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:self.statusIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusIndicator.widthAnchor constraintEqualToConstant:12],
        [self.statusIndicator.heightAnchor constraintEqualToConstant:12],
        [self.statusIndicator.trailingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor],
        [self.statusIndicator.bottomAnchor constraintEqualToAnchor:self.iconView.bottomAnchor]
    ]];

    // App name label
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:14];
    self.nameLabel.textColor = [UIColor blackColor];
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:self.nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.topAnchor],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-12]
    ]];

    // Bundle ID label
    self.idLabel = [[UILabel alloc] init];
    self.idLabel.font = [UIFont systemFontOfSize:11];
    self.idLabel.textColor = [UIColor grayColor];
    self.idLabel.numberOfLines = 2;
    self.idLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:self.idLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.idLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.idLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.idLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-12]
    ]];

    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:12]
    ]];
}

@end

@interface AppDataViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *appIDs;
@end

@implementation AppDataViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Free Fire 🔥";
    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.98 alpha:1.0];

    // Setup collection view with flow layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 30) / 2, 160);
    layout.minimumLineSpacing = 12;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

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

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.appIDs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AppDataCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];

    NSString *appID = self.appIDs[indexPath.item];
    AppStatusChecker *checker = [AppStatusChecker sharedChecker];

    // Set icon
    UIImage *icon = [checker iconForApp:appID];
    cell.iconView.image = icon ?: [UIImage systemImageNamed:@"square.and.pencil"];

    // Set name
    NSString *displayName = [checker displayNameForApp:appID];
    cell.nameLabel.text = displayName;

    // Set bundle ID
    cell.idLabel.text = appID;

    // Set status
    BOOL isRunning = [checker isAppRunning:appID];
    if (isRunning) {
        cell.statusIndicator.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
        cell.statusLabel.text = @"🟢 Running";
    } else {
        cell.statusIndicator.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.5];
        cell.statusLabel.text = @"⚫ Not running";
    }

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
