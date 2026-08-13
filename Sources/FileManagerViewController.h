#import <UIKit/UIKit.h>

@interface FileManagerViewController : UITableViewController
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSArray *fileList;
@property (nonatomic, strong) NSString *sectionName;
@property (nonatomic, strong) NSString *containerClass;
@end
