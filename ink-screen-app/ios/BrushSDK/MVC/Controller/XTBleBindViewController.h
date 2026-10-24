//
//  XTBleBindViewController.h
//  BrushSDK
//
//  Created by XTMacMini on 2025/3/5.
//

#import <UIKit/UIKit.h>
#import "XTDeviceConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XTBleBindViewControllerDelegate <NSObject>

- (void)backBindMac:(NSString *)mac;

@end

@interface XTBleBindViewController : UIViewController

@property (nonatomic, weak) id<XTBleBindViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
