#import "FileManagerViewController.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface FileManagerViewController () <UISearchBarDelegate, UIDocumentPickerDelegate>
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

    // Add right bar button
    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"Refresh"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(reloadFileList)];
    UIBarButtonItem *uploadBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"📤"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(uploadFileTapped)];
    self.navigationItem.rightBarButtonItems = @[uploadBtn, refreshBtn];

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
        // Show file options
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:selectedFile
                                                                       message:fullPath
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [alert addAction:[UIAlertAction actionWithTitle:@"✏️ Replace File" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self replaceFileAtPath:fullPath];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)uploadFileTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Upload File"
                                                                   message:@"Select an option"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"📁 Choose File" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self chooseFileForUpload];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"❌ Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chooseFileForUpload {
    // For now, show a simple demo alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"File Upload"
                                                                   message:@"File upload would open a file picker here.\n\nThis is a placeholder for full implementation."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)replaceFileAtPath:(NSString *)filePath {
    // Store the target path for the document picker callback
    objc_setAssociatedObject(self, @"targetFilePath", filePath, OBJC_ASSOCIATION_COPY_NONATOMIC);

    // Open document picker to select replacement file
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:@[@"public.content", @"public.item"]
        inMode:UIDocumentPickerModeImport];

    picker.delegate = self;
    picker.allowsMultipleSelection = NO;

    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;

    NSURL *selectedURL = urls.firstObject;
    NSString *targetFilePath = objc_getAssociatedObject(self, @"targetFilePath");

    // Start accessing the security-scoped resource
    if (![selectedURL startAccessingSecurityScopedResource]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:@"Cannot access selected file"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    // Copy the selected file to replace the target
    [fm removeItemAtPath:targetFilePath error:nil]; // Remove old file
    [fm copyItemAtURL:selectedURL toURL:[NSURL fileURLWithPath:targetFilePath] error:&error];

    // Stop accessing the security-scoped resource
    [selectedURL stopAccessingSecurityScopedResource];

    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error"
                                                                       message:[error localizedDescription]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Success"
                                                                       message:@"File replaced successfully"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

        // Refresh file list
        [self reloadFileList];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // User cancelled
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
