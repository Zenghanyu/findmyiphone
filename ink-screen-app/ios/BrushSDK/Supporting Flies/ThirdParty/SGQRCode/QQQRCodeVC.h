//
//  QQQRCodeVC.h
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QQQRCodeVCDelegate <NSObject>

- (void)scanCodeResultString:(NSString *)result;

@end


@interface QQQRCodeVC : UIViewController

@property (nonatomic, weak) id <QQQRCodeVCDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
