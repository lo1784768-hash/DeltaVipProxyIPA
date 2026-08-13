#import <Foundation/Foundation.h>

// Simple file logger for debugging on device
@interface DebugLogger : NSObject

+ (instancetype)sharedLogger;

// Log message to both console and file
- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

// Get log file path
- (NSString *)logFilePath;

// Clear logs
- (void)clearLogs;

// Get log contents as string
- (NSString *)getLogContents;

@end
