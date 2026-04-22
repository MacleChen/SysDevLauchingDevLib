//
//  IMPrivateHeaders.h
//  SMSHook
//
//  私有框架头文件声明
//  来源：class-dump ChatKit.framework / IMFoundation.framework
//  适用 iOS 14.0 - 17.x
//

#ifndef IMPrivateHeaders_h
#define IMPrivateHeaders_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ─────────────────────────────────────────────
// MARK: - IMFoundation
// ─────────────────────────────────────────────

/// 短信 / iMessage 服务标识
@interface IMServiceImpl : NSObject
/// 获取短信服务单例
+ (instancetype)SMSService;
/// 获取 iMessage 服务单例
+ (instancetype)iMessageService;
/// 服务名称（"SMS" / "iMessage"）
@property (nonatomic, readonly) NSString *name;
@end

/// 联系人句柄（对应一个手机号 / Apple ID）
@interface IMHandle : NSObject
/// 初始化句柄
/// @param service  IMServiceImpl 实例（SMSService / iMessageService）
/// @param address  手机号或 Apple ID
- (instancetype)initWithService:(IMServiceImpl *)service
                        address:(NSString *)address;
@property (nonatomic, readonly) NSString *ID;
@property (nonatomic, readonly) IMServiceImpl *service;
@end

/// 一条 IM 消息（基类）
@interface IMMessage : NSObject
+ (instancetype)instantMessageWithText:(NSAttributedString *)text
                            flags:(unsigned long long)flags
                         error:(NSError **)error;
@end

// ─────────────────────────────────────────────
// MARK: - ChatKit
// ─────────────────────────────────────────────

/// 消息组合对象（正文 + 主题）
@interface CKComposition : NSObject
- (instancetype)initWithText:(NSAttributedString *)text
                     subject:(nullable NSAttributedString *)subject;
/// 当前正文（富文本）
@property (nonatomic, copy) NSAttributedString *text;
@end

/// 消息发送上下文
@interface CKMessageSendContext : NSObject
@end

/// 一个聊天会话（对应一个联系人或群组）
@interface CKConversation : NSObject
/// 根据地址列表获取（或创建）会话
/// @param addresses  IMHandle 数组
+ (nullable instancetype)conversationForAddresses:(NSArray<IMHandle *> *)addresses;
/// 发送消息组合
/// @param composition  CKComposition 实例
- (void)sendMessageComposition:(CKComposition *)composition;
/// 会话内所有参与者
@property (nonatomic, readonly) NSArray<IMHandle *> *recipients;
/// 是否为 SMS 会话
@property (nonatomic, readonly) BOOL isSMSConversation;
@end

/// 会话列表管理器
@interface CKConversationList : NSObject
+ (instancetype)sharedConversationList;
- (nullable CKConversation *)conversationForExistingChatWithGroupID:(NSString *)groupID;
@end

NS_ASSUME_NONNULL_END

#endif /* IMPrivateHeaders_h */
