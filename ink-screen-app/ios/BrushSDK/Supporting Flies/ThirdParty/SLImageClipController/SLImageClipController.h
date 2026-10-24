//
//  SLImageClipController.h
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//



#import <UIKit/UIKit.h>
#import "XTDeviceConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface SLImageClipController : UIViewController

@property(nonatomic, strong) UIImage *image;

@property(nonatomic, strong) XTDeviceConfig *deviceConfig;

@end

NS_ASSUME_NONNULL_END
