#import "DebugLogger.h"

@interface DebugLogger ()
@property (nonatomic, strong) NSString *logFilePath;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@end

@implementation DebugLogger

+ (instancetype)sharedLogger {
    static DebugLogger *logger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[DebugLogger alloc] init];
    });
    return logger;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create log file path in Documents
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        self.logFilePath = [documentsPath stringByAppendingPathComponent:@"IMGUIDELTA_debug.log"];

        // Create queue for thread-safe logging
        self.logQueue = dispatch_queue_create("com.imguidelta.logger", DISPATCH_QUEUE_SERIAL);

        // Open file handle
        [self openFileHandle];

        // Log startup
        [self log:@"\n\n========================================"];
        [self log:@"IMGUIDELTA Debug Log Started"];
        [self log:@"Time: %@", [NSDate date]];
        [self log:@"========================================\n"];
    }
    return self;
}

- (void)openFileHandle {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Create file if not exists
    if (![fm fileExistsAtPath:self.logFilePath]) {
        [fm createFileAtPath:self.logFilePath contents:nil attributes:nil];
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
    if (self.fileHandle) {
        [self.fileHandle seekToEndOfFile];
    }
}

- (void)log:(NSString *)format, ... {
#ifdef DEBUG
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(self.logQueue, ^{
        // Print to console
        NSLog(@"%@", message);

        // Write to file
        if (self.fileHandle) {
            NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n",
                [self currentTimeString], message];
            NSData *data = [logLine dataUsingEncoding:NSUTF8StringEncoding];
            [self.fileHandle writeData:data];
            [self.fileHandle synchronizeFile];
        }
    });
#endif
}

- (NSString *)currentTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    return [formatter stringFromDate:[NSDate date]];
}

- (NSString *)logFilePath {
    if (!_logFilePath) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        _logFilePath = [documentsPath stringByAppendingPathComponent:@"IMGUIDELTA_debug.log"];
    }
    return _logFilePath;
}

- (void)clearLogs {
    dispatch_async(self.logQueue, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:self.logFilePath error:nil];
        [self openFileHandle];
        [self log:@"Logs cleared"];
    });
}

- (NSString *)getLogContents {
    return [NSString stringWithContentsOfFile:self.logFilePath encoding:NSUTF8StringEncoding error:nil];
}

- (void)dealloc {
    if (self.fileHandle) {
        [self.fileHandle closeFile];
    }
}

@end
