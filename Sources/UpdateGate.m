#import "UpdateGate.h"
#import "Endpoints.h"
#import "SecurityPinning.h"
#import <objc/runtime.h>

@implementation UpdateGate

+ (NSString *)appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
}

// So sánh version dạng "1.1.0": trả YES nếu a < b
+ (BOOL)version:(NSString *)a lessThan:(NSString *)b {
    NSArray<NSString *> *pa = [a componentsSeparatedByString:@"."];
    NSArray<NSString *> *pb = [b componentsSeparatedByString:@"."];
    NSInteger n = MAX(pa.count, pb.count);
    for (NSInteger i = 0; i < n; i++) {
        NSInteger va = i < pa.count ? [pa[i] integerValue] : 0;
        NSInteger vb = i < pb.count ? [pb[i] integerValue] : 0;
        if (va != vb) return va < vb;
    }
    return NO;
}

+ (void)checkFromViewController:(UIViewController *)host {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:EndpointVersion()]];
    req.timeoutInterval = 12;

    // Dùng pinnedSession → SSL pinning, chặn MITM giả response "không cần update"
    NSURLSessionDataTask *task = [[SecurityPinning shared].pinnedSession dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) return;   // lỗi mạng → không chặn (mod vẫn cần server nên vẫn an toàn)
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![j isKindOfClass:[NSDictionary class]]) return;

        NSString *minVer = j[@"min_version"];
        if (minVer.length == 0) return;

        if ([self version:[self appVersion] lessThan:minVer]) {
            // URL lấy từ server, fallback dùng EndpointVersion() domain (không hardcode plaintext)
            NSString *url = j[@"url"] ?: EndpointVersion();
            NSString *msg = j[@"message"] ?: @"Your version is outdated. Please update to the latest IPA to continue.";
            dispatch_async(dispatch_get_main_queue(), ^{ [self blockOn:host message:msg url:url]; });
        }
    }];
    [task resume];
}

+ (void)blockOn:(UIViewController *)host message:(NSString *)message url:(NSString *)url {
    UIViewController *blocker = [[UIViewController alloc] init];
    blocker.modalPresentationStyle = UIModalPresentationOverFullScreen;
    blocker.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    blocker.view.backgroundColor = [UIColor colorWithRed:0.024 green:0.027 blue:0.039 alpha:1.0];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"]];
    icon.tintColor = [UIColor colorWithRed:1.0 green:0.36 blue:0.17 alpha:1.0];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [blocker.view addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"UPDATE REQUIRED";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    title.textColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.961 alpha:1.0];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [blocker.view addSubview:title];

    UILabel *body = [[UILabel alloc] init];
    body.text = message;
    body.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    body.textColor = [UIColor colorWithRed:0.561 green:0.561 blue:0.659 alpha:1.0];
    body.textAlignment = NSTextAlignmentCenter;
    body.numberOfLines = 0;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [blocker.view addSubview:body];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"UPDATE NOW" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor colorWithRed:0.04 green:0.06 blue:0.13 alpha:1.0] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    btn.backgroundColor = [UIColor colorWithRed:0.133 green:0.827 blue:0.933 alpha:1.0];
    btn.layer.cornerRadius = 16;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    objc_setAssociatedObject(btn, "url", url, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [btn addTarget:self action:@selector(openUpdate:) forControlEvents:UIControlEventTouchUpInside];
    [blocker.view addSubview:btn];

    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:blocker.view.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:blocker.view.centerYAnchor constant:-110],
        [icon.widthAnchor constraintEqualToConstant:72],
        [icon.heightAnchor constraintEqualToConstant:72],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:22],
        [title.leadingAnchor constraintEqualToAnchor:blocker.view.leadingAnchor constant:32],
        [title.trailingAnchor constraintEqualToAnchor:blocker.view.trailingAnchor constant:-32],

        [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [body.leadingAnchor constraintEqualToAnchor:blocker.view.leadingAnchor constant:36],
        [body.trailingAnchor constraintEqualToAnchor:blocker.view.trailingAnchor constant:-36],

        [btn.topAnchor constraintEqualToAnchor:body.bottomAnchor constant:34],
        [btn.leadingAnchor constraintEqualToAnchor:blocker.view.leadingAnchor constant:40],
        [btn.trailingAnchor constraintEqualToAnchor:blocker.view.trailingAnchor constant:-40],
        [btn.heightAnchor constraintEqualToConstant:54],
    ]];

    // Tìm VC đang hiển thị trên cùng để present (không cho tắt)
    UIViewController *top = host;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:blocker animated:YES completion:nil];
}

+ (void)openUpdate:(UIButton *)sender {
    NSString *url = objc_getAssociatedObject(sender, "url");
    if (url) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

@end
