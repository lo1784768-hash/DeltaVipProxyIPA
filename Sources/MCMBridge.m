#import "MCMBridge.h"
#import <dlfcn.h>

// Global function pointers
container_query_create_t MCM_container_query_create = NULL;
container_query_set_class_t MCM_container_query_set_class = NULL;
container_query_iterate_results_sync_t MCM_container_query_iterate_results_sync = NULL;
container_query_release_t MCM_container_query_release = NULL;
container_copy_sandbox_token_t MCM_container_copy_sandbox_token = NULL;
container_object_sandbox_extension_activate_t MCM_container_object_sandbox_extension_activate = NULL;
container_object_identifier_t MCM_container_object_identifier = NULL;
container_object_path_t MCM_container_object_path = NULL;

void MCMBridgeInitialize(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Load libsystem_containermanager.dylib
        void *handle = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW);
        if (!handle) {
            NSLog(@"[MCMBridge] Failed to load libsystem_containermanager.dylib: %s", dlerror());
            return;
        }

        NSLog(@"[MCMBridge] ✅ Loaded libsystem_containermanager.dylib");

        // Load function pointers
        MCM_container_query_create = dlsym(handle, "container_query_create");
        MCM_container_query_set_class = dlsym(handle, "container_query_set_class");
        MCM_container_query_iterate_results_sync = dlsym(handle, "container_query_iterate_results_sync");
        MCM_container_query_release = dlsym(handle, "container_query_release");
        MCM_container_copy_sandbox_token = dlsym(handle, "container_copy_sandbox_token");
        MCM_container_object_sandbox_extension_activate = dlsym(handle, "container_object_sandbox_extension_activate");
        MCM_container_object_identifier = dlsym(handle, "container_object_identifier");
        MCM_container_object_path = dlsym(handle, "container_object_path");

        if (!MCM_container_query_create ||
            !MCM_container_query_set_class ||
            !MCM_container_query_iterate_results_sync ||
            !MCM_container_query_release ||
            !MCM_container_object_identifier ||
            !MCM_container_object_path) {
            NSLog(@"[MCMBridge] ⚠️  Some MCM functions not found");
        } else {
            NSLog(@"[MCMBridge] ✅ All MCM functions loaded successfully");
        }
    });
}
