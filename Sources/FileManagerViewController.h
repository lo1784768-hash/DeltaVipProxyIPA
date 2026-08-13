#import <UIKit/UIKit.h>

@interface FileManagerViewController : UITableViewController
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSArray *fileList;
@end
