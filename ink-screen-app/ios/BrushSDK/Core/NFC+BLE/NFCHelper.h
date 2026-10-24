//
//  NFCHelper.h
//
//  Created by lubozhi on 2018/7/9.
//  Copyright © 2018年 复旦微电子集团股份科技有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreNFC/CoreNFC.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "XTDeviceConfig.h"

typedef NS_ENUM(NSUInteger, OperationType) {
    ReadDeviceConfig        = 0,        //读取设备配置
    WriteCustomApdu         = 1,        //发送自定义指令
    WriteScreen             = 2,        //写屏+刷屏
    RefreshScreen           = 3,        //刷屏
    ModifyPin               = 4,        //修改Pin码
    WriteScreenOnly         = 5,        //写屏
    OTA                     = 6         //ota
};

@protocol NFCHelperDelegate<NSObject>

@optional
//读取设备配置回调
- (void)NfcReadConfigComplete:(XTDeviceConfig *)config;

//自定义指令回调
- (void)NfcCustomCMDComplete:(NSString *)cmdResult;

//记录日志回调
- (void)NfcLogComplete:(NSString *)log;

//pin码验证成功
- (void)NfcVerifyPinComplete:(NSString *)pin;

//pin码修改成功
- (void)NfcModifyPinComplete;

- (void)errCallBack:(NSString *)errMsg;

- (void)BeginScan:(NSMutableArray *)picData;

@end

@interface NFCHelper: NSObject

+ (instancetype)shareInstance;

//弹窗
- (void)alertMsg:(NSString *)msg;

//绑定设备
- (void)bandDeviceAndWriteNFCToCache:(NSString *)inputStr fromQR:(BOOL)fromQR;

//读取设备配置文件
//参数:
//hintText扫描框的文字提示
- (NSString *)getDeviceConfig:(NSString *)hintText isNeedScanTip:(BOOL)isNeed;

//导入图像到设备
//参数:
//hintText扫描框的文字提示
//imageData导入的图像数据
//screenCfg写屏时的app端设备配置，用于检测与当前设备是否匹配
//imageSectionNumber导入的图像区域号
//pin pin码，无pin设置为nil
- (NSString *)importImageToDevice:(NSString *)hintText
                        imageData:(NSData *)imageData
                      imageDataXT:(NSMutableArray *)imageDataXT
                        screenCfg:(XTDeviceConfig *)screenCfg
               imageSectionNumber:(NSInteger)imageSectionNumber
                              pin:(NSString *)pin
                         PageSize:(int)pageSize
                     IntervalTime:(int)intervalTime;

//OTA
- (NSString *)importOTAToDevice:(NSString *)hintText
                      imageData:(NSData *)imageData
                    imageDataXT:(NSMutableArray *)imageDataXT
                      screenCfg:(XTDeviceConfig *)screenCfg
             imageSectionNumber:(NSInteger)imageSectionNumber
                            pin:(NSString *)pin
                       PageSize:(int)pageSize
                   IntervalTime:(int)intervalTime;

@property(nonatomic, weak) id<NFCHelperDelegate> delegate;

//nfc reader是否正在读取
@property(nonatomic, assign) BOOL isReading;

@end
