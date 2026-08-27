#import <Foundation/Foundation.h>

// URL server được mã hoá trong binary (chống `strings`/xem link).
NSString *EndpointCheckKey(void);
NSString *EndpointResetBind(void);
NSString *EndpointGetMod(void);
NSString *EndpointGenerateDinhVi(void);
NSString *EndpointVersion(void);
NSString *EndpointSkinList(void);  // danh sách skin dynamic

// URL ảnh (cũng mã hoá XOR)
NSString *EndpointImgFreeFireMax(void);
NSString *EndpointImgFreeFireTH(void);

// UDID enrollment qua profile
NSString *EndpointGetUDID(void);
