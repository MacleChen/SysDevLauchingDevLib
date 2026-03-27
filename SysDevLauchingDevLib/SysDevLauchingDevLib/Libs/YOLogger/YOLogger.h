//
//  YOLogger.h
//  SMSHook
//
//  日志模块：支持文件轮转，按日期+后缀命名
//  存储路径：/var/mobile/yo_logs/springdylib_logs/
//  命名格式：2026-02-27A.log，超过 5MB 自动切换为 B、C…
//

#ifndef YOLogger_h
#define YOLogger_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ─────────────────────────────────────────────
// MARK: - 日志级别
// ─────────────────────────────────────────────

typedef NS_ENUM(NSInteger, YOLogLevel) {
    YOLogLevelDebug   = 0,   // 调试信息
    YOLogLevelInfo    = 1,   // 普通信息
    YOLogLevelWarning = 2,   // 警告
    YOLogLevelError   = 3,   // 错误
};

// ─────────────────────────────────────────────
// MARK: - 便捷宏
// ─────────────────────────────────────────────

/// 带文件名 / 行号的日志宏
#define YOLogD(fmt, ...) \
    [[YOLogger sharedLogger] log:YOLogLevelDebug \
                            file:@(__FILE__) \
                            line:__LINE__ \
                        function:@(__PRETTY_FUNCTION__) \
                          format:(fmt), ##__VA_ARGS__]

#define YOLogI(fmt, ...) \
    [[YOLogger sharedLogger] log:YOLogLevelInfo \
                            file:@(__FILE__) \
                            line:__LINE__ \
                        function:@(__PRETTY_FUNCTION__) \
                          format:(fmt), ##__VA_ARGS__]

#define YOLogW(fmt, ...) \
    [[YOLogger sharedLogger] log:YOLogLevelWarning \
                            file:@(__FILE__) \
                            line:__LINE__ \
                        function:@(__PRETTY_FUNCTION__) \
                          format:(fmt), ##__VA_ARGS__]

#define YOLogE(fmt, ...) \
    [[YOLogger sharedLogger] log:YOLogLevelError \
                            file:@(__FILE__) \
                            line:__LINE__ \
                        function:@(__PRETTY_FUNCTION__) \
                          format:(fmt), ##__VA_ARGS__]

// ─────────────────────────────────────────────
// MARK: - YOLogger
// ─────────────────────────────────────────────

@interface YOLogger : NSObject

/// 日志根目录（默认 /var/mobile/yo_logs/springdylib_logs）
@property (nonatomic, copy, readonly) NSString *logDirectory;

/// 单个日志文件最大字节数（默认 5 * 1024 * 1024 = 5 MB）
@property (nonatomic, assign) NSUInteger maxFileSizeBytes;

/// 当前最低输出级别（低于此级别的日志被忽略，默认 Debug）
@property (nonatomic, assign) YOLogLevel minimumLevel;

/// 是否同步写入 NSLog（方便 Xcode Console 查看，默认 YES）
@property (nonatomic, assign) BOOL mirrorToNSLog;

/// 单例
+ (instancetype)sharedLogger;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new  NS_UNAVAILABLE;

/// 核心写入方法（通过宏调用，也可直接调用）
- (void)log:(YOLogLevel)level
       file:(NSString *)file
       line:(NSInteger)line
   function:(NSString *)function
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(5, 6);

/// 返回当前正在写入的日志文件完整路径
- (NSString *)currentLogFilePath;

/// 手动触发文件轮转（一般不需要调用）
- (void)rotateIfNeeded;

/// 删除全部日志文件（谨慎使用）
- (void)clearAllLogs;

@end

NS_ASSUME_NONNULL_END

#endif /* YOLogger_h */
