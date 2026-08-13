#ifndef MCMBridge_h
#define MCMBridge_h

#include <stdio.h>
#include <Foundation/Foundation.h>

// MobileContainerManager (MCM) Private API Bindings
// Reverse-engineered from libsystem_containermanager.dylib

// Container query structure
typedef struct _container_query *container_query_t;
typedef struct _container_object *container_object_t;

// Function pointers
typedef int (*container_query_create_t)(container_query_t *out);
typedef int (*container_query_set_class_t)(container_query_t query, int class);
typedef int (*container_query_iterate_results_sync_t)(container_query_t query, int *count, container_object_t **results);
typedef int (*container_query_release_t)(container_query_t query);
typedef int (*container_copy_sandbox_token_t)(container_object_t obj, void **token);
typedef int (*container_object_sandbox_extension_activate_t)(container_object_t obj, void *extension);
typedef const char * (*container_object_identifier_t)(container_object_t obj);
typedef const char * (*container_object_path_t)(container_object_t obj);

// Global function pointers (dynamically loaded)
extern container_query_create_t MCM_container_query_create;
extern container_query_set_class_t MCM_container_query_set_class;
extern container_query_iterate_results_sync_t MCM_container_query_iterate_results_sync;
extern container_query_release_t MCM_container_query_release;
extern container_copy_sandbox_token_t MCM_container_copy_sandbox_token;
extern container_object_sandbox_extension_activate_t MCM_container_object_sandbox_extension_activate;
extern container_object_identifier_t MCM_container_object_identifier;
extern container_object_path_t MCM_container_object_path;

// Initialize MCM function pointers
void MCMBridgeInitialize(void);

// Container classes
#define CONTAINER_CLASS_APP_DATA 2
#define CONTAINER_CLASS_APP_GROUPS 7
#define CONTAINER_CLASS_SERVICE_DATA 10
#define CONTAINER_CLASS_SYSTEM_DATA 12
#define CONTAINER_CLASS_SYSTEM_GROUPS 13

#endif /* MCMBridge_h */
