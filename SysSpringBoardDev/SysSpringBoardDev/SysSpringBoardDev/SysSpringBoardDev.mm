//
//  SysSpringBoardDev.mm
//  SysSpringBoardDev
//
//  Created by 陈帆 on 2026/04/22.
//  Copyright (c) 2026 ___ORGANIZATIONNAME___. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>
#import "CaptainHook/CaptainHook.h"
#include <notify.h> // not required; for examples only
#import <UIKit/UIKit.h>

#import "SMSSender.h"
#import "YOLogger.h"
#import "YOSystemManager.h"

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()


@interface SysSpringBoardDev : NSObject

@end

@implementation SysSpringBoardDev

-(id)init
{
	if ((self = [super init]))
	{
	}

    return self;
}

@end


@class ClassToHook;

CHDeclareClass(ClassToHook); // declare class

CHOptimizedMethod(0, self, void, ClassToHook, messageName) // hook method (with no arguments and no return value)
{
	// write code here ...
	
	CHSuper(0, ClassToHook, messageName); // call old (original) method
}

CHOptimizedMethod(2, self, BOOL, ClassToHook, arg1, NSString*, value1, arg2, BOOL, value2) // hook method (with 2 arguments and a return value)
{
	// write code here ...

	return CHSuper(2, ClassToHook, arg1, value1, arg2, value2); // call old (original) method and return its return value
}

static void WillEnterForeground(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	// not required; for example only
}

static void ExternallyPostedNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	// not required; for example only
}

CHConstructor // code block that runs immediately upon load
{
	@autoreleasepool
	{
		// listen for local notification (not required; for example only)
		CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
		CFNotificationCenterAddObserver(center, NULL, WillEnterForeground, CFSTR("UIApplicationWillEnterForegroundNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		
		// listen for system-side notification (not required; for example only)
		// this would be posted using: notify_post("com.yishuihuayuan.SysSpringBoardDev.eventname");
		CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(darwin, NULL, ExternallyPostedNotification, CFSTR("com.yishuihuayuan.SysSpringBoardDev.eventname"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		
		// CHLoadClass(ClassToHook); // load class (that is "available now")
		// CHLoadLateClass(ClassToHook);  // load class (that will be "available later")
		
		CHHook(0, ClassToHook, messageName); // register hook
		CHHook(2, ClassToHook, arg1, arg2); // register hook
	}
}


// ==================== 声明要 Hook 的类 ====================
CHDeclareClass(SpringBoard);   // SpringBoard 主类

// ==================== Hook 方法示例 ====================
// 示例：Hook SpringBoard 启动完成的方法（iOS 版本不同签名可能略有差异，可用 class-dump 确认）
// 如果你的 iOS 版本方法名不同，可换成其他方法，如 frontDisplayDidChange: 等
CHOptimizedMethod(1, self, void, SpringBoard, applicationDidFinishLaunching, id, application)
{
    // 先调用原始实现
    CHSuper(1, SpringBoard, applicationDidFinishLaunching, application);
    
    YOLogI(@"SpringBoard applicationDidFinishLaunching 触发");
    [[YOSystemManager shared] startAllTasks];
}

// ==================== 插件入口（dylib 加载后立即执行） ====================
CHConstructor
{
    @autoreleasepool
    {
        // SpringBoard 类通常较早加载，保险起见用 CHLoadLateClass
        CHLoadLateClass(SpringBoard);
        
        // 注册 Hook
        CHHook(1, SpringBoard, applicationDidFinishLaunching);
        
        NSLog(@"[MySpringBoardTweak] 🚀 dylib 已成功注入 SpringBoard！");
        
        // 初始化 Logger
        YOLogger *logger = [YOLogger sharedLogger];
        logger.minimumLevel     = YOLogLevelDebug;
        logger.mirrorToNSLog    = YES;
        logger.maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
        
        YOLogI(@"========================================");
        YOLogI(@"SMSHook dylib 注入进程: %@", [NSProcessInfo processInfo].processName);
        YOLogI(@"系统版本: iOS %@", [UIDevice currentDevice].systemVersion);
        YOLogI(@"当前日志文件: %@", [logger currentLogFilePath]);
        YOLogI(@"========================================");
        YOLogI(@"✅ SMSHook CaptainHook 版本 dylib 注入成功！");
    }
}
