#import <Foundation/Foundation.h>

// Enumerate installed applications on device

@interface AppEnumerator : NSObject

+ (instancetype)sharedEnumerator;

// Get all installed app identifiers
- (NSArray<NSString *> *)allApplicationIdentifiers;

// Get app display name for identifier
- (NSString *)displayNameForIdentifier:(NSString *)identifier;

// Filter identifiers (exclude system apps, etc.)
- (NSArray<NSString *> *)filterIdentifiers:(NSArray<NSString *> *)identifiers
                               excludeSystem:(BOOL)excludeSystem;

@end
