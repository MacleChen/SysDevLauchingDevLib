// See http://iphonedevwiki.net/index.php/Logos

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <UIKit/UIKit.h>
#import "SMSSender.h"
#import "YOLogger.h"
#import "YOSystemManager.h"


// ─────────────────────────────────────────────
// MARK: - SpringBoard Hook
// ─────────────────────────────────────────────

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    YOLogI(@"SpringBoard applicationDidFinishLaunching 触发");

    [[YOSystemManager shared] startAllTasks];
}

%end


// ─────────────────────────────────────────────
// MARK: - 构造函数：dylib 注入时立即执行
// ─────────────────────────────────────────────

%ctor {
    YOLogger *logger        = [YOLogger sharedLogger];
    logger.minimumLevel     = YOLogLevelDebug;
    logger.mirrorToNSLog    = YES;
    logger.maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

    YOLogI(@"========================================");
    YOLogI(@"SMSHook dylib 注入进程: %@",
           [NSProcessInfo processInfo].processName);
    YOLogI(@"系统版本: iOS %@",
           [UIDevice currentDevice].systemVersion);
    YOLogI(@"当前日志文件: %@", [logger currentLogFilePath]);
    YOLogI(@"========================================");
}

%dtor {
    YOLogI(@"SMSHook dylib 即将卸载");
}
