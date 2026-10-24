//
//  XTDeviceConfig.h
//  EinkAPP
//
//  Created by xthh on 2025/1/21.
//  Copyright © 2025 复旦微电子集团股份科技有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XTEnum.h"
#import <XTDitherBleProtocol/XTImageDataProcessType.h>

NS_ASSUME_NONNULL_BEGIN

//读取设备配置
@interface XTDeviceConfig : NSObject<NSSecureCoding>

//根据NFC tag 判断是不是纯NFC
@property (nonatomic, assign) XTBrushType brushType;

//操作结果，YES成功，NO失败
//@property (nonatomic, assign) BOOL isSuccess;

//厂商代码
@property (nonatomic, copy) NSString *manufacturerCode;
//厂商名称
@property (nonatomic, copy) NSString *manufacturerName;
//颜色支持代码
@property (nonatomic, copy) NSString *screenColorCode;
//颜色支持名称
@property (nonatomic, copy) NSString *screenColorName;
//屏幕宽度，单位：像素 | Screen width in pixels.
@property (nonatomic, assign) NSInteger screenWidth;
//屏幕高度，单位：像素 | Screen height in pixels.
@property (nonatomic, assign) NSInteger screenHeight;
//绑定时选择的固定屏幕编号，1-9号屏 | Fixed screen number selected during binding, Screen 1-9.
@property (nonatomic, assign) NSInteger screenSpecNumber;
//刷图数据打包处理类型 | Image data packing mode.
@property (nonatomic, assign) XTImageDataProcessType imageDataProcessType;

@property (nonatomic, assign) NSInteger deviceNumber;

//图片容量
@property (nonatomic, assign) NSInteger imageCount;
//是否支持图片管理/图片存储，1支持，0不支持
@property (nonatomic, assign) NSInteger imageStorage;
//是否支持从模板保存图片，1支持，0不支持
@property (nonatomic, assign) NSInteger saveImgFromTemp;
//扫描方式，HorizontalType横扫，VerticalType竖扫 | Scan direction: HorizontalType or VerticalType.
@property (nonatomic, assign) ScanType scanType;
//图像合成模式
@property (nonatomic, assign) CombineType combineType;
//支持传输模式
@property (nonatomic, assign) NSInteger transMode;
//支持颜色数量
@property (nonatomic, assign) NSInteger colorCount;
//颜色值定义字典，单色只用0,1，双色用00,01,10,11
@property (nonatomic, strong) NSDictionary *colorDic;
//appID(老版本)/OTP(新版本)
@property (nonatomic, copy) NSString *appID;
//uuID
@property (nonatomic, copy) NSString *uuID;
//是否需要验pin
@property (nonatomic, assign) BOOL checkPin;
//有源还是无源模式
@property (nonatomic, assign) BOOL hasPower;
@property (nonatomic, copy) NSString *power;

//是否支持压缩
@property (nonatomic, assign) BOOL supportCompress;
//智慧芯转换
@property (nonatomic, assign) BOOL isZhiHuiXin;
//图像转换算法，当isZhiHuiXin为YES时生效，0 其他 1 N01算法 2 N02算法 3 N03算法
@property (nonatomic, assign) NSInteger imageAlgo;
//压缩算法，当supportCompress为YES时生效，0 不支持 1 旧算法 2 哈夫曼编码
@property (nonatomic, assign) NSInteger compressAlgo;

//版本号，20 第二代
@property (nonatomic, assign) NSInteger versionCode;
@property (nonatomic, copy) NSString *version;
//写几个图像区
@property (nonatomic, assign) NSInteger writeImageCount;
//pin码
@property (nonatomic, copy) NSString *pin;
//是否需要水平翻转图片 YES 需要水平翻转 NO 不需要水平翻转
@property (nonatomic, assign) BOOL flipHorizontal;
//是否需要垂直翻转图片 YES 需要垂直翻转 NO 不需要垂直翻转
@property (nonatomic, assign) BOOL flipVertical;
//防丢器刷图前是否需要先切换刷图模式 | Whether the anti-lost device must switch to brush mode before image upload.
@property (nonatomic, assign) BOOL needsFindMyBrushModeSwitch;
//是否为防丢器设备 | Whether this is an anti-lost device.
@property (nonatomic, assign) BOOL antiLostDevice;

//序列化该类的对象
+(void)saveLocalCfg:(XTDeviceConfig *)XTDeviceConfig;

//反序列化该类的对象
+ (XTDeviceConfig *)readLocalCfg;


//是不是Prism手机壳
+ (BOOL)isPrismDevice;
+ (BOOL)isPrismDeviceWithDeviceNumber:(NSInteger)deviceNumber
                           screenWidth:(NSInteger)screenWidth
                          screenHeight:(NSInteger)screenHeight;
+ (BOOL)isSupportedBindingDeviceWithDeviceNumber:(NSInteger)deviceNumber
                                     screenWidth:(NSInteger)screenWidth
                                    screenHeight:(NSInteger)screenHeight
                                 screenColorCode:(NSString *)screenColorCode;
- (BOOL)isPrismDeviceConfig;
- (BOOL)isSupportedBindingDevice;

//是不是手机壳
- (BOOL)isPhoneCaseDevice;

//一般用于nfc供电 发送13指令
- (BOOL)isDeviceNeedSend13cmd;
    
/**
 *  判断当前设备是否需要通过旋转来刷新图像（刷图）
 *
 *  @return YES表示需要旋转刷图，NO表示不需要
 */
- (BOOL)needsRotationToRefreshImage;

/**
 *  NFC读取设备信息时，判断其传图方式是否为蓝牙
 *
 *  @return YES表示是蓝牙传图，NO表示不是
 */
- (BOOL)isBluetoothTransferWhenNFCReading;

- (BOOL)isNameCardDevice;

//判断是否需要先发送防丢器切换刷图模式指令 | Whether to send FindMy/anti-lost switch-to-brush command first.
- (BOOL)isFindMyAndNeedSendChangeToBrushMode;

+ (int)getDeviceColorType:(NSString *)screenColorCode;

+ (int)getDeviceBleMaxMtu:(NSString *)screenColorCode;

@end

NS_ASSUME_NONNULL_END
