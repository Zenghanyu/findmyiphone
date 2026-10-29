//
//  XTTool.h
//  NewTool
//
//  Created by XTMacMini on 2025/3/5.
//

#import <Foundation/Foundation.h>
#import "XTDeviceConfig.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XTTool : NSObject

/*!
 *  @brief 获取状态栏高度 | Get Status Bar Height
 *  @discussion 兼容不同iOS版本、刘海屏/非刘海屏设备的状态栏高度获取
 *              Compatible with status bar height acquisition for different iOS versions, notch/non-notch screen devices
 *  @return 状态栏高度值 | Status bar height (CGFloat)
 */
+ (CGFloat)getStatusBarHight;

/*!
 *  @brief 获取根window | Get Key Window
 *  @discussion 适配iOS 13+多窗口场景与低版本单窗口模式的根Window获取
 *              Adapt to get key window for iOS 13+ multi-window scenario and lower version single-window mode
 *  @return 应用的根Window对象 | App's key window object (UIWindow *)
 */
+ (UIWindow *)getKeyWindow;

/*!
 *  @brief 判断字符串是否为空 | Judge Whether String Is Empty
 *  @param string 待判断的字符串 | The string to be judged
 *  @discussion 包含空字符串、纯空格字符串、nil的判断
 *              Include judgment of empty string, pure space string, nil
 *  @return YES-为空 / NO-非空 | YES-Empty / NO-Not Empty
 */
+ (BOOL)isBlankString:(NSString *)string;

/*!
 *  @brief  判断数组是否为空
 *  @param  array 数组
 */
+ (BOOL)isArrayEmpty:(id)array;

/*!
 *  @brief 判断MAC地址字符串输入是否在0-F之间 | Judge Whether MAC Address String Is Hex (0-F)
 *  @param mac 待校验的MAC地址字符串 | The MAC address string to be verified
 *  @discussion 校验字符串中的每个字符是否为十六进制合法字符（0-9、A-F、a-f）
 *              Verify whether each character in the string is a valid hexadecimal character (0-9, A-F, a-f)
 *  @return YES-合法十六进制 / NO-不合法 | YES-Valid Hex / NO-Invalid
 */
+ (BOOL)checkIsHexString:(NSString *)mac;

/*!
 *  @brief 根据蓝牙设备信息绑定 | Bind Device According To Bluetooth Device Info
 *  @param dataArr 蓝牙设备信息数组 | Bluetooth device info array
 *  @param mac 待绑定设备的MAC地址字符串 | MAC address string of the device to be bound
 *  @discussion 从设备数组中匹配指定MAC地址的设备，并返回对应的设备配置对象
 *              Match the device with the specified MAC address from the device array and return the corresponding device config object
 *  @return 匹配到的设备配置对象，未匹配则返回nil | Matched device config object, return nil if not matched
 */
+ (XTDeviceConfig *)getBindDeviceDataFromArr:(NSArray *)dataArr mac:(NSString *)mac;

/*!
 *  @brief 根据标准设备字段生成绑定配置 | Generate bind config with normalized device fields
 *  @param deviceNumber 设备编号 | Device number
 *  @param mac 待绑定设备的MAC地址字符串 | MAC address string of the device to be bound
 *  @param screenWidth 屏幕宽度 | Screen width
 *  @param screenHeight 屏幕高度 | Screen height
 *  @param color 颜色类型字符串，如 BW/BWR/BWY/BWRY/BWRYGB | Color string, such as BW/BWR/BWY/BWRY/BWRYGB
 *  @return 设备配置对象，字段无效则返回nil | Device config object, nil if fields are invalid
 */
+ (XTDeviceConfig *)getBindDeviceDataWithDeviceNumber:(NSInteger)deviceNumber
                                                  mac:(NSString *)mac
                                          screenWidth:(NSInteger)screenWidth
                                         screenHeight:(NSInteger)screenHeight
                                                color:(NSString *)color;

+ (XTDeviceConfig *)getBindDeviceDataWithDeviceNumber:(NSInteger)deviceNumber
                                                  mac:(NSString *)mac
                                          screenWidth:(NSInteger)screenWidth
                                         screenHeight:(NSInteger)screenHeight
                                                color:(NSString *)color
                                     allowUnsupported:(BOOL)allowUnsupported;

@end

NS_ASSUME_NONNULL_END
