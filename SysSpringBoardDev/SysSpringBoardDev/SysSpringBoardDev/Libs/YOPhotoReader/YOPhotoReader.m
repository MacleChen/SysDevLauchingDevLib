//
//  YOPhotoReader.m
//  SMSHook
//

#import "YOPhotoReader.h"
#import "../YOLogger/YOLogger.h"

NSString *const YOPhotoReaderErrorDomain = @"com.smshook.YOPhotoReaderErrorDomain";

// ─────────────────────────────────────────────
// MARK: - YOPhotoAsset Implementation
// ─────────────────────────────────────────────

@interface YOPhotoAsset ()
@property (nonatomic, strong, readwrite) PHAsset *asset;
@property (nonatomic, strong, readwrite) UIImage  *image;
@property (nonatomic, assign, readwrite) NSUInteger index;
@property (nonatomic, copy,   readwrite) NSString  *filename;
@property (nonatomic, strong, readwrite, nullable) NSDate *creationDate;
@property (nonatomic, assign, readwrite) CGSize     pixelSize;
@property (nonatomic, assign, readwrite) long long  fileSize;
@property (nonatomic, copy,   readwrite) NSString  *mediaTypeString;
@end

@implementation YOPhotoAsset

- (NSString *)debugDescription {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat       = @"yyyy-MM-dd HH:mm:ss";

    return [NSString stringWithFormat:
        @"<YOPhotoAsset #%lu>\n"
        @"  文件名    : %@\n"
        @"  尺寸      : %.0f × %.0f px\n"
        @"  拍摄时间  : %@\n"
        @"  文件大小  : %@\n"
        @"  媒体类型  : %@\n"
        @"  UIImage   : %@ (scale=%.1f)\n"
        @"  localID   : %@",
        (unsigned long)self.index,
        self.filename,
        self.pixelSize.width, self.pixelSize.height,
        self.creationDate ? [fmt stringFromDate:self.creationDate] : @"未知",
        [self _humanReadableFileSize],
        self.mediaTypeString,
        NSStringFromCGSize(self.image.size), self.image.scale,
        self.asset.localIdentifier];
}

- (NSString *)_humanReadableFileSize {
    if (self.fileSize < 0) return @"未知";
    double kb = self.fileSize / 1024.0;
    if (kb < 1024) return [NSString stringWithFormat:@"%.1f KB", kb];
    return [NSString stringWithFormat:@"%.2f MB", kb / 1024.0];
}

@end

// ─────────────────────────────────────────────
// MARK: - YOPhotoReader Private Interface
// ─────────────────────────────────────────────

@interface YOPhotoReader ()
/// 专用后台队列（PHImageManager 的回调也在此调度）
@property (nonatomic, strong) dispatch_queue_t readerQueue;
/// 图片管理器（复用同一个实例）
@property (nonatomic, strong) PHImageManager   *imageManager;
@end

// ─────────────────────────────────────────────
// MARK: - YOPhotoReader Implementation
// ─────────────────────────────────────────────

@implementation YOPhotoReader

#pragma mark - Singleton

+ (instancetype)sharedReader {
    static YOPhotoReader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] _init];
    });
    return instance;
}

- (instancetype)_init {
    if (self = [super init]) {
        _readerQueue  = dispatch_queue_create("com.smshook.YOPhotoReader.queue",
                                              DISPATCH_QUEUE_CONCURRENT);
        _imageManager = [PHImageManager defaultManager];
    }
    return self;
}

// ─────────────────────────────────────────────
// MARK: - 权限
// ─────────────────────────────────────────────

- (PHAuthorizationStatus)authorizationStatus {
    if (@available(iOS 14.0, *)) {
        return [PHPhotoLibrary authorizationStatusForAccessLevel:
                PHAccessLevelReadWrite];
    }
    return [PHPhotoLibrary authorizationStatus];
}

- (BOOL)isAuthorized {
    PHAuthorizationStatus s = self.authorizationStatus;
    if (@available(iOS 14.0, *)) {
        return (s == PHAuthorizationStatusAuthorized ||
                s == PHAuthorizationStatusLimited);
    }
    return s == PHAuthorizationStatusAuthorized;
}

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL, PHAuthorizationStatus))completion {
    if (!completion) return;

    // 已有权限直接回调
    if (self.isAuthorized) {
        YOLogI(@"[Photo] 已有相册权限 (status=%ld)", (long)self.authorizationStatus);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, self.authorizationStatus);
        });
        return;
    }

    YOLogI(@"[Photo] 发起相册权限请求...");

    void (^handler)(PHAuthorizationStatus) = ^(PHAuthorizationStatus status) {
        BOOL granted = NO;
        NSString *statusStr = @"";
        switch (status) {
            case PHAuthorizationStatusAuthorized:
                granted = YES; statusStr = @"完全授权"; break;
            case PHAuthorizationStatusLimited:
                granted = YES; statusStr = @"受限授权（部分照片）"; break;
            case PHAuthorizationStatusDenied:
                statusStr = @"用户拒绝"; break;
            case PHAuthorizationStatusRestricted:
                statusStr = @"系统限制"; break;
            case PHAuthorizationStatusNotDetermined:
                statusStr = @"未决定"; break;
            default:
                statusStr = @"未知"; break;
        }
        YOLogI(@"[Photo] 权限请求结果: %@ (granted=%@)", statusStr, granted ? @"YES" : @"NO");
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted, status);
        });
    };

    if (@available(iOS 14.0, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:handler];
    } else {
        [PHPhotoLibrary requestAuthorization:handler];
    }
}

// ─────────────────────────────────────────────
// MARK: - 查询
// ─────────────────────────────────────────────

- (NSUInteger)totalPhotoCount {
    if (!self.isAuthorized) return 0;
    return [self _buildFetchResult].count;
}

- (NSArray<PHAsset *> *)allPhotoAssets {
    if (!self.isAuthorized) return @[];
    PHFetchResult<PHAsset *> *result = [self _buildFetchResult];
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:result.count];
    [result enumerateObjectsUsingBlock:^(PHAsset *obj, NSUInteger idx, BOOL *stop) {
        [assets addObject:obj];
    }];
    return assets.copy;
}

// ─────────────────────────────────────────────
// MARK: - 读取单张
// ─────────────────────────────────────────────

- (void)fetchFirstPhotoWithTargetSize:(CGSize)targetSize
                           completion:(YOPhotoAssetCompletion)completion {
    [self fetchPhotoAtIndex:0 targetSize:targetSize completion:completion];
}

- (void)fetchPhotoAtIndex:(NSUInteger)index
               targetSize:(CGSize)targetSize
               completion:(YOPhotoAssetCompletion)completion {

    if (!completion) return;

    dispatch_async(self.readerQueue, ^{
        if (!self.isAuthorized) {
            YOLogW(@"[Photo] 无相册权限，无法读取图片");
            [self _callCompletion:completion asset:nil
                            error:[self _errorWithCode:YOPhotoReaderErrorPermissionDenied
                                               message:@"无相册访问权限"]];
            return;
        }

        PHFetchResult<PHAsset *> *result = [self _buildFetchResult];
        if (result.count == 0) {
            YOLogW(@"[Photo] 相册为空");
            [self _callCompletion:completion asset:nil
                            error:[self _errorWithCode:YOPhotoReaderErrorEmptyLibrary
                                               message:@"相册中没有图片"]];
            return;
        }

        if (index >= result.count) {
            YOLogW(@"[Photo] 序号 %lu 超出范围（共 %lu 张）",
                   (unsigned long)index, (unsigned long)result.count);
            [self _callCompletion:completion asset:nil
                            error:[self _errorWithCode:YOPhotoReaderErrorImageLoadFailed
                                               message:@"序号超出范围"]];
            return;
        }

        PHAsset *asset = [result objectAtIndex:index];
        YOLogD(@"[Photo] 开始加载第 %lu 张图片 (localID=%@)",
               (unsigned long)index, asset.localIdentifier);

        [self _loadImage:asset
                   index:index
              targetSize:targetSize
              completion:completion];
    });
}

// ─────────────────────────────────────────────
// MARK: - 批量读取
// ─────────────────────────────────────────────

- (void)fetchPhotosWithLimit:(NSUInteger)limit
                  targetSize:(CGSize)targetSize
                    progress:(nullable YOPhotoProgressBlock)progress
                  completion:(YOPhotoBatchCompletion)completion {

    dispatch_async(self.readerQueue, ^{
        if (!self.isAuthorized) {
            YOLogW(@"[Photo] 无相册权限，跳过批量读取");
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(@[], 0); });
            return;
        }

        PHFetchResult<PHAsset *> *result = [self _buildFetchResult];
        NSUInteger total = (limit == 0 || limit > result.count) ? result.count : limit;

        YOLogI(@"[Photo] 批量读取开始：共 %lu 张，限制 %lu 张，目标尺寸 %.0f×%.0f",
               (unsigned long)result.count,
               (unsigned long)total,
               targetSize.width, targetSize.height);

        if (total == 0) {
            YOLogW(@"[Photo] 相册为空，批量读取结束");
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(@[], 0); });
            return;
        }

        // 使用信号量逐张同步加载（保证顺序 + 不阻塞主线程）
        NSMutableArray<YOPhotoAsset *> *loaded = [NSMutableArray arrayWithCapacity:total];
        __block NSUInteger failedCount = 0;
        __block BOOL shouldStop = NO;

        for (NSUInteger i = 0; i < total && !shouldStop; i++) {
            PHAsset *asset = [result objectAtIndex:i];

            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            __block YOPhotoAsset *photoAsset = nil;

            [self _loadImage:asset
                       index:i
                  targetSize:targetSize
                  completion:^(YOPhotoAsset *pa, NSError *err) {
                if (pa) {
                    photoAsset = pa;
                } else {
                    failedCount++;
                    YOLogW(@"[Photo] 第 %lu 张加载失败: %@",
                           (unsigned long)i, err.localizedDescription);
                }
                dispatch_semaphore_signal(sema);
            }];

            dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW,
                                                        10 * NSEC_PER_SEC));

            if (photoAsset) {
                [loaded addObject:photoAsset];

                // 每张完成后触发 progress 回调（主线程）
                if (progress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progress(photoAsset, i, total, &shouldStop);
                    });
                }
            }
        }

        YOLogI(@"[Photo] 批量读取完成：成功 %lu 张，失败 %lu 张",
               (unsigned long)loaded.count, (unsigned long)failedCount);
        [self logLibrarySummary];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(loaded.copy, failedCount);
        });
    });
}

// ─────────────────────────────────────────────
// MARK: - 日志打印
// ─────────────────────────────────────────────

- (void)logAssetInfo:(YOPhotoAsset *)asset {
    if (!asset) return;
    YOLogI(@"[Photo] 图片已获取:\n%@", asset.debugDescription);
}

- (void)logLibrarySummary {
    if (!self.isAuthorized) {
        YOLogW(@"[Photo] 相册未授权，无法统计");
        return;
    }
    PHFetchResult *result = [self _buildFetchResult];

    // 统计视频数
    PHFetchOptions *videoOpts  = [[PHFetchOptions alloc] init];
    videoOpts.predicate = [NSPredicate predicateWithFormat:
                           @"mediaType == %d", PHAssetMediaTypeVideo];
    PHFetchResult *videos = [PHAsset fetchAssetsWithOptions:videoOpts];

    YOLogI(@"[Photo] ─── 相册概览 ───────────────");
    YOLogI(@"[Photo]   图片总数  : %lu 张", (unsigned long)result.count);
    YOLogI(@"[Photo]   视频总数  : %lu 条", (unsigned long)videos.count);
    YOLogI(@"[Photo]   权限状态  : %@", [self _authStatusString]);
    YOLogI(@"[Photo] ─────────────────────────────");
}

// ─────────────────────────────────────────────
// MARK: - 核心图片加载（私有）
// ─────────────────────────────────────────────

/**
 * 调用 PHImageManager 请求图片，组装 YOPhotoAsset 后回调
 * 在 readerQueue 上调用；completion 切回主线程
 */
- (void)_loadImage:(PHAsset *)phAsset
             index:(NSUInteger)index
        targetSize:(CGSize)targetSize
        completion:(YOPhotoAssetCompletion)completion {

    PHImageRequestOptions *opts = [[PHImageRequestOptions alloc] init];
    opts.synchronous        = NO;
    opts.deliveryMode       = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    opts.resizeMode         = PHImageRequestOptionsResizeModeExact;
    opts.networkAccessAllowed = YES; // 允许从 iCloud 下载

    [self.imageManager requestImageForAsset:phAsset
                                 targetSize:targetSize
                                contentMode:PHImageContentModeAspectFit
                                    options:opts
                              resultHandler:^(UIImage *_Nullable result,
                                              NSDictionary *_Nullable info) {

        // PHImageManager 可能多次回调（先给缩略图再给高清图）
        // deliveryMode=HighQuality 时通常只回调一次，但 iCloud 图片会先回调占位图
        BOOL isDegraded = [info[PHImageResultIsDegradedKey] boolValue];
        if (isDegraded) return; // 跳过低质量预览回调

        BOOL isCancelled = [info[PHImageCancelledKey] boolValue];
        NSError *phError = info[PHImageErrorKey];

        if (isCancelled || phError || !result) {
            YOLogE(@"[Photo] PHImageManager 加载失败 #%lu: cancelled=%@, error=%@",
                   (unsigned long)index,
                   isCancelled ? @"YES" : @"NO",
                   phError.localizedDescription ?: @"图片为空");
            [self _callCompletion:completion asset:nil
                            error:phError ?: [self _errorWithCode:YOPhotoReaderErrorImageLoadFailed
                                                          message:@"图片加载失败"]];
            return;
        }

        // ── 组装 YOPhotoAsset ──────────────────────────────────────────────

        YOPhotoAsset *photoAsset = [[YOPhotoAsset alloc] init];
        photoAsset.asset        = phAsset;
        photoAsset.image        = result;
        photoAsset.index        = index;
        photoAsset.pixelSize    = CGSizeMake(phAsset.pixelWidth, phAsset.pixelHeight);
        photoAsset.creationDate = phAsset.creationDate;

        // 文件名
        PHAssetResource *resource = [[PHAssetResource assetResourcesForAsset:phAsset]
                                     firstObject];
        photoAsset.filename        = resource.originalFilename ?: @"unknown";
        photoAsset.mediaTypeString = [self _mediaTypeStringForAsset:phAsset];

        // ── 打印日志 ───────────────────────────────────────────────────────
        [self logAssetInfo:photoAsset];

        [self _callCompletion:completion asset:photoAsset error:nil];
    }];
}

// ─────────────────────────────────────────────
// MARK: - 工具方法（私有）
// ─────────────────────────────────────────────

/// 构建按创建时间降序排列的 FetchResult（图片类型）
- (PHFetchResult<PHAsset *> *)_buildFetchResult {
    PHFetchOptions *opts        = [[PHFetchOptions alloc] init];
    opts.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                  ascending:NO]];
    opts.predicate              = [NSPredicate predicateWithFormat:
                                   @"mediaType == %d", PHAssetMediaTypeImage];
    return [PHAsset fetchAssetsWithOptions:opts];
}

/// 根据 UTI 猜测媒体类型字符串
- (NSString *)_mediaTypeStringForAsset:(PHAsset *)asset {
    PHAssetResource *resource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    NSString *uti = resource.uniformTypeIdentifier ?: @"";
    if ([uti containsString:@"heic"] || [uti containsString:@"heif"]) return @"image/heic";
    if ([uti containsString:@"jpeg"] || [uti containsString:@"jpg"])  return @"image/jpeg";
    if ([uti containsString:@"png"])  return @"image/png";
    if ([uti containsString:@"gif"])  return @"image/gif";
    if ([uti containsString:@"tiff"]) return @"image/tiff";
    if ([uti containsString:@"raw"])  return @"image/raw";
    return uti.length > 0 ? uti : @"image/unknown";
}

- (NSString *)_authStatusString {
    switch (self.authorizationStatus) {
        case PHAuthorizationStatusAuthorized:    return @"完全授权";
        case PHAuthorizationStatusLimited:       return @"受限授权（部分照片）";
        case PHAuthorizationStatusDenied:        return @"已拒绝";
        case PHAuthorizationStatusRestricted:    return @"系统限制";
        case PHAuthorizationStatusNotDetermined: return @"未请求";
        default:                                 return @"未知";
    }
}

- (void)_callCompletion:(YOPhotoAssetCompletion)completion
                  asset:(nullable YOPhotoAsset *)asset
                  error:(nullable NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(asset, error);
    });
}

- (NSError *)_errorWithCode:(YOPhotoReaderErrorCode)code message:(NSString *)message {
    return [NSError errorWithDomain:YOPhotoReaderErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
