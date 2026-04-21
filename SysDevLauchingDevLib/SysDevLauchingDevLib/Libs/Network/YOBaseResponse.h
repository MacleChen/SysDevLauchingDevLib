//
//  YOBaseResponse.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

// YOBaseResponse.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 协议：业务 Model 需实现，支持从字典初始化
@protocol YOResponseDataParsable <NSObject>
+ (nullable instancetype)modelFromDictionary:(NSDictionary *)dict;
@end

/// 泛型响应基类（对象类型）
/// 用法: YOResponseObject<YODeviceReportData *> *response
@interface YOResponseObject<__covariant DataType> : NSObject

@property (nonatomic, copy)            NSString  *code;
@property (nonatomic, copy)            NSString  *msg;
@property (nonatomic, strong, nullable) DataType  data;
@property (nonatomic, assign, readonly) BOOL      isSuccess;

+ (instancetype)responseFromDictionary:(NSDictionary *)dict
                             dataClass:(Class)dataClass;

@end

/// 泛型响应基类（数组类型）
/// 用法: YOResponseArray<YODeviceReportData *> *response
@interface YOResponseArray<__covariant DataType> : NSObject

@property (nonatomic, copy)             NSString            *code;
@property (nonatomic, copy)             NSString            *msg;
@property (nonatomic, strong, nullable) NSArray<DataType>   *data;
@property (nonatomic, assign, readonly) BOOL                 isSuccess;

+ (instancetype)responseFromDictionary:(NSDictionary *)dict
                             dataClass:(Class)dataClass;

@end

NS_ASSUME_NONNULL_END
