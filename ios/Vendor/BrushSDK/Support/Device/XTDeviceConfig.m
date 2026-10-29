//
//  XTDeviceConfig.m
//  EinkAPP
//
//  Created by xthh on 2025/1/21.
//  Copyright © 2025 复旦微电子集团股份科技有限公司. All rights reserved.
//

#import "XTDeviceConfig.h"
#import <XTDitherBleProtocol/XTDitherBleProtocol.h>

@implementation XTDeviceConfig

-(void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:self.manufacturerCode forKey:@"manufacturerCode"];
    [aCoder encodeObject:self.manufacturerName forKey:@"manufacturerName"];
    [aCoder encodeObject:self.screenColorCode forKey:@"screenColorCode"];
    [aCoder encodeObject:self.screenColorName forKey:@"screenColorName"];
    [aCoder encodeInteger:self.screenWidth forKey:@"screenWidth"];
    [aCoder encodeInteger:self.screenHeight forKey:@"screenHeight"];
    [aCoder encodeInteger:self.screenSpecNumber forKey:@"screenSpecNumber"];
    [aCoder encodeInteger:self.imageDataProcessType forKey:@"imageDataProcessType"];
    [aCoder encodeInteger:self.deviceNumber forKey:@"deviceNumber"];
    [aCoder encodeInteger:self.imageCount forKey:@"imageCount"];
    [aCoder encodeInteger:self.imageStorage forKey:@"imageStorage"];
    [aCoder encodeInteger:self.saveImgFromTemp forKey:@"saveImgFromTemp"];
    [aCoder encodeInteger:self.scanType forKey:@"scanType"];
    [aCoder encodeInteger:self.combineType forKey:@"combineType"];
    [aCoder encodeInteger:self.transMode forKey:@"transMode"];
    [aCoder encodeInteger:self.colorCount forKey:@"colorCount"];
    [aCoder encodeObject:self.colorDic forKey:@"colorDic"];
    [aCoder encodeObject:self.appID forKey:@"appID"];
    [aCoder encodeObject:self.uuID forKey:@"uuID"];
    [aCoder encodeBool:self.checkPin forKey:@"checkPin"];
    [aCoder encodeBool:self.hasPower forKey:@"hasPower"];
    [aCoder encodeBool:self.supportCompress forKey:@"supportCompress"];
    [aCoder encodeBool:self.isZhiHuiXin forKey:@"isZhiHuiXin"];
    [aCoder encodeInteger:self.imageAlgo forKey:@"imageAlgo"];
    [aCoder encodeInteger:self.compressAlgo forKey:@"compressAlgo"];
    [aCoder encodeObject:self.pin forKey:@"pin"];
    [aCoder encodeBool:self.flipHorizontal forKey:@"flipHorizontal"];
    [aCoder encodeBool:self.flipVertical forKey:@"flipVertical"];
    [aCoder encodeBool:self.needsFindMyBrushModeSwitch forKey:@"needsFindMyBrushModeSwitch"];
    [aCoder encodeBool:self.antiLostDevice forKey:@"antiLostDevice"];
    [aCoder encodeInteger:self.versionCode forKey:@"versionCode"];
    [aCoder encodeObject:self.power forKey:@"power"];
    [aCoder encodeInteger:self.writeImageCount forKey:@"writeImageCount"];
    [aCoder encodeInteger:self.brushType forKey:@"brushType"];
    [aCoder encodeObject:self.version forKey:@"version"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self==[super init]) {
        self.manufacturerCode = [aDecoder decodeObjectForKey:@"manufacturerCode"];
        self.manufacturerName = [aDecoder decodeObjectForKey:@"manufacturerName"];
        self.screenColorCode = [aDecoder decodeObjectForKey:@"screenColorCode"];
        self.screenColorName = [aDecoder decodeObjectForKey:@"screenColorName"];
        self.screenWidth = [aDecoder decodeIntegerForKey:@"screenWidth"];
        self.screenHeight = [aDecoder decodeIntegerForKey:@"screenHeight"];
        self.screenSpecNumber = [aDecoder containsValueForKey:@"screenSpecNumber"] ? [aDecoder decodeIntegerForKey:@"screenSpecNumber"] : 0;
        self.imageDataProcessType = [aDecoder containsValueForKey:@"imageDataProcessType"] ? [aDecoder decodeIntegerForKey:@"imageDataProcessType"] : XTImageDataProcessTypeDefault;
        self.deviceNumber = [aDecoder decodeIntegerForKey:@"deviceNumber"];
        self.imageCount = [aDecoder decodeIntegerForKey:@"imageCount"];
        self.imageStorage = [aDecoder containsValueForKey:@"imageStorage"] ? [aDecoder decodeIntegerForKey:@"imageStorage"] : 1;
        self.saveImgFromTemp = [aDecoder containsValueForKey:@"saveImgFromTemp"] ? [aDecoder decodeIntegerForKey:@"saveImgFromTemp"] : 0;
        self.scanType = [aDecoder decodeIntegerForKey:@"scanType"];
        self.combineType = [aDecoder decodeIntegerForKey:@"combineType"];
        self.transMode = [aDecoder decodeIntegerForKey:@"transMode"];
        self.colorCount = [aDecoder decodeIntegerForKey:@"colorCount"];
        if (@available(iOS 14.0, *)) {
            self.colorDic = [aDecoder decodeDictionaryWithKeysOfClass:NSString.class objectsOfClass:NSString.class forKey:@"colorDic"];
        } else {
            self.colorDic = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"colorDic"];
        }
        self.appID = [aDecoder decodeObjectForKey:@"appID"];
        self.uuID = [aDecoder decodeObjectForKey:@"uuID"];
        self.checkPin = [aDecoder decodeBoolForKey:@"checkPin"];
        self.hasPower = [aDecoder decodeBoolForKey:@"hasPower"];
        self.supportCompress = [aDecoder decodeBoolForKey:@"supportCompress"];
        self.isZhiHuiXin = [aDecoder decodeBoolForKey:@"isZhiHuiXin"];
        self.imageAlgo = [aDecoder decodeIntegerForKey:@"imageAlgo"];
        self.compressAlgo = [aDecoder decodeIntegerForKey:@"compressAlgo"];
        self.pin = [aDecoder decodeObjectForKey:@"pin"];
        self.flipHorizontal = [aDecoder decodeBoolForKey:@"flipHorizontal"];
        self.flipVertical = [aDecoder decodeBoolForKey:@"flipVertical"];
        self.needsFindMyBrushModeSwitch = [aDecoder containsValueForKey:@"needsFindMyBrushModeSwitch"] ? [aDecoder decodeBoolForKey:@"needsFindMyBrushModeSwitch"] : NO;
        self.antiLostDevice = [aDecoder containsValueForKey:@"antiLostDevice"] ? [aDecoder decodeBoolForKey:@"antiLostDevice"] : self.needsFindMyBrushModeSwitch;
        self.versionCode = [aDecoder decodeIntegerForKey:@"versionCode"];
        self.power = [aDecoder decodeObjectForKey:@"power"];
        self.writeImageCount = [aDecoder decodeIntegerForKey:@"writeImageCount"];
        self.brushType = [aDecoder decodeIntegerForKey:@"brushType"];
        self.version = [aDecoder decodeObjectForKey:@"version"];
    }
    return self;
}

/**
 支持NSSecureCoding协议 必须支持

 @return 必须支持
 */
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 序列化该类的对象

 @param XTDeviceConfig XTDeviceConfig 实例
 */
+ (void)saveLocalCfg:(XTDeviceConfig *)XTDeviceConfig {
    NSString *savePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filePath = [savePath stringByAppendingPathComponent:@"XTDeviceConfig.dat"];
    NSData *data=[NSKeyedArchiver archivedDataWithRootObject:XTDeviceConfig requiringSecureCoding:YES error:nil];
    [data writeToFile:filePath atomically:YES];
}

/**
 反序列化该类的对象

 @return return XTDeviceConfig 实例
 */
+ (XTDeviceConfig *)readLocalCfg {
    NSString *savePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filePath = [savePath stringByAppendingPathComponent:@"XTDeviceConfig.dat"];
    NSData *datData=[NSData dataWithContentsOfFile:filePath];
    NSError *error;

    XTDeviceConfig *result = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:NSString.class, NSDictionary.class, XTDeviceConfig.class, nil] fromData:datData error:&error];
    return result;
}

+ (BOOL)isPrismDeviceWithDeviceNumber:(NSInteger)deviceNumber
                           screenWidth:(NSInteger)screenWidth
                          screenHeight:(NSInteger)screenHeight {
    BOOL isOldPrism = screenWidth == 64 && (screenHeight == 1 || screenHeight == 2);
    return isOldPrism;
}

+ (BOOL)isSupportedBindingDeviceWithDeviceNumber:(NSInteger)deviceNumber
                                     screenWidth:(NSInteger)screenWidth
                                    screenHeight:(NSInteger)screenHeight
                                 screenColorCode:(NSString *)screenColorCode {
    return [XTBleProtocol isSupportedBindingDeviceWithDeviceNumber:deviceNumber
                                                       screenWidth:screenWidth
                                                      screenHeight:screenHeight
                                                   screenColorCode:screenColorCode];
}

+ (BOOL)isPrismDevice {
    XTDeviceConfig *current = [XTDeviceConfig readLocalCfg];
    if (!current) {
        return NO;
    }
    return [XTDeviceConfig isPrismDeviceWithDeviceNumber:current.deviceNumber
                                             screenWidth:current.screenWidth
                                            screenHeight:current.screenHeight];
}

- (BOOL)isPrismDeviceConfig {
    return [XTDeviceConfig isPrismDeviceWithDeviceNumber:self.deviceNumber
                                             screenWidth:self.screenWidth
                                            screenHeight:self.screenHeight];
}

- (BOOL)isSupportedBindingDevice {
    if (self.brushType != brushWithBle) {
        return YES;
    }
    return [XTDeviceConfig isSupportedBindingDeviceWithDeviceNumber:0
                                                        screenWidth:self.screenWidth
                                                       screenHeight:self.screenHeight
                                                    screenColorCode:self.screenColorCode];
}

//是不是手机壳
- (BOOL)isPhoneCaseDevice {
    return NO;
}

//一般用于nfc供电 发送13指令
- (BOOL)isDeviceNeedSend13cmd {
    BOOL isOldPrism = self.screenWidth == 64 && ( self.screenHeight == 1 || self.screenHeight == 2); //1是动物 2是游鱼
    return isOldPrism;
}

+ (int)getDeviceColorType:(NSString *)screenColorCode {
    int deviceColorType = 3; //3四色，5六色
    if([screenColorCode isEqualToString:COLOR_BWRY_CODE]) {
        deviceColorType = 3;
    } else if([screenColorCode isEqualToString:COLOR_BWRYGB_CODE]) {
        deviceColorType = 5;
    } else if([screenColorCode isEqualToString:COLOR_BWR_CODE]) {
        deviceColorType = 2;
    } else if ([screenColorCode isEqualToString:COLOR_BWY_CODE]){
        deviceColorType = 1;
    }
    return deviceColorType;
}

+ (int)getDeviceBleMaxMtu:(NSString *)screenColorCode {
    int mtu = 244;
    if([screenColorCode isEqualToString:COLOR_BWRY_CODE]) {//3 四色 黑白红黄
        mtu = 490;
    } else if([screenColorCode isEqualToString:COLOR_BWRYGB_CODE]) {//5 黑白红黄绿蓝
        mtu = 490;
    } else if([screenColorCode isEqualToString:COLOR_BWR_CODE]) {//2 黑白红
        mtu = 244;
    } else if ([screenColorCode isEqualToString:COLOR_BWY_CODE]){//5 黑白黄
        mtu = 244;
    }
    return mtu;
}

/**
 *  判断当前设备是否需要通过旋转来刷新图像（刷图）
 *
 *  @return YES表示需要旋转刷图，NO表示不需要
 */
- (BOOL)needsRotationToRefreshImage {
    return NO;
}

/**
 *  NFC读取设备信息时，判断其传图方式是否为蓝牙
 *
 *  @return YES表示是蓝牙传图，NO表示不是
 */
- (BOOL)isBluetoothTransferWhenNFCReading {
    return self.brushType == brushWithBle;
}

//桌牌类
- (BOOL)isNameCardDevice {
    return NO;
}

- (BOOL)isFindMyAndNeedSendChangeToBrushMode {
    return self.needsFindMyBrushModeSwitch;
}


//MARK: ================================  重写打印  ================================
- (NSString *)description {
    // 判断当前语言是否为中文（检查系统首选语言）
    BOOL isChinese = NO;
    NSString *preferredLang = [[NSLocale preferredLanguages] firstObject];
    if ([preferredLang hasPrefix:@"zh"]) {
        isChinese = YES;
    }

    // 扫描类型文本（根据语言切换）
    NSString *scanTypeStr;
    if (isChinese) {
        scanTypeStr = (self.scanType == VerticalType) ? @"垂直" : @"水平";
    } else {
        scanTypeStr = (self.scanType == VerticalType) ? @"Vertical" : @"Horizontal";
    }

    // 电源状态文本（根据语言切换）
    NSString *hasPowerStr = isChinese ? (self.hasPower ? @"有源" : @"无源") : (self.hasPower ? @"YES" : @"NO");

    // 格式化字符串（根据语言切换key）
    NSString *format;
    if (isChinese) {
        format = @"\n        MAC  :  %@        \n\n"
                 "        设备编号  :  %ld\n\n"
                 "        屏幕宽度  :  %ld\n\n"
                 "        屏幕高度  :  %ld\n\n"
                 "        颜色代码  :  %@\n\n"
                 "        扫描类型  :  %@\n\n"
                 "        颜色数量  :  %ld\n\n"
                 "        是否有源  :  %@\n\n"
                 "        设备电量  :  %@\n\n"
                 "        固件版本  :  %@\n";
    } else {
        format = @"\n  MAC                         :    %@\n\n"
                 "  deviceNumber       :    %ld\n\n"
                 "  screenWidth           :    %ld\n\n"
                 "  screenHeight          :    %ld\n\n"
                 "  screenColorCode  :    %@\n\n"
                 "  scanType                :    %@\n\n"
                 "  colorCount             :    %ld\n\n"
                 "  hasPower               :    %@\n\n"
                 "  power                     :    %@\n\n"
                 "  version                   :    %@\n";
    }

    return [NSString stringWithFormat:format,
            self.uuID,
            (long)self.deviceNumber,
            (long)self.screenWidth,
            (long)self.screenHeight,
            self.screenColorCode,
            scanTypeStr,
            (long)self.colorCount,
            hasPowerStr,
            self.power,
            self.version];
}

@end
