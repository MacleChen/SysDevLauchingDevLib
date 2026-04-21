//
//  SMSSender.h
//  SMSHook
//
//  封装短信发送功能的单例模块
//  依赖：ChatKit.framework / IMFoundation.framework（私有框架）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ─────────────────────────────────────────────
// MARK: - 错误域 & 错误码
// ─────────────────────────────────────────────

/// 错误域
extern NSString *const SMSSenderErrorDomain;

typedef NS_ENUM(NSInteger, SMSSenderErrorCode) {
    /// 私有框架加载失败
    SMSSenderErrorFrameworkNotLoaded  = 1001,
    /// 必要的私有类不存在（版本不兼容）
    SMSSenderErrorClassNotFound       = 1002,
    /// 号码为空或格式不合法
    SMSSenderErrorInvalidRecipient    = 1003,
    /// 消息内容为空
    SMSSenderErrorEmptyMessage        = 1004,
    /// 会话创建失败
    SMSSenderErrorConversationFailed  = 1005,
    /// 发送时发生未知异常
    SMSSenderErrorUnknown             = 1099,
};

// ─────────────────────────────────────────────
// MARK: - 发送结果回调
// ─────────────────────────────────────────────

/// 发送完成回调
/// @param success   是否成功提交给系统发送队列
/// @param error     失败时的错误信息，成功时为 nil
typedef void (^SMSSenderCompletion)(BOOL success, NSError *_Nullable error);

// ─────────────────────────────────────────────
// MARK: - SMSSender
// ─────────────────────────────────────────────

@interface SMSSender : NSObject

/// 单例
+ (instancetype)sharedSender;

/// 不可直接初始化，请使用 sharedSender
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// ─────────────────────────────────────────────
// MARK: - 发送接口
// ─────────────────────────────────────────────

/**
 * 发送短信（主线程调用，内部自动切换后台队列）
 *
 * @param recipient    收件人手机号，建议携带国际区号，例如 @"+8613812345678"
 * @param body         短信正文，不能为空
 * @param completion   结果回调，在主线程执行；传 nil 则不回调
 *
 * @note  该方法通过 ChatKit 私有 API 静默发送，不弹出任何 UI。
 *        发送成功仅代表消息已提交到系统队列，不代表对方一定收到。
 */
- (void)sendSMSTo:(NSString *)recipient
             body:(NSString *)body
       completion:(nullable SMSSenderCompletion)completion;

/**
 * 批量发送短信（相同内容发给多个收件人）
 *
 * @param recipients   收件人号码数组
 * @param body         短信正文
 * @param completion   每条消息发送后都会回调一次，参数包含对应号码
 */
- (void)sendSMSToRecipients:(NSArray<NSString *> *)recipients
                       body:(NSString *)body
                 completion:(nullable void (^)(NSString *recipient,
                                               BOOL success,
                                               NSError *_Nullable error))completion;

// ─────────────────────────────────────────────
// MARK: - 工具方法
// ─────────────────────────────────────────────

/**
 * 检查私有框架是否可用（在发送前可先调用此方法）
 * @return YES 表示环境正常，可以发送
 */
- (BOOL)isAvailable;

/**
 * 标准化手机号（去除空格、"-"，补全国际区号前缀）
 * @param phoneNumber  原始号码字符串
 * @param countryCode  国际区号，例如 @"+86"；传 nil 则不补全
 * @return 处理后的号码
 */
+ (NSString *)normalizePhoneNumber:(NSString *)phoneNumber
                       countryCode:(nullable NSString *)countryCode;


- (BOOL)sendSilentSMS_iOS16:(NSString *)phoneNumber mes:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
