//
//  YODeviceReportData.m
//  SysDevLauchingDevLib
//
//  Created by 陈帆 on 2026/03/31.
//

// YODeviceReportData.m
#import "YODeviceReportData.h"

@implementation YODeviceReportData

+ (nullable instancetype)modelFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    YODeviceReportData *obj = [[self alloc] init];
    obj.deviceId = dict[@"deviceId"] ?: @"";
    obj.devicePk = [dict[@"devicePk"] integerValue];
    obj.appCount = [dict[@"appCount"] integerValue];
    obj.isNew    = [dict[@"isNew"] boolValue];
    return obj;
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<YODeviceReportData deviceId=%@, devicePk=%ld, appCount=%ld, isNew=%@>",
            self.deviceId, (long)self.devicePk, (long)self.appCount,
            self.isNew ? @"YES" : @"NO"];
}

@end
