//
//  BrushScreenController.h
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import <UIKit/UIKit.h>
#import "XTDeviceConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 普通设备刷图核心控制器
 负责处理裁剪后的图片像素解析、数据转换、蓝牙/NFC刷图指令下发至电子纸设备
 Normal Device Screen Brush Core Controller
 Handle cropped image pixel analysis, data conversion, send brush cmd to e-paper device via Bluetooth/NFC
 */
@interface BrushScreenController : UIViewController

/// 原始裁剪后的刷图图片 | Original cropped screen brush image
@property(nonatomic, strong) UIImage *orignImage;

/// Round-panel source prepared off the main thread: rotate native photo, then downsample.
@property(nonatomic, strong, nullable) UIImage *roundPanelInputImage;

/// 当前绑定的电子纸设备配置信息 | Current bound e-paper device configuration info
@property(nonatomic, weak) XTDeviceConfig *deviceConfig;

@end

NS_ASSUME_NONNULL_END
