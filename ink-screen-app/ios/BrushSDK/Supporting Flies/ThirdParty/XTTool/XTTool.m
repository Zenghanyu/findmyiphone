//
//  XTTool.m
//  NewTool
//
//  Created by XTMacMini on 2025/3/5.
//

#import "XTTool.h"
#import "XTCommonUtils.h"
#import "UtilsMacros.h"

@implementation XTTool

/*!
 *  @brief 获取状态栏高度
 */
+ (CGFloat)getStatusBarHight {
    UIStatusBarManager *statusBarManager = [UIApplication sharedApplication].windows.firstObject.windowScene.statusBarManager;
    float statusBarHeight = statusBarManager.statusBarFrame.size.height;
    return statusBarHeight;
}

/*!
 *  @brief 获取根window
 */
+ (UIWindow *)getKeyWindow {
    UIWindow *keyWindow = nil;
    NSArray  *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
 }
 
/*!
 *  @brief  判断字符串是否为空
 *  @param  string 字符串
 */
+ (BOOL)isBlankString:(NSString *)string {
    if (string == nil || string == NULL || [string isKindOfClass:[NSNull class]] || [string isEqualToString:@""] ||[string isEqualToString:@"null"] || [string isEqualToString:@"NULL"] || [string isEqualToString:@"(null)"] || [string isEqualToString:@"（null）"] || [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        return YES;
    }
    return NO;
}

/*!
 *  @brief  判断数组是否为空
 *  @param  array 数组
 */
+ (BOOL)isArrayEmpty:(id)array {
    // 首先判断对象是否为 nil
    if (array == nil) {
        return YES;
    }
    // 接着判断对象是否为 NSNull 类型
    if ([array isKindOfClass:[NSNull class]]) {
        return YES;
    }
    // 然后判断对象是否为 NSArray 类型
    if (![array isKindOfClass:[NSArray class]]) {
        return YES;
    }
    // 最后判断数组的 count 属性是否为 0
    return [(NSArray *)array count] == 0;
}

/*!
 *  @brief  判断MAC地址字符串输入是否在0-F之间
 *  @param  mac  地址字符串
 */
+ (BOOL)checkIsHexString:(NSString *)mac {
    NSString *hexRegex = @"^(0x|0X)?[0-9a-fA-F]+$";
    NSPredicate *regexTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", hexRegex];
    return [regexTest evaluateWithObject:mac];
}

/*!
 *  @brief  根据蓝牙设备信息绑定
 *  @param  dataArr 本地数据库数据
 */
+ (XTDeviceConfig *)getBindDeviceDataFromArr:(NSArray *)dataArr mac:(NSString *)mac {
    if ([XTTool isArrayEmpty:dataArr] || dataArr.count < 7) {
        return nil;
    }
//    XTBLEDeviceModel *model = [[XTBLEDeviceModel alloc] init];
//    model.deviceNum     = [dataArr[0] integerValue];
//    model.projectID     = [dataArr[1] integerValue];
//    model.deviceName    = dataArr[2];
//    model.size          = [dataArr[3] floatValue];
//    model.width         = [dataArr[4] integerValue];
//    model.height        = [dataArr[5] integerValue];
//    model.color         = dataArr[6];
//    model.connectType   = dataArr[7];
//    model.ic            = dataArr[8];
//    model.nfcIC         = dataArr[9];
//    model.isLed         = [dataArr[10] isEqualToString:@"1"];
//    model.isFrontLight  = [dataArr[11] isEqualToString:@"1"];
//    model.isMessage     = [dataArr[12] isEqualToString:@"1"];
//    model.supportFont   = [dataArr[13] integerValue];
//    model.keyNum        = [dataArr[14] isEqualToString:@"1"];
//    model.pageNum       = [dataArr[15] isEqualToString:@"1"];
//    model.screenNum     = [dataArr[16] isEqualToString:@"1"];
//    model.tips          = dataArr[17];
//    model.mac           = mac;
    
    return [self getBindDeviceDataWithDeviceNumber:[dataArr[0] integerValue]
                                               mac:mac
                                       screenWidth:[dataArr[4] integerValue]
                                      screenHeight:[dataArr[5] integerValue]
                                             color:dataArr[6]];
}

+ (XTDeviceConfig *)getBindDeviceDataWithDeviceNumber:(NSInteger)deviceNumber
                                                  mac:(NSString *)mac
                                          screenWidth:(NSInteger)screenWidth
                                         screenHeight:(NSInteger)screenHeight
                                                color:(NSString *)color {
    return [self getBindDeviceDataWithDeviceNumber:deviceNumber
                                               mac:mac
                                       screenWidth:screenWidth
                                      screenHeight:screenHeight
                                             color:color
                                  allowUnsupported:NO];
}

+ (XTDeviceConfig *)getBindDeviceDataWithDeviceNumber:(NSInteger)deviceNumber
                                                  mac:(NSString *)mac
                                          screenWidth:(NSInteger)screenWidth
                                         screenHeight:(NSInteger)screenHeight
                                                color:(NSString *)color
                                     allowUnsupported:(BOOL)allowUnsupported {
    NSString *colorString = [[NSString stringWithFormat:@"%@", color ?: @""] uppercaseString];
    if (screenWidth <= 0 || screenHeight <= 0 || [XTTool isBlankString:colorString]) {
        return nil;
    }
    
    XTDeviceConfig *cdevice = [[XTDeviceConfig alloc] init];
    cdevice.brushType = brushWithBle;
    cdevice.appID = mac;
    cdevice.uuID = mac;
    
    if([colorString isEqualToString:@"BW"]){
        cdevice.screenColorCode = COLOR_BW_CODE;
        cdevice.colorCount = 2;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        cdevice.colorDic = colorDic;
    } else if([colorString isEqualToString:@"BWR"]){
        cdevice.screenColorCode = COLOR_BWR_CODE;
        cdevice.colorCount = 3;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        cdevice.colorDic = colorDic;
    }else if([colorString isEqualToString:@"BWY"]){
        cdevice.screenColorCode = COLOR_BWY_CODE;
        cdevice.colorCount = 3;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        cdevice.colorDic = colorDic;
    }else if([colorString isEqualToString:@"BWRY"]){
        cdevice.screenColorCode = COLOR_BWRY_CODE;
        cdevice.colorCount = 4;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        cdevice.colorDic = colorDic;
    }else if([colorString isEqualToString:@"BWRYGB"]){
        cdevice.screenColorCode = COLOR_BWRYGB_CODE;
        cdevice.colorCount = 6;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        [colorDic setValue: @"6" forKey:DIC_KEY_GREEN];
        [colorDic setValue: @"5" forKey:DIC_KEY_BLUE];
        cdevice.colorDic = colorDic;
    } else {
        return nil;
    }
    
    if (!allowUnsupported && ![XTDeviceConfig isSupportedBindingDeviceWithDeviceNumber:0
                                                                           screenWidth:screenWidth
                                                                          screenHeight:screenHeight
                                                                       screenColorCode:cdevice.screenColorCode]) {
        return nil;
    }

    cdevice.screenColorName = [XTCommonUtils getScreenColorByCode:cdevice.screenColorCode];
    cdevice.screenHeight = screenHeight;
    cdevice.screenWidth = screenWidth;
    cdevice.deviceNumber = 0;
    cdevice.scanType = HorizontalType;
//    switch (tagInfo.rototeType){
//        case 0:{
//            cdevice.scanType = HorizontalType;
//            break;
//        }
//        case 1:{
//            cdevice.scanType = VerticalType;
//            break;
//        }
//        case 2:{
//            cdevice.scanType = HorizontalType;
//            break;
//        }
//        case 3:{
//            cdevice.scanType = VerticalType;
//            break;
//        }
//    }
    if ([cdevice needsRotationToRefreshImage]) {
        cdevice.scanType = VerticalType;
    }
    cdevice.combineType = GeneralType;
    cdevice.writeImageCount = 1;
    cdevice.imageCount = [XTCommonUtils convertHexStringToDecimal:@"1"];
    cdevice.imageStorage = 1;
    cdevice.saveImgFromTemp = 0;
    cdevice.hasPower = YES;
    cdevice.supportCompress = YES;
    cdevice.manufacturerCode = @"0";
    cdevice.manufacturerName = @"0";
    return cdevice;
}

@end
