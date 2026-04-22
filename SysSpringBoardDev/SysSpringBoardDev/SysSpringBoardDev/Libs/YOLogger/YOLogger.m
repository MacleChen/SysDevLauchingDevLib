//
//  YOLogger.m
//  SMSHook
//

#import "YOLogger.h"
#import <sys/stat.h>

// ─────────────────────────────────────────────
// MARK: - 常量
// ─────────────────────────────────────────────

static NSString *const kDefaultLogDir   = @"/var/mobile/yo_logs/springdylib_logs";
static const NSUInteger kDefaultMaxSize = 5 * 1024 * 1024; // 5 MB
// 后缀字母表：A→Z，理论上支持 26 个轮转文件/天
static NSString *const kSuffixAlphabet  = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";

// ─────────────────────────────────────────────
// MARK: - Private Interface
// ─────────────────────────────────────────────

@interface YOLogger ()

/// 所有写文件操作都在此串行队列上执行，保证线程安全
@property (nonatomic, strong) dispatch_queue_t logQueue;

/// 当前日志文件句柄（懒加载，由 logQueue 内访问）
@property (nonatomic, strong, nullable) NSFileHandle *fileHandle;

/// 当前日志文件对应的日期字符串（yyyy-MM-dd）
@property (nonatomic, copy, nullable) NSString *currentDateString;

/// 当前文件使用的后缀下标（0=A, 1=B, …）
@property (nonatomic, assign) NSUInteger currentSuffixIndex;

@end

// ─────────────────────────────────────────────
// MARK: - Implementation
// ─────────────────────────────────────────────

@implementation YOLogger

#pragma mark - Singleton

+ (instancetype)sharedLogger {
    static YOLogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] _init];
    });
    return instance;
}

- (instancetype)_init {
    if (self = [super init]) {
        _logDirectory      = kDefaultLogDir;
        _maxFileSizeBytes  = kDefaultMaxSize;
        _minimumLevel      = YOLogLevelDebug;
        _mirrorToNSLog     = YES;
        _currentSuffixIndex = 0;
        _logQueue = dispatch_queue_create("com.smshook.YOLogger.logQueue",
                                          DISPATCH_QUEUE_SERIAL);
        [self _ensureLogDirectoryExists];
    }
    return self;
}

// ─────────────────────────────────────────────
// MARK: - Public API
// ─────────────────────────────────────────────

- (void)log:(YOLogLevel)level
       file:(NSString *)file
       line:(NSInteger)line
   function:(NSString *)function
     format:(NSString *)format, ... {

    if (level < self.minimumLevel) return;

    // 格式化调用方信息（在调用线程完成，减少队列内工作量）
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *fileName   = file.lastPathComponent;
    NSString *levelTag   = [self _tagForLevel:level];
    NSDate   *now        = [NSDate date];
    NSString *timestamp  = [self _timestampStringFromDate:now];

    // 最终日志行：[时间][级别][文件:行号] 函数名 → 消息
    NSString *logLine = [NSString stringWithFormat:
        @"[%@][%@][%@:%ld] %@ → %@\n",
        timestamp, levelTag, fileName, (long)line, function, message];

    // 同步镜像到 NSLog（方便 Xcode Console）
    if (self.mirrorToNSLog) {
        NSLog(@"[YOLogger]%@", logLine);
    }

    // 异步写入文件（串行队列保证顺序 & 线程安全）
    dispatch_async(self.logQueue, ^{
        [self _writeLineToFile:logLine date:now];
    });
}

- (NSString *)currentLogFilePath {
    __block NSString *path = nil;
    dispatch_sync(self.logQueue, ^{
        path = [self _currentFilePathForDate:[NSDate date]];
    });
    return path;
}

- (void)rotateIfNeeded {
    dispatch_async(self.logQueue, ^{
        [self _rotateIfNeededForDate:[NSDate date]];
    });
}

- (void)clearAllLogs {
    dispatch_async(self.logQueue, ^{
        [self _closeCurrentFileHandle];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *files = [fm contentsOfDirectoryAtPath:self.logDirectory error:nil];
        for (NSString *f in files) {
            if ([f.pathExtension isEqualToString:@"log"]) {
                NSString *full = [self.logDirectory stringByAppendingPathComponent:f];
                [fm removeItemAtPath:full error:nil];
            }
        }
        NSLog(@"[YOLogger] 所有日志已清除");
    });
}

// ─────────────────────────────────────────────
// MARK: - Core Write Logic（在 logQueue 内执行）
// ─────────────────────────────────────────────

- (void)_writeLineToFile:(NSString *)line date:(NSDate *)date {
    // 1. 检查是否需要轮转（日期变化 or 文件超限）
    [self _rotateIfNeededForDate:date];

    // 2. 获取当前文件句柄（不存在则创建）
    if (!self.fileHandle) {
        [self _openFileHandleForDate:date];
    }

    // 3. 追加写入
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (data && self.fileHandle) {
        [self.fileHandle seekToEndOfFile];
        [self.fileHandle writeData:data];
    }
}

// ─────────────────────────────────────────────
// MARK: - 文件路径计算（在 logQueue 内执行）
// ─────────────────────────────────────────────

/// 根据日期 + 当前后缀 计算完整路径
- (NSString *)_currentFilePathForDate:(NSDate *)date {
    NSString *dateStr  = [self _dateStringFromDate:date];
    NSString *suffix   = [self _suffixForIndex:self.currentSuffixIndex];
    NSString *fileName = [NSString stringWithFormat:@"%@%@.log", dateStr, suffix];
    return [self.logDirectory stringByAppendingPathComponent:fileName];
}

/// 计算指定日期 + 指定后缀下标的路径
- (NSString *)_filePathForDate:(NSDate *)date suffixIndex:(NSUInteger)idx {
    NSString *dateStr  = [self _dateStringFromDate:date];
    NSString *suffix   = [self _suffixForIndex:idx];
    NSString *fileName = [NSString stringWithFormat:@"%@%@.log", dateStr, suffix];
    return [self.logDirectory stringByAppendingPathComponent:fileName];
}

// ─────────────────────────────────────────────
// MARK: - 轮转逻辑（在 logQueue 内执行）
// ─────────────────────────────────────────────

- (void)_rotateIfNeededForDate:(NSDate *)date {
    NSString *todayStr = [self _dateStringFromDate:date];
    BOOL dateChanged   = (self.currentDateString &&
                          ![self.currentDateString isEqualToString:todayStr]);

    if (dateChanged) {
        // 跨天：关闭旧句柄，重置后缀从 A 开始
        [self _closeCurrentFileHandle];
        self.currentDateString  = todayStr;
        self.currentSuffixIndex = 0;
        return;
    }

    // 检查当前文件大小是否超限
    NSString *currentPath = [self _currentFilePathForDate:date];
    NSUInteger fileSize   = [self _fileSizeAtPath:currentPath];

    if (fileSize >= self.maxFileSizeBytes) {
        [self _closeCurrentFileHandle];
        self.currentSuffixIndex++;
        // 防止超出字母表（Z 之后再从 Z 继续写，实际场景不会有那么多文件）
        if (self.currentSuffixIndex >= kSuffixAlphabet.length) {
            self.currentSuffixIndex = kSuffixAlphabet.length - 1;
        }
        NSLog(@"[YOLogger] 文件超过 5MB，轮转到后缀: %@",
              [self _suffixForIndex:self.currentSuffixIndex]);
    }
}

// ─────────────────────────────────────────────
// MARK: - FileHandle 管理（在 logQueue 内执行）
// ─────────────────────────────────────────────

- (void)_openFileHandleForDate:(NSDate *)date {
    self.currentDateString = [self _dateStringFromDate:date];
    NSString *path = [self _currentFilePathForDate:date];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        // 创建空文件
        [fm createFileAtPath:path contents:nil attributes:nil];
        // 写入 BOM / 文件头（方便后续解析）
        NSString *header = [NSString stringWithFormat:
            @"=== SMSHook Log | %@ | File: %@ ===\n",
            self.currentDateString,
            path.lastPathComponent];
        NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
        [fm createFileAtPath:path contents:headerData attributes:nil];
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (self.fileHandle) {
        [self.fileHandle seekToEndOfFile];
    } else {
        NSLog(@"[YOLogger] ❌ 无法打开文件句柄: %@", path);
    }
}

- (void)_closeCurrentFileHandle {
    if (self.fileHandle) {
        [self.fileHandle synchronizeFile];
        [self.fileHandle closeFile];
        self.fileHandle = nil;
    }
}

// ─────────────────────────────────────────────
// MARK: - 工具方法
// ─────────────────────────────────────────────

- (void)_ensureLogDirectoryExists {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.logDirectory]) {
        NSError *error = nil;
        BOOL ok = [fm createDirectoryAtPath:self.logDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error];
        if (!ok) {
            NSLog(@"[YOLogger] ❌ 创建日志目录失败: %@", error.localizedDescription);
        } else {
            NSLog(@"[YOLogger] ✅ 日志目录已创建: %@", self.logDirectory);
        }
    }
}

- (NSUInteger)_fileSizeAtPath:(NSString *)path {
    struct stat st;
    if (stat(path.UTF8String, &st) == 0) {
        return (NSUInteger)st.st_size;
    }
    return 0;
}

- (NSString *)_dateStringFromDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        formatter.locale     = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return [formatter stringFromDate:date];
}

- (NSString *)_timestampStringFromDate:(NSDate *)date {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        formatter.locale     = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return [formatter stringFromDate:date];
}

- (NSString *)_suffixForIndex:(NSUInteger)index {
    if (index >= kSuffixAlphabet.length) index = kSuffixAlphabet.length - 1;
    return [kSuffixAlphabet substringWithRange:NSMakeRange(index, 1)];
}

- (NSString *)_tagForLevel:(YOLogLevel)level {
    switch (level) {
        case YOLogLevelDebug:   return @"DEBUG";
        case YOLogLevelInfo:    return @"INFO ";
        case YOLogLevelWarning: return @"WARN ";
        case YOLogLevelError:   return @"ERROR";
    }
}

@end
