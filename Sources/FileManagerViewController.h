#import <UIKit/UIKit.h>

@interface FileManagerViewController : UITableViewController
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSArray *fileList;
@property (nonatomic, strong) NSArray *filteredFileList;
@property (nonatomic, strong) NSString *sectionName;
@property (nonatomic, strong) NSString *containerClass;
@property (nonatomic, strong) UISearchBar *searchBar;
@end
