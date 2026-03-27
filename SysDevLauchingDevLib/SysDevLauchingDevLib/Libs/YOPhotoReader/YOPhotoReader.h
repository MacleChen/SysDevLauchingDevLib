//
//  YOPhotoReader.h
//  SMSHook
//
//  相册读取模块
//  - 封装 Photos.framework 授权 + 批量/单张读取
//  - 获取到图片对象后通过 YOLogger 打印详细信息
//  - 所有回调统一在主线程执行
//

#ifndef YOPhotoReader_h
#define YOPhotoReader_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

// ─────────────────────────────────────────────
// MARK: - 错误域 & 错误码
// ─────────────────────────────────────────────

extern NSString *const YOPhotoReaderErrorDomain;

typedef NS_ENUM(NSInteger, YOPhotoReaderErrorCode) {
    /// 用户拒绝相册权限
    YOPhotoReaderErrorPermissionDenied      = 2001,
    /// 权限受限（家长控制等）
    YOPhotoReaderErrorPermissionRestricted  = 2002,
    /// 相册为空，没有任何图片
    YOPhotoReaderErrorEmptyLibrary          = 2003,
    /// PHImageManager 返回空图片
    YOPhotoReaderErrorImageLoadFailed       = 2004,
    /// 请求图片超时
    YOPhotoReaderErrorTimeout               = 2005,
};

// ─────────────────────────────────────────────
// MARK: - 图片信息模型
// ─────────────────────────────────────────────

/// 单张图片的元数据 + 图片对象
@interface YOPhotoAsset : NSObject

/// PHAsset 原始对象
@property (nonatomic, strong, readonly) PHAsset *asset;

/// 解码后的 UIImage（已加载完成）
@property (nonatomic, strong, readonly) UIImage *image;

/// 图片在相册中的序号（从 0 开始）
@property (nonatomic, assign, readonly) NSUInteger index;

/// 文件名（如 "IMG_0001.HEIC"）
@property (nonatomic, copy,   readonly) NSString *filename;

/// 拍摄时间（nil 表示未知）
@property (nonatomic, strong, readonly, nullable) NSDate *creationDate;

/// 图片尺寸（PHAsset 原始分辨率，未缩放）
@property (nonatomic, assign, readonly) CGSize pixelSize;

/// 文件大小（字节，-1 表示未知）
@property (nonatomic, assign, readonly) long long fileSize;

/// 媒体类型描述（"image/jpeg"、"image/heic" 等）
@property (nonatomic, copy, readonly) NSString *mediaTypeString;

/// 便捷描述，用于日志打印
- (NSString *)debugDescription;

@end

// ─────────────────────────────────────────────
// MARK: - 回调类型
// ─────────────────────────────────────────────

/// 单张图片加载完成回调
/// @param asset   封装好的图片信息（加载失败时为 nil）
/// @param error   错误信息（成功时为 nil）
typedef void (^YOPhotoAssetCompletion)(YOPhotoAsset *_Nullable asset,
                                       NSError *_Nullable error);

/// 批量加载进度回调（每加载完一张触发一次）
/// @param asset      当前图片
/// @param index      当前序号（从 0 开始）
/// @param total      总数
/// @param stop       设为 YES 可中止后续加载
typedef void (^YOPhotoProgressBlock)(YOPhotoAsset *asset,
                                     NSUInteger index,
                                     NSUInteger total,
                                     BOOL *stop);

/// 批量加载全部完成回调
/// @param assets     成功加载的图片数组
/// @param failed     加载失败的数量
typedef void (^YOPhotoBatchCompletion)(NSArray<YOPhotoAsset *> *assets,
                                       NSUInteger failed);

// ─────────────────────────────────────────────
// MARK: - YOPhotoReader
// ─────────────────────────────────────────────

@interface YOPhotoReader : NSObject

/// 单例
+ (instancetype)sharedReader;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new  NS_UNAVAILABLE;

// ─────────────────────────────────────────────
// MARK: - 权限
// ─────────────────────────────────────────────

/// 当前相册授权状态
@property (nonatomic, assign, readonly) PHAuthorizationStatus authorizationStatus;

/// 是否已获得读取权限
@property (nonatomic, assign, readonly) BOOL isAuthorized;

/**
 * 请求相册读取权限（如果已有权限则直接回调）
 * @param completion  granted=YES 表示有权限，主线程回调
 */
- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted,
                                                      PHAuthorizationStatus status))completion;

// ─────────────────────────────────────────────
// MARK: - 查询
// ─────────────────────────────────────────────

/**
 * 查询相册中图片总数（不加载图片数据）
 * @return 图片数量，未授权时返回 0
 */
- (NSUInteger)totalPhotoCount;

/**
 * 获取所有 PHAsset（按创建时间降序，最新的在前）
 * @return PHAsset 数组，未授权时返回空数组
 */
- (NSArray<PHAsset *> *)allPhotoAssets;

// ─────────────────────────────────────────────
// MARK: - 读取单张
// ─────────────────────────────────────────────

/**
 * 读取相册第一张图片（最新拍摄）
 *
 * @param targetSize   请求的图片尺寸（传 PHImageManagerMaximumSize 获取原图）
 * @param completion   主线程回调
 */
- (void)fetchFirstPhotoWithTargetSize:(CGSize)targetSize
                           completion:(YOPhotoAssetCompletion)completion;

/**
 * 按序号读取指定图片
 *
 * @param index        序号（0 = 最新）
 * @param targetSize   请求的图片尺寸
 * @param completion   主线程回调
 */
- (void)fetchPhotoAtIndex:(NSUInteger)index
               targetSize:(CGSize)targetSize
               completion:(YOPhotoAssetCompletion)completion;

// ─────────────────────────────────────────────
// MARK: - 批量读取
// ─────────────────────────────────────────────

/**
 * 批量读取前 N 张图片（按创建时间降序）
 *
 * @param limit        最多读取张数（传 0 表示全部）
 * @param targetSize   每张图片请求的尺寸
 * @param progress     每张完成时回调（可传 nil）
 * @param completion   全部完成后回调（主线程）
 */
- (void)fetchPhotosWithLimit:(NSUInteger)limit
                  targetSize:(CGSize)targetSize
                    progress:(nullable YOPhotoProgressBlock)progress
                  completion:(YOPhotoBatchCompletion)completion;

// ─────────────────────────────────────────────
// MARK: - 日志打印
// ─────────────────────────────────────────────

/**
 * 打印单张图片的详细信息到 YOLogger（内部自动调用，也可手动调用）
 * @param asset  YOPhotoAsset 对象
 */
- (void)logAssetInfo:(YOPhotoAsset *)asset;

/**
 * 打印相册概览统计信息
 */
- (void)logLibrarySummary;

@end

NS_ASSUME_NONNULL_END

#endif /* YOPhotoReader_h */
