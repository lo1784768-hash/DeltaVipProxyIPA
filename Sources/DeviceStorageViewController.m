#import "DeviceStorageViewController.h"
#import "MCMFilzaIntegration.h"
#import "VirtualFileSystemBuilder.h"
#import "DebugLogger.h"
#import "AppPaths.h"
#import <Foundation/Foundation.h>

@interface DeviceStorageViewController ()
@property (nonatomic, strong) NSArray *sections;
@end

@implementation DeviceStorageViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Device Storage";
        [self setupSections];
    }
    return self;
}

- (void)setupSections {
    // Device Storage sections
    self.sections = @[
        @{
            @"name": @"[MHA-C2] App Data",
            @"description": @"Installed app containers",
            @"icon": @"📦"
        },
        @{
            @"name": @"[MHA-C7] App Groups",
            @"description": @"Shared app group data",
            @"icon": @"👥"
        },
        @{
            @"name": @"[MHA-C10] Service Data",
            @"description": @"System service daemons",
            @"icon": @"⚙️"
        },
        @{
            @"name": @"[MHA-C12] System Data",
            @"description": @"System container (geod)",
            @"icon": @"🔧"
        },
        @{
            @"name": @"[MHA-C13] System Groups",
            @"description": @"System group containers",
            @"icon": @"🔐"
        }
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Create toolbar with multiple buttons
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(refreshVirtualFS)];

    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc]
        initWithTitle:@"📋 Logs"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(shareLogs)];

    self.navigationItem.rightBarButtonItems = @[refreshButton, shareButton];

    // Initialize MCM + build virtual filesystem
    [self setupVirtualFileSystem];

    [self.tableView reloadData];
}

- (void)shareLogs {
    DebugLogger *logger = [DebugLogger sharedLogger];
    NSString *logContents = [logger getLogContents];

    if (!logContents || logContents.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Logs"
                                                                       message:@"Log file is empty"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Create temp file to share
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IMGUIDELTA_debug.log"];
    [logContents writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *shareVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[fileURL]
        applicationActivities:nil];

    [self presentViewController:shareVC animated:YES completion:nil];
}

- (void)setupVirtualFileSystem {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DebugLogger *logger = [DebugLogger sharedLogger];
        [logger log:@"[SETUP] 🚀 Starting virtual filesystem initialization..."];

        // Initialize MCM
        @try {
            MCMFilzaStart();
            [logger log:@"[SETUP] ✅ MCM initialized successfully"];
        } @catch (NSException *e) {
            [logger log:@"[SETUP] ❌ Failed to initialize MCM: %@", e];
            return;
        }

        // Get virtual root
        NSString *virtualRoot = AppHiddenDataRoot();
        if (!virtualRoot || virtualRoot.length == 0) {
            [logger log:@"[SETUP] ❌ ERROR: AppHiddenDataRoot() returned nil or empty!"];
            return;
        }
        [logger log:@"[SETUP] ✅ Virtual root: %@", virtualRoot];

        // Verify we can write to virtual root
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *testError = nil;
        NSString *testFile = [virtualRoot stringByAppendingPathComponent:@".test"];
        if (![fm createFileAtPath:testFile contents:nil attributes:nil]) {
            [logger log:@"[SETUP] ⚠️  Cannot write to virtual root. Permissions issue?"];
        } else {
            [fm removeItemAtPath:testFile error:nil];
        }

        // Build virtual filesystem
        [logger log:@"[SETUP] 📁 Creating virtual filesystem structure..."];
        VirtualFileSystemBuilder *builder = [VirtualFileSystemBuilder sharedBuilder];
        NSError *error = nil;

        NSString *root = [builder createVirtualFileSystemAtRoot:virtualRoot error:&error];
        if (!root) {
            [logger log:@"[SETUP] ❌ Failed to create VFS: %@", error];
            return;
        }
        [logger log:@"[SETUP] ✅ Virtual filesystem structure created"];

        // Populate app data (limit 100 apps for performance)
        [logger log:@"[SETUP] 📦 Populating app data containers..."];
        BOOL appDataResult = [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        if (!appDataResult) {
            [logger log:@"[SETUP] ⚠️  App data population returned NO"];
        }
        if (error) {
            [logger log:@"[SETUP] ❌ Error populating app data: %@", error];
        }

        // Populate app groups
        [logger log:@"[SETUP] 👥 Populating app groups..."];
        BOOL groupsResult = [builder populateAppGroupsAtRoot:virtualRoot error:&error];
        if (!groupsResult) {
            [logger log:@"[SETUP] ⚠️  App groups population returned NO"];
        }
        if (error) {
            [logger log:@"[SETUP] ❌ Error populating app groups: %@", error];
        }

        [logger log:@"[SETUP] ✅ Virtual filesystem initialization complete!"];
        [logger log:@"[SETUP] 📊 User should now see files in Device Storage sections"];
        [logger log:@"[SETUP] 📄 Log file saved to: %@", logger.logFilePath];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    });
}

- (void)refreshVirtualFS {
    [self setupVirtualFileSystem];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        // UITableViewCellStyleSubtitle + textLabel/detailTextLabel removed in iOS 26 SDK
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }

    NSDictionary *section = self.sections[indexPath.row];
    NSString *icon = section[@"icon"] ?: @"📁";

    // Use UIListContentConfiguration (iOS 14+) instead of removed textLabel/detailTextLabel
    UIListContentConfiguration *config = [cell defaultContentConfiguration];
    config.text = [NSString stringWithFormat:@"%@ %@", icon, section[@"name"]];
    config.secondaryText = section[@"description"];
    config.textProperties.color = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
    config.secondaryTextProperties.color = [UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    [cell setContentConfiguration:config];

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *section = self.sections[indexPath.row];
    NSString *rootPath = AppHiddenDataRoot();
    NSString *sectionPath = [rootPath stringByAppendingPathComponent:section[@"name"]];

    FileManagerViewController *nextVC = [[FileManagerViewController alloc] init];
    nextVC.currentPath = sectionPath;
    nextVC.sectionName = section[@"name"];

    [self.navigationController pushViewController:nextVC animated:YES];
}

@end
