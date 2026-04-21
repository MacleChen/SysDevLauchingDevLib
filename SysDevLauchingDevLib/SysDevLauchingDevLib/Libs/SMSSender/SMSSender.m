//
//  SMSSender.m
//  SMSHook
//

#import "SMSSender.h"
#import "../PrivateHeaders/IMPrivateHeaders.h"
#import <dlfcn.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────
// MARK: - 常量
// ─────────────────────────────────────────────

NSString *const SMSSenderErrorDomain = @"com.smshook.SMSSenderErrorDomain";

/// 私有框架路径
static NSString *const kChatKitPath      = @"/System/Library/PrivateFrameworks/ChatKit.framework/ChatKit";
static NSString *const kIMFoundationPath = @"/System/Library/PrivateFrameworks/IMFoundation.framework/IMFoundation";

// ─────────────────────────────────────────────
// MARK: - SMSSender (Private Interface)
// ─────────────────────────────────────────────

@interface SMSSender ()

/// 框架是否已加载
@property (nonatomic, assign) BOOL frameworkLoaded;

/// 发送专用串行队列（避免多线程竞态）
@property (nonatomic, strong) dispatch_queue_t sendQueue;

@end

// ─────────────────────────────────────────────
// MARK: - SMSSender Implementation
// ─────────────────────────────────────────────

@implementation SMSSender

#pragma mark - Singleton

+ (instancetype)sharedSender {
    static SMSSender *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] _init];
    });
    return instance;
}

- (instancetype)_init {
    if (self = [super init]) {
        _sendQueue = dispatch_queue_create("com.smshook.SMSSender.sendQueue",
                                           DISPATCH_QUEUE_SERIAL);
        _frameworkLoaded = NO;
        [self _loadPrivateFrameworks];
    }
    return self;
}

// ─────────────────────────────────────────────
// MARK: - 框架加载
// ─────────────────────────────────────────────

/// 加载私有框架（仅执行一次）
- (void)_loadPrivateFrameworks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *chatKit = dlopen(kChatKitPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        void *imFoundation = dlopen(kIMFoundationPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);

        if (!chatKit) {
            NSLog(@"[SMSSender] ❌ ChatKit 加载失败: %s", dlerror());
            return;
        }
        if (!imFoundation) {
            NSLog(@"[SMSSender] ❌ IMFoundation 加载失败: %s", dlerror());
            return;
        }

        // 验证关键类是否存在
        BOOL classesExist = (NSClassFromString(@"CKConversation")  != nil &&
                              NSClassFromString(@"CKComposition")   != nil &&
                              NSClassFromString(@"IMServiceImpl")   != nil &&
                              NSClassFromString(@"IMHandle")        != nil);

        if (!classesExist) {
            NSLog(@"[SMSSender] ❌ 关键私有类不存在，当前 iOS 版本可能不兼容");
            return;
        }

        self.frameworkLoaded = YES;
        NSLog(@"[SMSSender] ✅ 私有框架加载成功");
    });
}

// ─────────────────────────────────────────────
// MARK: - 公开接口实现
// ─────────────────────────────────────────────

- (BOOL)isAvailable {
    if (!self.frameworkLoaded) {
        [self _loadPrivateFrameworks];
    }
    return self.frameworkLoaded;
}

- (void)sendSMSTo:(NSString *)recipient
             body:(NSString *)body
       completion:(nullable SMSSenderCompletion)completion {

    // 参数校验（在调用线程同步执行，尽快返回错误）
    NSError *validationError = [self _validateRecipient:recipient body:body];
    if (validationError) {
        [self _invokeCompletion:completion success:NO error:validationError];
        return;
    }

    // 标准化号码
    NSString *normalizedRecipient = [SMSSender normalizePhoneNumber:recipient
                                                        countryCode:nil];

    // 切换到串行队列异步发送
    dispatch_async(self.sendQueue, ^{
        NSError *sendError = nil;
        BOOL success = [self _performSendTo:normalizedRecipient
                                       body:body
                                      error:&sendError];

        [self _invokeCompletion:completion success:success error:sendError];
    });
}

- (void)sendSMSToRecipients:(NSArray<NSString *> *)recipients
                       body:(NSString *)body
                 completion:(nullable void (^)(NSString *, BOOL, NSError *_Nullable))completion {

    if (recipients.count == 0) {
        NSError *error = [self _errorWithCode:SMSSenderErrorInvalidRecipient
                                      message:@"收件人列表为空"];
        if (completion) completion(@"", NO, error);
        return;
    }

    for (NSString *recipient in recipients) {
        [self sendSMSTo:recipient body:body completion:^(BOOL success, NSError *error) {
            if (completion) completion(recipient, success, error);
        }];
    }
}

// ─────────────────────────────────────────────
// MARK: - 核心发送逻辑（私有）
// ─────────────────────────────────────────────

/**
 * 实际调用私有 API 发送短信
 * 在 sendQueue 内执行，不要在主线程调用
 */
- (BOOL)_performSendTo:(NSString *)recipient
                  body:(NSString *)body
                 error:(NSError **)error {

    // 1. 检查框架是否可用
    if (!self.frameworkLoaded) {
        if (error) {
            *error = [self _errorWithCode:SMSSenderErrorFrameworkNotLoaded
                                  message:@"私有框架未加载，无法发送"];
        }
        return NO;
    }

    @try {
        // 2. 获取 SMS 服务
//        Class IMServiceClass = NSClassFromString(@"IMServiceImpl");
//        if (!IMServiceClass) {
//            if (error) *error = [self _errorWithCode:SMSSenderErrorClassNotFound
//                                             message:@"IMServiceImpl 类不存在"];
//            return NO;
//        }
//        IMServiceImpl *smsService = [IMServiceClass performSelector:@selector(SMSService)];
        
        // 2. 获取 SMS 服务（新方式）
//        Class IMServiceClass = NSClassFromString(@"IMService");
//        id smsService = [IMServiceClass performSelector:@selector(serviceWithName:)
//                                             withObject:@"SMS"];
//
//        if (!smsService) {
//            if (error) *error = [self _errorWithCode:SMSSenderErrorClassNotFound
//                                             message:@"获取 SMS 服务失败"];
//            return NO;
//        }
        

        // 3. 创建联系人句柄
        Class IMHandleClass = NSClassFromString(@"IMHandle");
        if (!IMHandleClass) {
            if (error) *error = [self _errorWithCode:SMSSenderErrorClassNotFound
                                             message:@"IMHandle 类不存在"];
            return NO;
        }
        IMHandle *handle = [IMHandleClass performSelector:@selector(handleWithID:)
                                               withObject:recipient];

        // 4. 获取或创建会话
        Class CKConvClass = NSClassFromString(@"CKConversation");
        if (!CKConvClass) {
            if (error) *error = [self _errorWithCode:SMSSenderErrorClassNotFound
                                             message:@"CKConversation 类不存在"];
            return NO;
        }
        CKConversation *conversation = [CKConvClass performSelector:@selector(conversationForAddresses:)
                                                        withObject:@[handle]];
        if (!conversation) {
            if (error) *error = [self _errorWithCode:SMSSenderErrorConversationFailed
                                             message:@"无法创建会话，请检查号码是否合法"];
            return NO;
        }

        // 5. 构建消息组合
        Class CKCompClass = NSClassFromString(@"CKComposition");
        if (!CKCompClass) {
            if (error) *error = [self _errorWithCode:SMSSenderErrorClassNotFound
                                             message:@"CKComposition 类不存在"];
            return NO;
        }
        NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:body];
        CKComposition *composition   = [[CKCompClass alloc] initWithText:attrText
                                                                  subject:nil];

        // 6. 发送
        [conversation sendMessageComposition:composition];

        NSLog(@"[SMSSender] ✅ 已提交发送 → %@（%lu 字）",
              recipient, (unsigned long)body.length);
        return YES;

    } @catch (NSException *exception) {
        NSLog(@"[SMSSender] ❌ 发送异常: %@", exception);
        if (error) {
            *error = [self _errorWithCode:SMSSenderErrorUnknown
                                  message:exception.reason ?: @"未知异常"];
        }
        return NO;
    }
}

// ─────────────────────────────────────────────
// MARK: - 工具方法
// ─────────────────────────────────────────────

+ (NSString *)normalizePhoneNumber:(NSString *)phoneNumber
                       countryCode:(nullable NSString *)countryCode {

    if (phoneNumber.length == 0) return phoneNumber;

    // 去除空格、连字符、括号
    NSCharacterSet *stripSet = [NSCharacterSet characterSetWithCharactersInString:@" -()"];
    NSString *normalized = [[phoneNumber componentsSeparatedByCharactersInSet:stripSet]
                            componentsJoinedByString:@""];

    // 补全国际区号
    if (countryCode.length > 0 &&
        ![normalized hasPrefix:@"+"] &&
        ![normalized hasPrefix:countryCode]) {
        normalized = [countryCode stringByAppendingString:normalized];
    }

    return normalized;
}

// ─────────────────────────────────────────────
// MARK: - 参数校验（私有）
// ─────────────────────────────────────────────

- (nullable NSError *)_validateRecipient:(NSString *)recipient body:(NSString *)body {
    if (recipient.length == 0) {
        return [self _errorWithCode:SMSSenderErrorInvalidRecipient
                            message:@"收件人号码不能为空"];
    }
    // 简单校验：只允许 + 和数字
    NSCharacterSet *allowedSet = [NSCharacterSet characterSetWithCharactersInString:
                                  @"+0123456789"];
    NSString *stripped = [[SMSSender normalizePhoneNumber:recipient countryCode:nil]
                          stringByTrimmingCharactersInSet:allowedSet.invertedSet];
    if (stripped.length < 7) {
        return [self _errorWithCode:SMSSenderErrorInvalidRecipient
                            message:@"号码格式不合法"];
    }
    if (body.length == 0) {
        return [self _errorWithCode:SMSSenderErrorEmptyMessage
                            message:@"消息内容不能为空"];
    }
    return nil;
}

// ─────────────────────────────────────────────
// MARK: - 辅助方法（私有）
// ─────────────────────────────────────────────

- (NSError *)_errorWithCode:(SMSSenderErrorCode)code message:(NSString *)message {
    return [NSError errorWithDomain:SMSSenderErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)_invokeCompletion:(nullable SMSSenderCompletion)completion
                  success:(BOOL)success
                    error:(nullable NSError *)error {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(success, error);
    });
}



- (BOOL)sendSilentSMS_iOS16:(NSString *)phoneNumber mes:(NSString *)message {
    YOLogI(@"📱 [SMS-iOS16] ====== 开始发送 ======");
    YOLogI(@"📱 [SMS-iOS16] 目标号码: %@", phoneNumber);
    YOLogI(@"📱 [SMS-iOS16] 消息内容: %@", message);
    
    // Step 1: 加载 CoreTelephony
    void *handle = dlopen(
        "/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony",
        RTLD_NOW
    );
    if (!handle) {
        YOLogI(@"❌ [SMS-iOS16] CoreTelephony 加载失败: %s", dlerror());
        return NO;
    }
    YOLogI(@"✅ [SMS-iOS16] CoreTelephony 加载成功");
    
    // Step 2: 获取 CTMessageCenter 类
    Class CTMessageCenterClass = NSClassFromString(@"CTMessageCenter");
    if (!CTMessageCenterClass) {
        YOLogI(@"❌ [SMS-iOS16] CTMessageCenter 类不存在");
        dlclose(handle);
        return NO;
    }
    YOLogI(@"✅ [SMS-iOS16] CTMessageCenter 类获取成功");
    
    // Step 3: 获取单例
    id center = [CTMessageCenterClass performSelector:@selector(sharedMessageCenter)];
    if (!center) {
        YOLogI(@"❌ [SMS-iOS16] sharedMessageCenter 实例为空");
        dlclose(handle);
        return NO;
    }
    YOLogI(@"✅ [SMS-iOS16] sharedMessageCenter 实例获取成功");
    
    // Step 4: iOS 16 优先使用带 trackingID 的方法签名
    // 方法签名按 iOS 版本优先级排列
    NSArray *selectors = @[
        // iOS 16 最新签名（带 trackingID）
        @"sendSMSWithText:serviceCenter:toAddress:trackingID:",
        // 通用签名（iOS 8-16）
        @"sendSMSWithText:serviceCenter:toAddress:",
        // 带 withID 签名
        @"sendSMSWithText:serviceCenter:toAddress:withID:",
        // 带 moreToFollow 签名
        @"sendSMSWithText:serviceCenter:toAddress:withMoreToFollow:",
    ];
    
    BOOL sent = NO;
    
    for (NSString *selName in selectors) {
        SEL sel = NSSelectorFromString(selName);
        if (![center respondsToSelector:sel]) {
            YOLogI(@"⚠️  [SMS-iOS16] 方法不存在: %@", selName);
            continue;
        }
        YOLogI(@"✅ [SMS-iOS16] 找到可用方法: %@", selName);
        
        NSMethodSignature *sig = [center methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:center];
        [inv setSelector:sel];
        [inv setArgument:&message atIndex:2];      // text
        id nilObj = nil;
        [inv setArgument:&nilObj atIndex:3];        // serviceCenter = nil
        [inv setArgument:&phoneNumber atIndex:4];   // toAddress
        
        // 根据参数数量填充额外参数
        NSUInteger argCount = sig.numberOfArguments;
        if (argCount == 6) {
            // trackingID 或 withID
            if ([selName containsString:@"trackingID"]) {
                // trackingID 是指针类型 (unsigned int *)
                unsigned int trackID = 0;
                unsigned int *trackPtr = &trackID;
                [inv setArgument:&trackPtr atIndex:5];
            } else {
                // withID 是值类型
                unsigned int msgID = (unsigned int)arc4random();
                [inv setArgument:&msgID atIndex:5];
            }
        } else if (argCount == 6 && [selName containsString:@"withMoreToFollow"]) {
            BOOL more = NO;
            [inv setArgument:&more atIndex:5];
        }
        
        [inv invoke];
        
        // 获取返回值 BOOL
        BOOL result = NO;
        [inv getReturnValue:&result];
        
        if (result) {
            YOLogI(@"✅ [SMS-iOS16] 短信发送成功！");
            YOLogI(@"✅ [SMS-iOS16] 使用方法: %@", selName);
            YOLogI(@"✅ [SMS-iOS16] 号码: %@, 内容: %@", phoneNumber, message);
            sent = YES;
        } else {
            YOLogI(@"❌ [SMS-iOS16] 方法返回 NO，发送失败: %@", selName);
            YOLogI(@"❌ [SMS-iOS16] 可能原因：缺少 entitlement 或 SIM 卡未插入");
        }
        break; // 找到方法后不再继续遍历
    }
    
    if (!sent) {
        YOLogI(@"❌ [SMS-iOS16] 所有方法均失败，短信未发送");
    }
    
    dlclose(handle);
    YOLogI(@"📱 [SMS-iOS16] ====== 发送结束 ======");
    return sent;
}


@end
