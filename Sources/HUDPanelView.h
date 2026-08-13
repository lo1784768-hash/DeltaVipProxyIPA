#import <UIKit/UIKit.h>

@interface HUDPanelView : UIView

@property (nonatomic, strong) UISwitch *serverToggle;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, copy) void (^onToggleChanged)(BOOL isOn);

- (instancetype)initWithFrame:(CGRect)frame appName:(NSString *)appName bundleID:(NSString *)bundleID;
- (void)updateStatus:(NSString *)status;
- (void)setLoading:(BOOL)isLoading;

@end
