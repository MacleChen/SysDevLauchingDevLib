//
//  VisionImageRecUtil.h
//  SysSpringBoardDev
//
//  Created by 陈帆 on 2026/04/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VisionImageRecUtil : NSObject


+ (instancetype)sharedInstance;

- (void)recognizeTextInImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
