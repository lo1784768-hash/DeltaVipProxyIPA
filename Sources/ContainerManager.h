#import <Foundation/Foundation.h>

// Private MobileContainerManager APIs
// Used to enumerate app containers without spoofing bundle ID

@interface ContainerManager : NSObject

+ (instancetype)sharedManager;

// List all accessible app containers (class 2)
- (NSArray<NSDictionary *> *)listAppContainers;

// List app groups (class 7)
- (NSArray<NSDictionary *> *)listAppGroups;

// List system containers (class 12, 13)
- (NSArray<NSDictionary *> *)listSystemContainers;

// Get container path for given identifier
- (NSString *)containerPathForIdentifier:(NSString *)identifier type:(NSInteger)type;

@end
