//
//  NetworkManager.h
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

#import <Foundation/Foundation.h>

typedef void(^SuccessBlock)(id responseObject);
typedef void(^FailureBlock)(NSError *error);

@interface NetworkManager : NSObject

+ (instancetype)sharedManager;

// GET
- (void)GET:(NSString *)url
 parameters:(NSDictionary *)params
    success:(SuccessBlock)success
    failure:(FailureBlock)failure;

// POST
- (void)POST:(NSString *)url
  parameters:(NSDictionary *)params
     success:(SuccessBlock)success
     failure:(FailureBlock)failure;

@end
