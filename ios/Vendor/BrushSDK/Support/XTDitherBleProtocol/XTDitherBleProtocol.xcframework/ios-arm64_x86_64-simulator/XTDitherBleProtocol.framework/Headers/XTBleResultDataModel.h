//
//  XTBleResultDataModel.h
//  XTDitherBleProtocol
//
//  Created by XTMacMini on 2025/10/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Token 读取结果模型。
/// 对应外层 XTE 分包合并后的 XTEK Token 文件结构，以及解析出的产品字段。
@interface XTBleResultDataModel : NSObject
// 外层头部字段
@property (nonatomic, copy) NSString *outerStartFlag;  // 外层起始标识（XTE）
@property (nonatomic, assign) UInt8 dataType;          // 数据类型（固定0x02）
@property (nonatomic, assign) UInt8 totalPackages;     // 总包数

// 内层头部字段（XTEK及后续头部）
@property (nonatomic, copy) NSString *innerFlag;       // 内层标识（固定XTEK）
@property (nonatomic, assign) UInt32 innerCheckSum;    // 内层累加和（4B）
@property (nonatomic, assign) UInt32 innerTotalSize;   // 文件大小（从文件标识开始）
@property (nonatomic, assign) UInt8 fileType;          // 文件标识（1B）
@property (nonatomic, assign) UInt8 compressFlag;      // 压缩标识（1B）

// Token子结构字段（原始解析结果）
@property (nonatomic, assign) UInt8 tokenFlag;         // Token标志位（固定0x54）
@property (nonatomic, assign) UInt16 tokenContentLen;  // Token内容长度（2B）
@property (nonatomic, assign) UInt32 tokenCheckSum;    // Token累加和（4B）
@property (nonatomic, strong) NSData *tokenContent;    // Token原始内容（二进制）
@property (nonatomic, copy) NSString *tokenString;     // Token内容转字符串（ASCII）

// 新增：Token内容拆分后的业务字段
@property (nonatomic, copy) NSString *productID;       // 产品ID（第一个字段）
@property (nonatomic, copy) NSString *uuidS;           // UUID_S（第二个字段）
@property (nonatomic, copy) NSString *tokenS;          // TOKEN_S（第三个字段）
@property (nonatomic, copy) NSString *sn;              // SN（第四个字段）

// 解析状态
@property (nonatomic, assign) BOOL isValid;            // 整体解析是否有效

@end

NS_ASSUME_NONNULL_END
