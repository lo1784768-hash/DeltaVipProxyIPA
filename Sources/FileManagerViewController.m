#import "FileManagerViewController.h"
#import <Foundation/Foundation.h>

@interface FileManagerViewController ()
@end

@implementation FileManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"IMGUIDELTA";
        self.currentPath = @"/private/var/mobile/Containers";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Root"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(goToRoot)];

    [self reloadFileList];
}

- (void)reloadFileList {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    self.fileList = [fm contentsOfDirectoryAtPath:self.currentPath error:&error];
    if (error) {
        NSLog(@"Error reading directory: %@", error);
        self.fileList = @[];
    }

    [self.tableView reloadData];
}

- (void)goToRoot {
    self.currentPath = @"/";
    [self reloadFileList];
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
