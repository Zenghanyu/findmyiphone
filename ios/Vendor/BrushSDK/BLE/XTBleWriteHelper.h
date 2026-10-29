//
//  XTBleWriteHelper.h
//  NewTool
//
//  Created by XTMacMini on 2025/3/7.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "XTDeviceConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief 蓝牙写入操作类型枚举 | BLE Write Operation Type Enum
 *  @discussion 定义蓝牙与电子纸设备交互的核心操作类型 | Define core operation types for BLE interaction with e-paper devices
 */
typedef NS_ENUM(NSUInteger, XTBleWriteOperationType) {
    XTBleWriteOperationTypeSacn        = 0,  ///< 扫描设备 | Scan Device
    XTBleWriteOperationTypeReadInfo    = 1,  ///< 读取电量/信号值等信息 | Read power/RSSI and other device info
    XTBleWriteOperationTypeWriteScreen = 2,  ///< 写屏+刷屏 | Write screen + refresh screen
    XTBleWriteOperationTypeOTA         = 3,  ///< OTA升级 | OTA Update
    XTBleWriteOperationTypeImageStorageWrite = 4, ///< 图片管理：写入指定图片槽 | Image storage: write slot
    XTBleWriteOperationTypeImageStorageCommand = 5, ///< 图片管理：删除/轮播控制 | Image storage: delete/carousel command
    XTBleWriteOperationTypeListScan = 6 ///< 绑定页：扫描附近设备列表 | Bind page: scan nearby device list
};

/**
 *  @brief 图片管理刷新标志 | Image Storage Refresh Flag
 */
typedef NS_ENUM(NSUInteger, XTImageStorageRefreshFlag) {
    XTImageStorageRefreshFlagSaveAndRefresh = 0, ///< 保存并立即刷新 | Save and refresh
    XTImageStorageRefreshFlagSaveOnly       = 1, ///< 仅保存 | Save only
    XTImageStorageRefreshFlagCarousel       = 2, ///< 轮播 | Carousel
    XTImageStorageRefreshFlagSchedule       = 3, ///< 定时任务 | Schedule task
    XTImageStorageRefreshFlagDelete         = 4  ///< 删除图片 | Delete image
};

/**
 *  @brief FindMy功能操作类型枚举 | FindMy Function Operation Type Enum
 *   当findmy 和 刷图
 */
typedef NS_ENUM(NSUInteger, XTFindMyOperationType) {
    XT_OP_DISCONNECT        = 1,  ///< 切换模式 | Switch Mode
};

/**
 *  @brief 扫描设备完成的回调Block类型 | Block Type for Scan Device Completion
 *  @param deviceConfig 扫描到的设备配置信息（未扫描到则为nil）| Scanned device configuration info (nil if not found)
 *  @param error 扫描过程中的错误信息（无错误则为nil）| Error info during scanning (nil if no error)
 */
typedef void(^XTScanDeviceCompletionBlock)(XTDeviceConfig * _Nullable deviceConfig, NSError * _Nullable error);

@class XTBleScannedDevice;

typedef void(^XTScannedDeviceUpdateBlock)(XTBleScannedDevice *device);
typedef void(^XTScannedDeviceCompletionBlock)(NSArray<XTBleScannedDevice *> *devices, NSError * _Nullable error);

@interface XTBleScannedDevice : NSObject<NSCopying>

@property (nonatomic, copy) NSString *mac;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *rssi;
@property (nonatomic, assign) NSInteger deviceNumber;
@property (nonatomic, assign) NSInteger screenWidth;
@property (nonatomic, assign) NSInteger screenHeight;
@property (nonatomic, copy) NSString *colorText;
@property (nonatomic, copy) NSString *supportMessage;
@property (nonatomic, assign) BOOL supported;
@property (nonatomic, strong, nullable) XTDeviceConfig *deviceConfig;

- (NSString *)resolutionText;

@end

/**
 *  @brief 蓝牙广播数据回调Block类型 | Block Type for BLE Advertisement Data Callback
 *  @param RSSI 设备信号强度值 | Device RSSI value
 *  @param power 设备电量值 | Device power value
 *  @param version 设备固件版本 | Device firmware version
 */
typedef void(^XTAdvertisementDataBack)(NSString *RSSI, NSString *power, NSString *version);

/**
 *  @brief 写图操作完成的回调Block类型 | Block Type for Write Image Operation Completion
 *  @param isSuccess 写图操作是否成功 | Whether the write image operation is successful
 *  @param error 写图过程中的错误信息（无错误则为nil）| Error info during write image (nil if no error)
 */
typedef void(^XTWriteImageBlock)(BOOL isSuccess, NSString * _Nullable error);

/**
 *  @brief 蓝牙写入助手（单例类）| BLE Write Helper (Singleton Class)
 *  @discussion 负责处理蓝牙设备的图像导入、OTA升级、设备信息读取、Token读写等核心操作，统一管理蓝牙写入流程
 *              Responsible for handling core operations such as image import, OTA update, device info reading, Token read/write for BLE devices, and unified management of BLE write processes
 */
@interface XTBleWriteHelper : NSObject

/// EasyFind integration: transport status only; SDK never presents application UI.
@property (nonatomic, copy, nullable) void (^statusHandler)(NSString *message);
@property (nonatomic, copy, nullable) void (^progressHandler)(double progress);

/**
 *  @brief 是否正在进行读取操作 | Whether a reading operation is in progress
 */
@property (nonatomic, assign) BOOL isWorking;

#pragma mark - 单例方法 | Singleton Method

/**
 *  @brief 获取单例实例 | Get Singleton Instance
 *  @discussion 全局唯一的XTBleWriteHelper实例，确保蓝牙操作的统一管理
 *              Globally unique XTBleWriteHelper instance to ensure unified management of BLE operations
 *  @return 共享的XTBleWriteHelper实例 | Shared XTBleWriteHelper instance
 */
+ (instancetype)shareInstance;

/**
 *  @brief 断开当前已连接的蓝牙外设 | Disconnect Current Connected BLE Peripheral
 *  @discussion 主动断开与当前蓝牙设备的连接，释放外设资源
 *              Actively disconnect from the current BLE device and release peripheral resources
 */
- (void)disconnectCurrentPeripherals;

#pragma mark - 核心操作方法 | Core Operation Methods

/**
 *  @brief 根据MAC地址扫描指定蓝牙设备 | Scan Specified BLE Device by MAC Address
 *  @param targetMac 目标设备的MAC地址字符串 | MAC address string of the target device
 *  @param completion 扫描完成后的回调Block | Completion block after scanning
 */
- (void)startScanWithTargetMac:(NSString *)targetMac
                    completion:(XTScanDeviceCompletionBlock)completion;

/**
 *  @brief 扫描附近可绑定设备列表（20秒单次扫描，不连接设备）| Scan nearby bindable devices (20s once, no connection)
 *  @param update 扫描到或解析完成单个设备时回调 | Called when a device is discovered or resolved
 *  @param completion 扫描结束回调 | Called when scan finishes
 */
- (void)scanAvailableDevicesWithUpdate:(nullable XTScannedDeviceUpdateBlock)update
                            completion:(nullable XTScannedDeviceCompletionBlock)completion;

/**
 *  @brief 导入图像数据到设备（单面板写屏+刷屏操作）| Import Image Data to Device (Single-panel Write Screen + Refresh Screen)
 *  @param imageHexDataArr 图像数据的十六进制分包数组（已按指定大小拆分的数据包）| Hex packet array of image data (data packets split by specified size)
 *  @param deviceConfig 写屏时的设备配置信息（用于校验与当前连接设备是否匹配）| Device configuration info for screen writing (used to verify match with current connected device)
 *  @param sendSize 每次发送的分包大小（需根据设备性能调整，建议244或490；490适用于手机壳设备）| Packet size per transmission (adjust according to device performance, recommended 244 or 490; 490 is suitable for phone case devices)
 *  @param writeImageBlock 写图操作完成后的回调Block | Completion block after write image operation
 *  @param rssi 蓝牙广播数据（RSSI/电量/版本）的回调Block | Callback block for BLE advertisement data (RSSI/power/version)
 */
- (void)importImageDataToDeviceWithImageHexDataArr:(NSMutableArray *)imageHexDataArr
                                      deviceConfig:(XTDeviceConfig *)deviceConfig
                                          sendSize:(NSInteger)sendSize
                                   writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                           advData:(nullable XTAdvertisementDataBack)rssi;

/**
 *  @brief 导入双面图像数据到设备（双面板写屏+刷屏操作）| Import Double-sided Image Data to Device (Dual-panel Write Screen + Refresh Screen)
 *  @param hexDataArrA A面图像数据的十六进制分包数组（已按指定大小拆分的数据包）| Hex packet array of side A image data (data packets split by specified size)
 *  @param hexDataArrB B面图像数据的十六进制分包数组（已按指定大小拆分的数据包）| Hex packet array of side B image data (data packets split by specified size)
 *  @param deviceConfig 写屏时的设备配置信息（用于校验与当前连接设备是否匹配）| Device configuration info for screen writing (used to verify match with current connected device)
 *  @param sendSize 每次发送的分包大小（需根据设备性能调整，建议244或490；490适用于手机壳设备）| Packet size per transmission (adjust according to device performance, recommended 244 or 490; 490 is suitable for phone case devices)
 *  @param writeImageBlock 写图操作完成后的回调Block | Completion block after write image operation
 *  @param advData 蓝牙广播数据（RSSI/电量/版本）的回调Block | Callback block for BLE advertisement data (RSSI/power/version)
 */
- (void)importImageDataToDeviceWithImageHexDataArrA:(NSMutableArray *)hexDataArrA
                                        hexDataArrB:(NSMutableArray *)hexDataArrB
                                       deviceConfig:(XTDeviceConfig *)deviceConfig
                                           sendSize:(NSInteger)sendSize
                                    writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                            advData:(nullable XTAdvertisementDataBack)advData;

/**
 *  @brief 导入OTA升级数据到设备（OTA升级操作）| Import OTA Update Data to Device (OTA Update Operation)
 *  @param otaHexData OTA升级数据的十六进制分包数组（已按指定大小拆分的数据包）| Hex packet array of OTA update data (data packets split by specified size)
 *  @param deviceConfig 设备配置信息（用于校验与当前连接设备是否匹配）| Device configuration info (used to verify match with current connected device)
 *  @param sendSize 每次发送的分包大小 | Packet size per transmission
 */
- (void)importOTADataToDeviceWithOtaHexData:(NSMutableArray *)otaHexData
                               deviceConfig:(XTDeviceConfig *)deviceConfig
                                   sendSize:(NSInteger)sendSize;

/**
 *  @brief 图片管理：将图片保存到设备指定槽位 | Image storage: save image to specified slot
 *  @param imageHexDataArr 图像数据数组 | Image data array
 *  @param deviceConfig 设备配置信息 | Device config
 *  @param sendSize 每次发送的分包大小 | Packet size per transmission
 *  @param imageIndex 图片槽位，1~6 | Image slot, 1~6
 *  @param refreshFlag 刷新标志，通常传保存并立即刷新或仅保存 | Refresh flag, usually save+refresh or save only
 *  @param param 附加参数；保存图片时传0 | Extra param; pass 0 when saving image
 *  @param writeImageBlock 完成回调 | Completion callback
 *  @param advData 广播信息回调 | Advertisement data callback
 */
- (void)importImageStorageDataToDeviceWithImageHexDataArr:(NSMutableArray *)imageHexDataArr
                                             deviceConfig:(XTDeviceConfig *)deviceConfig
                                                 sendSize:(NSInteger)sendSize
                                               imageIndex:(NSInteger)imageIndex
                                              refreshFlag:(XTImageStorageRefreshFlag)refreshFlag
                                                    param:(NSInteger)param
                                          writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                                  advData:(nullable XTAdvertisementDataBack)advData;

/**
 *  @brief 图片管理：删除指定槽位图片 | Image storage: delete specified image slots
 *  @param imageIndexes 图片槽位数组，元素范围1~6 | Image slots, values 1~6
 */
- (void)deleteImageStorageSlotsWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                                   imageIndexes:(NSArray<NSNumber *> *)imageIndexes
                                writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                        advData:(nullable XTAdvertisementDataBack)advData;

/**
 *  @brief 图片管理：更新轮播配置 | Image storage: update carousel config
 *  @param startIndex 起始槽位，1~6 | Start slot, 1~6
 *  @param intervalMinutes 轮播间隔，1~255分钟；0表示关闭轮播 | Carousel interval, 1~255 minutes; 0 stops carousel
 */
- (void)updateImageStorageCarouselWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                                        startIndex:(NSInteger)startIndex
                                   intervalMinutes:(NSInteger)intervalMinutes
                                   writeImageBlock:(XTWriteImageBlock)writeImageBlock
                                           advData:(nullable XTAdvertisementDataBack)advData;

/**
 *  @brief 读取设备电量、信号强度等信息 | Read Device Power, RSSI and Other Info
 *  @param deviceConfig 当前连接的设备配置信息 | Current connected device configuration info
 *  @param advData 设备信息读取完成后的回调Block（返回RSSI/电量/版本）| Callback block after reading device info (returns RSSI/power/version)
 */
- (void)readPowerAndRssiWithDevice:(XTDeviceConfig *)deviceConfig
                           advData:(XTAdvertisementDataBack)advData;

@end

NS_ASSUME_NONNULL_END
