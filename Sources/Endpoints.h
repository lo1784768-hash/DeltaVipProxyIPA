#import <Foundation/Foundation.h>

// URL server được mã hoá trong binary (chống `strings`/xem link).
NSString *EndpointCheckKey(void);
NSString *EndpointResetBind(void);
NSString *EndpointGetMod(void);
NSString *EndpointVersion(void);
