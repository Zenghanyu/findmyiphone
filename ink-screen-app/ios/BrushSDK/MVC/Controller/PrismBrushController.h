//
//  PrismBrushController.h
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import <UIKit/UIKit.h>
#import "XTDeviceConfig.h"

NS_ASSUME_NONNULL_BEGIN
/**
 Prism设备刷图专属控制器
 Prism款电子纸设备的特效刷图、动画配置、数据解析与指令下发处理页
 Prism Device Special Screen Brush Controller
 Handle special effect brush, animation config, data analysis and cmd send for prism e-paper device
 */
@interface PrismBrushController : UIViewController

/// Prism设备配置信息模型 | Prism device configuration info model
@property(nonatomic, strong) XTDeviceConfig *deviceInfo;

@end

NS_ASSUME_NONNULL_END
