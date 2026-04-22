//
//  BusinessNetworkManager.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

#import <Foundation/Foundation.h>
#import "YODeviceReportData.h"


NS_ASSUME_NONNULL_BEGIN

@interface BusinessNetworkManager : NSObject

+ (instancetype)sharedManager;

- (void)reportDeviceWithSuccess:(void(^)(id response))success
                        failure:(void(^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
