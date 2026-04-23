//
//  AssetToImagesReader.m
//  SysSpringBoardDev
//
//  Created by 陈帆 on 2026/04/22.
//

#import "AssetToImagesReader.h"
#import <Photos/Photos.h>
#import "VisionImageRecUtil.h"

@implementation AssetToImagesReader

+ (void)fetchPhotosInBackground {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        
        PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
        
        // 创建串行队列（逐张处理）
        dispatch_queue_t serialQueue = dispatch_queue_create("com.yourapp.assettoimages", DISPATCH_QUEUE_SERIAL);
        
        for (NSInteger i = 0; i < result.count; i++) {
            PHAsset *asset = result[i];
            
            // 每次延迟40秒调度执行
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 3.0 * NSEC_PER_SEC)), serialQueue, ^{
                [self fetchImageForAsset:asset];
            });
        }
    });
}

+ (void)fetchImageForAsset:(PHAsset *)asset {
    PHImageManager *imageManager = [PHImageManager defaultManager];
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    requestOptions.synchronous = NO; // 异步请求图片
    
    [imageManager requestImageForAsset:asset
                            targetSize:PHImageManagerMaximumSize // 你可以根据需求调整大小
                           contentMode:PHImageContentModeAspectFit
                               options:requestOptions
                         resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if (result) {
            // 在这里处理获取到的图片
//            NSLog(@"Image: %@", result);
            [[VisionImageRecUtil sharedInstance] recognizeTextInImage:result];
        }
    }];
}

@end
