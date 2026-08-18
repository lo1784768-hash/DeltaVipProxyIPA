#import <UIKit/UIKit.h>

/// Floating right-edge language toggle tab. Add once to the key UIWindow so it
/// appears across all screens. Tapping cycles between VI ↔ EN.
@interface LangTabView : UIView

/// Creates the tab view and pins it to the right edge of `window`.
/// Call once, right after -makeKeyAndVisible.
+ (void)installOnWindow:(UIWindow *)window;

@end
