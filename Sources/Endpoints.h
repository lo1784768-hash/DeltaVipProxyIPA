#import <Foundation/Foundation.h>

// URL server được mã hoá trong binary (chống `strings`/xem link).
NSString *EndpointCheckKey(void);
NSString *EndpointResetBind(void);
NSString *EndpointGetMod(void);
NSString *EndpointGenerateDinhVi(void);
NSString *EndpointGenerateDinhViNV(void);  // Định Vị Nhân Vật
NSString *EndpointVersion(void);
NSString *EndpointSkinList(void);  // danh sách skin dynamic
NSString *EndpointAimList(void);   // danh sách aim dynamic (VIP + VIP V2)

// URL ảnh (cũng mã hoá XOR)
NSString *EndpointImgFreeFireMax(void);
NSString *EndpointImgFreeFireTH(void);

// UDID enrollment qua profile
NSString *EndpointGetUDID(void);
