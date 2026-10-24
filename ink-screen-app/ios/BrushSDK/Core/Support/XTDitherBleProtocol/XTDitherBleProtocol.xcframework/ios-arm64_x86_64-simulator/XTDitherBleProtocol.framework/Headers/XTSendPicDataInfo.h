//
//  XTSendPicDataInfo.h
//  ChromaInk
//
//  Created by XTMacMini on 2025/8/26.
//

#import <Foundation/Foundation.h>
#import "XTImageDataProcessType.h"

NS_ASSUME_NONNULL_BEGIN

/// 刷图入参模型。
/// dataArr 是算法输出后的像素索引数据，宽高/颜色决定后续打包方式。
@interface XTSendPicDataInfo : NSObject

// 图片的抖点数据
@property (nonatomic, strong) NSMutableArray *dataArr;

// 设备的颜色信息
@property (nonatomic, assign) NSInteger deviceColorType;

// 兼容旧调用字段，当前打包逻辑不使用
@property (nonatomic, assign) NSInteger deviceNumber;

// 刷图数据打包处理类型；默认 XTImageDataProcessTypeDefault
@property (nonatomic, assign) XTImageDataProcessType imageDataProcessType;

// 设备屏幕的宽度
@property (nonatomic, assign) NSInteger width;

// 设备屏幕的高度
@property (nonatomic, assign) NSInteger height;

// BLE 单次发送小包大小，由设备 MTU 或特殊设备规则决定
@property (nonatomic, assign) NSInteger bagSize;

// 是否启用图片 RLE 压缩
@property (nonatomic, assign) BOOL isNeedCompress;

@end

NS_ASSUME_NONNULL_END
