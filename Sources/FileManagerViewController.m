#import "FileManagerViewController.h"
#import <Foundation/Foundation.h>

@interface FileManagerViewController ()
@end

@implementation FileManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Device Storage";
        self.currentPath = @"/private/var/mobile/Containers";
        self.sectionName = @"Device Storage";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.sectionName) {
        NSString *title = [self.sectionName stringByReplacingOccurrencesOfString:@"[MHA-" withString:@""];
        self.title = [title stringByReplacingOccurrencesOfString:@"]" withString:@""];
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(reloadFileList)];

    [self reloadFileList];
}

- (void)reloadFileList {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    NSLog(@"[FileMgr] 📂 Loading files from: %@", self.currentPath);

    // Check if path exists
    BOOL pathExists = [fm fileExistsAtPath:self.currentPath];
    if (!pathExists) {
        NSLog(@"[FileMgr] ❌ Path does not exist: %@", self.currentPath);
        self.fileList = @[];
        [self.tableView reloadData];
        return;
    }
    NSLog(@"[FileMgr] ✅ Path exists");

    // Check if readable
    BOOL isReadable = [fm isReadableFileAtPath:self.currentPath];
    NSLog(@"[FileMgr] 🔐 Path readable: %@", isReadable ? @"YES" : @"NO");

    self.fileList = [fm contentsOfDirectoryAtPath:self.currentPath error:&error];

    if (error) {
        NSLog(@"[FileMgr] ❌ Error reading directory: %@", error);
        self.fileList = @[];
    } else {
        NSLog(@"[FileMgr] ✅ Found %lu items in directory", (unsigned long)self.fileList.count);
        for (NSString *file in self.fileList) {
            NSString *fullPath = [self.currentPath stringByAppendingPathComponent:file];
            BOOL isDir = NO;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            NSLog(@"[FileMgr]   %c %@", isDir ? 'D' : 'F', file);
        }
    }

    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fileList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }

    NSString *fileName = self.fileList[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:fileName];

    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];

    cell.textLabel.text = fileName;
    cell.accessoryType = isDir ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedFile = self.fileList[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedFile];

    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];

    if (isDir) {
        FileManagerViewController *nextVC = [[FileManagerViewController alloc] init];
        nextVC.currentPath = fullPath;
        [self.navigationController pushViewController:nextVC animated:YES];
    }
}

@end
