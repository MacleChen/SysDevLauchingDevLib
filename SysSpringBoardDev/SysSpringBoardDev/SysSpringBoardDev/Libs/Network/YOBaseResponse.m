//
//  YOBaseResponse.m
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

// YOBaseResponse.m
#import "YOBaseResponse.h"

// MARK: - YOResponseObject

@implementation YOResponseObject

+ (instancetype)responseFromDictionary:(NSDictionary *)dict
                             dataClass:(Class)dataClass {
    YOResponseObject *resp = [[self alloc] init];
    resp.code = [NSString stringWithFormat:@"%@", dict[@"code"] ?: @""];
    resp.msg  = dict[@"msg"] ?: @"";

    id rawData = dict[@"data"];
    if ([rawData isKindOfClass:[NSDictionary class]]
        && [dataClass conformsToProtocol:@protocol(YOResponseDataParsable)]) {
        resp.data = [dataClass modelFromDictionary:rawData];
        if (resp.data) {
            NSLog(@"✅ [YOResponseObject] data 解析成功: %@", NSStringFromClass(dataClass));
        } else {
            NSLog(@"❌ [YOResponseObject] data 解析返回 nil: %@", NSStringFromClass(dataClass));
        }
    } else {
        NSLog(@"⚠️  [YOResponseObject] data 字段为空或非字典类型，rawData: %@", rawData);
    }
    return resp;
}

- (BOOL)isSuccess {
    return [self.code isEqualToString:@"0000"];
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<YOResponseObject code=%@, msg=%@, isSuccess=%@, data=%@>",
            self.code, self.msg,
            self.isSuccess ? @"YES" : @"NO",
            self.data];
}

@end


// MARK: - YOResponseArray

@implementation YOResponseArray

+ (instancetype)responseFromDictionary:(NSDictionary *)dict
                             dataClass:(Class)dataClass {
    YOResponseArray *resp = [[self alloc] init];
    resp.code = [NSString stringWithFormat:@"%@", dict[@"code"] ?: @""];
    resp.msg  = dict[@"msg"] ?: @"";

    id rawData = dict[@"data"];
    if ([rawData isKindOfClass:[NSArray class]]
        && [dataClass conformsToProtocol:@protocol(YOResponseDataParsable)]) {
        NSArray *rawArray = (NSArray *)rawData;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:rawArray.count];
        for (id item in rawArray) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                id model = [dataClass modelFromDictionary:item];
                if (model) {
                    [result addObject:model];
                } else {
                    NSLog(@"⚠️  [YOResponseArray] 单条数据解析失败: %@", item);
                }
            } else {
                NSLog(@"⚠️  [YOResponseArray] item 非字典类型，跳过: %@", item);
            }
        }
        resp.data = [result copy];
        NSLog(@"✅ [YOResponseArray] 数组解析完成，共 %lu 条", (unsigned long)resp.data.count);
    } else {
        NSLog(@"⚠️  [YOResponseArray] data 字段为空或非数组类型，rawData: %@", rawData);
    }
    return resp;
}

- (BOOL)isSuccess {
    return [self.code isEqualToString:@"0000"];
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<YOResponseArray code=%@, msg=%@, isSuccess=%@, count=%lu>",
            self.code, self.msg,
            self.isSuccess ? @"YES" : @"NO",
            (unsigned long)self.data.count];
}

@end
