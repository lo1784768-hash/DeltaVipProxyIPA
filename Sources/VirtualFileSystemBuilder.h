#import <Foundation/Foundation.h>

// Build virtual folder structure with symlinks to real container paths

@interface VirtualFileSystemBuilder : NSObject

+ (instancetype)sharedBuilder;

// Create virtual folder structure at root
// Returns root path or nil if failed
- (NSString *)createVirtualFileSystemAtRoot:(NSString *)rootPath
                                     error:(NSError **)error;

// Populate [MHA-C2] App Data with app containers
- (BOOL)populateAppDataAtRoot:(NSString *)rootPath
                   limit:(NSUInteger)limit
                  error:(NSError **)error;

// Populate [MHA-C7] App Groups
- (BOOL)populateAppGroupsAtRoot:(NSString *)rootPath
                         error:(NSError **)error;

@end
