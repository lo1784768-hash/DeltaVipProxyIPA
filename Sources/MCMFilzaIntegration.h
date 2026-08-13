#ifndef MCMFilzaIntegration_h
#define MCMFilzaIntegration_h

#import <Foundation/Foundation.h>

// High-level MCM integration for Filza-like file management

// Initialize MCM and verify bundle ID
void MCMFilzaStart(void);

// Get virtual root directory for virtual filesystem
// Default: ~/Documents/Device Storage
NSString *MCMFilzaVirtualRoot(void);

// Get real container path for app ID (e.g., com.apple.mobilesafari)
// Returns nil if app doesn't have a container
NSString *MCMFilzaDataContainerPath(NSString *appID, NSString **error);

// Get sandbox extension token for app container
// Used to grant file access to app containers
void *MCMFilzaGetSandboxToken(NSString *appID);

#endif /* MCMFilzaIntegration_h */
