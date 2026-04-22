//
//  YODeviceReportData.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

// YODeviceReportData.h
#import <Foundation/Foundation.h>
#import "YOBaseResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface YODeviceReportData : NSObject <YOResponseDataParsable>

@property (nonatomic, copy)   NSString *deviceId;
@property (nonatomic, assign) NSInteger devicePk;
@property (nonatomic, assign) NSInteger appCount;
@property (nonatomic, assign) BOOL      isNew;

@end

NS_ASSUME_NONNULL_END
