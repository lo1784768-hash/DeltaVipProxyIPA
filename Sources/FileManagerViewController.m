#import "FileManagerViewController.h"
#import <Foundation/Foundation.h>

@interface FileManagerViewController () <UISearchBarDelegate>
@end

@implementation FileManagerViewController

// Static clipboard for copy/paste
static NSString *_clipboardFilePath = nil;
static NSString *_clipboardFileName = nil;

+ (NSString *)clipboardFilePath {
    return _clipboardFilePath;
}

+ (void)setClipboardFilePath:(NSString *)path {
    _clipboardFilePath = path;
}

+ (NSString *)clipboardFileName {
    return _clipboardFileName;
}

+ (void)setClipboardFileName:(NSString *)name {
    _clipboardFileName = name;
}

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

    // Add right bar buttons
    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(reloadFileList)];

    // Paste button - only visible when clipboard has content
    NSMutableArray *buttons = [NSMutableArray arrayWithObject:refreshBtn];
    if (FileManagerViewController.clipboardFilePath) {
        UIBarButtonItem *pasteBtn = [[UIBarButtonItem alloc]
            initWithTitle:@"📋 Paste"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(pasteFileTapped)];
        [buttons insertObject:pasteBtn atIndex:0];
    }

    self.navigationItem.rightBarButtonItems = buttons;

    // Add search bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    self.searchBar.placeholder = @"🔍 Search files...";
    self.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchBar;

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
        self.filteredFileList = @[];
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
        self.filteredFileList = @[];
    } else {
        NSLog(@"[FileMgr] ✅ Found %lu items in directory", (unsigned long)self.fileList.count);
        for (NSString *file in self.fileList) {
            NSString *fullPath = [self.currentPath stringByAppendingPathComponent:file];
            BOOL isDir = NO;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            NSLog(@"[FileMgr]   %c %@", isDir ? 'D' : 'F', file);
        }
        self.filteredFileList = self.fileList;
    }

    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredFileList ? self.filteredFileList.count : self.fileList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0];
        cell.textLabel.textColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
    }

    NSArray *displayList = self.filteredFileList ? self.filteredFileList : self.fileList;
    NSString *fileName = displayList[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:fileName];

    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];

    cell.textLabel.text = isDir ? [NSString stringWithFormat:@"📁 %@", fileName] : [NSString stringWithFormat:@"📄 %@", fileName];
    cell.accessoryType = isDir ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *displayList = self.filteredFileList ? self.filteredFileList : self.fileList;
    NSString *selectedFile = displayList[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedFile];

    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];

    if (isDir) {
        FileManagerViewController *nextVC = [[FileManagerViewController alloc] init];
        nextVC.currentPath = fullPath;
        [self.navigationController pushViewController:nextVC animated:YES];
    } else {
        // Show file options (Filza-style)
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:selectedFile
                                                                       message:fullPath
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self copyFileAtPath:fullPath fileName:selectedFile];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"🗑️ Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deleteFileAtPath:fullPath];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)uploadFileTapped {
    // Not used anymore - paste functionality replaces this
}

- (void)copyFileAtPath:(NSString *)filePath fileName:(NSString *)fileName {
    // Copy file to clipboard
    FileManagerViewController.clipboardFilePath = filePath;
    FileManagerViewController.clipboardFileName = fileName;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Copied"
                                                                   message:[NSString stringWithFormat:@"📋 %@", fileName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];

    // Refresh to show paste button
    [self.navigationController.topViewController viewDidLoad];
}

- (void)deleteFileAtPath:(NSString *)filePath {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];

    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:[error localizedDescription]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Deleted"
                                                                       message:@"File deleted successfully"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadFileList];
    }
}

- (void)pasteFileTapped {
    NSString *clipboardPath = FileManagerViewController.clipboardFilePath;
    NSString *clipboardName = FileManagerViewController.clipboardFileName;

    if (!clipboardPath) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:@"Clipboard is empty"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *targetPath = [self.currentPath stringByAppendingPathComponent:clipboardName];
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    // Read clipboard file
    NSData *fileData = [NSData dataWithContentsOfFile:clipboardPath options:0 error:&error];

    if (error || !fileData) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:[error localizedDescription] ?: @"Cannot read clipboard file"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Write to target path (overwrite if exists)
    BOOL success = [fileData writeToFile:targetPath atomically:YES];

    if (!success) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:@"Cannot write to target location"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Pasted"
                                                                       message:[NSString stringWithFormat:@"📋 %@", clipboardName]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadFileList];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredFileList = self.fileList;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", searchText];
        self.filteredFileList = [self.fileList filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
