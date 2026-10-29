//
//  XTImageDataProcessType.h
//  XTDitherBleProtocol
//
//  Created by XTMacMini on 2026/8/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 刷图数据打包处理类型。
/// Image data packing mode for brush data generation.
typedef NS_ENUM(NSInteger, XTImageDataProcessType) {
    /// 默认打包方式，适用于普通屏幕。
    /// Default packing for normal screens.
    XTImageDataProcessTypeDefault = 0,
    /// 6 色双芯片打包方式，适用于需要左右芯片分通道取数的屏幕。
    /// Six-color dual-chip packing, used when firmware expects separate left/right channel data.
    XTImageDataProcessTypeSixColorDualChip = 1
};

NS_ASSUME_NONNULL_END
