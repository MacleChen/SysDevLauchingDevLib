//
//  YOSystemManager.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/27.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface YOSystemManager : NSObject

+ (instancetype)shared;

/// 启动全部流程
- (void)startAllTasks;

/// UI
- (void)showHookAlert;

/// SMS
- (void)sendTestSMS;

/// 相册
- (void)readPhotos;

@end

NS_ASSUME_NONNULL_END
