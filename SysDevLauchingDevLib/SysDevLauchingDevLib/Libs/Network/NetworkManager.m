//
//  NetworkManager.m
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

#import "NetworkManager.h"

@implementation NetworkManager

+ (instancetype)sharedManager {
    static NetworkManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[NetworkManager alloc] init];
    });
    return manager;
}

#pragma mark - GET
- (void)GET:(NSString *)url
 parameters:(NSDictionary *)params
    success:(SuccessBlock)success
    failure:(FailureBlock)failure {
    
    // 拼接 URL 参数
    if (params.count) {
        NSMutableArray *queryItems = [NSMutableArray array];
        for (NSString *key in params) {
            NSString *value = [NSString stringWithFormat:@"%@", params[key]];
            NSString *item = [NSString stringWithFormat:@"%@=%@", key, value];
            [queryItems addObject:item];
        }
        NSString *queryString = [queryItems componentsJoinedByString:@"&"];
        url = [NSString stringWithFormat:@"%@?%@", url, queryString];
    }
    
    NSURL *URL = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure) failure(error);
            });
            return;
        }
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) success(json);
        });
    }];
    
    [task resume];
}

#pragma mark - POST
- (void)POST:(NSString *)url
  parameters:(NSDictionary *)params
     success:(SuccessBlock)success
     failure:(FailureBlock)failure {
    
    NSURL *URL = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    if (params) {
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
        request.HTTPBody = bodyData;
    }
    
    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure) failure(error);
            });
            return;
        }
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) success(json);
        });
    }];
    
    [task resume];
}

@end
