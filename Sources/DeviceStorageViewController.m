#import "DeviceStorageViewController.h"
#import "MCMFilzaIntegration.h"
#import "VirtualFileSystemBuilder.h"
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

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(refreshVirtualFS)];

    // Initialize MCM + build virtual filesystem
    [self setupVirtualFileSystem];

    [self.tableView reloadData];
}

- (void)setupVirtualFileSystem {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"[SETUP] 🚀 Starting virtual filesystem initialization...");

        // Initialize MCM
        @try {
            MCMFilzaStart();
            NSLog(@"[SETUP] ✅ MCM initialized successfully");
        } @catch (NSException *e) {
            NSLog(@"[SETUP] ❌ Failed to initialize MCM: %@", e);
            return;
        }

        // Get virtual root
        NSString *virtualRoot = MCMFilzaVirtualRoot();
        if (!virtualRoot || virtualRoot.length == 0) {
            NSLog(@"[SETUP] ❌ ERROR: MCMFilzaVirtualRoot() returned nil or empty!");
            return;
        }
        NSLog(@"[SETUP] ✅ Virtual root: %@", virtualRoot);

        // Verify we can write to virtual root
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *testError = nil;
        NSString *testFile = [virtualRoot stringByAppendingPathComponent:@".test"];
        if (![fm createFileAtPath:testFile contents:nil attributes:nil]) {
            NSLog(@"[SETUP] ⚠️  Cannot write to virtual root. Permissions issue?");
        } else {
            [fm removeItemAtPath:testFile error:nil];
        }

        // Build virtual filesystem
        NSLog(@"[SETUP] 📁 Creating virtual filesystem structure...");
        VirtualFileSystemBuilder *builder = [VirtualFileSystemBuilder sharedBuilder];
        NSError *error = nil;

        NSString *root = [builder createVirtualFileSystemAtRoot:virtualRoot error:&error];
        if (!root) {
            NSLog(@"[SETUP] ❌ Failed to create VFS: %@", error);
            return;
        }
        NSLog(@"[SETUP] ✅ Virtual filesystem structure created");

        // Populate app data (limit 100 apps for performance)
        NSLog(@"[SETUP] 📦 Populating app data containers...");
        BOOL appDataResult = [builder populateAppDataAtRoot:virtualRoot limit:100 error:&error];
        if (!appDataResult) {
            NSLog(@"[SETUP] ⚠️  App data population returned NO");
        }
        if (error) {
            NSLog(@"[SETUP] ❌ Error populating app data: %@", error);
        }

        // Populate app groups
        NSLog(@"[SETUP] 👥 Populating app groups...");
        BOOL groupsResult = [builder populateAppGroupsAtRoot:virtualRoot error:&error];
        if (!groupsResult) {
            NSLog(@"[SETUP] ⚠️  App groups population returned NO");
        }
        if (error) {
            NSLog(@"[SETUP] ❌ Error populating app groups: %@", error);
        }

        NSLog(@"[SETUP] ✅ Virtual filesystem initialization complete!");
        NSLog(@"[SETUP] 📊 User should now see files in Device Storage sections");

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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }

    NSDictionary *section = self.sections[indexPath.row];
    NSString *icon = section[@"icon"] ?: @"📁";
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", icon, section[@"name"]];
    cell.detailTextLabel.text = section[@"description"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *section = self.sections[indexPath.row];
    NSString *rootPath = MCMFilzaVirtualRoot();
    NSString *sectionPath = [rootPath stringByAppendingPathComponent:section[@"name"]];

    FileManagerViewController *nextVC = [[FileManagerViewController alloc] init];
    nextVC.currentPath = sectionPath;
    nextVC.sectionName = section[@"name"];

    [self.navigationController pushViewController:nextVC animated:YES];
}

@end
