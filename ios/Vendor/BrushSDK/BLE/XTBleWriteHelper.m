//
//  XTBleWriteHelper.m
//  NewTool
//
//  Created by XTMacMini on 2025/3/7.
//

#import "XTBleWriteHelper.h"
#import <XTDitherBleProtocol/XTDitherBleProtocol.h>
#import "UtilsMacros.h"


#import "XTCommonUtils.h"

static const NSInteger XTBatchMaxPacketCount = 254;
static const NSInteger XTBatchPayloadBytes = 307200;
static const NSInteger XTBleSendResultDisconnected = -1001;

@implementation XTBleScannedDevice

- (id)copyWithZone:(NSZone *)zone {
    XTBleScannedDevice *device = [[[self class] allocWithZone:zone] init];
    device.mac = self.mac;
    device.deviceName = self.deviceName;
    device.rssi = self.rssi;
    device.deviceNumber = self.deviceNumber;
    device.screenWidth = self.screenWidth;
    device.screenHeight = self.screenHeight;
    device.colorText = self.colorText;
    device.supportMessage = self.supportMessage;
    device.supported = self.supported;
    device.deviceConfig = self.deviceConfig;
    return device;
}

- (NSString *)resolutionText {
    if (self.screenWidth <= 0 || self.screenHeight <= 0) {
        return @"-";
    }
    return [NSString stringWithFormat:@"%ld x %ld", (long)self.screenWidth, (long)self.screenHeight];
}

@end

@interface XTBleWriteHelper()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    NSString  *kWriteServerUUID;// 写服务UUID | Write Service UUID
    NSString  *kWriteCharacteristicUUID;// 写特征值UUID | Write Characteristic UUID
    NSString  *kNotifyCharacteristicUUID;// 通知特征值UUID | Notify Characteristic UUID
}

/* 操作类型（蓝牙写入的操作类型枚举） | Operation Type (BLE Write Operation Type Enum) */
@property(nonatomic, assign) XTBleWriteOperationType   currentOpType;

/* 写入数据（存储写入的十六进制数据数组，用于刷图等操作） | Write Data (Store hex data array for screen refresh/OTA) */
//side A - A面图像数据 | Side A Image Data
@property(nonatomic, strong) NSMutableArray            *brushDataHexArrA;
//side B - B面图像数据 | Side B Image Data
@property(nonatomic, strong) NSMutableArray            *brushDataHexArrB;

/* 写屏时硬件端的设备配置（存储写屏操作时硬件的配置信息） | Device Config (Store hardware config for screen write) */
@property(nonatomic, strong) XTDeviceConfig            *deviceConfig;

/* 需要刷图的MAC（记录需要执行刷图操作的设备MAC地址） | Target MAC (Record target device MAC for screen refresh) */
@property(nonatomic, copy)   NSString                  *writeMac;

/* 中央管理者（蓝牙中央管理器，负责设备的扫描、连接管理） | Central Manager (BLE central manager for scan/connection) */
@property(nonatomic, strong) CBCentralManager          *centralManager;

/* 已发现外设标志（标记是否已发现目标蓝牙外设） | Discovered Flag (Mark if target peripheral is discovered) */
@property(nonatomic, assign) BOOL                      hasDiscoveredPeripheral;

/* 蓝牙管理器状态（记录蓝牙中央管理器的状态：开启/关闭等） | Manager State (Record BLE central manager state) */
@property(nonatomic, assign) CBManagerState            peripheralState;

/* 当前连接的外设（记录当前正在连接或已连接的蓝牙外设） | Current Peripheral (Record connected/connecting BLE peripheral) */
@property(nonatomic, strong) CBPeripheral              *currentPeripheral;

/* 写入特征（用于向外设写入数据的蓝牙特征） | Write Characteristic (BLE characteristic for write data) */
@property(nonatomic, strong) CBCharacteristic          *writeCharacteristic;

/* 读取特征（用于从外设读取数据的蓝牙特征） | Read Characteristic (BLE characteristic for read data) */
@property(nonatomic, strong) CBCharacteristic          *readCharacteristic;

/* 总写入大小（需要写入的总数据量，单位：字节） | MTU Size (Total write data size per packet, unit: byte) */
@property(nonatomic, assign) NSInteger                 writeMtuSize;

/* 刷图数据包数组（存储需要执行刷图操作的十六进制数据包） | Screen Refresh Data (Store hex data packets for screen refresh) */
@property(nonatomic, strong) NSMutableArray            *writeScreenHexDataArr;

/* 补传数据包数组（存储需要重新补传的数据包，用于重传机制） | Retransmit Data (Store packets need retransmit for retry mechanism) */
@property(nonatomic, strong) NSMutableArray            *fixWriteScreenHexDataArr;

#pragma mark - 刷图参数 | Screen Refresh Parameters

/* 应答等待计时（等待硬件返回应答结果的计时或状态标记） | Response Wait (Wait for hardware response status) */
@property(nonatomic, assign) NSInteger                 waitAnswerRunning;

/* FLASH删除长度（刷新图片时需从设备FLASH删除的内容长度） | Flash Delete Length (Length to delete from device flash) */
@property(nonatomic, assign) NSInteger                 writeNeedFlashLen;

/* 蓝牙连接状态（记录蓝牙当前连接状态：未连接/连接中等） | BLE Connection State (0=disconnected, 1=connected) */
@property(nonatomic, assign) NSInteger                 bleConnectState;

/* 蓝牙连接次数（蓝牙连接尝试的累计次数） | BLE Connect Count (Total BLE connection attempts) */
@property(nonatomic, assign) NSInteger                 nBleConnectCount;

/* 扫描连接耗时（从开始扫描到成功连接的时间，单位：秒） | Scan Time (Time from scan start to connect success, unit: s) */
@property(nonatomic, assign) double                    scanDeviceTime;

/* 数据发送耗时（向设备发送数据的总时间，单位：秒） | Data Send Time (Total time for data transmission, unit: s) */
@property(nonatomic, assign) double                    deviceSendDataTime;

/* 刷图总耗时（完成整个刷图操作的总时间，单位：秒） | Total Screen Refresh Time (Total time for screen refresh, unit: s) */
@property(nonatomic, assign) double                    brushScreenTime;

/* 已断开连接标志（标记当前是否已与设备断开蓝牙连接） | Disconnected Flag (Mark if BLE is disconnected) */
@property(nonatomic, assign) BOOL                      ishadDisconnect;

/* 业务流程内主动断开标志，例如防丢器切换刷图模式 | Ignore expected disconnect, such as FindMy mode switch */
@property(nonatomic, assign) BOOL                      shouldIgnoreNextDisconnect;

/* 预期会主动断开的外设 | Peripheral expected to disconnect intentionally */
@property(nonatomic, strong) CBPeripheral              *expectedDisconnectPeripheral;

/* 扫描重试次数（扫描超时未发现设备时，最大重试3次） | Scan Retry Count (Max 3 retries for scan timeout) */
@property(nonatomic, assign) NSInteger                 scanRetryCount;

// 【新增】扫描超时任务Block（仅处理扫描超时） | Scan Timeout Block (Only for scan timeout)
@property(nonatomic, strong) dispatch_block_t          scanTimeoutBlock;
// 【新增】扫描超时任务队列（仅用于扫描超时） | Scan Timeout Queue (GCD queue for scan timeout)
@property(nonatomic, strong) dispatch_queue_t          scanTimeoutQueue;

/* 连接计数（累计的连接尝试次数，用于限制重试次数） | Connect Retry Count (Total connection retry attempts) */
@property(nonatomic, assign) NSInteger                 connectCount;

/* 连接超时任务句柄（处理蓝牙连接超时的任务Block） | Connect Timeout Block (Handle BLE connect timeout) */
@property(nonatomic, strong) dispatch_block_t          connectTimeoutBlock;

/* 超时任务队列（用于执行连接超时任务的GCD队列） | Connect Timeout Queue (GCD queue for connect timeout) */
@property(nonatomic, strong) dispatch_queue_t          connectTimeoutQueue;

// 服务发现超时任务 | Service Discover Timeout Block
@property(nonatomic, strong) dispatch_block_t          serviceDiscoverTimeoutBlock;
@property(nonatomic, strong) dispatch_queue_t          serviceDiscoverTimeoutQueue;

/* AdvertisementData回调 | Advertisement Data Callback Block */
@property(nonatomic, copy)   XTAdvertisementDataBack                advDataBlock;

@property(nonatomic, copy)   XTWriteImageBlock                      writeImageBlock;

/* 图片管理04指令参数 | Image storage 0x04 command params */
@property(nonatomic, strong) NSArray<NSNumber *>                    *imageStorageParamBytes;
@property(nonatomic, strong) NSArray<NSArray<NSNumber *> *>          *imageStorageCommandParamList;

/* 批量处理相关变量 | Batch Processing Variables */
@property (nonatomic, assign) NSInteger totalFlashDeleteLength;    /* 总Flash删除长度（所有批次总和） | Total Flash Delete Length (sum of all batches) */
@property (nonatomic, assign) NSInteger totalPackageCount;         /* 总数据包数（用于判断批量/非批量） | Total Package Count (judge batch/non-batch mode) */

/* AdvertisementData回调 | Scan Completion Callback Block */
@property(nonatomic, copy) XTScanDeviceCompletionBlock scanBlock;
@property(nonatomic, copy) XTScannedDeviceUpdateBlock scanListUpdateBlock;
@property(nonatomic, copy) XTScannedDeviceCompletionBlock scanListCompletionBlock;
@property(nonatomic, strong) NSMutableDictionary<NSString *, XTBleScannedDevice *> *scannedDeviceMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *scannedDeviceUpdateTimes;

@end

static BOOL EFIsBlankString(NSString *value) { return ![value isKindOfClass:NSString.class] || [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0; }

@implementation XTBleWriteHelper

#pragma mark - 单例方法 | Singleton Method
/**
 *  @brief 获取单例实例 | Get Singleton Instance
 *  @discussion 全局唯一的XTBleWriteHelper实例，确保蓝牙操作的统一管理
 *              Globally unique XTBleWriteHelper instance for unified BLE operation management
 *  @return 共享的XTBleWriteHelper实例 | Shared XTBleWriteHelper instance
 */
+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    static XTBleWriteHelper *bleHelper;
    dispatch_once(&onceToken, ^{
        bleHelper = [[XTBleWriteHelper alloc] init];
    });
    return bleHelper;
}

/**
 *  @brief 初始化方法 | Init Method
 *  @discussion 初始化蓝牙中央管理器，获取蓝牙服务/特征UUID
 *              Init BLE central manager and get service/characteristic UUIDs
 */
- (instancetype)init {
    if (self = [super init]) {
        //初始化蓝牙 | Init BLE central manager
        [self centralManager];
        // 获取服务UUID和通知/写特征码 | Get service/notify/write characteristic UUIDs
        kWriteServerUUID = [XTBleProtocol getBLEServiceUUID];
        kWriteCharacteristicUUID = [XTBleProtocol getBLEWriteCharacteristicUUID];
        kNotifyCharacteristicUUID = [XTBleProtocol getBLENotifyCharacteristicUUID];
    }
    return self;
}

//MARK: ============================ 入口方法 | Entry Methods ============================

/**
 *  @brief 根据MAC地址扫描指定蓝牙设备 | Scan Specified BLE Device by MAC Address
 *  @param targetMac 目标设备的MAC地址 | Target device MAC address
 *  @param completion 扫描完成后的回调Block | Completion block after scan
 */
- (void)startScanWithTargetMac:(NSString *)targetMac
                    completion:(XTScanDeviceCompletionBlock)completion {
    NSString *rawMac = targetMac ?: @"";
    NSString *normalizedMac = [[[rawMac componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""]
                               uppercaseString];
    normalizedMac = [[[normalizedMac stringByReplacingOccurrencesOfString:@":" withString:@""]
                      stringByReplacingOccurrencesOfString:@"：" withString:@""]
                     stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (normalizedMac.length == 0) {
        NSError *error = [NSError errorWithDomain:@"BleScanError" code:-100 userInfo:@{NSLocalizedDescriptionKey:XTLS(@"XT_Target_MAC_Empty")}];
        if (completion) {
            completion(nil, error);
        }
        return;
    }
    _isWorking = YES;
    _writeMac = normalizedMac;
    _currentOpType = XTBleWriteOperationTypeSacn;
    _scanRetryCount = 0;
    _scanBlock = completion;

    [self startScanPeripherals];
}

- (void)scanAvailableDevicesWithUpdate:(XTScannedDeviceUpdateBlock)update
                            completion:(XTScannedDeviceCompletionBlock)completion {
    [self disconnectCurrentPeripherals];
    _isWorking = YES;
    _currentOpType = XTBleWriteOperationTypeListScan;
    _scanRetryCount = 0;
    _hasDiscoveredPeripheral = NO;
    _scanListUpdateBlock = update;
    _scanListCompletionBlock = completion;
    _scannedDeviceMap = [NSMutableDictionary dictionary];
    _scannedDeviceUpdateTimes = [NSMutableDictionary dictionary];
    [self startScanPeripherals];
}

/**
 *  @brief 导入单面板图像数据到设备（写屏+刷屏操作） | Import Single-panel Image Data to Device
 *  @param imageHexDataArr 图像数据的十六进制分包数组 | Hex packet array of image data
 *  @param deviceConfig 写屏时的设备配置信息 | Device config for screen write
 *  @param sendSize 每次发送的分包大小 | Packet size per transmission
 *  @param writeImageBlock 写图操作完成后的回调 | Completion block after write image
 *  @param advData 蓝牙广播数据回调 | BLE advertisement data callback
 */
- (void)importImageDataToDeviceWithImageHexDataArr:(NSMutableArray *)imageHexDataArr
                                      deviceConfig:(XTDeviceConfig *)deviceConfig
                                          sendSize:(NSInteger)sendSize
                                   writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                           advData:(XTAdvertisementDataBack)advData {
    if(!imageHexDataArr || imageHexDataArr.count == 0){
        return ;
    }
    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        return;
    }
    if (![deviceConfig isSupportedBindingDevice]) {
        if (writeImageBlock) {
            writeImageBlock(NO, XTLS(@"XT_Unsupported_Device"));
        }
        return;
    }
    _currentOpType = XTBleWriteOperationTypeWriteScreen;
    _brushDataHexArrA = imageHexDataArr;
    _advDataBlock = advData;

    _deviceConfig = deviceConfig;
    _writeMac = deviceConfig.uuID;
    _writeMtuSize = sendSize;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _isWorking = YES;
    _writeImageBlock = writeImageBlock;
    [self beginTidyUpBrushData];
}

/**
 *  @brief 导入双面图像数据到设备（写屏+刷屏操作） | Import Dual-panel Image Data to Device
 *  @param hexDataArrA A面图像数据的十六进制分包数组 | Hex packet array of side A image data
 *  @param hexDataArrB B面图像数据的十六进制分包数组 | Hex packet array of side B image data
 *  @param deviceConfig 写屏时的设备配置信息 | Device config for screen write
 *  @param sendSize 每次发送的分包大小 | Packet size per transmission
 *  @param writeImageBlock 写图操作完成后的回调 | Completion block after write image
 *  @param advData 蓝牙广播数据回调 | BLE advertisement data callback
 */
- (void)importImageDataToDeviceWithImageHexDataArrA:(NSMutableArray *)hexDataArrA
                                        hexDataArrB:(NSMutableArray *)hexDataArrB
                                       deviceConfig:(XTDeviceConfig *)deviceConfig
                                           sendSize:(NSInteger)sendSize
                                    writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                            advData:(nullable XTAdvertisementDataBack)advData {
    // 参数校验 | Parameter validation
    if ((hexDataArrA.count == 0) && (hexDataArrB.count == 0)) {
        [self pushDaskDetail:XTLS(@"XT_Image_Data_Empty") done:YES sucesss:NO];
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Image_Data_Empty"));
        return;
    }
    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Device_Empty"));
        return;
    }
    if (![deviceConfig isSupportedBindingDevice]) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Unsupported_Device"));
        return;
    }
    _currentOpType = XTBleWriteOperationTypeWriteScreen;
    _deviceConfig = deviceConfig;

    _brushDataHexArrA = hexDataArrA;
    _brushDataHexArrB = hexDataArrB;

    _writeMac = deviceConfig.uuID;
    _writeMtuSize = sendSize;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _isWorking = YES;
    _writeImageBlock = writeImageBlock;
    _advDataBlock = advData;
    [self pushDaskDetail:XTLS(@"XT_Processing_Image") done:NO sucesss:NO];
    [self beginTidyUpBrushData];
}

/**
 *  @brief 导入OTA升级数据到设备（OTA操作） | Import OTA Update Data to Device
 *  @param otaHexData OTA数据的十六进制分包数组 | Hex packet array of OTA data
 *  @param deviceConfig 设备配置信息 | Device config info
 *  @param sendSize 每次发送的分包大小 | Packet size per transmission
 */
- (void)importOTADataToDeviceWithOtaHexData:(NSMutableArray *)otaHexData
                               deviceConfig:(XTDeviceConfig *)deviceConfig
                                   sendSize:(NSInteger)sendSize {
    if(!otaHexData || otaHexData.count == 0){
        return ;
    }

    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        return;
    }

    _currentOpType = XTBleWriteOperationTypeOTA;
    _brushDataHexArrA = otaHexData;
    _deviceConfig = deviceConfig;
    _writeMac = deviceConfig.uuID;
    _writeMtuSize = sendSize;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _isWorking = YES;
    [self beginTidyUpBrushData];
}

/**
 *  @brief 图片管理：写入指定图片槽位 | Image storage: write specified image slot
 */
- (void)importImageStorageDataToDeviceWithImageHexDataArr:(NSMutableArray *)imageHexDataArr
                                             deviceConfig:(XTDeviceConfig *)deviceConfig
                                                 sendSize:(NSInteger)sendSize
                                               imageIndex:(NSInteger)imageIndex
                                              refreshFlag:(XTImageStorageRefreshFlag)refreshFlag
                                                    param:(NSInteger)param
                                          writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                                  advData:(nullable XTAdvertisementDataBack)advData {
    if(!imageHexDataArr || imageHexDataArr.count == 0){
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Image_Data_Empty"));
        return;
    }
    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Device_Empty"));
        return;
    }
    if (![deviceConfig isSupportedBindingDevice]) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Unsupported_Device"));
        return;
    }
    NSInteger safeIndex = MIN(MAX(imageIndex, 1), 6);
    NSInteger safeParam = MIN(MAX(param, 0), 255);
    _currentOpType = XTBleWriteOperationTypeImageStorageWrite;
    _brushDataHexArrA = imageHexDataArr;
    _brushDataHexArrB = nil;
    _imageStorageParamBytes = [self imageStorageParamBytesWithImageIndex:safeIndex
                                                              refreshFlag:refreshFlag
                                                                    param:safeParam];
    _imageStorageCommandParamList = nil;
    _advDataBlock = advData;

    _deviceConfig = deviceConfig;
    _writeMac = deviceConfig.uuID;
    _writeMtuSize = sendSize;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _isWorking = YES;
    _writeImageBlock = writeImageBlock;
    [self pushDaskDetail:XTLS(@"XT_Processing_Image_Manager_Data") done:NO sucesss:NO];
    [self beginTidyUpBrushData];
}

/**
 *  @brief 图片管理：删除指定图片槽位 | Image storage: delete specified slots
 */
- (void)deleteImageStorageSlotsWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                                   imageIndexes:(NSArray<NSNumber *> *)imageIndexes
                                writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                        advData:(nullable XTAdvertisementDataBack)advData {
    NSMutableArray<NSArray<NSNumber *> *> *commands = [NSMutableArray array];
    for (NSNumber *indexNumber in imageIndexes) {
        NSInteger index = indexNumber.integerValue;
        if (index == 0) {
            [commands addObject:@[@0, @(XTImageStorageRefreshFlagDelete)]];
            break;
        }
        if (index < 1 || index > 6) {
            continue;
        }
        [commands addObject:@[@(index), @(XTImageStorageRefreshFlagDelete)]];
    }
    if (commands.count == 0) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Select_Delete_Image"));
        return;
    }
    [self startImageStorageCommandWithDeviceConfig:deviceConfig
                                      commandParam:commands
                                   writeImageBlock:writeImageBlock
                                           advData:advData];
}

- (NSArray<NSNumber *> *)imageStorageParamBytesWithImageIndex:(NSInteger)imageIndex
                                                  refreshFlag:(XTImageStorageRefreshFlag)refreshFlag
                                                        param:(NSInteger)param {
    if (refreshFlag == XTImageStorageRefreshFlagCarousel ||
        refreshFlag == XTImageStorageRefreshFlagSchedule) {
        return @[@(imageIndex), @(refreshFlag), @(param)];
    }
    return @[@(imageIndex), @(refreshFlag)];
}

/**
 *  @brief 图片管理：更新轮播配置 | Image storage: update carousel config
 */
- (void)updateImageStorageCarouselWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                                        startIndex:(NSInteger)startIndex
                                   intervalMinutes:(NSInteger)intervalMinutes
                                   writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                           advData:(nullable XTAdvertisementDataBack)advData {
    NSInteger safeIndex = MIN(MAX(startIndex, 1), 6);
    NSInteger safeInterval = MIN(MAX(intervalMinutes, 0), 255);
    NSArray *command = @[@(safeIndex), @(XTImageStorageRefreshFlagCarousel), @(safeInterval)];
    [self startImageStorageCommandWithDeviceConfig:deviceConfig
                                      commandParam:@[command]
                                   writeImageBlock:writeImageBlock
                                           advData:advData];
}

- (void)startImageStorageCommandWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                                    commandParam:(NSArray<NSArray<NSNumber *> *> *)commandParam
                                 writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                         advData:(nullable XTAdvertisementDataBack)advData {
    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Device_Empty"));
        return;
    }
    if (![deviceConfig isSupportedBindingDevice]) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Unsupported_Device"));
        return;
    }
    if (commandParam.count == 0) {
        if (writeImageBlock) writeImageBlock(NO, XTLS(@"XT_Image_Manager_Command_Empty"));
        return;
    }
    _currentOpType = XTBleWriteOperationTypeImageStorageCommand;
    _imageStorageCommandParamList = commandParam;
    _imageStorageParamBytes = nil;
    _deviceConfig = deviceConfig;
    _writeMac = deviceConfig.uuID;
    _writeMtuSize = 244;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _isWorking = YES;
    _writeImageBlock = writeImageBlock;
    _advDataBlock = advData;
    [self startScanPeripherals];
}

/**
 *  @brief 读取设备电量、信号强度等信息 | Read Device Power, RSSI and Other Info
 *  @param deviceConfig 当前设备配置 | Current device config
 *  @param advData 设备信息回调 | Device info callback block
 */
- (void)readPowerAndRssiWithDevice:(XTDeviceConfig *)deviceConfig
                           advData:(XTAdvertisementDataBack)advData {
    if (!deviceConfig || deviceConfig.uuID.length == 0) {
        advData(@"0",@"-",@"-");
        return;
    }
    _currentOpType = XTBleWriteOperationTypeReadInfo;
    _advDataBlock = advData;
    _deviceConfig = deviceConfig;
    _writeMac = deviceConfig.uuID;
    _hasDiscoveredPeripheral = NO;
    _ishadDisconnect = NO;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;
    _connectCount = 0;
    _nBleConnectCount = 0;
    _isWorking = YES;
    _writeMtuSize = 244;
    [self beginTidyUpBrushData];
}

//MARK:  ============================= 蓝牙扫描/管理 | BLE Scan/Management =============================
/**
 *  @brief 开始扫描蓝牙外设 | Start Scanning BLE Peripherals
 *  @discussion 停止之前的扫描，重置扫描状态，启动扫描超时任务
 *              Stop previous scan, reset scan state, start scan timeout task
 */
- (void)startScanPeripherals {
    _nBleConnectCount = 0;
    _scanDeviceTime = (long)[[NSDate date] timeIntervalSince1970];
    _hasDiscoveredPeripheral = NO;

    // 停止之前的扫描，避免重复扫描 | Stop previous scan to avoid duplicate
    [self.centralManager stopScan];
    if ([self shouldScanOnceWithoutRetry]) {
        DLog(@"准备扫描绑定设备：%@，超时时间：20秒", _writeMac);
    } else {
        DLog(@"准备扫描设备：%@，当前重试次数：%ld/3", _writeMac, (long)_scanRetryCount);
    }

    if (_currentOpType != XTBleWriteOperationTypeListScan) {
        [self showLoadingWithMsg:[self scanLoadingMessage]];
    }
    NSDictionary *scanOptions = _currentOpType == XTBleWriteOperationTypeListScan
        ? @{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}
        : nil;
    [self.centralManager scanForPeripheralsWithServices:nil options:scanOptions];
    [self startScanTimeout]; // 启动扫描超时任务 | Start scan timeout task
}

/**
 *  @brief 绑定页扫描只扫一次，连接流程保留重试 | Bind scan only once; connection flow keeps retry
 */
- (BOOL)shouldScanOnceWithoutRetry {
    return _currentOpType == XTBleWriteOperationTypeSacn
        || _currentOpType == XTBleWriteOperationTypeListScan;
}

- (NSString *)scanLoadingMessage {
    if ([self shouldScanOnceWithoutRetry]) {
        return XTLS(@"SearchingBT");
    }
    return _scanRetryCount == 0 ? XTLS(@"SearchingBT") : [NSString stringWithFormat:@"%@（%ld/3）", XTLS(@"SearchingBT"), _scanRetryCount + 1];
}

/**
 *  @brief 启动扫描超时任务 | Start Scan Timeout Task
 *  @discussion 绑定页20秒单次扫描；连接流程15秒超时后最多重试3次
 *              Bind scan once for 20s; connection flow retries up to 3 times after 15s timeout
 */
- (void)startScanTimeout {
    // 1. 先清理旧任务 | Clean old task first
    [self cleanScanTimeoutTask];

    // 2. 初始化扫描超时队列 | Init scan timeout queue
    if (!self.scanTimeoutQueue) {
        self.scanTimeoutQueue = dispatch_queue_create("com.xt.scanTimeout", DISPATCH_QUEUE_SERIAL);
    }

    // 3. 弱引用自身 | Weak reference to self
    __weak typeof(self) weakSelf = self;
    // 4. 定义扫描超时任务 | Define scan timeout task
    self.scanTimeoutBlock = dispatch_block_create(0, ^{
        if (dispatch_block_testcancel(self.scanTimeoutBlock)) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.isWorking) return;

            if (strongSelf.currentOpType == XTBleWriteOperationTypeListScan) {
                XTScannedDeviceCompletionBlock completion = strongSelf.scanListCompletionBlock;
                NSArray<XTBleScannedDevice *> *snapshot = nil;
                @synchronized (strongSelf.scannedDeviceMap) {
                    snapshot = strongSelf.scannedDeviceMap.allValues;
                }
                NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(XTBleScannedDevice *device, NSDictionary<NSString *,id> *bindings) {
                    (void)bindings;
                    return device.mac.length > 0;
                }];
                NSArray<XTBleScannedDevice *> *devices = [[snapshot filteredArrayUsingPredicate:predicate] sortedArrayUsingComparator:^NSComparisonResult(XTBleScannedDevice *left, XTBleScannedDevice *right) {
                    return [left.mac compare:right.mac options:NSCaseInsensitiveSearch];
                }];
                [strongSelf cleanScanTimeoutTask];
                [strongSelf.centralManager stopScan];
                strongSelf.scanRetryCount = 0;
                strongSelf.isWorking = NO;
                strongSelf.scanListUpdateBlock = nil;
                strongSelf.scanListCompletionBlock = nil;

                if (completion) {
                    completion(devices, nil);
                }
                return;
            }

            // 超时未发现设备，执行重试逻辑 | Retry if timeout
            if (!strongSelf.hasDiscoveredPeripheral) {
                DLog(@"扫描超时，设备：%@，当前重试次数：%ld", strongSelf.writeMac, (long)strongSelf.scanRetryCount);
                [strongSelf.centralManager stopScan];

                if ([strongSelf shouldScanOnceWithoutRetry]) {
                    XTScanDeviceCompletionBlock completion = strongSelf.scanBlock;
                    NSError *error = [NSError errorWithDomain:@"BleScanError"
                                                         code:-11
                                                     userInfo:@{NSLocalizedDescriptionKey: XTLS(@"NoDeviceFound")}];
                    [strongSelf cleanScanTimeoutTask];
                    strongSelf.scanRetryCount = 0;
                    strongSelf.isWorking = NO;
                    strongSelf.scanBlock = nil;

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(nil, error);
                        }
                    });
                    return;
                }

                strongSelf.scanRetryCount++;
                if (strongSelf.scanRetryCount < 3) {
                    DLog(@"重试扫描设备：%@，重试次数：%ld/3", strongSelf.writeMac, (long)strongSelf.scanRetryCount);
                    [strongSelf showLoadingWithMsg:[strongSelf scanLoadingMessage]];
                    [strongSelf.centralManager scanForPeripheralsWithServices:nil options:nil];
                    [strongSelf startScanTimeout]; // 重新启动扫描超时任务 | Restart scan timeout
                } else {
                    XTScanDeviceCompletionBlock completion = strongSelf.scanBlock;
                    NSError *error = [NSError errorWithDomain:@"BleScanError"
                                                         code:-11
                                                     userInfo:@{NSLocalizedDescriptionKey: XTLS(@"NoDeviceFound")}];
                    [strongSelf cleanScanTimeoutTask];
                    [strongSelf.centralManager stopScan];
                    strongSelf.scanRetryCount = 0;
                    strongSelf.isWorking = NO;
                    strongSelf.scanBlock = nil;

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(nil, error);
                        }
                    });
                }
            } else {
                // 已发现设备，清理扫描超时任务 | Clean timeout task if device found
                [strongSelf cleanScanTimeoutTask];
            }
        });
    });

    NSTimeInterval timeout = [self shouldScanOnceWithoutRetry] ? 20.0 : 15.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), self.scanTimeoutQueue, self.scanTimeoutBlock);
}

/**
 *  @brief 清理扫描超时任务 | Clean Scan Timeout Task
 *  @discussion 取消并释放扫描超时Block和队列
 *              Cancel and release scan timeout block/queue
 */
- (void)cleanScanTimeoutTask {
    if (self.scanTimeoutBlock) {
        if (dispatch_block_testcancel(self.scanTimeoutBlock) == 0) {
            dispatch_block_cancel(self.scanTimeoutBlock);
        }
        self.scanTimeoutBlock = nil;
    }
}

/**
 *  @brief 连接指定蓝牙外设 | Connect to Specified BLE Peripheral
 *  @param peripheral 目标蓝牙外设 | Target BLE peripheral
 */
- (void)connectBleWithPeripheral:(CBPeripheral *)peripheral {
    [self showLoadingWithMsg:[NSString stringWithFormat:@"%@%@",XTLS(@"ConnectingBT"),_connectCount == 0 ? @"" : [NSString stringWithFormat:@" - %ld",_connectCount]]];
    _hasDiscoveredPeripheral = YES;
    // 打印日志 | Print log
    DLog(@"Scanning stopped because a peripheral was discovered.");

    // 停止扫描 | Stop scan
    [self.centralManager stopScan];
    // 停止扫描并清理超时任务 | Stop scan and clean timeout task
    [self cleanScanTimeoutTask];
    self.scanRetryCount = 0;

    NSDictionary *connectOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey : @YES,
                                     CBConnectPeripheralOptionNotifyOnDisconnectionKey : @YES,
                                     CBConnectPeripheralOptionNotifyOnNotificationKey : @YES};

    self.currentPeripheral = peripheral;
    DLog(@"connectPeripheral: %@",peripheral);
    [self.centralManager connectPeripheral:peripheral options:connectOptions];

    [self startConnectTimeoutWithPeripheral:peripheral];
}

/**
 *  @brief 启动连接超时任务 | Start Connect Timeout Task
 *  @param peripheral 目标蓝牙外设 | Target BLE peripheral
 *  @discussion 15秒连接超时则重试，最多重试3次
 *              Retry if connect timeout in 15s, max 3 retries
 */
- (void)startConnectTimeoutWithPeripheral:(CBPeripheral *)peripheral {
    // 1. 清理旧连接超时任务 | Clean old connect timeout task
    [self cleanConnectTimeoutTask];

    // 2. 初始化连接超时队列 | Init connect timeout queue
    if (!self.connectTimeoutQueue) {
        self.connectTimeoutQueue = dispatch_queue_create("com.xt.connectTimeout", DISPATCH_QUEUE_SERIAL);
    }

    // 3. 弱引用自身 | Weak reference to self
    __weak typeof(self) weakSelf = self;
    // 4. 定义连接超时任务 | Define connect timeout task
    self.connectTimeoutBlock = dispatch_block_create(0, ^{
        if (dispatch_block_testcancel(self.connectTimeoutBlock)) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.isWorking) return;

            // 超时未连接成功 | Timeout if not connected
            if (strongSelf.currentPeripheral && strongSelf.currentPeripheral.state == CBPeripheralStateConnecting) {
                [strongSelf disconnectCurrentPeripherals];
                if (strongSelf.connectCount < 3) {
                    [strongSelf connectBleWithPeripheral:peripheral];
                    DLog(@"连接重试次数: %ld",(long)strongSelf.connectCount);
                    strongSelf.connectCount ++;
                } else {
                    strongSelf.connectCount = 0;
                    [strongSelf alertMsg:XTLS(@"Bluetooth Connection timed out")];
                }
            } else {
                // 已连接或断开，清理任务 | Clean task if connected/disconnected
                [strongSelf cleanConnectTimeoutTask];
            }
        });
    });

    // 5. 延迟15秒执行 | Execute after 15s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), self.connectTimeoutQueue, self.connectTimeoutBlock);
}

/**
 *  @brief 清理连接超时任务 | Clean Connect Timeout Task
 *  @discussion 取消并释放连接超时Block和队列
 *              Cancel and release connect timeout block/queue
 */
- (void)cleanConnectTimeoutTask {
    if (self.connectTimeoutBlock) {
        if (dispatch_block_testcancel(self.connectTimeoutBlock) == 0) {
            dispatch_block_cancel(self.connectTimeoutBlock);
        }
        self.connectTimeoutBlock = nil;
    }
}

/**
 *  @brief 启动服务发现超时任务 | Start Service Discover Timeout Task
 *  @param peripheral 目标蓝牙外设 | Target BLE peripheral
 *  @discussion 5秒服务发现超时则断开重连，最多重试1次
 *              Disconnect and retry if service discover timeout in 5s, max 1 retry
 */
- (void)startServiceDiscoverTimeoutWithPeripheral:(CBPeripheral *)peripheral {
    // 先清理旧任务 | Clean old task first
    [self cleanServiceDiscoverTimeoutTask];

    if (!self.serviceDiscoverTimeoutQueue) {
        self.serviceDiscoverTimeoutQueue = dispatch_queue_create("com.xt.serviceDiscoverTimeout", DISPATCH_QUEUE_SERIAL);
    }

    __weak typeof(self) weakSelf = self;
    self.serviceDiscoverTimeoutBlock = dispatch_block_create(0, ^{
        if (dispatch_block_testcancel(self.serviceDiscoverTimeoutBlock)) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.isWorking) return;

            // 超时未发现服务，断开重连 | Disconnect and retry if timeout
            DLog(@"服务扫描超时（5秒），设备：%@", peripheral.name);
            [strongSelf disconnectCurrentPeripherals];
            [strongSelf alertMsg:XTLS(@"XT_BLE_Service_Scan_Timeout")];

            // 重试扫描连接（最多1次） | Retry scan/connect (max 1 time)
            if (strongSelf.connectCount < 1) {
                strongSelf.connectCount++;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [strongSelf startScanPeripherals];
                });
            }
        });
    });

    // 5秒后执行超时逻辑 | Execute after 5s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), self.serviceDiscoverTimeoutQueue, self.serviceDiscoverTimeoutBlock);
}

/**
 *  @brief 清理服务发现超时任务 | Clean Service Discover Timeout Task
 */
- (void)cleanServiceDiscoverTimeoutTask {
    if (self.serviceDiscoverTimeoutBlock) {
        if (dispatch_block_testcancel(self.serviceDiscoverTimeoutBlock) == 0) {
            dispatch_block_cancel(self.serviceDiscoverTimeoutBlock);
        }
        self.serviceDiscoverTimeoutBlock = nil;
    }
}

- (BOOL)isReadyToSendBleData {
    return _isWorking &&
           _bleConnectState == 1 &&
           _currentPeripheral &&
           _currentPeripheral.state == CBPeripheralStateConnected &&
           _writeCharacteristic;
}

- (void)runOnMainThread:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)notifyWriteImageCompletionWithSuccess:(BOOL)success error:(NSString *)error {
    XTWriteImageBlock block = _writeImageBlock;
    if (!block) {
        return;
    }
    [self runOnMainThread:^{
        block(success, error);
    }];
}

- (void)finishCurrentOperationWithBleDisconnected {
    BOOL shouldNotify = _isWorking;
    NSString *message = XTLS(@"XT_BleDisconnected");

    _isWorking = NO;
    _bleConnectState = 0;
    _waitAnswerRunning = XTBleSendResultDisconnected;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;

    [self.centralManager stopScan];
    [self cleanScanTimeoutTask];
    [self cleanConnectTimeoutTask];
    [self cleanServiceDiscoverTimeoutTask];

    if (_currentPeripheral) {
        CBPeripheral *peripheral = _currentPeripheral;
        peripheral.delegate = nil;
        if (_centralManager &&
            (peripheral.state == CBPeripheralStateConnected ||
             peripheral.state == CBPeripheralStateConnecting ||
             peripheral.state == CBPeripheralStateDisconnecting)) {
            [_centralManager cancelPeripheralConnection:peripheral];
        }
    }

    _currentPeripheral = nil;
    _writeCharacteristic = nil;
    _readCharacteristic = nil;

    if (!shouldNotify) {
        return;
    }

    DLog(@"ble operation stopped because device disconnected");
    if (_currentOpType == XTBleWriteOperationTypeWriteScreen ||
        _currentOpType == XTBleWriteOperationTypeImageStorageWrite ||
        _currentOpType == XTBleWriteOperationTypeImageStorageCommand) {
        [self notifyWriteImageCompletionWithSuccess:NO error:message];
    }
    [self alertMsg:message];
}

/**
 *  @brief 断开当前已连接的蓝牙外设 | Disconnect Current Connected BLE Peripheral
 *  @discussion 清理所有超时任务，重置蓝牙状态
 *              Clean all timeout tasks and reset BLE state
 */
- (void)disconnectCurrentPeripherals {
    _bleConnectState = 0;
    _waitAnswerRunning = XTBleSendResultDisconnected;
    _shouldIgnoreNextDisconnect = NO;
    _expectedDisconnectPeripheral = nil;

    if (_centralManager) {
        [self.centralManager stopScan];
    }

    if (_centralManager && _currentPeripheral && _currentPeripheral.state == CBPeripheralStateConnected) {
        [self.centralManager cancelPeripheralConnection:_currentPeripheral];
        _currentPeripheral = nil;
    }

    // 【修改】清理所有超时任务 | Clean all timeout tasks
    [self cleanScanTimeoutTask];
    [self cleanConnectTimeoutTask];

    // 重置所有状态 | Reset all states
    _advDataBlock = nil;
    _scanBlock = nil;
    _scanListUpdateBlock = nil;
    _scanListCompletionBlock = nil;
    _scannedDeviceMap = nil;
    _scannedDeviceUpdateTimes = nil;
    _imageStorageParamBytes = nil;
    _imageStorageCommandParamList = nil;
    _scanRetryCount = 0;
    _connectCount = 0;
    _isWorking = NO;
}

//MARK: ============================ 蓝牙代理 | BLE Delegate Methods ============================
//MARK: CBCentralManagerDelegate
/**
 *  @brief 蓝牙开关状态更新时调用 | Called when BLE manager state updated
 *  @param central 蓝牙中央管理器 | BLE central manager
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    NSString *message = @"";
    switch (central.state) {
        case CBManagerStateUnknown:{
            message = XTLS(@"XT_unkonwState");
            self.peripheralState = central.state;
            [self alertMsg:message];
        }
            break;
        case CBManagerStateResetting:{
            message = XTLS(@"XT_resetState");
            self.peripheralState = central.state;
            [self alertMsg:message];
        }
            break;
        case CBManagerStateUnsupported:{
            message = XTLS(@"XT_UnsupportedState");
            self.peripheralState = central.state;
            [self alertMsg:message];
        }
            break;
        case CBManagerStateUnauthorized:{
            message = XTLS(@"XT_UnauthorizedState");
            self.peripheralState = central.state;
            [self alertMsg:message];
        }
            break;
        case CBManagerStatePoweredOff:{
            message = XTLS(@"XT_ClosedState");
            self.peripheralState = central.state;
            [self alertMsg:message];
        }
            break;
        case CBManagerStatePoweredOn:{
            message = XTLS(@"XT_AvailableState");
            self.peripheralState = central.state;
        }
            break;
        default:
            message = XTLS(@"XT_OtherState");
            [self alertMsg:message];
            break;
    }

    if (self.peripheralState == CBManagerStatePoweredOn && _isWorking == YES) {
        if (_currentOpType != XTBleWriteOperationTypeListScan) {
            [self showLoadingWithMsg:[self scanLoadingMessage]];
        }
        NSDictionary *scanOptions = _currentOpType == XTBleWriteOperationTypeListScan
            ? @{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}
            : nil;
        [self.centralManager scanForPeripheralsWithServices:nil options:scanOptions];
    }
}

/**
 *  @brief 扫描到蓝牙外设时调用 | Called when BLE peripheral is discovered
 *  @param central 蓝牙中央管理器 | BLE central manager
 *  @param peripheral 扫描到的外设 | Discovered peripheral
 *  @param advertisementData 广播数据 | Advertisement data
 *  @param RSSI 信号强度 | Signal strength
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (!peripheral) return;

    if (_currentOpType == XTBleWriteOperationTypeListScan) {
        [self handleListScanAdvertisementData:advertisementData peripheral:peripheral RSSI:RSSI];
        return;
    }

    if (_currentOpType ==  XTBleWriteOperationTypeSacn) {
        XTWeakSelf
        // 确保在主线程处理回调（避免UI操作异常）| Ensure callback in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleAdvertisementData:advertisementData peripheral:peripheral];
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *mac = [XTBleProtocol getDeviceBleInfoFromCBAdvDataManufacturerData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]][@"MAC"];
        NSString *mac1 = [advertisementData objectForKey:@"kCBAdvDataLocalName"] ;
        NSString *nameMac = [XTBleProtocol getBleMacFromCBAdvDataLocalName:mac1];

        //        DLog(@"mac ======== : %@ -- %@",mac,_writeMac);//35380900B0B7
        NSString *targetLower = [_writeMac lowercaseString];

        if ([mac isEqualToString:_writeMac] || [mac1 isEqualToString:_writeMac] || [nameMac isEqualToString:_writeMac] || [mac isEqualToString:targetLower] || [mac1 isEqualToString:targetLower] || [nameMac isEqualToString:targetLower]) {
            [self.centralManager stopScan];
            [self cleanScanTimeoutTask];

            DLog(@"had found current device mac: %@ \r\n LowerMac: %@ \r\n advertisementData: %@ \r\n RSSI: %@",_writeMac,targetLower, advertisementData, RSSI);

            DLog(@"mac ======== : mac %@ -- mac1 %@ -- nameMac%@ -- omac%@",mac,mac1,nameMac,_writeMac);//35380900B0B7

            NSString *ver = [XTBleProtocol getVersionFromCBAdvDataManufacturerData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]];
            DLog(@"current version = %@", ver);

            NSDictionary *advDict = [XTBleProtocol getDeviceBleInfoFromCBAdvDataManufacturerData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]];
            DLog(@"current advDict = %@ = %@", advDict,[advertisementData objectForKey:@"kCBAdvDataManufacturerData"]);

            NSString *battery = [NSString stringWithFormat:@"%@",advDict[@"battery"]];
            NSString *rssiStr = RSSI ? RSSI.stringValue : XTLS(@"XT_C_UNKOWN");
            DLog(@"read power: %@ - %@",advDict[@"battery"],_deviceConfig.power);

            _deviceConfig.version = ver;
            _deviceConfig.power = !EFIsBlankString( battery) ? battery : @"";
            [XTDeviceConfig saveLocalCfg:_deviceConfig];

            if (_advDataBlock) {
                _advDataBlock(rssiStr,_deviceConfig.power,ver);
            }

            if (_currentOpType == XTBleWriteOperationTypeReadInfo) { //读到信息了，断开连接 | Disconnect after read info
                [self disconnectCurrentPeripherals];
                return;
            }
            [self checkBattery:_deviceConfig.power peripheral:peripheral];
        }
    });
}

- (void)handleListScanAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData
                             peripheral:(CBPeripheral *)peripheral
                                   RSSI:(NSNumber *)RSSI {
    if (_currentOpType != XTBleWriteOperationTypeListScan || !self.isWorking) {
        return;
    }
    if (RSSI.integerValue == 128 || RSSI.integerValue == 127) {
        return;
    }

    NSString *rawLocalName = [self safeStringFromObject:advertisementData[CBAdvertisementDataLocalNameKey]];
    NSString *localName = rawLocalName.length > 0 ? rawLocalName : [self safeStringFromObject:peripheral.name];
    NSString *localNameUpper = [localName uppercaseString];

    NSData *manufacturerData = advertisementData[@"kCBAdvDataManufacturerData"];
    NSDictionary *deviceDict = [XTBleProtocol getDeviceBleInfoFromCBAdvDataManufacturerData:manufacturerData];
    NSString *advMac = [self normalizedMacAddressFromString:deviceDict[@"MAC"]];
    NSString *nameMac = [self normalizedMacAddressFromString:[XTBleProtocol getBleMacFromCBAdvDataLocalName:localNameUpper ?: @""]];
    NSString *localNameMac = [self normalizedMacAddressFromString:localNameUpper];

    NSString *finalMac = nameMac.length > 0 ? nameMac : (advMac.length > 0 ? advMac : localNameMac);
    if (EFIsBlankString(finalMac)) {
        return;
    }

    NSString *key = finalMac;
    XTBleScannedDevice *callbackDevice = nil;
    @synchronized (self.scannedDeviceMap) {
        XTBleScannedDevice *device = self.scannedDeviceMap[key];
        BOOL isNewDevice = device == nil;
        if (!device) {
            device = [[XTBleScannedDevice alloc] init];
            device.mac = finalMac;
            device.deviceName = localName.length > 0 ? localName : peripheral.name;
            device.deviceNumber = 0;
            device.colorText = XTLS(@"XT_Pending_Screen");
            device.supported = YES;
            device.supportMessage = XTLS(@"XT_Select_Screen");
            self.scannedDeviceMap[key] = device;
        }

        NSString *newRssi = RSSI.stringValue ?: @"-";
        NSInteger oldRssiValue = device.rssi.integerValue;
        NSInteger newRssiValue = newRssi.integerValue;
        NSDate *lastUpdateDate = self.scannedDeviceUpdateTimes[key];
        BOOL rssiChanged = ![device.rssi isEqualToString:newRssi];
        BOOL shouldUpdateRssi = isNewDevice
            || (rssiChanged && (ABS(oldRssiValue - newRssiValue) >= 4
                                || !lastUpdateDate
                                || [[NSDate date] timeIntervalSinceDate:lastUpdateDate] >= 1.0));
        if (!shouldUpdateRssi) {
            return;
        }

        device.rssi = newRssi;
        if (device.deviceName.length == 0) {
            device.deviceName = localName.length > 0 ? localName : peripheral.name;
        }
        self.scannedDeviceUpdateTimes[key] = [NSDate date];
        callbackDevice = [device copy];
    }

    if (callbackDevice && self.scanListUpdateBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentOpType == XTBleWriteOperationTypeListScan && self.scanListUpdateBlock) {
                self.scanListUpdateBlock(callbackDevice);
            }
        });
    }
}

- (void)resolveScannedDeviceConfig:(XTBleScannedDevice *)device {
    if (!device || EFIsBlankString(device.mac)) {
        return;
    }

    @synchronized (self.scannedDeviceMap) {
        XTBleScannedDevice *storedDevice = self.scannedDeviceMap[device.mac];
        storedDevice.supported = YES;
        storedDevice.supportMessage = XTLS(@"XT_Select_Screen");
        storedDevice.colorText = XTLS(@"XT_Pending_Screen");
    }
}

- (NSString *)displayColorTextForDeviceConfig:(XTDeviceConfig *)deviceConfig {
    if (!deviceConfig) {
        return @"-";
    }
    NSString *colorName = [deviceConfig.screenColorName stringByReplacingOccurrencesOfString:@"FM_C_" withString:@""];
    if (!EFIsBlankString(colorName)) {
        return colorName;
    }
    if (!EFIsBlankString(deviceConfig.screenColorCode)) {
        return deviceConfig.screenColorCode;
    }
    return @"-";
}

- (NSString *)safeStringFromObject:(id)object {
    if (!object || [object isKindOfClass:NSNull.class]) {
        return @"";
    }
    if ([object isKindOfClass:NSString.class]) {
        return [(NSString *)object stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([object respondsToSelector:@selector(stringValue)]) {
        return [[object stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return [[NSString stringWithFormat:@"%@", object] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (BOOL)isValidHexMacAddressFlexible:(NSString *)string {
    if (EFIsBlankString(string)) {
        return NO;
    }

    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    NSString *cleanedString = [[string componentsSeparatedByCharactersInSet:hexSet.invertedSet] componentsJoinedByString:@""];
    return cleanedString.length >= 12;
}

- (NSString *)normalizedMacAddressFromString:(id)object {
    NSString *string = [self safeStringFromObject:object];
    if (EFIsBlankString(string)) {
        return @"";
    }

    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    NSString *cleanedString = [[string componentsSeparatedByCharactersInSet:hexSet.invertedSet] componentsJoinedByString:@""];
    if (cleanedString.length < 12) {
        return @"";
    }
    return [[cleanedString substringToIndex:12] uppercaseString];
}

/**
 *  @brief 处理蓝牙广播数据 | Handle BLE Advertisement Data
 *  @param advertisementData 广播数据 | Advertisement data
 *  @param peripheral 蓝牙外设 | BLE peripheral
 */
- (void)handleAdvertisementData:(NSDictionary<NSString *,id> *)advertisementData peripheral:(CBPeripheral *)peripheral {
    // 1. 从广播解析设备信息 | Parse device info from advertisement data
    NSData *manufacturerData = advertisementData[@"kCBAdvDataManufacturerData"];
    NSDictionary *deviceDict = [XTBleProtocol getDeviceBleInfoFromCBAdvDataManufacturerData:manufacturerData];
    NSString *advMac = [deviceDict[@"MAC"] uppercaseString]; // 统一大写处理 | Unified uppercase
    DLog(@"扫描到设备，解析的MAC：%@，目标MAC：%@ %@", advMac, self.writeMac,deviceDict);

    // 2. 第一种匹配：通过制造商数据中的MAC匹配 | Match by MAC in manufacturer data
    if (!EFIsBlankString(advMac) && [advMac isEqualToString:self.writeMac]) {
        [self processMatchedDeviceWithDeviceDict:deviceDict peripheral:peripheral];
        return;
    }

    // 3. 第二种匹配： 从本地名称解析MAC | Match by MAC parsed from local name
    NSString *localName = [advertisementData[@"kCBAdvDataLocalName"] uppercaseString];
    if (EFIsBlankString(localName)) {
        DLog(@"设备本地名称为空，跳过匹配 | Device local name is empty, skip match");
        return;
    }

    // 从本地名称解析 MAC | Parse MAC from local name
    NSString *nameMac = [XTBleProtocol getBleMacFromCBAdvDataLocalName:localName];
    BOOL isBaiRui = !EFIsBlankString(nameMac)
    && [nameMac isEqualToString:self.writeMac];
    BOOL isNamemac = [localName isEqualToString:self.writeMac];

    if (isBaiRui || isNamemac) {
        [self processAntiLostDeviceWithMacArr:@[nameMac ?: @"", @""] deviceDict:deviceDict localName:localName peripheral:peripheral isBaiRui:isBaiRui];
    }
}

/**
 *  @brief 处理通过制造商数据匹配的设备 | Process Device Matched by Manufacturer Data
 *  @param deviceDict 设备信息字典 | Device info dict
 *  @param peripheral 蓝牙外设 | BLE peripheral
 */
- (void)processMatchedDeviceWithDeviceDict:(NSDictionary *)deviceDict peripheral:(CBPeripheral *)peripheral {
    [self.centralManager stopScan];
    [self cleanScanTimeoutTask];
    self.hasDiscoveredPeripheral = YES;
    self.scanRetryCount = 0;
    DLog(@"通过名字匹配到设备：%@，MAC：%@", peripheral.name, self.writeMac);

    [self finishMacOnlyScanWithMac:self.writeMac];
}

/**
 *  @brief 处理防丢器设备（或其他通过本地名称匹配的设备）| Process Anti-lost Device (Matched by Local Name)
 *  @param macArr 兼容旧参数，当前只使用 MAC | Legacy parameter, current flow only uses MAC
 *  @param deviceDict 设备信息字典 | Device info dict
 *  @param localName 设备本地名称 | Device local name
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param isBaiRui 是否为百瑞设备 | Is BaiRui device
 */
- (void)processAntiLostDeviceWithMacArr:(NSArray *)macArr
                             deviceDict:(NSDictionary *)deviceDict
                              localName:(NSString *)localName
                             peripheral:(CBPeripheral *)peripheral
                               isBaiRui:(BOOL)isBaiRui {
    [self.centralManager stopScan];
    [self cleanScanTimeoutTask];
    self.hasDiscoveredPeripheral = YES;
    self.scanRetryCount = 0;
    DLog(@"通过本地名称匹配到防丢器设备：%@，MAC：%@", peripheral.name, self.writeMac);

    [self finishMacOnlyScanWithMac:self.writeMac];
}

/**
 *  @brief 绑定扫描只返回 MAC，屏幕参数由 UI 后续选择 | Bind scan returns MAC only, screen params are selected later by UI
 */
- (void)finishMacOnlyScanWithMac:(NSString *)mac {
    NSString *cleanMac = [[[mac ?: @"" stringByReplacingOccurrencesOfString:@":" withString:@""]
                           stringByReplacingOccurrencesOfString:@"：" withString:@""]
                          stringByReplacingOccurrencesOfString:@"-" withString:@""];
    cleanMac = [[cleanMac stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (EFIsBlankString(cleanMac)) {
        [self handleScanErrorWithMessage:XTLS(@"XT_Invalid_MAC")];
        return;
    }

    XTDeviceConfig *macOnlyConfig = [[XTDeviceConfig alloc] init];
    macOnlyConfig.appID = cleanMac;
    macOnlyConfig.uuID = cleanMac;
    macOnlyConfig.brushType = brushWithBle;
    if (self.scanBlock) {
        self.scanBlock(macOnlyConfig, nil);
    }
    self.isWorking = NO;
}

/**
 *  @brief 统一处理扫描错误 | Unified Handle Scan Error
 *  @param message 错误信息 | Error message
 */
- (void)handleScanErrorWithMessage:(NSString *)message {
    DLog(@"扫描错误：%@ | Scan error: %@", message, message);

    if (self.scanBlock) {
        NSError *error = [NSError errorWithDomain:@"BleScanError"
                                             code:-10
                                         userInfo:@{NSLocalizedDescriptionKey: message}];
        self.scanBlock(nil, error);
    }
    [self cleanScanTimeoutTask];
    _isWorking = NO;
}

/**
 *  @brief 检查设备电量并决定是否连接 | Check Device Power and Decide Connect
 *  @param batt 设备电量 | Device power
 *  @param peripheral 蓝牙外设 | BLE peripheral
 */
- (void)checkBattery:(NSString *)batt peripheral:(CBPeripheral *)peripheral {
    // 非刷图/OTA直接连接 | Direct connect if not screen refresh/OTA
    if (_currentOpType != XTBleWriteOperationTypeWriteScreen && _currentOpType != XTBleWriteOperationTypeOTA) {
        [self connectBleWithPeripheral:peripheral];
        return;
    }
    /*
     *  防丢器切换刷图模式后会主动断开并重新广播。
     *  重新扫描命中后必须直接连接，否则会打断后续刷图流程。
     *
     *  Anti-lost devices disconnect and advertise again after switching to brush mode.
     *  Once rediscovered, connect immediately so the upload flow can continue.
     */
    if ([_deviceConfig isFindMyAndNeedSendChangeToBrushMode] && _ishadDisconnect == YES) {
        [self connectBleWithPeripheral:peripheral];
        return;
    }
    [self connectBleWithPeripheral:peripheral];

    //    NSInteger newPower = [_deviceConfig.power integerValue];
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        NSString *content = @"";
    //        if (newPower <= 20 && newPower > 10) {
    //            content = @"设备电量已低于20%，请尽快充电。\n请确定是否继续传屏？";
    //        } else if (newPower <= 10 && newPower > 0) {
    //            content = @"设备电量已低于10%，可能引起传屏失败，请尽快充电。\n请确定是否继续传屏？";
    //        } else { //设备电量读取异常或电量已耗尽，最后连不上的时候有提示
    //            [self connectBleWithPeripheral:peripheral];
    //            return;
    //        }
    //
    //    });
}

/**
 *  @brief 蓝牙连接失败时调用 | Called when BLE connect failed
 *  @param central 蓝牙中央管理器 | BLE central manager
 *  @param peripheral 连接失败的外设 | Failed peripheral
 *  @param error 错误信息 | Error info
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    DLog(@" centralManager connected failed");
    [self alertMsg:XTLS(@"XT_tansFailed")];
    _bleConnectState = 0;
}

/**
 *  @brief 蓝牙连接断开时调用 | Called when BLE disconnected
 *  @param central 蓝牙中央管理器 | BLE central manager
 *  @param peripheral 断开连接的外设 | Disconnected peripheral
 *  @param error 错误信息 | Error info
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    DLog(@"设备断开连接：%@ -- 错误信息：%@", peripheral.name, error.localizedDescription);
    _bleConnectState = 0;
    _waitAnswerRunning = XTBleSendResultDisconnected;

    if (_shouldIgnoreNextDisconnect && peripheral == _expectedDisconnectPeripheral) {
        DLog(@"expected disconnect for internal BLE flow, continue working");
        _shouldIgnoreNextDisconnect = NO;
        _expectedDisconnectPeripheral = nil;
        return;
    }

    if (_isWorking) {
        [self finishCurrentOperationWithBleDisconnected];
    }
}

/**
 *  @brief 蓝牙连接成功时调用 | Called when BLE connected successfully
 *  @param central 蓝牙中央管理器 | BLE central manager
 *  @param peripheral 连接成功的外设 | Connected peripheral
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    if (!_isWorking) {
        [central cancelPeripheralConnection:peripheral];
        return;
    }

    DLog(@"Peripheral connect scucess，ready discover services");
    //连接成功后立即清理连接超时任务（关键！）| Clean connect timeout task after success
    [self cleanConnectTimeoutTask];

    [self showLoadingWithMsg:XTLS(@"ScanningBTServices")];

    // 设置设备的代理 | Set peripheral delegate
    peripheral.delegate = self;
    // services:传入nil  代表扫描所有服务 | Discover all services (nil = all)
    [peripheral discoverServices:nil];
    [self startServiceDiscoverTimeoutWithPeripheral:peripheral];
}

//MARK: CBPeripheralDelegate
/**
 *  @brief 发现蓝牙外设服务时调用 | Called when BLE peripheral services discovered
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param error 错误信息 | Error info
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    // 【新增】服务发现成功，清理超时任务 | Clean timeout task after success
    [self cleanServiceDiscoverTimeoutTask];

    if (error) {
        DLog(@"服务发现失败：%@", error.localizedDescription);
        [self alertMsg:XTLS(@"XT_BLE_Service_Discover_Failed")];
        [self disconnectCurrentPeripherals];
        return;
    }

    // 遍历所有的服务 | Traverse all services
    for (CBService *service in peripheral.services){
        //        DLog(@"kWriteServerUUID: %@",service.UUID.UUIDString);
        // 获取对应的服务 | Get target service
        if ([service.UUID.UUIDString isEqualToString:kWriteServerUUID] || [service.UUID.UUIDString isEqualToString:[kWriteServerUUID lowercaseString]]){
            // 根据服务去扫描特征 | Discover characteristics for service
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
}

/**
 *  @brief 发现蓝牙外设特征时调用 | Called when BLE peripheral characteristics discovered
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param service 特征对应的服务 | Service of characteristic
 *  @param error 错误信息 | Error info
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    // 遍历所有的特征 | Traverse all characteristics
    int a1 = 0;
    int a2 = 0;
    for (CBCharacteristic *characteristic in service.characteristics){
        //        DLog(@"kWriteCharacteristicUUID:%@",characteristic.UUID.UUIDString);
        if ([characteristic.UUID.UUIDString isEqualToString:kNotifyCharacteristicUUID] || [characteristic.UUID.UUIDString isEqualToString:[kNotifyCharacteristicUUID lowercaseString]]) {
            _currentPeripheral = peripheral;
            _readCharacteristic = characteristic;
            a1 = 1;
            [_currentPeripheral setNotifyValue:YES forCharacteristic:_readCharacteristic];
            //            [_currentPeripheral readValueForCharacteristic:_readCharacteristic];
        }

        if ([characteristic.UUID.UUIDString isEqualToString:kWriteCharacteristicUUID] || [characteristic.UUID.UUIDString isEqualToString:[kWriteCharacteristicUUID lowercaseString]]) {
            _currentPeripheral = peripheral;
            _writeCharacteristic = characteristic;
            a2 = 1;
        }
    }

    DLog(@"ble writed characteristic state %d,%d", a1, a2);
    if (_bleConnectState == 0 && a1 == 1 && a2 == 1) {
        DLog(@"ble writed characteristic sucess");
        //        [self nfcAlertMsg:[NSString stringWithFormat:@"%@ 30%%",XTLS(@"XT_Screen_Refreshing_image")] success:YES delay:0];
        // 这里开始刷图 | Start screen refresh
        _bleConnectState = 1;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (![self isReadyToSendBleData]) {
                [self finishCurrentOperationWithBleDisconnected];
                return;
            }

            // 开始刷图 | Start screen refresh
            if (_currentOpType == XTBleWriteOperationTypeWriteScreen ||
                _currentOpType == XTBleWriteOperationTypeImageStorageWrite) {
                if (_writeScreenHexDataArr.count > XTBatchMaxPacketCount) {
                    [self beginUploadWithWriteData];
                } else {
                    [self beginBrushWriteData];
                }
            } else if (_currentOpType == XTBleWriteOperationTypeOTA) {
                [self beginBrushWriteData];
            } else if (_currentOpType == XTBleWriteOperationTypeImageStorageCommand) {
                [self beginImageStorageCommandWriteData];
            } else {
                [self alertMsg:XTLS(@"XT_Write_Type_Error")];
            }
        });
    } else {
        [self alertMsg:XTLS(@"ScanBTServicesFailed")];
    }
}

/**
 *  @brief 特征通知状态更新时调用 | Called when characteristic notification state updated
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param characteristic 目标特征 | Target characteristic
 *  @param error 错误信息 | Error info
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(nullable NSError *)error {
    if (error) {
        // 开启/关闭失败（如特征不支持通知、CCCD描述符不存在、蓝牙连接断开）| Failed to enable/disable notification
        DLog(@"通知状态更新失败：%@ | Notification state update failed: %@", error.localizedDescription, error.localizedDescription);
        return;
    }

    // 查看当前特征的通知状态 | Check current notification state
    if (characteristic.isNotifying) {
        DLog(@"特征 %@ 的通知已开启，等待外设推送数据... | Characteristic %@ notification enabled, waiting for peripheral data...", characteristic.UUID, characteristic.UUID);
    } else {
        DLog(@"特征 %@ 的通知已关闭 | Characteristic %@ notification disabled", characteristic.UUID, characteristic.UUID);
    }
}

/**
 *  @brief 写入特征值后调用（仅CBCharacteristicWriteWithResponse模式）| Called after write value (only CBCharacteristicWriteWithResponse)
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param characteristic 目标特征 | Target characteristic
 *  @param error 错误信息 | Error info
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    // 不会进入这里 | Not enter here
    if (error) {
        DLog(@"write fail");
        DLog(@"Error writing characteristic value: %@",[error localizedDescription]);
    } else{
        NSData *value = characteristic.value;
        DLog(@"write success, value: %@ lenth = %ld",value, value.length);
    }
}

/**
 *  @brief 读取特征值后调用 | Called after read characteristic value
 *  @param peripheral 蓝牙外设 | BLE peripheral
 *  @param characteristic 目标特征 | Target characteristic
 *  @param error 错误信息 | Error info
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        DLog(@"Error reading characteristic value: %@", [error localizedDescription]);
    } else{
        NSData *data = characteristic.value;
        NSString *resultCmd = [XTCommonUtils convertDataToHexString:data];;
        DLog(@"-------- ble data back :%@ ----------------------------------",resultCmd);

        // 处理接收到的数据 指令回复 | Handle received data (command response)
        NSMutableArray *arrarResult = [XTBleProtocol getBleSendResult:data];
        if (arrarResult != NULL && arrarResult.count == 2) {
            _waitAnswerRunning = [XTCommonUtils convertNumberToInt:arrarResult[0]];
            _fixWriteScreenHexDataArr = arrarResult[1];
            if (_fixWriteScreenHexDataArr != NULL ) {
                DLog(@"ble need fix data: -- %ld", _fixWriteScreenHexDataArr.count);
            }
        } else {
            DLog(@" ble failed: %@", arrarResult);
        }
    }
}

//MARK:  ============================= 蓝牙发送(刷图/OTA) | BLE Send (Screen Refresh/OTA) =============================
/**
 *  @brief 图片管理控制命令发送（删除/轮播）| Send image storage control commands (delete/carousel)
 */
- (void)beginImageStorageCommandWriteData {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_imageStorageCommandParamList.count == 0) {
            [self alertMsg:XTLS(@"XT_Image_Manager_Command_Empty")];
            if (_writeImageBlock) {
                _writeImageBlock(NO, XTLS(@"XT_Image_Manager_Command_Empty"));
            }
            [self disconnectCurrentPeripherals];
            return;
        }

        [self showLoadingWithMsg:XTLS(@"XT_Sending_Image_Manager_Command")];
        for (NSInteger i = 0; i < _imageStorageCommandParamList.count; i++) {
            if (![self isReadyToSendBleData]) {
                [self finishCurrentOperationWithBleDisconnected];
                return;
            }

            NSArray<NSNumber *> *paramBytes = _imageStorageCommandParamList[i];
            NSString *cmdStr = [XTBleProtocol getBrushScreenOrder:0x01 paramBytes:paramBytes];
            DLog(@"send image storage command %@", cmdStr);
            BOOL isDeleteCommand = paramBytes.count >= 2 && [paramBytes[1] integerValue] == XTImageStorageRefreshFlagDelete;
            BOOL shouldWaitResponse = !isDeleteCommand || i == _imageStorageCommandParamList.count - 1;
            if (shouldWaitResponse) {
                NSInteger value = [self sendDataToDevice:cmdStr];
                if (value == XTBleSendResultDisconnected || !_isWorking) {
                    return;
                }
                if (value != 1) {
                    NSString *error = [NSString stringWithFormat:XTLS(@"XT_Image_Manager_Command_Failed_Format"), (long)value];
                    [self alertMsg:error];
                    if (_writeImageBlock) {
                        _writeImageBlock(NO, error);
                    }
                    _isWorking = NO;
                    [self disconnectCurrentPeripherals];
                    return;
                }
            } else {
                if (![self isReadyToSendBleData]) {
                    [self finishCurrentOperationWithBleDisconnected];
                    return;
                }

                NSData *data = [XTCommonUtils convertHexStringToData:cmdStr];
                [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
                            if (self.progressHandler) { double progress = MIN(0.95, (double)(i + 1) / MAX(1, _writeScreenHexDataArr.count) * 0.95); dispatch_async(dispatch_get_main_queue(), ^{ if (self.progressHandler) self.progressHandler(progress); }); }
            }
            [NSThread sleepForTimeInterval:0.5];
        }

        if (_writeImageBlock) {
            _writeImageBlock(YES, nil);
        }
        _isWorking = NO;
        [self disconnectCurrentPeripherals];
        [self alertMsg:XTLS(@"XT_Image_Manager_Command_Complete")];
    });
}

/**
 *  @brief 开始刷图/OTA数据发送 | Start Screen Refresh/OTA Data Send
 *  @discussion 处理防丢模式切换、Flash删除、数据发送、补包、校验逻辑
 *              Handle anti-lost mode switch, flash delete, data send, retransmit, validation
 */
- (void)beginBrushWriteData {
    DLog(@"---------- begin brush image -----------");
    DLog(@"brush config: mac=%@ size=%ldx%ld color=%@ scanType=%ld findMySwitch=%@ hadDisconnect=%@",
         _deviceConfig.uuID,
         (long)_deviceConfig.screenWidth,
         (long)_deviceConfig.screenHeight,
         _deviceConfig.screenColorCode,
         (long)_deviceConfig.scanType,
         [_deviceConfig isFindMyAndNeedSendChangeToBrushMode] ? @"YES" : @"NO",
         _ishadDisconnect ? @"YES" : @"NO");
    // 异步发送 | Async send
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![self isReadyToSendBleData]) {
            [self finishCurrentOperationWithBleDisconnected];
            return;
        }

        /*
         *  1.69防丢器等设备默认可能处于FindMy/防丢模式，不能直接刷图。
         *  第一次连接先发0x16切换刷图模式，然后断开、重新扫描、重连；第二次连接才继续删除Flash并发送图片数据。
         *
         *  Some anti-lost devices may be in FindMy mode by default and cannot upload image data directly.
         *  The first connection sends 0x16 to switch to brush mode, disconnects, rescans, and reconnects.
         *  The second connection continues with flash deletion and image upload.
         */
        if ([_deviceConfig isFindMyAndNeedSendChangeToBrushMode] && _ishadDisconnect == NO) {
            // 发送命令断开findmy | Send command to disconnect findmy
            NSString *order = [XTBleProtocol startFindMyOperationOrderWithCmd:0x16 opAndParam:XT_OP_DISCONNECT];
            DLog(@"---------- send 15/16 cmd %@ -----------",order);
            NSInteger value = [self sendDataToDevice:order];
            if (value != 1) {
                if (value != XTBleSendResultDisconnected) {
                    NSString *message = XTLS(@"XT_Antilost_Switch_Brush_Mode_Failed");
                    [self notifyWriteImageCompletionWithSuccess:NO error:message];
                    [self disconnectCurrentPeripherals];
                }
                return;
            }

            //只是中断，不是结束所以不能用这个方法 | Only interrupt, not end
            //[self disconnectCurrentPeripherals];
            if (_centralManager && _currentPeripheral && _currentPeripheral.state == CBPeripheralStateConnected) {
                _ishadDisconnect = YES;
                _shouldIgnoreNextDisconnect = YES;
                _expectedDisconnectPeripheral = _currentPeripheral;
                [self.centralManager cancelPeripheralConnection:_currentPeripheral];
                _currentPeripheral = nil;
            }
            // 【修改】清理所有超时任务 | Clean all timeout tasks
            [self cleanScanTimeoutTask];
            [self cleanConnectTimeoutTask];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //重新扫描 | Rescan
                [self startScanPeripherals];
            });
            return;
        }

        // 发送删除FLASH指令 | Send flash delete command
        NSString *orderDeleteFlash = [XTBleProtocol getDeleteFlashOrder:(int)_writeNeedFlashLen];
        NSInteger value = [self sendDataToDevice: orderDeleteFlash];
        if (value != 1) {
            if (value != XTBleSendResultDisconnected) {
                [self handleErrorWithValue:value cmd:0x01];
            }
            return;
        }

        DLog(@"11FLASH delete state %@ = %ld = %ld", orderDeleteFlash,(long)value,(long)_writeNeedFlashLen);

        [self showLoadingWithMsg:_currentOpType == XTBleWriteOperationTypeOTA ? XTLS(@"XT_readywritedata") : XTLS(@"XT_Screen_Refreshing_image")];

        _scanDeviceTime = (long)[[NSDate date] timeIntervalSince1970] - _scanDeviceTime;
        _brushScreenTime = (long)[[NSDate date] timeIntervalSince1970];

        // 先设置为全部都需要补包 | Set all need retransmit initially
        _fixWriteScreenHexDataArr = [NSMutableArray array];
        for (int i = 0; i < _writeScreenHexDataArr.count; i++){
            [_fixWriteScreenHexDataArr addObject:[NSNumber numberWithInt:0]];
        }

        NSUInteger x1 = [_currentPeripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        DLog(@"maximumWriteValueLengthForType = %ld", x1);

        // 共可以补包5次 | Max 5 retransmit times
        for (int failCount = 0; failCount < 5; failCount++){
            if (![self isReadyToSendBleData]) {
                [self finishCurrentOperationWithBleDisconnected];
                return;
            }

            // 发送数据包 | Send data packets
            for (int i = 0; i < _writeScreenHexDataArr.count; i++){
                if (_fixWriteScreenHexDataArr != NULL && i < _fixWriteScreenHexDataArr.count) {
                    int indexValue = [_fixWriteScreenHexDataArr[i] intValue];
                    if (indexValue == 0){
                        // 这里是表示需要补包的 | Need retransmit
                        NSMutableArray *page = _writeScreenHexDataArr[i];
                        for (int j = 0; j < page.count; j++) {
                            if (![self isReadyToSendBleData]) {
                                [self finishCurrentOperationWithBleDisconnected];
                                return;
                            }

                            NSData *data = page[j];
                            // 发送数据 | Send data
                            DLog(@"--- sendData - All %d - current %d - %d - %lu - %@",j, i, (int)_writeScreenHexDataArr.count,(unsigned long)data.length,[XTCommonUtils convertDataToHexString:data]);
                            [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
                            [NSThread sleepForTimeInterval:[_deviceConfig isPhoneCaseDevice] ? 0.015 : 0.025];
                        }
                        int t;
                        for(t = 0; t < 50 && [self isReadyToSendBleData]; t++) {
                            if (_currentPeripheral.canSendWriteWithoutResponse == true) {
                                break;
                            }
                            [NSThread sleepForTimeInterval:0.001];
                        }
                        DLog(@"ready to write %d", t);
                        if (![self isReadyToSendBleData]) {
                            DLog(@"ble disconnected, brush failed");
                            [self finishCurrentOperationWithBleDisconnected];
                            return;
                        }
                    }
                }
            }

            // 清空需要补包的 | Clear retransmit array
            _fixWriteScreenHexDataArr = [NSMutableArray array];

            [NSThread sleepForTimeInterval:0.2];// 间隔0.2秒 | Interval 0.2s
            if (_currentOpType == XTBleWriteOperationTypeWriteScreen ||
                _currentOpType == XTBleWriteOperationTypeImageStorageWrite) {
                [self showLoadingWithMsg:_currentOpType == XTBleWriteOperationTypeImageStorageWrite ? XTLS(@"XT_Saving_Image") : XTLS(@"XT_Screen_Refreshing")];

                /* 其他情况 → 常规校验指令（区分单/双面）| Normal validation command (single/dual panel) */
                int cmdValue = 0x03; // 双面 | Dual panel
                if (_brushDataHexArrA.count == 0) cmdValue = 0x02; // 仅B面 | Only side B
                else if (_brushDataHexArrB.count == 0) cmdValue = 0x01; // 仅A面 | Only side A

                // 获取连接04指令 | Get update command (04)
                NSString *orderUpdataOrder = nil;
                if (_currentOpType == XTBleWriteOperationTypeImageStorageWrite && _imageStorageParamBytes.count > 0) {
                    orderUpdataOrder = [XTBleProtocol getBrushScreenOrder:0x01 paramBytes:_imageStorageParamBytes];
                } else {
                    orderUpdataOrder = [XTBleProtocol getUpdateOrder:0 value:0];
                }

                // 发送 | Send
                DLog(@"send 04 cmd %@", orderUpdataOrder);
                value = [self sendDataToDevice:orderUpdataOrder];
                if (value == XTBleSendResultDisconnected || !_isWorking) {
                    return;
                }
                if (value == 2){
                    value = [self sendDataToDevice:orderUpdataOrder];
                    DLog(@"send 04 cmd again = %ld", (long)value);
                    if (value == XTBleSendResultDisconnected || !_isWorking) {
                        return;
                    }
                } else if (value == 3){
                    DLog(@"brush failed, data not complete， fix data...");
                    [self showLoadingWithMsg:XTLS(@"XT_Screen_Refreshing_image")];
                } else if (value == 1){
                    dispatch_async(dispatch_get_main_queue(), ^{
                    });

                    if (_writeImageBlock) {
                        _writeImageBlock(YES,nil);
                    }
                    [self disconnectCurrentPeripherals];
                    [NSThread sleepForTimeInterval:2];// 间隔2秒 | Interval 2s
                    [self alertMsg:XTLS(@"The task has been completed")];
                    _isWorking = NO;
                    return;
                }
            } else {
                //发送个05通知主板 OTA升级 | Send OTA start command (05)
                NSString *otaUpdateStr = [XTBleProtocol startHardwareUpdateOrder];
                DLog(@"send hardware ota begin cmd 05 %@", otaUpdateStr);

                value = [self sendDataToDevice:otaUpdateStr];
                DLog(@"send hardware ota begin cmd 05 back = %ld", (long)value);
                if (value == XTBleSendResultDisconnected || !_isWorking) {
                    return;
                }
                if (value == 1) {
                    // ota
                    // 必须要先断开蓝牙在停5秒 | Disconnect BLE and wait 5s
                    [self showLoadingWithMsg:XTLS(@"XT_doingota")];
                    [self disconnectCurrentPeripherals];
                    [NSThread sleepForTimeInterval:5];// 间隔5秒 | Interval 5s
                    [self alertMsg:XTLS(@"XT_OtaSuccess")];
                    DLog(@"OTA sueccss");
                    _isWorking = NO;
                    return;
                } else if (value == 2) {
                    value = [self sendDataToDevice:otaUpdateStr];
                    DLog(@"send hardware ota begin cmd 05 again = %ld", (long)value);
                    if (value == XTBleSendResultDisconnected || !_isWorking) {
                        return;
                    }
                } else if (value == 3){
                    DLog(@"brush failed, data not complete， fix data...");
                    [self showLoadingWithMsg:XTLS(@"XT_readywritedata")];
                }
            }
        }
        DLog(@"bursh failed");
        _isWorking = NO;
        [self alertMsg:XTLS(@"XT_BleDisconnected")];
        if (_writeImageBlock) {
            _writeImageBlock(NO,XTLS(@"XT_BleDisconnected"));
        }
        [self disconnectCurrentPeripherals];
    });
}

/**
 *  @brief 处理并整理刷图/OTA数据 | Process and Tidy Up Screen Refresh/OTA Data
 *  @discussion 根据操作类型生成对应的分包数据，计算Flash删除长度
 *              Generate packet data by operation type, calculate flash delete length
 */
- (void)beginTidyUpBrushData {
    // 根据当前操作类型处理不同逻辑 | Handle by operation type
    switch (_currentOpType) {
        case XTBleWriteOperationTypeWriteScreen:
        case XTBleWriteOperationTypeImageStorageWrite: {
            [self showLoadingWithMsg:XTLS(@"XT_readywritedata")];
            // 获取设备颜色类型 | Get device color type
            int deviceColorType = [XTDeviceConfig getDeviceColorType:_deviceConfig.screenColorCode];

            if (![_deviceConfig isNameCardDevice]) {
                // 生成屏幕写入的分包数据 | Generate screen write packet data
                _writeScreenHexDataArr = [XTBleProtocol getPicSendPageData:_brushDataHexArrA
                                                                picWidth:(int)_deviceConfig.screenWidth
                                                               picHeight:(int)_deviceConfig.screenHeight
                                                         deviceColorType:deviceColorType
                                                                pageSize:(int)_writeMtuSize
                                                          isNeedCompress:YES
                                                    imageDataProcessType:_deviceConfig.imageDataProcessType];
            } else {
                _writeScreenHexDataArr = [self generateWriteScreenHexDataWithArrA:_brushDataHexArrA
                                                                             arrB:_brushDataHexArrB
                                                                       deviceInfo:_deviceConfig
                                                                        colorType:deviceColorType
                                                                     writeAllSize:_writeMtuSize];
            }
            break;
        }
        case XTBleWriteOperationTypeOTA: {
            [self showLoadingWithMsg:XTLS(@"XT_readyOta")];

            // 生成OTA升级的分包数据 | Generate OTA packet data
            _writeScreenHexDataArr = [XTBleProtocol getOTASendPageData:_brushDataHexArrA
                                                            pageSize:(int)_writeMtuSize];
            DLog(@"_writeNeedFlashLen-finish:%ld", (long)_writeNeedFlashLen);
            break;
        }
        default:
            // 可根据需要添加默认处理 | Add default handle if needed
            break;
    }
    if ((_currentOpType == XTBleWriteOperationTypeWriteScreen ||
         _currentOpType == XTBleWriteOperationTypeImageStorageWrite) && (_writeScreenHexDataArr.count == 0)) {
        _isWorking = NO;
        [self alertMsg:XTLS(@"XT_Brush_Data_Empty")];
        if (_writeImageBlock) {
            _writeImageBlock(NO, XTLS(@"XT_Brush_Data_Empty"));
        }
        return;
    }

    // 计算需要清空的闪存空间大小（所有操作类型共用逻辑）| Calculate flash delete length (common logic)
    _writeNeedFlashLen = (int)[XTBleProtocol getDeleteFlashLength:_writeScreenHexDataArr];

    // 开始扫描外设 | Start scan peripheral
    [self startScanPeripherals];
}

/**
 *  @brief 发送指令到蓝牙设备 | Send Command to BLE Device
 *  @param cmdStr 指令字符串（十六进制）| Command string (hex)
 *  @return 发送结果：1=成功，2=超时，3=失败，其他=错误码 | Send result: 1=success, 2=timeout, 3=failed, others=error code
 */
- (NSInteger)sendDataToDevice:(NSString *)cmdStr {
    if (![self isReadyToSendBleData]) {
        [self finishCurrentOperationWithBleDisconnected];
        return XTBleSendResultDisconnected;
    }

    _waitAnswerRunning = 1;
    NSData *data = [XTCommonUtils convertHexStringToData:cmdStr];
    [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];

    int nGetTimeout = 0;
    int waitNum = 250;

    while (_waitAnswerRunning == 1){
        if (![self isReadyToSendBleData]) {
            _waitAnswerRunning = XTBleSendResultDisconnected;
            break;
        }
        [NSThread sleepForTimeInterval: 0.02];
        nGetTimeout++;
        if (nGetTimeout > waitNum) {
            break;
        }
    }
    if (_waitAnswerRunning == XTBleSendResultDisconnected) {
        DLog(@"cmd send failed because bluetooth disconnected");
        return XTBleSendResultDisconnected;
    } else if (_waitAnswerRunning == 1) {
        DLog(@"cmd send time out");
        return 2;
    } else if (_waitAnswerRunning == 2) {
        DLog(@"cmd send failed");
        return 3;
    } else if (_waitAnswerRunning == 104) {
        DLog(@"Command execution failed");
        return 104;
    }  else if (_waitAnswerRunning == 205) {
        DLog(@"RSA security authentication failed");
        return 205;
    } else if (_waitAnswerRunning == 206) {
        DLog(@"ECDSA signature verification failed");
        return 206;
    }
    DLog(@"cmd send success");
    return 1;
}

#pragma mark - 私有辅助方法：刷图数据生成 | Private Helper: Screen Refresh Data Generate
/**
 *  @brief 生成双面/单面板刷图数据 | Generate Dual/Single Panel Screen Refresh Data
 *  @param arrA A面图像数据数组 | Side A image data array
 *  @param arrB B面图像数据数组 | Side B image data array
 *  @param deviceInfo 设备配置 | Device config
 *  @param colorType 设备颜色类型 | Device color type
 *  @param writeAllSize 分包大小 | Packet size
 *  @return 生成的刷图数据包数组 | Generated screen refresh packet array
 */
- (NSMutableArray *)generateWriteScreenHexDataWithArrA:(NSMutableArray *)arrA
                                                  arrB:(NSMutableArray *)arrB
                                            deviceInfo:(XTDeviceConfig *)deviceInfo
                                             colorType:(NSInteger)colorType
                                          writeAllSize:(NSInteger)writeAllSize {
    XTSendPicDataInfo *pict1 = [self createSendPicDataInfoWithDataArr:arrA deviceInfo:deviceInfo colorType:colorType bagSize:writeAllSize];
    XTSendPicDataInfo *pict2 = [self createSendPicDataInfoWithDataArr:arrB deviceInfo:deviceInfo colorType:colorType bagSize:writeAllSize];

    XTSendPicDataInfo *dataOne = nil, *dataTwo = nil;
    if (pict1 && pict2) { dataOne = pict1; dataTwo = pict2; }
    else if (pict1) dataOne = pict1;
    else if (pict2) dataOne = pict2;

    return [XTBleProtocol getPicSendPageDataOne:dataOne dataTwo:dataTwo];
}

/**
 *  @brief 创建图像发送数据信息对象 | Create Image Send Data Info Object
 *  @param dataArr 图像数据数组 | Image data array
 *  @param deviceInfo 设备配置 | Device config
 *  @param colorType 设备颜色类型 | Device color type
 *  @param bagSize 分包大小 | Packet size
 *  @return 图像发送数据信息对象 | Image send data info object
 */
- (XTSendPicDataInfo *)createSendPicDataInfoWithDataArr:(NSMutableArray *)dataArr
                                             deviceInfo:(XTDeviceConfig *)deviceInfo
                                              colorType:(NSInteger)colorType
                                                bagSize:(NSInteger)bagSize {
    if (!dataArr || dataArr.count == 0) return nil;

    XTSendPicDataInfo *info = [XTSendPicDataInfo new];
    info.dataArr = dataArr;
    info.width = deviceInfo.screenWidth;
    info.height = deviceInfo.screenHeight;
    info.deviceColorType = colorType;
    info.bagSize = bagSize;
    info.deviceNumber = 0;
    info.imageDataProcessType = deviceInfo.imageDataProcessType;
    info.isNeedCompress = YES;
    return info;
}

#pragma mark - 核心发送逻辑（区分批量/非批量）| Core Send Logic (Batch/Non-batch)
/**
 *  @brief 开始批量上传数据（适用于>254包的大文件）| Start Batch Upload (For >254 packets large file)
 *  @discussion 分批次发送、分批次删除Flash、分批次校验、补包，最多重试5次
 *              Send by batch, delete flash by batch, validate by batch, retransmit, max 5 retries
 */
- (void)beginUploadWithWriteData {
    DLog(@"---------- 开始刷图 -----------");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![self isReadyToSendBleData]) {
            [self finishCurrentOperationWithBleDisconnected];
            return;
        }

        [self initBrushTime];
        self.totalPackageCount = _writeScreenHexDataArr.count; /* 记录总包数 | Record total package count */
        NSInteger maxPerBatch = XTBatchMaxPacketCount; /* 单批最大包数（阈值）| Max packets per batch (threshold) */
        self.totalFlashDeleteLength = (int)[XTBleProtocol getDeleteFlashLength:_writeScreenHexDataArr]; /* 总删除长度 | Total delete length */

        /* 区分批量/非批量模式 | Judge batch/non-batch mode */
        BOOL isBatchMode = (self.totalPackageCount > maxPerBatch);
        DLog(@"总包数: %ld，模式: %@（总删除长度: %ld字节）",
             self.totalPackageCount,
             isBatchMode ? @"批量（分批次删除）" : @"非批量（全局删除）",
             self.totalFlashDeleteLength);

        /* 计算总批次（批量模式有效，向上取整）| Calculate total batches (batch mode only, round up) */
        NSInteger totalBatches = isBatchMode ? (self.totalPackageCount + maxPerBatch - 1) / maxPerBatch : 1;

        /* 多轮重试（最多5次）| Max 5 retries */
        for (int retry = 0; retry < 5; retry++) {
            BOOL allSuccess = YES;

            /* 循环处理每个批次 | Process each batch */
            for (int batchNum = 1; batchNum <= totalBatches; batchNum++) {
                if (![self isReadyToSendBleData]) {
                    [self finishCurrentOperationWithBleDisconnected];
                    return;
                }

                /* 计算当前批次的起始/结束索引（闭区间）| Calculate start/end index of current batch (closed interval) */
                NSInteger start = (batchNum - 1) * maxPerBatch;
                NSInteger end = MIN(start + maxPerBatch - 1, self.totalPackageCount - 1);
                /* 提取当前批次数据 | Extract current batch data */
                NSMutableArray *currentBatchData = [self getBatchDataFrom:start to:end];

                /* 批量模式：每批前执行分批次删除 | Batch mode: delete flash by batch before each batch */
                if (isBatchMode) {
                    if (![self sendBatchDeleteFlashCommandWithTotalSize:self.totalFlashDeleteLength
                                                               batchNum:batchNum
                                                              batchData:currentBatchData]) {
                        if (!_isWorking) {
                            return;
                        }
                        [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Batch_Delete_Failed_Format"), batchNum] done:NO sucesss:NO];
                        allSuccess = NO;
                        break;
                    }
                }

                /* 发送并校验当前批次数据（传递总批次用于校验指令判断）| Send and validate current batch data */
                if (![self sendAndCheckBatchWithStart:start end:end batchNumber:batchNum totalBatches:totalBatches isBatchMode:isBatchMode]) {
                    if (!_isWorking) {
                        return;
                    }
                    allSuccess = NO;
                    break;
                }
            }

            /* 所有批次成功，结束流程 | All batches success, end process */
            if (allSuccess) {
                [self finishBrushSuccessfully];
                return;
            }
            if (!_isWorking) {
                return;
            }

            /* 重试间隔1秒，推送重试日志 | Retry interval 1s, push retry log */
            [NSThread sleepForTimeInterval:1.0];
            [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Retry_Count_Format"), retry + 1] done:NO sucesss:NO];
        }

        /* 所有重试失败，推送失败日志 | All retries failed, push failure log */
        [self pushDaskDetail:XTLS(@"XT_BLE_Transfer_Failed") done:YES sucesss:NO];
        if (_writeImageBlock) {
            [self notifyWriteImageCompletionWithSuccess:NO error:XTLS(@"XT_BLE_Transfer_Failed")];
        }
        [self disconnectCurrentPeripherals];
    });
}

/**
 *  @brief 提取指定索引范围的批次数据 | Extract Batch Data from Specified Index Range
 *  @param start 起始索引（包含）| Start index (inclusive)
 *  @param end 结束索引（包含）| End index (inclusive)
 *  @return 当前批次的数据包数组 | Current batch data array
 */
- (NSMutableArray *)getBatchDataFrom:(NSInteger)start to:(NSInteger)end {
    NSMutableArray *batchData = [NSMutableArray arrayWithCapacity:end - start + 1];
    for (NSInteger i = start; i <= end; i++) {
        [batchData addObject:_writeScreenHexDataArr[i]];
    }
    return batchData;
}

/**
 *  @brief 批量模式：分批次删除Flash | Batch Mode: Delete Flash by Batch
 *  @param totalSize 总删除长度 | Total delete length
 *  @param batchNum 当前批次号 | Current batch number
 *  @param batchData 当前批次数据 | Current batch data
 *  @return 是否删除成功 | Delete success or not
 */
- (BOOL)sendBatchDeleteFlashCommandWithTotalSize:(NSInteger)totalSize
                                        batchNum:(NSInteger)batchNum
                                       batchData:(NSArray *)batchData {
    /* 1. 计算当前批次的删除长度 | Calculate current batch delete length */
    NSInteger currentLen = (int)[XTBleProtocol getDeleteFlashLength:batchData.mutableCopy];
    if (currentLen <= 0) {
        DLog(@"⚠️ 批次%ld：长度无效（%ld）", batchNum, currentLen);
        return NO;
    }

    /* 2. 计算当前批次的偏移量（按批次号推导：每批最大254包约300K）| Calculate current batch offset */
    NSInteger offset = (batchNum - 1) * XTBatchPayloadBytes;

    /* 3. 调用协议类生成批次删除指令（含总长度、偏移量、当前长度）| Generate batch delete command */
    NSString *deleteOrder = [XTBleProtocol getDeleteFlashOrderWithAllBtyeLenth:totalSize
                                                                      offset:offset
                                                                  currentLen:currentLen];

    if (!deleteOrder) {
        DLog(@"⚠️ 批次%ld：生成指令失败", batchNum);
        return NO;
    }

    /* 4. 发送删除指令并获取结果 | Send delete command and get result */
    NSInteger result = [self sendDataToDevice:deleteOrder];
    DLog(@"批次%ld删除结果：总长度=%ld，偏移=%ld，当前长度=%ld，指令=%@，结果=%ld",
         batchNum, totalSize, offset, currentLen, deleteOrder, result);
    [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Batch_Delete_Flash_Format"), batchNum, currentLen] done:NO sucesss:NO];
    return (result == 1);
}

/**
 *  @brief 发送并校验单个批次的数据 | Send and Validate Single Batch Data
 *  @param start 批次起始索引 | Batch start index
 *  @param end 批次结束索引 | Batch end index
 *  @param batchNumber 当前批次号 | Current batch number
 *  @param totalBatches 总批次 | Total batches
 *  @param isBatchMode 是否为批量模式 | Is batch mode
 *  @return 批次处理是否成功 | Batch process success or not
 */
- (BOOL)sendAndCheckBatchWithStart:(NSInteger)start
                               end:(NSInteger)end
                       batchNumber:(NSInteger)batchNumber
                      totalBatches:(NSInteger)totalBatches
                       isBatchMode:(BOOL)isBatchMode {
    NSInteger batchSize = end - start + 1;
    if (batchSize <= 0) return YES; /* 空批次直接返回成功 | Empty batch return success */

    /* 推送批次开始日志（区分模式）| Push batch start log */
    NSString *modeStr = isBatchMode ? XTLS(@"XT_Batch_Mode") : XTLS(@"XT_Non_Batch_Mode");
    [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Send_Batch_Format"),
                          modeStr, batchNumber, totalBatches, batchSize]
                    done:NO
                 sucesss:NO];

    /* 创建补包标记数组（初始全0，表示需要发送）| Create retransmit flag array (all 0 initially) */
    NSMutableArray *batchFixArr = [self createBatchFixArrayWithSize:batchSize];
    /* 发送当前批次数据 | Send current batch data */
    if (![self sendBatchPackagesFrom:start to:end fixArray:batchFixArr batchNumber:batchNumber]) {
        return NO;
    }

    /* 校验当前批次数据并处理补包 | Validate current batch data and handle retransmit */
    return [self checkAndFixBatchFrom:start to:end batchNumber:batchNumber totalBatches:totalBatches];
}

/**
 *  @brief 创建批次补包标记数组 | Create Batch Retransmit Flag Array
 *  @param size 数组大小（与批次包数一致）| Array size (same as batch packet count)
 *  @return 初始化后的补包标记数组（元素为@0）| Initialized retransmit flag array (elements are @0)
 */
- (NSMutableArray *)createBatchFixArrayWithSize:(NSInteger)size {
    NSMutableArray *fixArr = [NSMutableArray arrayWithCapacity:size];
    for (int i = 0; i < size; i++) {
        [fixArr addObject:@0];
    }
    return fixArr;
}

/**
 *  @brief 发送批次内的所有数据包 | Send All Packets in Batch
 *  @param start 批次起始索引 | Batch start index
 *  @param end 批次结束索引 | Batch end index
 *  @param fixArr 补包标记数组 | Retransmit flag array
 *  @param batchNumber 当前批次号 | Current batch number
 *  @return 是否发送成功（蓝牙断开返回NO）| Send success (NO if BLE disconnected)
 */
- (BOOL)sendBatchPackagesFrom:(NSInteger)start
                           to:(NSInteger)end
                     fixArray:(NSMutableArray *)fixArr
                  batchNumber:(NSInteger)batchNumber {
    [self showLoadingWithMsg:XTLS(@"XT_Sending_Data")];
    for (NSInteger i = start; i <= end; i++) {
        if (![self isReadyToSendBleData]) {
            [self finishCurrentOperationWithBleDisconnected];
            return NO;
        }

        NSInteger batchIndex = i - start; /* 批次内相对索引 | Relative index in batch */
        int needSend = [fixArr[batchIndex] intValue];
        if (needSend != 0) continue; /* 已补包的包跳过发送 | Skip sent packets */

        /* 发送当前包的所有子包 | Send all sub-packets of current packet */
        NSMutableArray *page = _writeScreenHexDataArr[i];
        for (NSData *data in page) {
            if (![self isReadyToSendBleData]) {
                [self finishCurrentOperationWithBleDisconnected];
                return NO;
            }

            [_currentPeripheral writeValue:data forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];

            DLog(@"%@",[XTCommonUtils convertDataToHexString:data]);
            [NSThread sleepForTimeInterval:0.020]; /* 发送间隔（避免设备处理不过来）| Send interval */
        }

        if (self.progressHandler) {
            double progress = MIN(0.95, (double)(i + 1) / MAX(1, _writeScreenHexDataArr.count) * 0.95);
            dispatch_async(dispatch_get_main_queue(), ^{ if (self.progressHandler) self.progressHandler(progress); });
        }
        /* 等待设备就绪（确保设备可接收下一包）| Wait for device ready */
        [self waitForDeviceReadyToSend];

        /* 检查蓝牙连接状态（断开则终止发送）| Check BLE connection state */
        if (![self checkBleConnection]) {
            return NO;
        }
    }
    return YES;
}

/**
 *  @brief 检查蓝牙连接状态 | Check BLE Connection State
 *  @return 连接状态（1=连接，0=断开）| Connection state (1=connected, 0=disconnected)
 */
- (BOOL)checkBleConnection {
    if (![self isReadyToSendBleData]) {
        DLog(@"蓝牙已断开 | BLE disconnected");
        [self finishCurrentOperationWithBleDisconnected];
        return NO;
    }
    return YES;
}

/**
 *  @brief 等待设备就绪（可接收下一包数据）| Wait for Device Ready to Receive Next Packet
 *  @discussion 超时时间：50ms（避免无限等待）| Timeout: 50ms (avoid infinite wait)
 */
- (void)waitForDeviceReadyToSend {
    int t = 0;
    while (t < 50 && [self isReadyToSendBleData] && !_currentPeripheral.canSendWriteWithoutResponse) {
        [NSThread sleepForTimeInterval:0.001];
        t++;
    }
    DLog(@"等待设备就绪：%dms | Wait for device ready: %dms", t, t);
}

/**
 *  @brief 校验批次数据并处理补包 | Validate Batch Data and Handle Retransmit
 *  @param start 批次起始索引 | Batch start index
 *  @param end 批次结束索引 | Batch end index
 *  @param batchNumber 当前批次号 | Current batch number
 *  @param totalBatches 总批次 | Total batches
 *  @return 校验是否成功 | Validation success or not
 */
- (BOOL)checkAndFixBatchFrom:(NSInteger)start
                          to:(NSInteger)end
                 batchNumber:(NSInteger)batchNumber
                totalBatches:(NSInteger)totalBatches {
    [NSThread sleepForTimeInterval:0.1]; /* 等待设备接收完成 | Wait for device receive complete */

    DLog(@"current %ld, all %ld",batchNumber,totalBatches);

    [self pushDaskDetail:XTLS(@"data_check") done:NO sucesss:NO];

    /* 发送校验指令（根据模式和批次位置选择指令）| Send validation command */
    NSString *checkOrder = [self getBatchCheckOrderWithBatchNumber:batchNumber
                                                      totalBatches:totalBatches];
    NSInteger checkResult = [self sendDataToDevice:checkOrder];
    if (checkResult == XTBleSendResultDisconnected || !_isWorking) {
        return NO;
    }

    /* 处理校验结果：3=需要补包，2=指令发送失败（重试一次），1=成功 | Handle validation result */
    if (checkResult == 3) {
        [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Batch_Need_Retransmit_Format"), batchNumber] done:NO sucesss:NO];
        [self fixBatchPackagesFrom:start to:end batchNumber:batchNumber];
        return YES; /* 补包后视为临时成功，进入下一轮整体校验 | Temporary success after retransmit */
    } else if (checkResult == 2) {
        checkResult = [self sendDataToDevice:checkOrder]; /* 重试一次校验指令 | Retry validation command */
        if (checkResult == XTBleSendResultDisconnected || !_isWorking) {
            return NO;
        }
    }

    return (checkResult == 1); /* 1=校验成功，其他=失败 | 1=success, others=failed */
}

/**
 *  @brief 获取批次校验指令（区分模式和批次位置）| Get Batch Validation Command (By Mode and Batch Position)
 *  @param batchNumber 当前批次号 | Current batch number
 *  @param totalBatches 总批次 | Total batches
 *  @return 校验指令字符串 | Validation command string
 */
- (NSString *)getBatchCheckOrderWithBatchNumber:(NSInteger)batchNumber
                                   totalBatches:(NSInteger)totalBatches {
    BOOL isLargeBatch = (self.totalPackageCount > XTBatchMaxPacketCount); /* 是否批量模式（>254包）| Is batch mode (>254 packets) */

    /* 批量模式 + 非最后批次 → 补包校验指令 | Batch mode + not last batch → retransmit validation command */
    if (isLargeBatch && batchNumber < totalBatches) {
        DLog(@"批量模式非最后批次（%ld/%ld），使用补包校验指令", batchNumber, totalBatches);
        return [XTBleProtocol getBitmapAndFixDataOrder];
    }

    if (_currentOpType == XTBleWriteOperationTypeImageStorageWrite && _imageStorageParamBytes.count > 0) {
        return [XTBleProtocol getBrushScreenOrder:0x01 paramBytes:_imageStorageParamBytes];
    }

    /* 其他情况 → 常规校验指令（区分单/双面）| Other cases → normal validation command (single/dual panel) */
    int cmdValue = 0x03; // 双面 | Dual panel
    if (_brushDataHexArrA.count == 0) cmdValue = 0x02; // 仅B面 | Only side B
    else if (_brushDataHexArrB.count == 0) cmdValue = 0x01; // 仅A面 | Only side A
    DLog(@"使用常规校验指令（模式：%@，批次：%ld/%ld）",
         isLargeBatch ? @"批量" : @"非批量", batchNumber, totalBatches);
    return [XTBleProtocol getUpdateOrder:0 value:cmdValue];
}

/**
 *  @brief 处理批次补包（发送设备标记为缺失的包）| Handle Batch Retransmit (Send Missing Packets)
 *  @param start 批次起始索引 | Batch start index
 *  @param end 批次结束索引 | Batch end index
 *  @param batchNumber 当前批次号 | Current batch number
 */
- (void)fixBatchPackagesFrom:(NSInteger)start
                          to:(NSInteger)end
                 batchNumber:(NSInteger)batchNumber {
    for (NSInteger i = start; i <= end; i++) {
        NSInteger batchIndex = i - start; /* 批次内相对索引 | Relative index in batch */
        /* 检查补包标记数组是否有效 | Check retransmit flag array validity */
        if (_fixWriteScreenHexDataArr && batchIndex < _fixWriteScreenHexDataArr.count) {
            int needFix = [_fixWriteScreenHexDataArr[batchIndex] intValue];
            if (needFix == 0) { /* 0=需要补包 | 0=need retransmit */
                /* 发送当前包的所有子包 | Send all sub-packets of current packet */
                NSMutableArray *page = _writeScreenHexDataArr[i];
                for (NSData *data in page) {
                    if (![self isReadyToSendBleData]) {
                        [self finishCurrentOperationWithBleDisconnected];
                        return;
                    }

                    [_currentPeripheral writeValue:data
                                 forCharacteristic:_writeCharacteristic
                                              type:CBCharacteristicWriteWithoutResponse];
                    [NSThread sleepForTimeInterval:0.005];
                }
                /* 推送补包日志 | Push retransmit log */
                [self pushDaskDetail:[NSString stringWithFormat:XTLS(@"XT_Retransmit_Packet_Format"), i+1, batchNumber] done:NO sucesss:NO];
            }
        }
    }
    [_fixWriteScreenHexDataArr removeAllObjects]; /* 清空补包标记（避免重复补包）| Clear retransmit flag */
}

/**
 *  @brief 初始化刷图时间（记录开始时间）| Init Screen Refresh Time (Record Start Time)
 */
- (void)initBrushTime {
    _scanDeviceTime = (long)[[NSDate date] timeIntervalSince1970] - _scanDeviceTime;
    _brushScreenTime = (long)[[NSDate date] timeIntervalSince1970];
    [self pushDaskDetail:XTLS(@"XT_Screen_Refreshing_image") done:NO sucesss:NO];
}

/**
 *  @brief 刷图成功处理（断开连接、更新状态、推送日志）| Screen Refresh Success Handle (Disconnect, Update State, Push Log)
 */
- (void)finishBrushSuccessfully {
    [self pushDaskDetail:XTLS(@"ScreenRefreshStart") done:NO sucesss:NO];
    if (_writeImageBlock) {
        _writeImageBlock(YES, nil);
    }
    [self disconnectCurrentPeripherals]; /* 断开蓝牙连接 | Disconnect BLE */
    _isWorking = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pushDaskDetail:XTLS(@"The task has been completed") done:YES sucesss:YES];
    });
    [NSThread sleepForTimeInterval:2.0]; /* 延迟断开，确保设备断开处理完成 | Delay to ensure device process complete */
}

#pragma mark - 通用辅助方法 | General Helper Methods
/**
 *  @brief 推送任务详情（加载/提示）| Push Task Detail (Loading/Alert)
 *  @param msg 提示信息 | Message
 *  @param done 是否完成 | Is done
 *  @param sucesss 是否成功 | Is success
 */
- (void)pushDaskDetail:(NSString *)msg done:(BOOL)done sucesss:(BOOL)sucesss {
    if (done) {
        [self alertMsg:msg];
    } else {
        [self showLoadingWithMsg: msg];
    }
}

/**
 *  @brief 显示提示信息 | Show Alert Message
 *  @param msg 提示信息 | Message
 */
- (void)alertMsg:(NSString *)msg {
    if (self.statusHandler) dispatch_async(dispatch_get_main_queue(), ^{ if (self.statusHandler) self.statusHandler(msg); });
    dispatch_async(dispatch_get_main_queue(), ^{
    });
}

/**
 *  @brief 显示加载信息 | Show Loading Message
 *  @param msg 加载信息 | Message
 */
- (void)showLoadingWithMsg:(NSString *)msg {
    if (self.statusHandler) dispatch_async(dispatch_get_main_queue(), ^{ if (self.statusHandler) self.statusHandler(msg); });
    if (_currentOpType == XTBleWriteOperationTypeListScan) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
    });
}

/**
 *  @brief 处理指令发送错误 | Handle Command Send Error
 *  @param value 错误码 | Error code
 *  @param cmd 指令码 | Command code
 */
- (void)handleErrorWithValue:(NSInteger)value cmd:(NSInteger)cmd {
    NSString *errorMsg;
    switch (value) {
        case 206:
            errorMsg = [NSString stringWithFormat:XTLS(@"XT_Command_Need_Signature_Format"), cmd];
            break;
        case 205:
            errorMsg = [NSString stringWithFormat:XTLS(@"XT_Command_Security_Failed_Format"), cmd];
            break;
        case 104:
            errorMsg = [NSString stringWithFormat:XTLS(@"XT_Command_Execution_Failed_Format"), cmd];
            break;
        default:
            errorMsg = [NSString stringWithFormat:XTLS(@"XT_Delete_Flash_Unknown_Error_Format"), cmd];
            break;
    }
    [self disconnectCurrentPeripherals];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self alertMsg:errorMsg];
    });
}

//MARK: lazyload | Lazy Loading
/**
 *  @brief 懒加载蓝牙中央管理器 | Lazy Load BLE Central Manager
 *  @return 蓝牙中央管理器 | BLE central manager
 */
- (CBCentralManager *)centralManager {
    if (!_centralManager){
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    }
    return _centralManager;
}

@end
