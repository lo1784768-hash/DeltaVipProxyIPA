#import "MCMFilzaIntegration.h"
#import "MCMBridge.h"
#import <Foundation/Foundation.h>

// Bundle ID this integration runs under
// Patched to accept multiple bundle IDs
static NSString * const kAllowedBundleIDs[] = {
    @"com.apple.mobile.MobileHouseArrest",  // Original Filza/MobileHouseArrest
    @"com.imguidelta.app",                   // Our app
};
static const NSUInteger kAllowedBundleIDCount = 2;

static BOOL MCMCheckBundleID(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    // Check environment variable for testing
    const char *allowAny = getenv("MCM_ALLOW_ANY_BUNDLE");
    if (allowAny && strcmp(allowAny, "1") == 0) {
        NSLog(@"[MCMFilza] ⚠️  MCM_ALLOW_ANY_BUNDLE set, allowing any bundle ID: %@", bundleID);
        return YES;
    }

    for (NSUInteger i = 0; i < kAllowedBundleIDCount; i++) {
        if ([bundleID isEqualToString:kAllowedBundleIDs[i]]) {
            NSLog(@"[MCMFilza] ✅ Bundle ID allowed: %@", bundleID);
            return YES;
        }
    }

    NSLog(@"[MCMFilza] ❌ Bundle ID not allowed: %@", bundleID);
    return NO;
}

void MCMFilzaStart(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[MCMFilza] 🚀 Initializing MCM...");

        // Initialize MCM bridge
        MCMBridgeInitialize();

        // Check bundle ID
        if (!MCMCheckBundleID()) {
            NSLog(@"[MCMFilza] ❌ Bundle ID check failed!");
            return;
        }

        NSLog(@"[MCMFilza] ✅ MCM initialization complete");
    });
}

NSString *MCMFilzaVirtualRoot(void) {
    NSString *homeDir = NSHomeDirectory();
    NSString *documentsDir = [homeDir stringByAppendingPathComponent:@"Documents"];
    NSString *virtualRoot = [documentsDir stringByAppendingPathComponent:@"Device Storage"];

    NSLog(@"[MCMFilza] 📁 Virtual root: %@", virtualRoot);

    return virtualRoot;
}

NSString *MCMFilzaDataContainerPath(NSString *appID, NSString **error) {
    if (!appID || appID.length == 0) {
        if (error) *error = @"appID is nil or empty";
        return nil;
    }

    // Initialize MCM if not done
    MCMFilzaStart();

    // Check if MCM functions are available
    if (!MCM_container_query_create) {
        if (error) *error = @"MCM functions not loaded";
        NSLog(@"[MCMFilza] ❌ MCM functions not available for %@", appID);
        return nil;
    }

    @try {
        // Create container query
        container_query_t query = NULL;
        int result = MCM_container_query_create(&query);
        if (result != 0 || !query) {
            if (error) *error = [NSString stringWithFormat:@"container_query_create failed: %d", result];
            NSLog(@"[MCMFilza] ❌ Failed to create query for %@: %d", appID, result);
            return nil;
        }

        // Set query class to App Data (class 2)
        result = MCM_container_query_set_class(query, CONTAINER_CLASS_APP_DATA);
        if (result != 0) {
            if (error) *error = [NSString stringWithFormat:@"container_query_set_class failed: %d", result];
            NSLog(@"[MCMFilza] ❌ Failed to set class for %@: %d", appID, result);
            MCM_container_query_release(query);
            return nil;
        }

        // Iterate results synchronously
        int count = 0;
        container_object_t *results = NULL;
        result = MCM_container_query_iterate_results_sync(query, &count, &results);
        if (result != 0) {
            if (error) *error = [NSString stringWithFormat:@"container_query_iterate_results_sync failed: %d", result];
            NSLog(@"[MCMFilza] ❌ Failed to iterate for %@: %d", appID, result);
            MCM_container_query_release(query);
            return nil;
        }

        NSString *containerPath = nil;

        // Search for matching container
        for (int i = 0; i < count; i++) {
            if (!results[i]) continue;

            const char *identifier = MCM_container_object_identifier(results[i]);
            if (!identifier) continue;

            NSString *containerID = [NSString stringWithUTF8String:identifier];

            // Match app ID
            if ([containerID isEqualToString:appID]) {
                const char *path = MCM_container_object_path(results[i]);
                if (path) {
                    containerPath = [NSString stringWithUTF8String:path];
                    NSLog(@"[MCMFilza] ✅ Found container for %@: %@", appID, containerPath);
                    break;
                }
            }
        }

        MCM_container_query_release(query);

        if (!containerPath) {
            if (error) *error = @"No container found for app ID";
            NSLog(@"[MCMFilza] ⚠️  No container found for %@", appID);
        }

        return containerPath;

    } @catch (NSException *e) {
        if (error) *error = [NSString stringWithFormat:@"Exception: %@", e];
        NSLog(@"[MCMFilza] ❌ Exception while querying %@: %@", appID, e);
        return nil;
    }
}

void *MCMFilzaGetSandboxToken(NSString *appID) {
    if (!appID || appID.length == 0) {
        return NULL;
    }

    if (!MCM_container_query_create) {
        NSLog(@"[MCMFilza] ❌ MCM functions not available");
        return NULL;
    }

    @try {
        container_query_t query = NULL;
        int result = MCM_container_query_create(&query);
        if (result != 0 || !query) {
            NSLog(@"[MCMFilza] ❌ Failed to create query for sandbox token");
            return NULL;
        }

        MCM_container_query_set_class(query, CONTAINER_CLASS_APP_DATA);

        int count = 0;
        container_object_t *results = NULL;
        MCM_container_query_iterate_results_sync(query, &count, &results);

        void *token = NULL;
        for (int i = 0; i < count; i++) {
            if (!results[i]) continue;

            const char *identifier = MCM_container_object_identifier(results[i]);
            if (identifier && strcmp(identifier, [appID UTF8String]) == 0) {
                token = NULL;
                MCM_container_copy_sandbox_token(results[i], &token);
                break;
            }
        }

        MCM_container_query_release(query);

        if (token) {
            NSLog(@"[MCMFilza] ✅ Got sandbox token for %@", appID);
        }

        return token;

    } @catch (NSException *e) {
        NSLog(@"[MCMFilza] ❌ Exception getting sandbox token: %@", e);
        return NULL;
    }
}
