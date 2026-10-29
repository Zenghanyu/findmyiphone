//
//  NFCHelper.m
//
//  Created by lubozhi on 2019/7/19.
//  Copyright © 2018年 复旦微电子集团股份科技有限公司. All rights reserved.
//

#import "NFCHelper.h"
#import "XTCommonUtils.h"
#import <XTDitherBleProtocol/XTDitherBleProtocol.h>
#import "UtilsMacros.h"
#import "XTMBManager.h"
#import "NFCTagObject.h"
#import "FMCompressUtils.h"
#import <AudioToolbox/AudioToolbox.h>
#import "XTTool.h"

@interface NFCHelper()<NFCTagReaderSessionDelegate, CBCentralManagerDelegate,CBPeripheralDelegate>

@property(nonatomic, strong) NFCTagReaderSession    *session;
@property(nonatomic, strong) NSMutableDictionary    *hexDic;
@property(nonatomic, strong) NSMutableDictionary    *colorTypeDic;

//操作类型
@property(nonatomic, assign) OperationType          opType;
@property(nonatomic, copy) NSString                 *hintText;
@property(nonatomic, copy) NSString                 *apdu;
@property(nonatomic, strong) NSData                 *imageData;
@property(nonatomic, strong) NSMutableArray         *imageDataXTArr;

//写屏时硬件端的设备配置
@property(nonatomic, strong) XTDeviceConfig           *screenCfg;

//屏幕图像区域号，从0开始
@property(nonatomic, assign) NSInteger              imageSectionNumber;
@property(nonatomic, copy) NSString                 *nfcLog;

//原pin码
@property(nonatomic, copy) NSString                 *oldPin;

//新pin码
@property(nonatomic, copy) NSString                 *pin;


// 中央管理者 -->管理设备的扫描 --连接
@property (nonatomic, strong) CBCentralManager      *centralManager;

// 存储的设备 //苹果需要对蓝牙强引用
@property (nonatomic, strong) NSMutableArray        *peripherals;
@property (nonatomic, strong) CBPeripheral          *cbPeripheral;

// 状态
@property (nonatomic, assign) CBManagerState        peripheralState;
@property (nonatomic, strong) CBPeripheral          *currentPeripheral;
//特征
@property (nonatomic, strong) CBCharacteristic      *writeCharacteristic;
@property (nonatomic, strong) CBCharacteristic      *readCharacteristic;

@property (nonatomic, strong) id                    currentNFCTag;

//是否已经开始刷图
@property (nonatomic, assign) BOOL                  isNfcCanUsed;
@property (nonatomic, assign) BOOL                  isBrushSuccess;

@property (nonatomic, assign) BOOL                  isNeedScanTip;

- (XTBrushType)brushTypeForBoundDevice:(XTDeviceConfig *)deviceConfig pureNFC:(BOOL)pureNFC;

@end

static int globaPageSize = 244;
static float globaIntervalTime = 0.01;
// 写服务
static NSString         *kWriteServerUUID = @"------";
// 写特征值
static NSString         *kWriteCharacteristicUUID = @"------";
// 读特征
static NSString         *kNotifyCharacteristicUUID = @"------";
// 需要刷图的MAC
static NSString         *strUpdataMac = @"31390B00866F";
// 需要写入的数据包信息
static NSMutableArray   *arraySendDataPage;
// 需要补包的数据
static NSMutableArray   *arraySubPageData;
// 应答结果等待
static int              globaWaitAnswerRunning = 1;
// 删除FLASH的长度
static int              nDeleteFlashLen = 0;

NSMutableArray          *arrayBWRYData_1;

static int              nBleConnectCount = 0;
// 扫描时间
static int              nScanTagTime = 0;
// 连接状态
static int              nBleConnectState = 0;

static int              temp2 = 0;

// 从扫描连接用的时间
static double           lScanDeviceTime = 0;
// 发送时间
static double           lDeviceSendTime = 0;
// 刷图用的时间
static double           lFrushPicTime = 0;

// 任务类型，0PIC，1OTA
static int              nTaskType = 0;

@implementation NFCHelper

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    static NFCHelper *nfcHelper;
    dispatch_once(&onceToken, ^{
        nfcHelper = [[NFCHelper alloc] init];
    });
    return nfcHelper;
}

- (instancetype)init {
    
    [self centralManager];
    
    // 获取服务UUID和通知/写特征码
    kWriteServerUUID = [XTBleProtocol getBLEServiceUUID];
    kWriteCharacteristicUUID = [XTBleProtocol getBLEWriteCharacteristicUUID];
    kNotifyCharacteristicUUID = [XTBleProtocol getBLENotifyCharacteristicUUID];
    
    if (self = [super init]) {
        _hexDic = [[NSMutableDictionary alloc] initWithCapacity:16];
        [_hexDic setObject:@"0000" forKey:@"0"];
        [_hexDic setObject:@"0001" forKey:@"1"];
        [_hexDic setObject:@"0010" forKey:@"2"];
        [_hexDic setObject:@"0011" forKey:@"3"];
        [_hexDic setObject:@"0100" forKey:@"4"];
        [_hexDic setObject:@"0101" forKey:@"5"];
        [_hexDic setObject:@"0110" forKey:@"6"];
        [_hexDic setObject:@"0111" forKey:@"7"];
        [_hexDic setObject:@"1000" forKey:@"8"];
        [_hexDic setObject:@"1001" forKey:@"9"];
        [_hexDic setObject:@"1010" forKey:@"A"];
        [_hexDic setObject:@"1011" forKey:@"B"];
        [_hexDic setObject:@"1100" forKey:@"C"];
        [_hexDic setObject:@"1101" forKey:@"D"];
        [_hexDic setObject:@"1110" forKey:@"E"];
        [_hexDic setObject:@"1111" forKey:@"F"];
        
        _colorTypeDic = [[NSMutableDictionary alloc] init];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Black") forKey:DIC_KEY_BLACK];
        [_colorTypeDic setObject:XTLS(@"XT_Color_White") forKey:DIC_KEY_WHITE];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Red") forKey:DIC_KEY_RED];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Yellow") forKey:DIC_KEY_YELLOW];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Orange") forKey:DIC_KEY_ORANGE];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Green") forKey:DIC_KEY_GREEN];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Cyan") forKey:DIC_KEY_QING];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Blue") forKey:DIC_KEY_BLUE];
        [_colorTypeDic setObject:XTLS(@"XT_Color_Purple") forKey:DIC_KEY_PURPLE];
        
        _isReading = NO;
        _isNfcCanUsed = YES;
        _isNeedScanTip = NO;
    }
    return self;
}

//读取设备配置文件
- (NSString *)getDeviceConfig:(NSString *)hintText isNeedScanTip:(BOOL)isNeed {
    NSString *response = @"";
    _hintText = hintText;
    _isNeedScanTip = isNeed;
    response = [self startNDEF:ReadDeviceConfig];
    return response;
}

//导入图像到设备
- (NSString *)importImageToDevice:(NSString *)hintText
                        imageData:(NSData *)imageData
                      imageDataXT:(NSMutableArray *)imageDataXT
                        screenCfg:(XTDeviceConfig *)screenCfg
               imageSectionNumber:(NSInteger)imageSectionNumber
                              pin:(NSString *)pin
                         PageSize:(int)pageSize
                     IntervalTime:(int)intervalTime {
    NSString *response = @"";
    _hintText = hintText;
    if(!imageData || imageData.length <= 0){
        response = XTLS(@"XT_No_Empty_Data");
        return response;
    }
    if (!screenCfg || ![screenCfg isSupportedBindingDevice]) {
        response = XTLS(@"XT_Unsupported_Device");
        return response;
    }
    nTaskType = 0;
    _imageData = imageData;
    _imageDataXTArr = imageDataXT;
    _screenCfg = screenCfg;
    _imageSectionNumber = imageSectionNumber;
    _pin = pin;
    globaPageSize = pageSize;
    globaIntervalTime = intervalTime / 1000.0;
    _isBrushSuccess = NO;
    response = [self startNDEF:WriteScreen];
    return response;
}

//导入OTA到设备
- (NSString *)importOTAToDevice:(NSString *)hintText
                      imageData:(NSData *)imageData
                    imageDataXT:(NSMutableArray *)imageDataXT
                      screenCfg:(XTDeviceConfig *)screenCfg
             imageSectionNumber:(NSInteger)imageSectionNumber
                            pin:(NSString *)pin
                       PageSize:(int)pageSize
                   IntervalTime:(int)intervalTime{
    NSString *response = @"";
    _hintText = hintText;
    if(!imageData||imageData.length <= 0){
        response = XTLS(@"XT_No_Empty_Data");
        return response;
    }
    if (screenCfg.brushType == brushWithNfc) {
        response = XTLS(@"XT_NFC_Device_Unsupported_OTA");
        return response;
    }
    nTaskType = 1;
    _imageData = imageData;
    _imageDataXTArr = imageDataXT;
    _screenCfg = screenCfg;
    _imageSectionNumber = imageSectionNumber;
    _pin = pin;
    globaPageSize = pageSize;
    globaIntervalTime = intervalTime / 1000.0;
    _isBrushSuccess = NO;
    response = [self startNDEF:OTA];
    return response;
}

//MARK: NFCTagReaderSessionDelegate
- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags API_AVAILABLE(ios(13.0)) {   //NDEF读写代理
    DLog(@"------tagReaderSession");
    if(tags.count > 1) {
        [self showMsgOnSession: session message:XTLS(@"XT_More_Tags") isContinueScan:YES];
        return;
    }
    id<NFCTag> tagCurrent = tags.firstObject;
    BOOL isBleBrush = [self isBleBrush:tagCurrent];
    if (isBleBrush) {
        if (_opType == OTA) {
            DLog(@"------tagReaderSession OTA 2");
            if (nBleConnectCount == 0) {
                strUpdataMac = _screenCfg.appID;
                
                lScanDeviceTime = (long)[[NSDate date] timeIntervalSince1970];
                [self.centralManager stopScan];
                [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 2%%",XTLS(@"XT_doingota")] success:YES delay:0];
                
                DLog(@"current device mac：%@", strUpdataMac);
                if (self.peripheralState ==  CBManagerStatePoweredOn){
                    nScanTagTime = 0;
                    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
                } else {
                    [self nfcAlertMsg:XTLS(@"XT_NFCwarn") success:NO delay:1];
                }
                
                if (tags.count == 1){
                    self.currentNFCTag = tags.firstObject;
                }
            }
        } else if (_opType == WriteScreen){
            DLog(@"%@", [NSString stringWithFormat:@"------tagReaderSession 2 - &nBleConnectCount %d", nBleConnectCount]);
            if (nBleConnectCount == 0) {
                // 测试异步循环读NFC
                strUpdataMac = _screenCfg.appID;
                lScanDeviceTime = (long)[[NSDate date] timeIntervalSince1970];
                [self.centralManager stopScan];
                [self nfcAlertMsg:XTLS(@"XT_readyBrushing") success:YES delay:0];
                
                DLog(@"Preparing to scan for devices：%@", strUpdataMac);
                
                if (self.peripheralState == CBManagerStatePoweredOn){
                    nScanTagTime = 0;
                    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
                } else {
                    [self nfcAlertMsg:XTLS(@"XT_NFCwarn") success:NO delay:1];
                }
                if (tags.count == 1){
                    self.currentNFCTag = tags.firstObject;
                }
            } else {
                DLog(@"----- ble device has been found, ble stop scanning. -----");
            }
        } else if (_opType == ReadDeviceConfig){
            DLog(@"------tagReaderSession 3");
            if (_isNeedScanTip == NO) { //只做激活蓝牙用
                // 这里只表示 NFC 唤醒成功，后续 BLE 写入仍使用页面已绑定的设备配置。
                XTDeviceConfig *activationConfig = [[XTDeviceConfig alloc] init];
                activationConfig.brushType = brushWithBle;
                if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                    [_delegate NfcReadConfigComplete:activationConfig];
                }
                [self nfcAlertMsg:XTLS(@"XT_NFC_Fast_Broadcast_Activated") success:YES delay:1];
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_opType == ReadDeviceConfig){
                    // 绑定设备
                    if (tags.count > 1) {
                        [self nfcAlertMsg:XTLS(@"XT_NFCMoreTag") success:YES delay:0];
                        if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                            [_delegate NfcReadConfigComplete:nil];
                        }
                        return;
                    }
                    
                    id  tag = tags.firstObject;
                    [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
                        if (error) {
                            [self nfcAlertMsg:XTLS(@"XT_NFCConnectFailed") success:NO delay:1];
                            if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                                [_delegate NfcReadConfigComplete:nil];
                            }
                            return;
                        }
                        [tag queryNDEFStatusWithCompletionHandler:^(NFCNDEFStatus status, NSUInteger capacity, NSError * _Nullable error) {
                            if (status == NFCNDEFStatusNotSupported) {
                                [self nfcAlertMsg:XTLS(@"XT_NFCNotNdef") success:NO delay:1];
                                if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                                    [_delegate NfcReadConfigComplete:nil];
                                }
                                return;
                            }
                            if (error) {
                                [self nfcAlertMsg:XTLS(@"XT_queryNFCConnectFailed") success:NO delay:1];
                                if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                                    [_delegate NfcReadConfigComplete:nil];
                                }
                                return;
                            } else {
                                //读
                                [tag readNDEFWithCompletionHandler:^(NFCNDEFMessage * _Nullable message, NSError * _Nullable error) {
                                    if (error) {
                                        [self nfcAlertMsg:XTLS(@"XT_readNFCConnectFailed") success:NO delay:1];
                                        if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                                            [_delegate NfcReadConfigComplete:nil];
                                        }
                                        return;
                                    } else if (message == nil) {
                                        [self nfcAlertMsg:XTLS(@"XT_NFCBlank") success:NO delay:1];
                                        if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                                            [_delegate NfcReadConfigComplete:nil];
                                        }
                                        return;
                                    } else {
                                        [self nfcAlertMsg:XTLS(@"XT_readinfo") success:YES delay:0];
                                        DLog(@"result---%@",message);
                                        if (message != NULL && message.records != NULL) {
                                            NSUInteger count = message.records.count;
                                            for (int i = 0; i < count; i++) {
                                                NFCNDEFPayload *ary = message.records[i];
                                                NSString *inputStr = [[NSString alloc] initWithData:ary.payload encoding:NSUTF8StringEncoding];
                                                DLog(@"NFC read info ---%@",inputStr);
                                                [self bandDeviceAndWriteNFCToCache:inputStr fromQR:NO];
                                            }
                                        } else {
                                            [self nfcAlertMsg:XTLS(@"XT_NFCdataWarn") success:NO delay:1];
                                        }
                                    }
                                }];
                            }
                        }];
                    }];
                }
            });
        }
    } else {
        BOOL isConnected = [self connectTag:tagCurrent];
        if(!isConnected){
            [self showMsgOnSession: session message:NSLocalizedString(@"FM_NFC_Connect_Fail", nil) isContinueScan:YES];
            return;
        }
        NFCTagObject *tagObj = [[NFCTagObject alloc] initWithTag:tagCurrent];
        NSInteger statusCode = BT_OPERATION_FAILED;
        NSString *cmdResult = @"";
        NSString *cmdStr = @"";
    //    NSString *resultStr = @"";
        NSString *errMsg = @"";
        NSString *resultText = @"";
        
        _nfcLog = @"";
        if(_opType == WriteCustomApdu){
            NSArray *customArr = [_apdu componentsSeparatedByString:@","];
            for(NSString *cmdApdu in customArr){
                if(cmdApdu.length<=0){
                    continue;
                }
                
                NSDate *startTime = [NSDate date];
                cmdResult = [tagObj writeNFCString:cmdApdu code:&statusCode errMsg:&errMsg];
                NSDate *endTime = [NSDate date];
                NSTimeInterval timeInterval = [endTime timeIntervalSinceDate:startTime];
                NSLog(@"耗时: %f 秒", timeInterval);
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Write_Fail_Data", nil), cmdApdu, errMsg] isContinueScan:YES];
                    return;
                }
                resultText = [NSString stringWithFormat:@"%@apdu:%@;result:%@\n", resultText, cmdApdu, cmdResult];
    //            [NSThread sleepForTimeInterval:0.3];
            }
            
            __block typeof(self) blockSelf = self;
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcCustomCMDComplete:)]) {
                    [blockSelf.delegate NfcCustomCMDComplete:resultText];
                }
            });
        }
        else if(_opType == WriteScreen || _opType == WriteScreenOnly){
            cmdResult = [tagObj writeNFCString:GET_CONFIG_INFO_CMD code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), errMsg] isContinueScan:YES];
                return;
            }
            
            //解析屏幕配置
            XTDeviceConfig *deviceCfg = [self parseDeviceCfg:cmdResult errMsg:&errMsg];
            if(!deviceCfg){
                [self showMsgOnSession: session message:errMsg isContinueScan:YES];
                return;
            }
            if (_isNeedScanTip == YES) {
                XTDeviceConfig *bindConfig = [[XTDeviceConfig alloc] init];
                bindConfig.brushType = deviceCfg.brushType;
                bindConfig.appID = deviceCfg.appID;
                bindConfig.uuID = deviceCfg.uuID;
                __block typeof(self) blockSelf = self;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                        [blockSelf.delegate NfcReadConfigComplete:bindConfig];
                    }
                });
                [self nfcAlertMsg:XTLS(@"XT_ReadInfoSuccess") success:YES delay:1];
                return;
            }
            
            //检查是否需要pin
            cmdStr = CHECK_NEED_PIN_CMD;
            cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                return;
            }

            NSString  *resultCode = @"";
            if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
            }
            else{
                resultCode = cmdResult;
            }
            //无需验pin
            if([self isCMDSuccess:resultCode]){
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
                deviceCfg.checkPin = NO;
            }
            //需要验pin
            else if([resultCode isEqualToString:@"6985"]){
                deviceCfg.checkPin = YES;
                
                session.alertMessage = NSLocalizedString(@"FM_Verify_Pin", nil);
                NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:_screenCfg.pin.length/2 digit:2];
                cmdStr = [NSString stringWithFormat:VERIFY_PIN_CMD, hexLen, _screenCfg.pin];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                    return;
                }
                if(![self isCMDSuccess:cmdResult]){
                    //设备被锁
                    if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                    }
                    //验pin错误
                    else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                        NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal:[cmdResult substringWithRange:NSMakeRange(3, 1)]];
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                    }
                    //其他错误
                    else{
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                    }
                    return;
                }
                
                //验pin成功,再次读取配置
                cmdStr = CHECK_NEED_PIN_CMD;
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                    return;
                }

                resultCode = @"";
                if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                    resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                    cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
                }
                else{
                    resultCode = cmdResult;
                }
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
            }
            else{
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, resultCode] isContinueScan:YES];
                return;
            }
            
            //检测当前屏幕配置与app屏幕配置是否匹配
            if(![self checkDeviceCfg:_screenCfg currentDeviceCfg:deviceCfg errMsg:&errMsg]){
                errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Device_Check_Fail", nil), errMsg];
                [self showMsgOnSession: session message:errMsg isContinueScan:YES];
                return;
            }
            
            //验pin
            if(_screenCfg.checkPin){
                session.alertMessage = NSLocalizedString(@"FM_Verify_Pin", nil);
                NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:_pin.length/2 digit:2];
                cmdStr = [NSString stringWithFormat:VERIFY_PIN_CMD, hexLen, _pin];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                    return;
                }
                if(![self isCMDSuccess:cmdResult]){
                    //设备被锁
                    if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                    }
                    //验pin错误
                    else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                        NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal: [cmdResult substringWithRange:NSMakeRange(3, 1)]];
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                    }
                    //其他错误
                    else{
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                    }
                    return;
                }
                //验pin成功
                else{
                    __block typeof(self) blockSelf = self;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcVerifyPinComplete:)]) {
                            [blockSelf.delegate NfcVerifyPinComplete:_pin];
                        }
                    });
                }
            }
            
            //发送图像
            session.alertMessage = NSLocalizedString(@"FM_Image_Importing", nil);
            
            //包切割尺寸
            size_t cutSize = 0xFA;
            NSDate *startTime = [NSDate date];
            NSMutableData *sendData;
            //压缩模式
            if(_screenCfg.supportCompress){
                //压缩分几包
                size_t compressCount;
                //压缩分包的余数
                size_t compressRemainder;
                //压缩分包数
                size_t compressPackageSize;
                //输出预留空间
                size_t outLen = 5000;
                
                //单图,旧四色模式合成
                if(_screenCfg.combineType == SingleType || _screenCfg.combineType == Color4Type){
                    //原压缩算法
                    if(_screenCfg.compressAlgo == 1){
                        compressRemainder = _imageData.length % 2000;
                        compressCount = _imageData.length / 2000;
                        if(compressRemainder>0){
                            compressCount++;
                        }
                    }
                    //哈夫曼编码压缩
                    else{
                        compressRemainder = 0;
                        compressCount = 1;
                        outLen = _imageData.length;
                    }
                    //压缩分包数=压缩总包数
                    compressPackageSize = compressCount;
                }
                //双图合成
                else if(_screenCfg.combineType == ComplexType){
                    //原压缩算法
                    if(_screenCfg.compressAlgo == 1){
                        compressRemainder = (_imageData.length/2) % 2000;
                        compressPackageSize = (_imageData.length/2) / 2000;
                        if(compressRemainder>0){
                            compressPackageSize++;
                        }
                        
                    }
                    //哈夫曼编码压缩
                    else{
                        compressRemainder = 0;
                        compressPackageSize = 1;
                        outLen = _imageData.length/2;
                    }
                    //压缩总包数=压缩分包数*2
                    compressCount = compressPackageSize * 2;
                }
                //三色以上通用模式
                else{
                    //原压缩算法
                    if(_screenCfg.compressAlgo == 1){
                        //计算每个分区的分包数和余数
                        compressRemainder = (_imageData.length/_screenCfg.writeImageCount) % 2000;
                        compressPackageSize = (_imageData.length/_screenCfg.writeImageCount) / 2000;
                        if(compressRemainder>0){
                            compressPackageSize++;
                        }
                    }
                    //哈夫曼编码压缩
                    else{
                        compressRemainder = 0;
                        compressPackageSize = 1;
                        outLen = _imageData.length/_screenCfg.writeImageCount;
                    }
                    //压缩总包数=压缩分包数*图像分区数
                    compressCount = compressPackageSize * _screenCfg.writeImageCount;
                    NSLog(@"image length:%ld 余数:%ld 压缩分包数:%ld 压缩总包数:%ld", _imageData.length, compressRemainder, compressPackageSize, compressCount);
                }
                
                UInt8 byteValue;
                //大于250字节，分包发送
                size_t packageCount, packageSize, remainder;
                //压缩后的数据
                NSData *compressData;
                NSUInteger compressCopyDataIdx=0;//复制压缩数据索引
                NSUInteger copyDataIdx=0;//复制传输数据索引
                unsigned char *inData;
                unsigned char outData[outLen*2];
                size_t inLen = 0;
                
                size_t sendDataLen = 0;
    //            int r = 0;
                NSData *copyData;
                NSData *imageData;
                //解压使能, 0接收数据 1解压数据，最后一包的时候发送解压使能
                NSInteger needDecompress = 0;
                
                //压缩分包
                NSInteger imageIdx = _imageSectionNumber;
                for(int k=0; k<compressCount; k++){
                    session.alertMessage = [NSString stringWithFormat:@"%lu%%", (k*100)/compressCount];
                    //最后一包检测是否有余数包
                    if(_screenCfg.combineType == SingleType || _screenCfg.combineType == Color4Type){
                        //原压缩算法
                        if(_screenCfg.compressAlgo == 1){
                            //最后一包
                            if(k==compressCount-1){
                                if(compressRemainder>0){
                                    inLen = compressRemainder;
                                }
                                else{
                                    inLen = 2000;
                                }
                            }
                            //非最后一包
                            else{
                                inLen = 2000;
                            }
                        }
                        //哈夫曼编码压缩
                        else{
                            inLen = outLen;
                        }
                        imageIdx = _imageSectionNumber;
                    }
                    //双图模式
                    else if(_screenCfg.combineType == ComplexType){
                        //原压缩算法
                        if(_screenCfg.compressAlgo == 1){
                            if(k==compressPackageSize-1){
                                if(compressRemainder>0){
                                    inLen = compressRemainder;
                                }
                                else{
                                    inLen = 2000;
                                }
                            }
                            else if(k==compressCount-1){
                                if(compressRemainder>0){
                                    inLen = compressRemainder;
                                }
                                else{
                                    inLen = 2000;
                                }
                            }
                            //非最后一包
                            else{
                                inLen = 2000;
                            }
                        }
                        //哈夫曼编码压缩
                        else{
                            inLen = outLen;
                        }
                        
                        if(k<compressPackageSize){
                            imageIdx = _imageSectionNumber;//屏幕序号，从0开始
                        }
                        else{
                            imageIdx = _imageSectionNumber+1;//屏幕序号+1
                        }
                    }
                    //三色以上通用模式
                    else{
                        //原压缩算法
                        if(_screenCfg.compressAlgo == 1){
                            //分区最后一包
                            if(k%compressPackageSize == compressPackageSize-1){
                                if(compressRemainder>0){
                                    inLen = compressRemainder;
                                }
                                else{
                                    inLen = 2000;
                                }
                            }
                            //非最后一包
                            else{
                                inLen = 2000;
                            }
                        }
                        //哈夫曼编码压缩
                        else{
                            inLen = outLen;
                        }
                    }
                    
                    //截取数据
                    copyData = [_imageData subdataWithRange:NSMakeRange(compressCopyDataIdx, inLen)];
                    compressCopyDataIdx = compressCopyDataIdx + inLen;
    //                NSLog(@"输入数据大小 %ld 数据:%@", copyData.length, copyData);
                    
                    inLen = copyData.length;
                    inData = (unsigned char*)[copyData bytes];
                    
                    //压缩数据
                    if(_screenCfg.compressAlgo == 1){
                        [FMCompressUtils FMCompressData:inData inLen:inLen outData:outData outLen:&outLen];
                    }
                    //哈夫曼编码压缩
                    else{
                        [FMCompressUtils FMCompressByHuffman:inData inLen:inLen outData:outData outLen:&outLen];
                    }
                    
                    compressData = [NSData dataWithBytes:outData length:outLen];
                    NSLog(@"输入数据大小 %ld 压缩数据大小 %ld 压缩比 %0.2f%%", copyData.length, compressData.length, (float)(compressData.length*100/copyData.length));
                    
                    //传输分包
                    remainder = compressData.length % cutSize;
                    packageCount = compressData.length / cutSize;
                    if(remainder>0){
                        packageCount++;
                    }
                    //分包数=总包数
                    packageSize = packageCount;
                    //索引重置
                    copyDataIdx=0;
                    for(int i=0; i<packageCount; i++){
                        if(i%10 == 0){
                            session.alertMessage = [NSString stringWithFormat:@"%lu%%", (k*100)/compressCount+(i*100)/(packageCount*compressCount)];
                        }
                        if(i==packageCount-1){
                            if(remainder>0){
                                sendDataLen = remainder;
                            }
                            else{
                                sendDataLen = cutSize;
                            }
                            needDecompress = 1;
                        }
                        else{
                            sendDataLen = cutSize;
                            needDecompress = 0;
                        }
                        
                        sendData = [[NSMutableData alloc] init];
                        //命令开始
                        byteValue = 0xF0;
                        [sendData appendBytes:&byteValue length:1];
                        //原压缩算法
                        if(_screenCfg.compressAlgo == 1){
                            byteValue = 0xD3;
                            [sendData appendBytes:&byteValue length:1];
                            byteValue = imageIdx;//屏幕序号，从0开始
                            [sendData appendBytes:&byteValue length:1];
                            //解压使能, 0接收数据 1解压数据，最后一包的时候发送解压使能
                            byteValue = needDecompress;
                            [sendData appendBytes:&byteValue length:1];
                            byteValue = sendDataLen + 2;//数据区长度，包括lc
                            [sendData appendBytes:&byteValue length:1];
                            //压缩包序号
                            byteValue = k % compressPackageSize;
                            [sendData appendBytes:&byteValue length:1];
                            //压缩包子包序号
                            byteValue = i % packageSize;
                            [sendData appendBytes:&byteValue length:1];
                        }
                        //哈夫曼编码压缩
                        else{
                            byteValue = 0xC3;
                            [sendData appendBytes:&byteValue length:1];
                            byteValue = imageIdx;//屏幕序号，从0开始
                            [sendData appendBytes:&byteValue length:1];
                            //开始传输第一包
                            if(copyDataIdx==0){
                                byteValue = 0x00;
                            }
                            //最后一包
                            else if(i==packageCount-1){
                                byteValue = 0x02;
                            }
                            else{
                                byteValue = 0x01;
                            }
                            [sendData appendBytes:&byteValue length:1];
                            byteValue = sendDataLen;//数据区长度，包括lc
                            [sendData appendBytes:&byteValue length:1];
                        }
                        
                        imageData = [compressData subdataWithRange:NSMakeRange(copyDataIdx, sendDataLen)];
                        [sendData appendData:imageData];
    //                    NSLog(@"截取数据 %@", imageData);
                        copyDataIdx = copyDataIdx + sendDataLen;
                        
                        _nfcLog = [NSString stringWithFormat:@"%@\r\n%@", _nfcLog, [XTCommonUtils convertDataToHexString:sendData]];
                        cmdResult = [tagObj writeNFCData:sendData code:&statusCode errMsg:&errMsg];
                        if(statusCode != BT_SUCCESS){
                            [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Image_Import_Fail", nil), errMsg] isContinueScan:YES];
                            return;
                        }
                        if(![self isCMDSuccess:cmdResult]){
                            [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Image_Import_Fail", nil), cmdResult] isContinueScan:YES];
                            return;
                        }
                    }
                    
                    if(_screenCfg.combineType == GeneralType){
                        //分区最后一包
                        if(k%compressPackageSize == compressPackageSize-1){
                            //不能提前，必须在结尾加
                            imageIdx++;
                        }
                    }
                }
            }
            //非压缩模式
            else{
                //大于cutSize字节，分包发送
                size_t packageCount, remainder;

                UInt8 byteValue;
                NSUInteger copyDataIdx=0;//复制图像数据索引
                size_t sendDataLen = 0;
                
                //分包大小
                size_t packageSize;
                //单图合成
                if(_screenCfg.combineType == SingleType || _screenCfg.combineType == Color4Type){
                    remainder = _imageData.length % cutSize;
                    packageCount = _imageData.length / cutSize;
                    if(remainder>0){
                        packageCount++;
                    }
                    //分包数=总包数
                    packageSize = packageCount;
                }
                //双图模式
                else if(_screenCfg.combineType == ComplexType){
                    remainder = (_imageData.length/2) % cutSize;
                    packageSize = (_imageData.length/2) / cutSize;
                    if(remainder>0){
                        packageSize++;
                    }
                    //总包数=分包数*2
                    packageCount = packageSize * 2;
                }
                //三色以上通用模式
                else{
                    //计算每个分区的分包数和余数
                    remainder = (_imageData.length/_screenCfg.writeImageCount) % cutSize;
                    packageSize = (_imageData.length/_screenCfg.writeImageCount) / cutSize;
                    if(remainder>0){
                        packageSize++;
                    }
                    //总包数=分包数*图像分区数
                    packageCount = packageSize * _screenCfg.writeImageCount;
                }
                
                NSInteger imageIdx = _imageSectionNumber;
                for(int i=0; i<packageCount; i++){
                    session.alertMessage = [NSString stringWithFormat:@"%lu%%", (i*100)/packageCount];
                    
                    //分区最后一包
                    if(i%packageSize == packageSize-1){
                        if(remainder>0){
                            sendDataLen = remainder;
                        }
                        else{
                            sendDataLen = cutSize;
                        }
                    }
                    //非最后一包
                    else{
                        sendDataLen = cutSize;
                    }
                    
                    sendData = [[NSMutableData alloc] init];
                    //命令开始
                    byteValue = 0xF0;
                    [sendData appendBytes:&byteValue length:1];
                    byteValue = 0xD2;
                    [sendData appendBytes:&byteValue length:1];

                    if(i%packageSize == packageSize-1){
                        byteValue = _imageSectionNumber;//屏幕序号，从0开始
                    }
                    else{
                        byteValue = _imageSectionNumber+1;//屏幕序号+1
                    }
                    
                    [sendData appendBytes:&byteValue length:1];
                    //包序号，从0开始
                    byteValue = i % packageSize;
                    [sendData appendBytes:&byteValue length:1];
                    byteValue = sendDataLen;//数据区长度，满包情况下固定为cutSize
                    [sendData appendBytes:&byteValue length:1];
                    
                    NSData *imageData = [_imageData subdataWithRange:NSMakeRange(copyDataIdx, sendDataLen)];
                    [sendData appendData:imageData];
                    copyDataIdx = copyDataIdx+sendDataLen;
                    
                    _nfcLog = [NSString stringWithFormat:@"%@\r\n%@", _nfcLog, [XTCommonUtils convertDataToHexString:sendData]];
                    cmdResult = [tagObj writeNFCData:sendData code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Image_Import_Fail", nil), errMsg] isContinueScan:YES];
                        return;
                    }
                    if(![self isCMDSuccess:cmdResult]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Image_Import_Fail", nil), cmdResult] isContinueScan:YES];
                        return;
                    }
                    
                    //分区最后一包
                    if(i%packageSize == packageSize-1){
                        //不能提前，必须在结尾加
                        imageIdx++;
                    }
                }
            }
            
            NSDate *endTime = [NSDate date];
            NSTimeInterval timeInterval = [endTime timeIntervalSinceDate:startTime];
            NSLog(@"图片传输结束，耗时: %f 秒", timeInterval);
            
            if(_nfcLog.length > 0){
                __block typeof(self) blockSelf = self;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcLogComplete:)]) {
                        [blockSelf.delegate NfcLogComplete:blockSelf.nfcLog];
                    }
                });
            }
            
            if(_opType != WriteScreenOnly){
                //刷新屏幕,hexImageSectionNumber bit7 刷屏指令方式 bit6~bit0图像区号
                session.alertMessage = NSLocalizedString(@"FM_Screen_Refreshing", nil);
                NSInteger p2Param;
                NSString *hexImageSectionNumber;
                //有源刷屏
                if(_screenCfg.hasPower){
                    p2Param = 0x80 | _imageSectionNumber;
                    hexImageSectionNumber = [XTCommonUtils convertDecimalToHexStringWithDigit:p2Param digit:2];
                    cmdStr = [NSString stringWithFormat:REFRESH_POWER_CMD, hexImageSectionNumber];
                    cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        [self showMsgOnSession: session message:XTLS(@"XT_NFC_Error_Or_Low_Battery") isContinueScan:YES];
                        return;
                    }
                    NSString *powFlag = @"00";//01有电池，00无电池
                    if(cmdResult.length==6){
                        powFlag = [cmdResult substringWithRange:NSMakeRange(0, 2)];
                        cmdResult = [cmdResult substringWithRange:NSMakeRange(2, 4)];
                    }
                    
                    if(![self isCMDSuccess:cmdResult]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
                        return;
                    }
                    
                    //有电池情况下结束流程，无电池则等待刷屏结果
                    if([powFlag isEqualToString:@"00"]){
                        session.alertMessage = XTLS(@"XT_Battery_Depleted_Replace");
                    }
                    else{
                        NSLog(@"有电");
                        session.alertMessage = XTLS(@"XT_Refresh_Started_Move_Phone");
                    }
                    
                    NSString *refreshFlag = @"01";
                    do{
                        cmdStr = GET_REFRESH_STATUS;
                        cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                        if(statusCode != BT_SUCCESS){
                            if([powFlag isEqualToString:@"00"]){
                                //失败继续下一次
                                continue;
                            }
                            else{
                                //失败就退出循环
                                break;;
                            }
        //                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
        //                        return;
                        }
                        if(cmdResult.length==6){
                            refreshFlag = [cmdResult substringWithRange:NSMakeRange(0, 2)];
                            cmdResult = [cmdResult substringWithRange:NSMakeRange(2, 4)];
                        }
                        if(![self isCMDSuccess:cmdResult]){
                            //失败不退出
                            continue;
        //                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
        //                        return;
                        }
                        NSLog(@"refreshFlag %@", refreshFlag);
                        [NSThread sleepForTimeInterval:0.3];
                    }
                    while ([refreshFlag isEqualToString:@"01"]);
                }
                //无源刷屏
                else{
                    p2Param = _imageSectionNumber;
                    hexImageSectionNumber = [XTCommonUtils convertDecimalToHexStringWithDigit:p2Param digit:2];
                    cmdStr = [NSString stringWithFormat:REFRESH_SCREEN_CMD, hexImageSectionNumber];
                    cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                        return;
                    }
                    if([cmdResult isEqualToString:@"6986"] || [cmdResult isEqualToString:@"68C6"]){
                        cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                        if(statusCode != BT_SUCCESS){
                            [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                            return;
                        }
                    }
                    if([cmdResult isEqualToString:@"68C6"]){
                        cmdStr = @"F0D4850000";
                        cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                        if(statusCode != BT_SUCCESS){
                            [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                            return;
                        }
                    }
                    if(![self isCMDSuccess:cmdResult]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
                        return;
                    }
                }
            }
        }
        else if(_opType == ReadDeviceConfig){
            //获取屏幕配置
            cmdResult = [tagObj writeNFCString:GET_CONFIG_INFO_CMD code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), errMsg] isContinueScan:YES];
                return;
            }
            
            //解析屏幕配置
            XTDeviceConfig *deviceCfg = [self parseDeviceCfg:cmdResult errMsg:&errMsg];
            if(!deviceCfg){
                [self showMsgOnSession: session message:errMsg isContinueScan:YES];
                return;
            }
            
            //检查是否需要pin
            cmdStr = CHECK_NEED_PIN_CMD;
            cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Config_Fail", nil), errMsg] isContinueScan:YES];
                return;
            }
            
            NSString *resultCode = @"";
            if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
            }
            else{
                resultCode = cmdResult;
            }
            //无需验pin
            if([self isCMDSuccess:resultCode]){
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
                deviceCfg.checkPin = NO;
                deviceCfg.pin = @"";
            }
            //需要验pin
            else if([resultCode isEqualToString:@"6985"]){
                deviceCfg.checkPin = YES;
                deviceCfg.pin = _pin;
                if(deviceCfg.pin == nil || deviceCfg.pin.length<=0){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Set_Pin", nil), errMsg] isContinueScan:NO];
                    return;
                }
                
                session.alertMessage = NSLocalizedString(@"FM_Verify_Pin", nil);
                NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:deviceCfg.pin.length/2 digit:2];
                cmdStr = [NSString stringWithFormat:VERIFY_PIN_CMD, hexLen, deviceCfg.pin];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                    return;
                }
                if(![self isCMDSuccess:cmdResult]){
                    //设备被锁
                    if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                    }
                    //验pin错误
                    else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                        NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal: [cmdResult substringWithRange:NSMakeRange(3, 1)]];
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                    }
                    //其他错误
                    else{
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                    }
                    return;
                }
                
                //验pin成功,再次读取配置
                cmdStr = CHECK_NEED_PIN_CMD;
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                    return;
                }

                resultCode = @"";
                if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                    resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                    cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
                }
                else{
                    resultCode = cmdResult;
                }
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
            }
            else{
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, resultCode] isContinueScan:YES];
                return;
            }
            if (_isNeedScanTip == NO && ![deviceCfg isSupportedBindingDevice]) {
                [self showMsgOnSession:session message:XTLS(@"XT_Unsupported_Device_Binding") isContinueScan:NO];
                __block typeof(self) blockSelf = self;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                        [blockSelf.delegate NfcReadConfigComplete:nil];
                    }
                });
                return;
            }
            
            __block typeof(self) blockSelf = self;
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
                    [blockSelf.delegate NfcReadConfigComplete:deviceCfg];
                }
            });
        }
        else if(_opType == RefreshScreen){
            cmdResult = [tagObj writeNFCString:GET_CONFIG_INFO_CMD code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), errMsg] isContinueScan:YES];
                return;
            }
            
            //解析屏幕配置
            XTDeviceConfig *deviceCfg = [self parseDeviceCfg:cmdResult errMsg:&errMsg];
            if(!deviceCfg){
                [self showMsgOnSession: session message:errMsg isContinueScan:YES];
                return;
            }
            
            //检查是否需要pin
            cmdStr = CHECK_NEED_PIN_CMD;
            cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                return;
            }

            NSString  *resultCode = @"";
            if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
            }
            else{
                resultCode = cmdResult;
            }
            //无需验pin
            if([self isCMDSuccess:resultCode]){
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
                deviceCfg.checkPin = NO;
            }
            //需要验pin
            else if([resultCode isEqualToString:@"6985"]){
                deviceCfg.checkPin = YES;
                
                session.alertMessage = NSLocalizedString(@"FM_Verify_Pin", nil);
                NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:_screenCfg.pin.length/2 digit:2];
                cmdStr = [NSString stringWithFormat:VERIFY_PIN_CMD, hexLen, _screenCfg.pin];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                    return;
                }
                if(![self isCMDSuccess:cmdResult]){
                    //设备被锁
                    if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                    }
                    //验pin错误
                    else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                        NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal: [cmdResult substringWithRange:NSMakeRange(3, 1)]];
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                    }
                    //其他错误
                    else{
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                    }
                    return;
                }
                
                //验pin成功,再次读取配置
                cmdStr = CHECK_NEED_PIN_CMD;
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                    return;
                }

                resultCode = @"";
                if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                    resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                    cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
                }
                else{
                    resultCode = cmdResult;
                }
                //处理自定义类型屏幕
                [self customProcessDeviceCfg:deviceCfg cmdResult:cmdResult];
            }
            else{
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, resultCode] isContinueScan:YES];
                return;
            }
            
            //检测当前屏幕配置与app屏幕配置是否匹配
            if(![self checkDeviceCfg:_screenCfg currentDeviceCfg:deviceCfg errMsg:&errMsg]){
                errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Device_Check_Fail", nil), errMsg];
                [self showMsgOnSession: session message:errMsg isContinueScan:YES];
                return;
            }
            
            //验pin
            if(_screenCfg.checkPin){
                session.alertMessage = NSLocalizedString(@"FM_Verify_Pin", nil);
                NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:_pin.length/2 digit:2];
                cmdStr = [NSString stringWithFormat:VERIFY_PIN_CMD, hexLen, _pin];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                    return;
                }
                if(![self isCMDSuccess:cmdResult]){
                    //设备被锁
                    if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                    }
                    //验pin错误
                    else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                        NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal: [cmdResult substringWithRange:NSMakeRange(3, 1)]];
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                    }
                    //其他错误
                    else{
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Verify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                    }
                    return;
                }
                //验pin成功
                else{
                    __block typeof(self) blockSelf = self;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcVerifyPinComplete:)]) {
                            [blockSelf.delegate NfcVerifyPinComplete:_pin];
                        }
                    });
                }
            }
            
            //刷新屏幕,hexImageSectionNumber bit7 刷屏指令方式 bit6~bit0图像区号
            session.alertMessage = NSLocalizedString(@"FM_Screen_Refreshing", nil);
            NSInteger p2Param;
            NSString *hexImageSectionNumber;
            //有源刷屏
            if(_screenCfg.hasPower){
                p2Param = 0x80 | _imageSectionNumber;
                hexImageSectionNumber = [XTCommonUtils convertDecimalToHexStringWithDigit:p2Param digit:2];
                cmdStr = [NSString stringWithFormat:REFRESH_POWER_CMD, hexImageSectionNumber];
                
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:XTLS(@"XT_NFC_Error_Or_Low_Battery") isContinueScan:YES];
                    return;
                }
                NSString *powFlag = @"00";//01有电池，00无电池
                if(cmdResult.length==6){
                    powFlag = [cmdResult substringWithRange:NSMakeRange(0, 2)];
                    cmdResult = [cmdResult substringWithRange:NSMakeRange(2, 4)];
                }
                if(![self isCMDSuccess:cmdResult]){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
                    return;
                }
                
                //有电池情况下结束流程，无电池则等待刷屏结果
                if([powFlag isEqualToString:@"00"]){
                    session.alertMessage = XTLS(@"XT_Battery_Depleted_Replace");
                }
                else{
                    NSLog(@"有电");
                    session.alertMessage = XTLS(@"XT_Refresh_Started_Move_Phone");
                }
                
                NSString *refreshFlag = @"01";
                do{
                    cmdStr = GET_REFRESH_STATUS;
                    cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        if([powFlag isEqualToString:@"00"]){
                            //失败继续下一次
                            continue;
                        }
                        else{
                            //失败就退出循环
                            break;;
                        }
    //                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
    //                        return;
                    }
                    if(cmdResult.length==6){
                        refreshFlag = [cmdResult substringWithRange:NSMakeRange(0, 2)];
                        cmdResult = [cmdResult substringWithRange:NSMakeRange(2, 4)];
                    }
                    if(![self isCMDSuccess:cmdResult]){
                        //失败不退出
                        continue;
    //                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
    //                        return;
                    }
                    NSLog(@"refreshFlag %@", refreshFlag);
                    [NSThread sleepForTimeInterval:0.3];
                }
                while ([refreshFlag isEqualToString:@"01"]);
            }
            //无源刷屏
            else{
                p2Param = _imageSectionNumber;
                hexImageSectionNumber = [XTCommonUtils convertDecimalToHexStringWithDigit:p2Param digit:2];
                cmdStr = [NSString stringWithFormat:REFRESH_SCREEN_CMD, hexImageSectionNumber];
                cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                if(statusCode != BT_SUCCESS){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                    return;
                }
                if([cmdResult isEqualToString:@"6986"] || [cmdResult isEqualToString:@"68C6"]){
                    cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                        return;
                    }
                }
                if([cmdResult isEqualToString:@"68C6"]){
                    cmdStr = @"F0D4850000";
                    cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
                    if(statusCode != BT_SUCCESS){
                        [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                        return;
                    }
                }
                if(![self isCMDSuccess:cmdResult]){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Refresh_Screen_Fail", nil), cmdStr, cmdResult] isContinueScan:YES];
                    return;
                }
            }
        }
        else if(_opType == ModifyPin){
            session.alertMessage = NSLocalizedString(@"FM_Processing", nil);
            
            //检查是否需要pin
            cmdStr = CHECK_NEED_PIN_CMD;
            cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_NFC_Read_Fail", nil), cmdStr, errMsg] isContinueScan:YES];
                return;
            }

            NSString *resultCode = @"";
            if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
                resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
                cmdResult = [cmdResult substringWithRange:NSMakeRange(0, cmdResult.length-CMD_CODE_LENGTH)];
            }
            else{
                resultCode = cmdResult;
            }
            //无需验pin
            if([self isCMDSuccess:resultCode]){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_No_Set_Pin", nil), cmdResult] isContinueScan:YES];
                return;
            }
            
            //修改pin
            cmdStr = [NSString stringWithFormat:@"%@FF%@", _oldPin, _pin];
            NSInteger dataLen = cmdStr.length/2;
            NSString *hexLen = [XTCommonUtils convertDecimalToHexStringWithDigit:dataLen digit:2];
            //80D90101原adminpin修改新userpin，80D90102原userpin修改新userpin
            cmdStr = [NSString stringWithFormat:@"80D90102%@%@", hexLen, cmdStr];
            cmdResult = [tagObj writeNFCString:cmdStr code:&statusCode errMsg:&errMsg];
            if(statusCode != BT_SUCCESS){
                [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Modify_Pin_Fail", nil), errMsg] isContinueScan:YES];
                return;
            }

            if(![self isCMDSuccess:cmdResult]){
                //设备被锁
                if([cmdResult isEqualToString:@"6983"] || [[cmdResult uppercaseString] isEqualToString:@"69C0"]){
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Device_Locked", nil), errMsg] isContinueScan:NO];
                }
                //验pin错误
                else if ([[cmdResult uppercaseString] rangeOfString:@"63C"].location != NSNotFound){
                    NSInteger remainTimes = [XTCommonUtils convertHexStringToDecimal: [cmdResult substringWithRange:NSMakeRange(3, 1)]];
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Modify_Pin_Fail_Count", nil), (long)remainTimes] isContinueScan:NO];
                }
                //其他错误
                else{
                    [self showMsgOnSession: session message:[NSString stringWithFormat:NSLocalizedString(@"FM_Modify_Pin_Fail", nil), cmdResult] isContinueScan:NO];
                }
                return;
            }
            //修改pin码成功
            else{
                __block typeof(self) blockSelf = self;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(NfcModifyPinComplete)]) {
                        [blockSelf.delegate NfcModifyPinComplete];
                    }
                });
            }
        }
        
        session.alertMessage = NSLocalizedString(@"FM_Operation_Success", nil);
        [session invalidateSession];
    }
}

- (void)bandDeviceAndWriteNFCToCache:(NSString *)inputStr fromQR:(BOOL)fromQR {
    TagBindInfo tagInfo = [XTBleProtocol getNFCTagBindInfo:inputStr];
    if (tagInfo.result) {
        XTDeviceConfig *cdevice = [[XTDeviceConfig alloc] init];
        cdevice.brushType = brushWithBle;
        cdevice.appID = tagInfo.mac;
        cdevice.uuID = tagInfo.mac;
        
        if (_delegate && [_delegate respondsToSelector:@selector(NfcReadConfigComplete:)]) {
            [_delegate NfcReadConfigComplete:cdevice];
        }
        if (fromQR == NO) {
            [self nfcAlertMsg:XTLS(@"XT_ReadInfoSuccess") success:YES delay:0.25];
        } else {
            [self nfcAlertMsg:XTLS(@"XT_bindsuccess") success:YES delay:0.25];
        }
    } else {
        [self nfcAlertMsg:XTLS(@"XT_deviceWriteError") success:NO delay:0.25];
    }
}

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session API_AVAILABLE(ios(13.0)) {
    //    DLog(@"readerSessionDidBecomeActive");
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error API_AVAILABLE(ios(13.0)){
    DLog(@"didInvalidateWithError:%@",error);
    _isNfcCanUsed = NO; //置为不可用
    NSString *msg = @"";
    switch (error.code) {
        case NFCReaderErrorUnsupportedFeature: {
            DLog(@"NFCReaderErrorUnsupportedFeature");
            msg = XTLS(@"XT_ErrUnsupportedFeature");
        }
            break;
        case NFCReaderErrorSecurityViolation: {
            DLog(@"NFCReaderErrorSecurityViolation");
            msg = XTLS(@"XT_ErrSecurityViolation");
        }
            break;
        case NFCReaderErrorInvalidParameter: {
            DLog(@"NFCReaderErrorInvalidParameter");
            msg = XTLS(@"XT_ErrInvalidParam");
        }
            break;
        case NFCReaderErrorInvalidParameterLength: {
            DLog(@"NFCReaderErrorSecurityViolation");
            msg = XTLS(@"XT_ErrInvalidParamLen");
        }
            break;
        case NFCReaderErrorParameterOutOfBound: {
            DLog(@"NFCReaderErrorSecurityViolation");
            msg = XTLS(@"XT_ErrParamOutOfBound");
        }
            break;
        case NFCReaderErrorRadioDisabled: {
            DLog(@"NFCReaderErrorSecurityViolation");
            msg = XTLS(@"XT_ErrRadioDisabled");
        }
            break;
        case NFCReaderTransceiveErrorTagConnectionLost: {
            DLog(@"NFCReaderTransceiveErrorTagConnectionLost");
            msg = XTLS(@"XT_ErrTagConnLost");
        }
            break;
        case NFCReaderTransceiveErrorSessionInvalidated: {
            DLog(@"NFCReaderTransceiveErrorTagConnectionLost");
            msg = XTLS(@"XT_ErrSessionInvalidated");
        }
            break;
        case NFCReaderTransceiveErrorTagNotConnected: {
            DLog(@"NFCReaderTransceiveErrorTagConnectionLost");
            msg = XTLS(@"XT_ErrTagNotConnected");
        }
            break;
        case NFCReaderTransceiveErrorPacketTooLong: {
            DLog(@"NFCReaderTransceiveErrorTagConnectionLost");
            msg = XTLS(@"XT_ErrPacketTooLong");
        }
            break;
        case NFCReaderTransceiveErrorRetryExceeded: {
            DLog(@"NFCReaderTransceiveErrorRetryExceeded");
            msg = XTLS(@"XT_ErrRetryExceeded");
        }
            break;
        case NFCReaderTransceiveErrorTagResponseError: {
            DLog(@"NFCReaderTransceiveErrorTagResponseError");
            msg = XTLS(@"XT_ErrTagResponseErr");
        }
            break;
        case NFCReaderSessionInvalidationErrorUserCanceled: {
            DLog(@"NFCReaderSessionInvalidationErrorUserCanceled");
        }
            break;
        case NFCReaderSessionInvalidationErrorSessionTimeout: {
            DLog(@"NFCReaderSessionInvalidationErrorSessionTimeout");
            if (!(_screenCfg.brushType == brushWithNfc)) {
                msg = XTLS(@"XT_ErrSessionTimeout");
            }
        }
            break;
        case NFCReaderSessionInvalidationErrorSessionTerminatedUnexpectedly: {
            DLog(@"NFCReaderSessionInvalidationErrorSessionTerminatedUnexpectedly");
            msg = XTLS(@"XT_ErrSystemBusy");
        }
            break;
        case NFCReaderSessionInvalidationErrorSystemIsBusy: {
            DLog(@"NFCReaderSessionInvalidationErrorSystemIsBusy");
            msg = XTLS(@"XT_ErrSystemBusy");
        }
            break;
        case NFCReaderSessionInvalidationErrorFirstNDEFTagRead: {
            DLog(@"NFCReaderSessionInvalidationErrorFirstNDEFTagRead");
            msg = XTLS(@"XT_ErrFirstNDEFTagInvalid");
        }
            break;
        case NFCTagCommandConfigurationErrorInvalidParameters: {
            DLog(@"NFCTagCommandConfigurationErrorInvalidParameters");
            msg = XTLS(@"XT_ErrTagConfigInvalid");
        }
            break;
        case NFCNdefReaderSessionErrorTagNotWritable: {
            DLog(@"NFCTagCommandConfigurationErrorInvalidParameters");
            msg = XTLS(@"XT_ErrNDEFTagNotWritable");
        }
            break;
        case NFCNdefReaderSessionErrorTagUpdateFailure: {
            DLog(@"NFCTagCommandConfigurationErrorInvalidParameters");
            msg = XTLS(@"XT_ErrNDEFTagUpdateFail");
        }
            break;
        case NFCNdefReaderSessionErrorTagSizeTooSmall: {
            DLog(@"NFCTagCommandConfigurationErrorInvalidParameters");
            msg = XTLS(@"XT_ErrNDEFTagSizeSmall");
        }
            break;
        case NFCNdefReaderSessionErrorZeroLengthMessage: {
            DLog(@"NFCTagCommandConfigurationErrorInvalidParameters");
            msg = XTLS(@"XT_ErrNDEFTagZeroMsg");
        }
            break;
        default:
            break;
    }
    if (_centralManager) {
        [_centralManager stopScan];
    }
    BOOL shouldNotifyDelegate = error.code == NFCReaderSessionInvalidationErrorUserCanceled
        || error.code == NFCReaderSessionInvalidationErrorSessionTimeout
        || ![XTTool isBlankString:msg];
    if (shouldNotifyDelegate && _delegate && [_delegate respondsToSelector:@selector(errCallBack:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate errCallBack:msg];
        });
    }
    if (_session) {
        [self nfcAlertMsg:msg success:NO delay:0.01];
        if (![XTTool isBlankString:msg]) {
            [XTMBManager showAlertViewWithText:msg delayHid:5.0];
        }
        
        DLog(@"brush failed，time ：%f", [[NSDate date] timeIntervalSince1970] - lFrushPicTime);
    }
}

//MARK: CBCentralManagerDelegate
// 蓝牙开关状态更新时调用
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStateUnknown:{
            [self nfcAlertMsg:XTLS(@"XT_unkonwState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        case CBManagerStateResetting:{
            [self nfcAlertMsg:XTLS(@"XT_resetState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        case CBManagerStateUnsupported:{
            [self nfcAlertMsg:XTLS(@"XT_UnsupportedState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        case CBManagerStateUnauthorized:{
            [self nfcAlertMsg:XTLS(@"XT_UnauthorizedState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        case CBManagerStatePoweredOff:{
            [self nfcAlertMsg:XTLS(@"XT_ClosedState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        case CBManagerStatePoweredOn:{
            [self nfcAlertMsg:XTLS(@"XT_AvailableState") success:YES delay:0];
            self.peripheralState = central.state;
        }
            break;
        default:
            [self nfcAlertMsg:XTLS(@"XT_OtherState") success:YES delay:0];
            break;
    }
}

/**
 扫描到设备
 @param central 中心管理者
 @param peripheral 扫描到的设备
 @param advertisementData 广告信息
 @param RSSI 信号强度
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
    NSString * mac = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    if ([mac isEqualToString:strUpdataMac]){
        DLog(@"had found current device mac: %@，RSSI: %@",mac, RSSI);
        
        NSString *ver = [XTBleProtocol getVersionFromCBAdvDataManufacturerData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]];
        DLog(@"current version = %@", ver);
        
        XTDeviceConfig *info = [XTDeviceConfig readLocalCfg];
        info.version = ver;
        [XTDeviceConfig saveLocalCfg:info];
        
        BOOL result = [ver caseInsensitiveCompare:@"1.0.0"] == NSOrderedSame;
        if (nTaskType == 1 && result) {
            // 当前版本按用户选择的屏幕配置工作，不再按设备编号拦截 OTA。
        }
        nScanTagTime = 1;
        
        [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 20%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
        // 停止扫描
        [self.centralManager stopScan];
        
        if (![self.peripherals containsObject:peripheral]){
            [self.peripherals addObject: peripheral];
            DLog(@"connectPeripheral: %@", peripheral);
            self.cbPeripheral = peripheral;
            [self.centralManager connectPeripheral:peripheral options:nil];
        } else {
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }
}

/**
 连接失败
 
 @param central 中心管理者
 @param peripheral 连接失败的设备
 @param error 错误信息
 */

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    DLog(@" centralManager connected failed");
    [self nfcAlertMsg:XTLS(@"XT_tansFailed") success:NO delay:1];
    nBleConnectState = 0;
}

/**
 连接断开
 @param central 中心管理者
 @param peripheral 连接断开的设备
 @param error 错误信息
 */

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    DLog(@"centralManager disconnect %@", [NSString stringWithFormat:@" -- %@",error]);
    nBleConnectState = 0;
}

/**
 连接成功
 @param central 中心管理者
 @param peripheral 连接成功的设备
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    DLog(@"Peripheral connect scucess，ready discover services");
    [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 25%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
    
    // 设置设备的代理
    peripheral.delegate = self;
    // services:传入nil  代表扫描所有服务
    [peripheral discoverServices:nil];
}

//MARK: CBPeripheralDelegate
/**
 扫描到服务
 @param peripheral 服务对应的设备
 @param error 扫描错误信息
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    // 遍历所有的服务
    for (CBService *service in peripheral.services){
        DLog(@"kWriteServerUUID: %@",service.UUID.UUIDString);
        // 获取对应的服务
        if ([service.UUID.UUIDString isEqualToString:kWriteServerUUID]){
            // 根据服务去扫描特征
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    
}

/**
 扫描到对应的特征
 
 @param peripheral 设备
 @param service 特征对应的服务
 @param error 错误信息
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    // 遍历所有的特征
    int a1 = 0;
    int a2 = 0;
    for (CBCharacteristic *characteristic in service.characteristics){
        DLog(@"kWriteCharacteristicUUID:%@",characteristic.UUID.UUIDString);
        if ([characteristic.UUID.UUIDString isEqualToString:kNotifyCharacteristicUUID]) {
            _currentPeripheral = peripheral;
            _readCharacteristic = characteristic;
            a1 = 1;
            [_currentPeripheral setNotifyValue:YES forCharacteristic:_readCharacteristic];
            [_currentPeripheral readValueForCharacteristic:_readCharacteristic];
        }
        
        if ([characteristic.UUID.UUIDString isEqualToString:kWriteCharacteristicUUID]) {
            _currentPeripheral = peripheral;
            _writeCharacteristic = characteristic;
            a2 = 1;
        }
    }
    
    DLog(@"ble writed characteristic state %d,%d", a1, a2);
    if (nBleConnectCount == 0 && a1 == 1 && a2 == 1) {
        DLog(@"ble writed characteristic sucess");
        [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 30%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
        // 这里开始刷图
        nBleConnectCount = 2;
        nBleConnectState = 1;
        
        // 开始刷图
        [self beginBrushPic];
    }
}

//写数据之后的回调   只有设置为CBCharacteristicWriteWithResponse之后才调用
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    // 不会进入这里
    if (error) {
        DLog(@"write fail");
        DLog(@"Error writing characteristic value: %@",[error localizedDescription]);
    } else{
        NSData *value = characteristic.value;
        DLog(@"write success, value: %@ lenth = %ld",value, value.length);
    }
}

//读数据之后的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        DLog(@"Error reading characteristic value: %@", [error localizedDescription]);
    } else{
        NSData *data = characteristic.value;
        NSString *resultCmd = [XTCommonUtils convertDataToHexString:data];;
        DLog(@"-------- ble data back :%@ ----------------------------------",resultCmd);
        
        // 处理接收到的数据
        NSMutableArray *arrarResult = [XTBleProtocol getBleSendResult:data];
        
        if (arrarResult) {
            if (arrarResult.count == 2) {
                globaWaitAnswerRunning = [XTCommonUtils convertNumberToInt:arrarResult[0]];
                arraySubPageData = arrarResult[1];
                if (arraySubPageData != NULL ) {
                    DLog(@"ble need fix data: -- %ld", arraySubPageData.count);
                }
            } else {
                globaWaitAnswerRunning = [XTCommonUtils convertNumberToInt:arrarResult[0]];
            }
        } else {
            DLog(@" ble failed: %@", arrarResult);
        }
    }
}


//MARK: Methods
//重开NFC
- (void)showMsgOnSession:(NFCReaderSession *)session
                 message:(NSString *)msg
          isContinueScan:(BOOL)isContinueScan {
    if(isContinueScan){
        session.alertMessage = msg;
        [NSThread sleepForTimeInterval:0.2];//0.2
        if(_session){
            _isReading = YES;
            [_session restartPolling];
        }
    } else{
        if(_session){
            _isReading = NO;
            [_session invalidateSessionWithErrorMessage:msg];
            _session = nil;
        }
    }
}

//NFC 弹窗
- (void)nfcAlertMsg:(NSString *)msg success:(BOOL)success delay:(CGFloat)delay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (success) {
            _session.alertMessage = msg;
        } else {
            [_session invalidateSessionWithErrorMessage:msg];
        }
    });
    if (delay != 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self removeSession];
        });
    }
}

//移除NFC session
- (void)removeSession {
    DLog(@"NFC removeSession");
    if(_session){
        [_session invalidateSession];
        _session = nil;
        _imageData = nil;
        DLog(@"NFC really removeSession");

        [NSThread sleepForTimeInterval:2];
    }
    if(_centralManager && _currentPeripheral && nBleConnectState == 1){
        [_centralManager cancelPeripheralConnection:_currentPeripheral];
    }
    _isReading = NO;
}

- (void)alertMsg:(NSString *)msg {
    [XTMBManager showAlertViewWithText:msg delayHid:1.5];
}

- (XTBrushType)brushTypeForBoundDevice:(XTDeviceConfig *)deviceConfig pureNFC:(BOOL)pureNFC {
    if (pureNFC) {
        return brushWithNfc;
    }
    if ([deviceConfig isPhoneCaseDevice]) {
        return brushWithNfcAndBle;
    }
    return brushWithBle;
}

//读TAG
- (BOOL)isBleBrush:(id<NFCTag>) tag {
    DLog(@"ReadTag %@",tag);
    if (tag.type == NFCTagTypeMiFare) {
        DLog(@"ReadTag NFC供电，蓝牙刷图");
        return YES;
    } else if (tag.type == NFCTagTypeISO7816Compatible) {
        DLog(@"ReadTag 纯NFC刷图");
    } else {
        DLog(@"ReadTag other");
    }
    return NO;
}

//连接NDEF
- (BOOL)connectTag:(id<NFCTag>) tag{
    DLog(@"connectTag");
    __block NFCTagReaderSession *blockSession = _session;
    __block BOOL result = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [blockSession connectToTag:tag completionHandler:^(NSError *connectError){
        if(connectError != nil){
            DLog(@"connect error:%lu", connectError.code);
        }
        else{
            result = YES;
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

//解析屏幕配置信息
- (XTDeviceConfig *)parseDeviceCfg:(NSString *)cmdResult errMsg:(NSString **)errMsg{
    NSString *resultCode = @"";
    //每字节2个hexstring
    NSInteger hexPerByte = 2;
    if(cmdResult&&cmdResult.length>CMD_CODE_LENGTH){
        resultCode = [cmdResult substringFromIndex:cmdResult.length-CMD_CODE_LENGTH];
    }
    else{
        resultCode = cmdResult;
    }
    if(![self isCMDSuccess:resultCode]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), resultCode];
        return nil;
    }
    cmdResult = [cmdResult substringToIndex:cmdResult.length-CMD_CODE_LENGTH];
//    NSLog(@"读取cmdResult:%@", cmdResult);
    
    XTDeviceConfig *deviceCfg = [[XTDeviceConfig alloc] init];
    deviceCfg.brushType = brushWithNfc;
    //A0
    NSString *tlvHeader = @"";
    NSString *hexLen = @"";
    NSString *tlvContent = @"";
    NSString *tlvValue = @"";
    NSInteger tlvIdx = 0;
    NSInteger contentLen = 0;
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A0];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_A0]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A0];
        return nil;
    }
    //获取tlv内容
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A0];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    
    if(contentLen<7){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A0];
        return nil;
    }
    //获取厂商代码
    tlvValue = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    deviceCfg.manufacturerCode = tlvValue;
    deviceCfg.manufacturerName = [XTCommonUtils getManufacturerNameByCode:deviceCfg.manufacturerCode];
    
    //获取水平翻转，垂直翻转配置
    tlvValue = [cmdResult substringWithRange:NSMakeRange(tlvIdx+1*hexPerByte, 1*hexPerByte)];
    NSInteger bit7 = ([XTCommonUtils convertHexStringToDecimal:tlvValue]) >> 7;
    NSInteger bit6 = (([XTCommonUtils convertHexStringToDecimal:tlvValue]) & 0x40) >> 6;
    //水平翻转
    if(bit7 == 1){
        deviceCfg.flipHorizontal = YES;
        NSLog(@"水平翻转");
    }
    else{
        deviceCfg.flipHorizontal = NO;
    }
    
    //垂直翻转
    if(bit6 == 1){
        deviceCfg.flipVertical = YES;
        NSLog(@"垂直翻转");
    }
    else{
        deviceCfg.flipVertical = NO;
    }
    
    //获取支持颜色
    tlvValue = [cmdResult substringWithRange:NSMakeRange(tlvIdx+2*hexPerByte, 1*hexPerByte)];
    deviceCfg.screenColorCode = tlvValue;
    //支持颜色数量
    tlvValue = [tlvValue substringWithRange:NSMakeRange(0, 1)];
    NSInteger intValue = [XTCommonUtils convertHexStringToDecimal:tlvValue];
    deviceCfg.colorCount = intValue;
    NSLog(@"支持颜色数量:%ld", intValue);
    deviceCfg.screenColorName = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Unit_Format"), deviceCfg.colorCount];
        
    //获取屏幕分辨率
    //高度
    tlvValue = [cmdResult substringWithRange:NSMakeRange(tlvIdx+3*hexPerByte, 2*hexPerByte)];
    deviceCfg.screenHeight = [XTCommonUtils convertHexStringToDecimal:tlvValue];
    //宽度
    tlvValue = [cmdResult substringWithRange:NSMakeRange(tlvIdx+5*hexPerByte, 2*hexPerByte)];
    deviceCfg.screenWidth = [XTCommonUtils convertHexStringToDecimal:tlvValue];
    
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //A1
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_A1]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
        return nil;
    }
    //获取颜色参数
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
        return nil;
    }
    //获取扫描方式
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    if([tlvContent isEqualToString:@"00"]){
        deviceCfg.scanType = VerticalType;
    }
    else if([tlvContent isEqualToString:@"01"]){
        deviceCfg.scanType = HorizontalType;
    }
    else{
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
        return nil;
    }
    
    //二色，三色的颜色配置读取A1，三色以上的颜色配置读取E0
    if(deviceCfg.colorCount <= 3){
        //获取图像混合模式和支持颜色数量
        tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx+1*hexPerByte, 1*hexPerByte)];
        //图像混合模式
        intValue = ([XTCommonUtils convertHexStringToDecimal:tlvContent])&0xF0;
        intValue = intValue >> 4;
        if(intValue == VALUE_SINGLE_MODE){
            deviceCfg.combineType = SingleType;
        }
        else if(intValue == VALUE_COMPLEX_MODE){
            deviceCfg.combineType = ComplexType;
        }
        else{
            *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
            return nil;
        }
    
        //支持颜色数量
        intValue = ([XTCommonUtils convertHexStringToDecimal:tlvContent])&0x0F;
        if(deviceCfg.colorCount != intValue){
            *errMsg = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Mismatch_Format"), @"A0", deviceCfg.colorCount, @"A1", intValue];
            return nil;
        }
        
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        for(int i=1;i<=deviceCfg.colorCount;i++){
            NSInteger colorIdx = tlvIdx + 1*hexPerByte + i*hexPerByte;
            NSInteger color2Device = 0;
            tlvContent = [cmdResult substringWithRange:NSMakeRange(colorIdx, 1*hexPerByte)];
            NSInteger colorValue = [XTCommonUtils convertHexStringToDecimal:tlvContent];
            intValue = (colorValue&0xE0)>>5;
            //获取图像颜色值
            if(deviceCfg.combineType == SingleType){
                color2Device = (colorValue&0x10)>>4;
            }
            else{
                color2Device = (colorValue&0x18)>>3;
            }
            
            if(intValue == VALUE_BLACK){
                [colorDic setValue: [NSString stringWithFormat: @"%ld", (long)color2Device] forKey:DIC_KEY_BLACK];
            }
            else if(intValue == VALUE_WHITE){
                [colorDic setValue: [NSString stringWithFormat: @"%ld", (long)color2Device] forKey:DIC_KEY_WHITE];
            }
            else if(intValue == VALUE_RED){
                [colorDic setValue: [NSString stringWithFormat: @"%ld", (long)color2Device] forKey:DIC_KEY_RED];
            }
            else if(intValue == VALUE_YELLOW){
                [colorDic setValue: [NSString stringWithFormat: @"%ld", (long)color2Device] forKey:DIC_KEY_YELLOW];
            }
            else{
                *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_A1];
                return nil;
            }
        }
        deviceCfg.colorDic = colorDic;
    }
    else{
        deviceCfg.combineType = ComplexType;
    }
    
    //B1
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B1];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_B1]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B1];
        return nil;
    }
    //获取图片容量
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B1];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    deviceCfg.imageCount = [XTCommonUtils convertHexStringToDecimal:tlvContent];
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //B2
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B2];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_B2]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B2];
        return nil;
    }
    //检查用户数据区长度是否正确
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B2];
        return nil;
    }
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //B3
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B3];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_B3]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B3];
        return nil;
    }
    //检查供电模式长度是否正确
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_B3];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    if([tlvContent isEqualToString:@"01"]){
        deviceCfg.hasPower = YES;
    }
    else{
        deviceCfg.hasPower = NO;
    }
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //C0
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C0];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_C0]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C0];
        return nil;
    }
    //获取AppID
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C0];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    deviceCfg.appID = tlvContent;
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //C1
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C1];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_C1]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C1];
        return nil;
    }
    //获取uuID
    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_C1];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    deviceCfg.uuID = tlvContent;
    tlvIdx = tlvIdx + contentLen*hexPerByte;
    
    //D1
    if(cmdResult.length<tlvIdx+2*hexPerByte){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_D1];
        return nil;
    }
    tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
    tlvIdx += 1*hexPerByte;
    if(![tlvHeader isEqualToString:TLV_D1]){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_D1];
        return nil;
    }

    contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
    if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
        *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_D1];
        return nil;
    }
    tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
    //截取首字节，判断是否是压缩模式，00，非压缩模式，01，压缩模式
    NSString *compressMode = [tlvContent substringWithRange:NSMakeRange(0, 2)];
    NSLog(@"compressAlgo:%@", compressMode);
    if([compressMode isEqualToString:@"00"]){
        deviceCfg.supportCompress = NO;
        deviceCfg.compressAlgo = 0;
    }
    else{
        deviceCfg.supportCompress = YES;
        deviceCfg.compressAlgo = [XTCommonUtils convertHexStringToDecimal:compressMode];
    }
    //截取第二字节，版本号，0x20，第二代
    NSString *versionCode = [tlvContent substringWithRange:NSMakeRange(2, 2)];
    deviceCfg.versionCode = [XTCommonUtils convertHexStringToDecimal: versionCode];
    
    //三色以上读取
    if(deviceCfg.colorCount > 3){
        deviceCfg.combineType = GeneralType;
        //从E0读取颜色参数
        tlvIdx = tlvIdx + contentLen*hexPerByte;
        if(cmdResult.length<tlvIdx+2*hexPerByte){
            *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_E0];
            return nil;
        }
        tlvHeader = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
        tlvIdx += 1*hexPerByte;
        hexLen = [cmdResult substringWithRange:NSMakeRange(tlvIdx, 1*hexPerByte)];
        tlvIdx += 1*hexPerByte;
        if(![tlvHeader isEqualToString:TLV_E0]){
            *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_E0];
            return nil;
        }

        contentLen = [XTCommonUtils convertHexStringToDecimal:hexLen];
        if(cmdResult.length<(tlvIdx+contentLen*hexPerByte)){
            *errMsg = [NSString stringWithFormat:NSLocalizedString(@"FM_Read_Config_Fail", nil), TLV_E0];
            return nil;
        }
        tlvContent = [cmdResult substringWithRange:NSMakeRange(tlvIdx, contentLen*hexPerByte)];
        
        tlvValue = [tlvContent substringWithRange:NSMakeRange(0, 1*hexPerByte)];
        //刷屏所需图片数量
        intValue = ([XTCommonUtils convertHexStringToDecimal:tlvValue])&0xF0;
        intValue = intValue >> 4;
        deviceCfg.writeImageCount = intValue;
        NSLog(@"刷屏所需图片数量:%ld", intValue);
        if(deviceCfg.imageCount < intValue){
            *errMsg = [NSString stringWithFormat:XTLS(@"XT_Image_Capacity_Less_Than_Required_Format"), deviceCfg.imageCount, intValue];
            return nil;
        }
        
        intValue = ([XTCommonUtils convertHexStringToDecimal:tlvValue])&0x0F;
        if(deviceCfg.colorCount != intValue){
            *errMsg = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Mismatch_Format"), @"A0", deviceCfg.colorCount, @"E0", intValue];
            return nil;
        }
        
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        for(int i=0;i<deviceCfg.colorCount;i++){
            NSInteger colorIdx = 2*hexPerByte + i*2*hexPerByte;
            //1字节颜色定义
            NSString *colorCode = [tlvContent substringWithRange:NSMakeRange(colorIdx, 1*hexPerByte)];
            //1字节转换格式 最高位 1bit 传输模式 0串行 1并行 剩余7bit 实际传输的颜色值
            tlvValue = [tlvContent substringWithRange:NSMakeRange(colorIdx+1*hexPerByte, 1*hexPerByte)];
            NSInteger colorValue = [XTCommonUtils convertHexStringToDecimal:tlvValue];
            //传输模式
            intValue = (colorValue&0x80)>>7;
            deviceCfg.transMode = intValue;
//            if(intValue == PARALLEL_TRANS_MODE){
//                NSLog(@"并行模式");
//            }
//            else{
//                NSLog(@"串行模式");
//            }
            //实际传输的颜色值
            intValue = colorValue&0x7F;
            
            //设置图像颜色值
            if([_colorTypeDic objectForKey:colorCode] != nil){
                [colorDic setValue: [NSString stringWithFormat: @"%ld", intValue] forKey:colorCode];
            }
            else{
                *errMsg = [NSString stringWithFormat:XTLS(@"XT_Unknown_Color_Definition_Format"), TLV_E0, colorCode];
                return nil;
            }
        }
        deviceCfg.colorDic = colorDic;
    }
    return deviceCfg;
}

//检测屏幕配置是否匹配
- (BOOL)checkDeviceCfg:(XTDeviceConfig *)appCfg currentDeviceCfg:(XTDeviceConfig *)currentDeviceCfg errMsg:(NSString **)errMsg{
    //屏幕尺寸检验
    if(appCfg.screenWidth != currentDeviceCfg.screenWidth || appCfg.screenHeight != currentDeviceCfg.screenHeight){
        *errMsg = SCREEN_SIZE_ERROR;
        return NO;
    }
    //颜色模式检验
    if(![appCfg.screenColorCode isEqualToString:currentDeviceCfg.screenColorCode]){
        *errMsg = COLOR_MODE_ERROR;
        return NO;
    }
    //扫描模式检验
    if(appCfg.scanType != currentDeviceCfg.scanType){
        *errMsg = SCAN_MODE_ERROR;
        return NO;
    }
    //混合模式检验
    if(appCfg.combineType != currentDeviceCfg.combineType){
        *errMsg = COMBINE_MODE_ERROR;
        return NO;
    }
    //支持颜色数量检验
    if(appCfg.colorDic.count != currentDeviceCfg.colorDic.count){
        *errMsg = COLOR_COUNT_ERROR;
        return NO;
    }
    //颜色值检验
    NSString *appColorKey, *appColorValue, *deviceColorValue;
    NSArray *appKeys = appCfg.colorDic.allKeys;
    for(int i=0;i<appCfg.colorDic.count;i++){
        appColorKey = [appKeys objectAtIndex:i];
        appColorValue = [appCfg.colorDic objectForKey:appColorKey];
        deviceColorValue = [currentDeviceCfg.colorDic objectForKey:appColorKey];
        if(![appColorValue isEqualToString:deviceColorValue]){
            *errMsg = COLOR_VALUE_ERROR;
            return NO;
        }
    }
    //是否带pin校验
    if(appCfg.checkPin != currentDeviceCfg.checkPin){
        *errMsg = PIN_CHECK_ERROR;
        return NO;
    }
    return YES;
}

//检验指令下发是否成功
- (BOOL)isCMDSuccess:(NSString *)text
{
    if(text && [text isEqualToString:NDEF_SUCCESS]){
        return YES;
    } else{
        return NO;
    }
}

//处理自定义类型屏幕
- (void)customProcessDeviceCfg:(XTDeviceConfig *)deviceCfg cmdResult:(NSString *)cmdResult {
    deviceCfg.imageAlgo = 0;
    //旧四色模式
    if([cmdResult isEqualToString:@"345F636F6C6F722053637265656E"]){
        deviceCfg.combineType = Color4Type;
        deviceCfg.colorCount = 4;
        deviceCfg.screenColorCode = COLOR_BWRY_CODE;
        deviceCfg.screenColorName = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Unit_Format"), deviceCfg.colorCount];
        deviceCfg.screenHeight = deviceCfg.screenHeight / 2;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        deviceCfg.colorDic = colorDic;
    }
    //SE0398N02 三色屏幕需要加转换算法
    else if([cmdResult isEqualToString:@"5345303339384E30320000000000"]){
        deviceCfg.isZhiHuiXin = YES;
        deviceCfg.imageAlgo = 2;
    }
    //SE0398N01_01 三色屏幕,是四色屏幕模拟的，需要加转换算法
    else if([cmdResult isEqualToString:@"5345303339384E30310100000000"]){
        deviceCfg.isZhiHuiXin = YES;
        deviceCfg.combineType = Color4Type;
        deviceCfg.imageAlgo = 1;
        deviceCfg.colorCount = 3;
        deviceCfg.screenColorCode = COLOR_BWR_CODE;
        deviceCfg.screenColorName = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Unit_Format"), deviceCfg.colorCount];
        deviceCfg.screenHeight = deviceCfg.screenHeight / 2;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"3" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"1" forKey:DIC_KEY_RED];
        deviceCfg.colorDic = colorDic;
    }
    //SE0398N01_02 四色屏幕，旧四色模式，需要加转换算法
    else if([cmdResult isEqualToString:@"5345303339384E30310200000000"]){
        deviceCfg.isZhiHuiXin = YES;
        deviceCfg.combineType = Color4Type;
        deviceCfg.imageAlgo = 1;
        deviceCfg.colorCount = 4;
        deviceCfg.screenColorCode = COLOR_BWRY_CODE;
        deviceCfg.screenColorName = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Unit_Format"), deviceCfg.colorCount];
        deviceCfg.screenHeight = deviceCfg.screenHeight / 2;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        deviceCfg.colorDic = colorDic;
    }
    //SE0398N03 四色屏幕，旧四色模式，需要加转换算法
    else if([cmdResult isEqualToString:@"5345303339384E30310300000000"]){
        deviceCfg.isZhiHuiXin = YES;
        deviceCfg.combineType = Color4Type;
        deviceCfg.imageAlgo = 3;
        deviceCfg.colorCount = 4;
        deviceCfg.screenColorCode = COLOR_BWRY_CODE;
        deviceCfg.screenColorName = [NSString stringWithFormat:XTLS(@"XT_Color_Count_Unit_Format"), deviceCfg.colorCount];
        deviceCfg.screenHeight = deviceCfg.screenHeight / 2;
        NSMutableDictionary *colorDic = [[NSMutableDictionary alloc] init];
        [colorDic setValue: @"0" forKey:DIC_KEY_BLACK];
        [colorDic setValue: @"1" forKey:DIC_KEY_WHITE];
        [colorDic setValue: @"3" forKey:DIC_KEY_RED];
        [colorDic setValue: @"2" forKey:DIC_KEY_YELLOW];
        deviceCfg.colorDic = colorDic;
    }
}

//MARK:  ============================= 蓝牙发送 =============================
- (int)senDataToDevice:(NSString *)cmdStr {
    globaWaitAnswerRunning = 1;
    NSData *data = [XTCommonUtils convertHexStringToData:cmdStr];
    [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
    int nGetTimeout = 0;
    while (globaWaitAnswerRunning == 1){
        [NSThread sleepForTimeInterval:0.1];
        nGetTimeout++;
        if (nGetTimeout > 50) {
            break;
        }
    }
    switch (globaWaitAnswerRunning) {
        case 1:
            DLog(@"cmd send time out");
            return 2;
        case 2:
            DLog(@"cmd send failed");
            return 3;
        case 104:
            DLog(@"Command execution failed");
            return 104;
        case 205:
            DLog(@"RSA security authentication failed");
            return 205;
        case 206:
            DLog(@"ECDSA signature verification failed");
            return 206;
        default:
            DLog(@"cmd send success");
            return 1;
    }
}

- (void)senDataToDeviceWithNoNeedResponse:(NSString *)cmdStr {
    NSData *data = [XTCommonUtils convertHexStringToData:cmdStr];
    [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

//MARK:  ============================= 开始刷图 =============================
- (void)beginBrushPic {
    DLog(@"---------- begin brush image -----------");
    [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 40%%",_opType == OTA ? XTLS(@"XT_readywritedata") : XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
    // 异步发送
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ( _screenCfg.screenWidth == 64) {
            if (_screenCfg.screenHeight == 1 || _screenCfg.screenHeight == 2 ) {
                //prism
                NSString *orderPrism = [XTBleProtocol getPrismBrushOrder:nDeleteFlashLen];
                // 发送指令
                int value = [self senDataToDevice:orderPrism];
                if (value == 1) {
                    NSString *orderFlushPicOrder = [XTBleProtocol getPicRefreshOrder];
                    DLog(@"send delete Flash back = %d - %@", value, orderFlushPicOrder);
                    
                    [self showMsgOnSession: _session message:[NSString stringWithFormat:@"%@ 60%%",XTLS(@"XT_Screen_Refreshing_image")] isContinueScan:YES];
                    DLog(@"NFC restartPolling");
                    
                    [self senDataToDeviceWithNoNeedResponse:orderFlushPicOrder];
                    [self nfcAlertMsg:XTLS(@"XT_Screen_Refreshing") success:YES delay:0];

                    // 等待返回成功
                    globaWaitAnswerRunning = 1;
                    for (int nw = 0; nw < 30; nw++){
                        if (globaWaitAnswerRunning == 0){
                            break;
                        }
                        [NSThread sleepForTimeInterval:0.64];// 间隔1秒
                        if (globaWaitAnswerRunning == 0){
                            break;
                        }
                        /*
                         if (nBleConnectState == 0) {
                         DLog(@"BLE not connected - bruch failed");
                         return;
                         }*/
                        if (_isNfcCanUsed == NO) {
                            DLog(@"NFC invalidate - brush image failed 1111");
                            [self nfcAlertMsg:XTLS(@"XT_unavailable") success:NO delay:1];
                            break;
                        }
                    }
                    DLog(@"brush success，time ：%f", [[NSDate date] timeIntervalSince1970] - lFrushPicTime);
                    [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 100%%",XTLS(@"XT_brushCompelte")] success:YES delay:1];
                }
                return;
            }
        }
        
//        return;
//        //测试17ProMax用
//        [NSThread sleepForTimeInterval:2.0];

        // 获取删除FLASH指令
        NSString *deleteFlashOrder = [XTBleProtocol getDeleteFlashOrder:nDeleteFlashLen];

        // 发送指令
        int value = [self senDataToDevice:deleteFlashOrder];
        DLog(@"11FLASH delete state %@ = %d = %d", deleteFlashOrder,value,nDeleteFlashLen);
        if (value != 1) {
            [self handleErrorWithValue:value cmd:0x01];
            return;
        }
        
        [self nfcAlertMsg:[NSString stringWithFormat:@"%@ %d%%",_opType == OTA ? XTLS(@"XT_readywritedata") : XTLS(@"XT_Screen_Refreshing_image"), value == 1 ? 41 : 39] success:YES delay:0];
        
        lScanDeviceTime = (long)[[NSDate date] timeIntervalSince1970] - lScanDeviceTime;
        lDeviceSendTime = (long)[[NSDate date] timeIntervalSince1970];
        DLog(@"globaIntervalTime:%f", globaIntervalTime);
        
        // 先设置为全部都需要补包
        arraySubPageData = [NSMutableArray array];
        for (int i = 0; i < arraySendDataPage.count; i++){
            [arraySubPageData addObject:[NSNumber numberWithInt:0]];
        }
        NSUInteger x1 = [_currentPeripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        DLog(@"maximumWriteValueLengthForType = %ld", x1);
        
        // 共可以补包5次
        for (int failCount = 0; failCount < 5; failCount++){
            // 发送数据包
            for (int i = 0; i < arraySendDataPage.count; i++){
                if (arraySubPageData != NULL && i < arraySubPageData.count) {
                    int indexValue = [arraySubPageData[i] intValue];
                    if (indexValue == 0){
                        // 这里是表示需要补包的
                        NSMutableArray *page = arraySendDataPage[i];
                        for (int j = 0; j < page.count; j++) {
                            if (nBleConnectState == 1) {
                                NSData *data = page[j];
                                // 发送数据
                                DLog(@"--- sendData - All %d - current %d - %d - %lu - %@",j, i, (int)arraySendDataPage.count,(unsigned long)data.length,[XTCommonUtils convertDataToHexString:data]);
                                
                                [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
                                
                                // globaPageSize
                                float intervalTime = 0.015;//5
                                [NSThread sleepForTimeInterval:intervalTime];
                            }
                        }
                        int t;
                        for(t = 0; t < 50; t++) {
                            if (_currentPeripheral.canSendWriteWithoutResponse == true) {
                                break;
                            }
                            [NSThread sleepForTimeInterval:0.001];
                        }
                        DLog(@"ready to write %d", t);
                        if (nBleConnectState == 0) {
                            DLog(@"ble disconnected, brush failed");
                            [self nfcAlertMsg:XTLS(@"XT_Nfc1Disconnected") success:NO delay:1];
                            return;
                        }
                    }
                }
            }
            
            // 清空需要补包的
            arraySubPageData = [NSMutableArray array];
            
            // 获取连接指令
            NSString *orderUpdataOrder = [XTBleProtocol getUpdateOrder:nTaskType == 0 ? 0 : 2 value:0]; // 0-pic 2-ota;
            
            // 发送
            DLog(@"send 04 cmd =%@",orderUpdataOrder);
            value = [self senDataToDevice:orderUpdataOrder];
            if (value == 2){
                value = [self senDataToDevice:orderUpdataOrder];
                DLog(@"send 04 cmd again = %d", value);
            } else if (value == 3){
                DLog(@"brush failed, data not complete");
                [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 55%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
            } else if (value == 1){
                if (nTaskType == 0) {
                    // pic
                    globaWaitAnswerRunning = 1;
                    [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 56%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
                    
                    DLog(@"connect ble time：%f", lScanDeviceTime);
                    DLog(@"send file time：%f", [[NSDate date] timeIntervalSince1970] - lDeviceSendTime);
                    
                    [self showMsgOnSession:_session message:[NSString stringWithFormat:@"%@ 60%%",XTLS(@"XT_Screen_Refreshing_image")] isContinueScan:YES];
                    DLog(@"NFC restartPolling");
                    [NSThread sleepForTimeInterval:0.2];// 间隔1秒
                    
                    int bWriteNFCBegin = 1;
                    // 发个13指令
                    NSString *flushPicOrder = [XTBleProtocol getPicRefreshOrder];
                    DLog(@"send image brush cmd 13 back = %d - %@", value, flushPicOrder);
                    // 这里不需要等回复
                    [self senDataToDeviceWithNoNeedResponse:flushPicOrder];

                    //开始刷图
                    [self nfcAlertMsg:XTLS(@"XT_Screen_Refreshing") success:YES delay:0];
                    lFrushPicTime = [[NSDate date] timeIntervalSince1970];
                    
                    // 等待13命令返回成功
                    globaWaitAnswerRunning = 1;
                    for (int nw = 0; nw < 40; nw++){        //niel25 ---》 50
                        if (globaWaitAnswerRunning == 0){
                            break;
                        }
//                        [self nfcAlertMsg:[NSString stringWithFormat:@"%@-%d",XTLS(@"XT_Screen_Refreshing"),nw] success:YES delay:0];
                        [NSThread sleepForTimeInterval:0.5];// 间隔1秒   70 + 30 * 0.64
                        //                        if (nBleConnectState == 0) { //蓝牙断掉了
                        //                            [_session connectToTag:_currentNFCTag completionHandler:^(NSError * _Nullable error) {
                        //                                if (error) {
                        //                                    [self nfcAlertMsg:XTLS(@"XT_NFCConnectFailed") success:NO delay:1];
                        //                                    return;
                        //                                }
                        //
                        //                            }];
                        //                        }
                        if (_isNfcCanUsed == NO) {
                            DLog(@"NFC disconnected - brush failed 222");
                            [self nfcAlertMsg:XTLS(@"XT_unavailable") success:NO delay:1];
                            return;
                        }
                    }
                    bWriteNFCBegin = 0;
                    DLog(@"brush sueccss. time：%f", [[NSDate date] timeIntervalSince1970] - lFrushPicTime);
//                    [self playSystemNFCBeep];
                    [self nfcAlertMsg:XTLS(@"XT_brushCompelte") success:YES delay:1];
                    _isBrushSuccess = YES;
                    return;
                } else {
                    //发送个05通知主板 OTA升级
                    NSString *otaUpdateStr = [XTBleProtocol startHardwareUpdateOrder];
                    value = [self senDataToDevice:otaUpdateStr];
                    DLog(@"send hardware ota begin cmd 05 back = %d", value);
                    if (value == 1) {
                        // ota
                        // 必须要先断开蓝牙在停5秒
                        [self nfcAlertMsg:XTLS(@"XT_doingota") success:YES delay:0];
                        if (nBleConnectState == 1) {
                            [self.centralManager cancelPeripheralConnection:_currentPeripheral];
                        }
                        [NSThread sleepForTimeInterval:5];// 间隔1秒
                        
                        DLog(@"OTA sueccss");
                        [self nfcAlertMsg:XTLS(@"XT_OtaSuccess") success:YES delay:1];
                    } else if (value == 2) {
                        value = [self senDataToDevice:otaUpdateStr];
                        DLog(@"send hardware ota begin cmd 05 again = %d", value);
                    } else if (value == 3){
                        [self nfcAlertMsg:XTLS(@"XT_OtaFailed") success:NO delay:1];
                    }
                    return;
                }
            }
        }
        DLog(@"bursh failed");
        [self nfcAlertMsg:XTLS(@"XT_unavailable") success:NO delay:1];
    });
}

//启动NDEF读写功能
- (NSString *)startNDEF:(OperationType)opType {
    if (!NFCTagReaderSession.readingAvailable) {
        [self alertMsg:XTLS(@"XT_Support_iPhone")];
        return XTLS(@"XT_Support_iPhone");
    }
    NSString *response = @"";
    _opType = opType;
    
//    _session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443
//                                                         delegate:self
//                                                            queue:dispatch_get_global_queue(0, 0)];
    //初始化
    if (!self.session) {
        [self alertMsg:XTLS(@"XT_NFCInitFailed")];
        return XTLS(@"XT_NFCInitFailed");
    }
    _isNfcCanUsed = YES;
    
    if(_hintText && _hintText.length > 0){
        if (_opType == WriteScreen){
            temp2 = 0;
            [self nfcAlertMsg:XTLS(@"XT_readywritedata") success:YES delay:0];
            arrayBWRYData_1 = _imageDataXTArr;
            
            if (_screenCfg.screenWidth == 64 && _screenCfg.screenHeight == 1) {
                nDeleteFlashLen =  [XTCommonUtils convertNumberToInt:(arrayBWRYData_1[0])];
            } else if (_screenCfg.screenWidth == 64 && _screenCfg.screenHeight == 2) {
                nDeleteFlashLen =  [XTCommonUtils convertNumberToInt:(arrayBWRYData_1[0])];
            } else if(NO) {
                globaPageSize = 490;
                DLog(@"globaPageSize:%d", globaPageSize);
                arraySendDataPage = [XTBleProtocol getPrismSendPageData:arrayBWRYData_1
                                                             pageSize:globaPageSize];
                // 获取需要清空的空间大小
                nDeleteFlashLen = (int)[XTBleProtocol getDeleteFlashLength:arraySendDataPage];
            } else {
                // 获取所有的分包数据
                int deviceColorType = 3; //3四色，5六色
                if([_screenCfg.screenColorCode isEqualToString:COLOR_BWRY_CODE]){
                    deviceColorType = 3;
                } else if([_screenCfg.screenColorCode isEqualToString:COLOR_BWRYGB_CODE]){
                    deviceColorType = 5;
                }
                globaPageSize = 490;
                arraySendDataPage = [XTBleProtocol getPicSendPageData:arrayBWRYData_1
                                                           picWidth:(int)_screenCfg.screenWidth
                                                          picHeight:(int)_screenCfg.screenHeight
                                                    deviceColorType:deviceColorType
                                                           pageSize:globaPageSize
                                                     isNeedCompress:YES];

                // 获取需要清空的空间大小
                nDeleteFlashLen = (int)[XTBleProtocol getDeleteFlashLength:arraySendDataPage];
            }
        } else if (_opType == OTA) {
            [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 2%%",XTLS(@"XT_readyOta")] success:YES delay:0];
            arrayBWRYData_1 = _imageDataXTArr;
            globaPageSize = 490;
            arraySendDataPage = [XTBleProtocol getOTASendPageData:_imageDataXTArr pageSize:globaPageSize];
            
            // 获取需要清空的空间大小
            nDeleteFlashLen = (int)[XTBleProtocol getDeleteFlashLength:arraySendDataPage];
            DLog(@"nDeleteFlashLen-finish:%d", nDeleteFlashLen);
        } else if (_opType == ReadDeviceConfig) {
            [self nfcAlertMsg:XTLS(@"XT_readinfo") success:YES delay:0];
            temp2 = 0;
        } else {
            [self nfcAlertMsg:XTLS(@"XT_brushing") success:YES delay:0];
            temp2 = 1;
        }
    }
    nBleConnectCount = 0;
    _isReading = YES;
    [_session beginSession];
    return response;
}

- (void)playSystemNFCBeep {
    SystemSoundID soundID = 1300;
    AudioServicesPlaySystemSound(soundID);
    AudioServicesPlaySystemSound(4095);
}

- (void)handleErrorWithValue:(NSInteger)value cmd:(NSInteger)cmd {
    NSString *errorMsg;
    switch (value) {
        case 206:
            errorMsg = XTLS(@"XT_Command_Need_Signature");
            break;
        case 205:
            errorMsg = XTLS(@"XT_Command_Security_Failed");
            break;
        case 104:
            errorMsg = XTLS(@"XT_Command_Execution_Failed");
            break;
        default:
            errorMsg = XTLS(@"XT_Unknown_Error_Retry");
            break;
    }
    
    [self nfcAlertMsg:errorMsg success:NO delay:1.0];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self alertMsg:errorMsg];
    });
}

//MARK: lazyload
- (NSMutableArray *)peripherals {
    if (!_peripherals) {
        _peripherals = [NSMutableArray array];
    }
    return _peripherals;
}

- (CBCentralManager *)centralManager {
    if (!_centralManager){
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return _centralManager;
}

- (NFCTagReaderSession *)session {
    if (!_session) {
        _session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443
                                                             delegate:self
                                                                queue:dispatch_get_global_queue(0, 0)];
    }
    return _session;
}


@end
