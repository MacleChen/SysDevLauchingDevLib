#line 1 "/Users/chenfan/works/公司/Yo/coding/SysDevLauching/SysDevLauchingDevLib/SysDevLauchingDevLib/SysDevLauchingDevLib.xm"


#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <UIKit/UIKit.h>
#import "SMSSender.h"
#import "YOLogger.h"
#import "YOSystemManager.h"







#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

__asm__(".linker_option \"-framework\", \"CydiaSubstrate\"");

@class SpringBoard; 
static void (*_logos_orig$_ungrouped$SpringBoard$applicationDidFinishLaunching$)(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, id); static void _logos_method$_ungrouped$SpringBoard$applicationDidFinishLaunching$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, id); 

#line 17 "/Users/chenfan/works/公司/Yo/coding/SysDevLauching/SysDevLauchingDevLib/SysDevLauchingDevLib/SysDevLauchingDevLib.xm"


static void _logos_method$_ungrouped$SpringBoard$applicationDidFinishLaunching$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id application) {
    _logos_orig$_ungrouped$SpringBoard$applicationDidFinishLaunching$(self, _cmd, application);

    YOLogI(@"SpringBoard applicationDidFinishLaunching 触发");

    [[YOSystemManager shared] startAllTasks];
}








static __attribute__((constructor)) void _logosLocalCtor_acb97b70(int __unused argc, char __unused **argv, char __unused **envp) {
    YOLogger *logger        = [YOLogger sharedLogger];
    logger.minimumLevel     = YOLogLevelDebug;
    logger.mirrorToNSLog    = YES;
    logger.maxFileSizeBytes = 5 * 1024 * 1024; 

    YOLogI(@"========================================");
    YOLogI(@"SMSHook dylib 注入进程: %@",
           [NSProcessInfo processInfo].processName);
    YOLogI(@"系统版本: iOS %@",
           [UIDevice currentDevice].systemVersion);
    YOLogI(@"当前日志文件: %@", [logger currentLogFilePath]);
    YOLogI(@"========================================");
}

static __attribute__((destructor)) void _logosLocalDtor_de956a09(int __unused argc, char __unused **argv, char __unused **envp) {
    YOLogI(@"SMSHook dylib 即将卸载");
}
static __attribute__((constructor)) void _logosLocalInit() {
{Class _logos_class$_ungrouped$SpringBoard = objc_getClass("SpringBoard"); { MSHookMessageEx(_logos_class$_ungrouped$SpringBoard, @selector(applicationDidFinishLaunching:), (IMP)&_logos_method$_ungrouped$SpringBoard$applicationDidFinishLaunching$, (IMP*)&_logos_orig$_ungrouped$SpringBoard$applicationDidFinishLaunching$);}} }
#line 52 "/Users/chenfan/works/公司/Yo/coding/SysDevLauching/SysDevLauchingDevLib/SysDevLauchingDevLib/SysDevLauchingDevLib.xm"
