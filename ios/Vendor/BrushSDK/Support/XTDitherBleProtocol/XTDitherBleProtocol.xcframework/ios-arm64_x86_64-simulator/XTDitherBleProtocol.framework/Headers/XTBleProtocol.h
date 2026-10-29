//
//  XTBleProtocol.h
//  XTBleProtocol
//
//  Created by xthh on 2024/6/19.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "XTImageDataProcessType.h"

@class XTSendPicDataInfo;
@class XTBleResultDataModel;

@interface XTBleProtocol : NSObject

// 定义一个结构体 TagBindInfo，用于存储设备的绑定信息
// Defines TagBindInfo for device binding information.
typedef struct TagBindInfo {
    // 设备的 MAC 地址，使用 NSString 类型存储
    // Device MAC address.
    NSString *mac;
    // 设备的颜色信息，使用 NSString 类型存储
    // Device color information.
    NSString *color;
    // 兼容旧 NFC 格式字段；当前选屏幕流程不使用
    // Legacy NFC field; not used by current screen-selection flow.
    NSInteger deviceNumber;
    // 设备屏幕的宽度，使用 NSInteger 类型存储
    // Device screen width.
    NSInteger width;
    // 设备屏幕的高度，使用 NSInteger 类型存储
    // Device screen height.
    NSInteger height;
    // 屏幕类型，0 表示点阵屏，1 表示 prism 屏
    // Screen type: 0 = dot-matrix screen, 1 = prism screen.
    NSInteger screenType;
    // 旋转类型，0 表示 0 度，1 表示 90 度，2 表示 180 度，3 表示 70 度
    // Rotation type: 0 = 0 degrees, 1 = 90 degrees, 2 = 180 degrees, 3 = 70 degrees.
    NSInteger rotationType;
    // 水平镜像类型，1 表示镜像
    // Horizontal mirror flag: 1 = mirrored.
    NSInteger mirrorHorType;
    // 垂直镜像类型，1 表示镜像
    // Vertical mirror flag: 1 = mirrored.
    NSInteger mirrorVerType;
    // 操作结果，true 表示获取成功
    // Operation result: true means success.
    bool result;
} TagBindInfo;

// MARK: ========================================    数据处理    ========================================

/**
 * 从 NFC 中获取需要的绑定信息。
 * Gets required binding information from NFC payload.
 * @param info NFC 中的信息 / NFC payload string.
 * @return 解析得到的绑定信息结构体 / Parsed binding information.
 */
+ (TagBindInfo)getNFCTagBindInfo:(NSString *)info;

/**
 * 导入图片数据（二维数组），传出分包后的图片数据。
 * Converts 2D image data into paged packets for transmission.
 * 示例 表示图片宽5像素，高2像素，其中每一行颜色分别是“黑白红黄黑白”
 * Example: width 5 px, height 2 px, each row uses color indexes.
 012301
 012301
 *
 * 默认 RGB 值与序号对应关系如下 黑 0，白 1，红 2，黄 3
 * 颜色类型，黑白 - 0，黑白黄 - 1，黑白红 - 2，黑白红黄 - 3，NCOLOR - 4，E6 - 5
 * Default RGB index mapping: black 0, white 1, red 2, yellow 3.
 * Color type: BW = 0, BWY = 1, BWR = 2, BWRY = 3, NCOLOR = 4, E6 = 5.
 * @param data 传入的图片数据，二维数组形式 / Input 2D image data.
 * @param width 图片的宽度 / Image width.
 * @param height 图片的高度 / Image height.
 * @param deviceColorType 设备的颜色类型 / Device color type.
 * @param pageSize 每个包的大小 / Packet size.
 * @param isNeedCompress 是否需要压缩 / Whether compression is required.
 * @return 分包后的图片数据，每一包还分 <=5 个子包 / Paged packet data, each page contains up to five sub-packets.
 */
+ (NSMutableArray *)getPicSendPageData:(NSMutableArray *)data
                              picWidth:(int)width
                             picHeight:(int)height
                       deviceColorType:(int)deviceColorType
                              pageSize:(int)pageSize
                        isNeedCompress:(BOOL)isNeedCompress;

/**
 * 导入图片数据（二维数组），按指定处理类型传出分包后的图片数据。
 * Converts 2D image data into paged packets with the specified packing mode.
 */
+ (NSMutableArray *)getPicSendPageData:(NSMutableArray *)data
                              picWidth:(int)width
                             picHeight:(int)height
                       deviceColorType:(int)deviceColorType
                              pageSize:(int)pageSize
                        isNeedCompress:(BOOL)isNeedCompress
                  imageDataProcessType:(XTImageDataProcessType)imageDataProcessType;

/**
 * 兼容旧调用，deviceNumber 不再参与刷图数据判断。
 * Legacy API. deviceNumber is ignored by image packing logic.
 */
+ (NSMutableArray *)getPicSendPageData:(NSMutableArray *)data
                              picWidth:(int)width
                             picHeight:(int)height
                       deviceColorType:(int)deviceColorType
                              pageSize:(int)pageSize
                        isNeedCompress:(BOOL)isNeedCompress
                          deviceNumber:(NSInteger)deviceNumber;

// 原生数据，不压缩、不分包
// Raw image data without compression or paging.
+ (NSMutableArray *)getPicData:(NSMutableArray *)data
                      picWidth:(int)width
                     picHeight:(int)height
               deviceColorType:(int)deviceColorType
                      pageSize:(int)pageSize
                isNeedCompress:(BOOL)isNeedCompress;

// 原生数据，不压缩、不分包，可指定刷图数据打包处理类型
// Raw image data without compression or paging, using the specified packing mode.
+ (NSMutableArray *)getPicData:(NSMutableArray *)data
                      picWidth:(int)width
                     picHeight:(int)height
               deviceColorType:(int)deviceColorType
                      pageSize:(int)pageSize
                isNeedCompress:(BOOL)isNeedCompress
          imageDataProcessType:(XTImageDataProcessType)imageDataProcessType;

// 兼容旧调用，deviceNumber 不再参与刷图数据判断。
// Legacy API. deviceNumber is ignored by image packing logic.
+ (NSMutableArray *)getPicData:(NSMutableArray *)data
                      picWidth:(int)width
                     picHeight:(int)height
               deviceColorType:(int)deviceColorType
                      pageSize:(int)pageSize
                isNeedCompress:(BOOL)isNeedCompress
                  deviceNumber:(NSInteger)deviceNumber;

/**
 * 将 LCD 原图转换为 RGB565 大端字节数据，不做抖点。
 * Converts a source LCD image to RGB565 big-endian bytes without dithering.
 *
 * @param inputImage 原始图片，调用方应先缩放到屏幕分辨率 / Source image, expected to match screen resolution.
 * @param mirrorHorizontally 是否水平镜像 / Whether to mirror horizontally.
 * @param mirrorVertical 是否垂直镜像 / Whether to mirror vertically.
 * @return RGB565 大端字节数组，格式为 [高1, 低1, 高2, 低2, ...] / RGB565 big-endian byte array.
 */
+ (NSMutableArray<NSNumber *> *)getLCDRGB565DataWithImage:(UIImage *)inputImage
                                      mirrorHorizontally:(BOOL)mirrorHorizontally
                                          mirrorVertical:(BOOL)mirrorVertical;

/**
 * 将 RGB565 大端字节数据转换为 LCD 双字节 RLE 数据。
 * Converts RGB565 big-endian bytes to LCD double-byte RLE data.
 *
 * 输入格式：[高1, 低1, 高2, 低2, ...]，输出格式：[数量, 颜色高, 颜色低]。
 * Input format: [high1, low1, high2, low2, ...]. Output format: [count, high, low].
 *
 * @param rgb565Data RGB565 大端字节数组 / RGB565 big-endian byte array.
 * @return RLE 压缩后的字节数组，每 1365 组后补 0 对齐 4096 字节段 / RLE byte array with 4096-byte segment padding.
 */
+ (NSMutableArray<NSNumber *> *)getLCDRLEDataFromRGB565Data:(NSArray<NSNumber *> *)rgb565Data;

/**
 * 将 LCD 原图直接转换为带 XTEK 图片格式头的 RLE 字节数据，不做抖点。
 * Converts a source LCD image directly to XTEK-wrapped RLE byte data without dithering.
 *
 * 内部流程：UIImage -> RGB565 大端 -> 双字节 RLE -> XTEK 图片格式头。
 * Internal flow: UIImage -> RGB565 big-endian -> double-byte RLE -> XTEK image header.
 *
 * @param inputImage 原始图片，调用方应先缩放到屏幕分辨率 / Source image, expected to match screen resolution.
 * @param mirrorHorizontally 是否水平镜像 / Whether to mirror horizontally.
 * @param mirrorVertical 是否垂直镜像 / Whether to mirror vertically.
 * @return 带图片格式头的 RLE 字节数据，可直接作为 LCD 图像数据传输 / XTEK-wrapped RLE byte data ready as LCD image payload.
 */
+ (NSData *)getLCDUploadDataWithImage:(UIImage *)inputImage
                  mirrorHorizontally:(BOOL)mirrorHorizontally
                      mirrorVertical:(BOOL)mirrorVertical;

/**
 * 将 LCD 原图直接转换为可传输分包数据，不做抖点。
 * Converts a source LCD image directly to paged transmission data without dithering.
 *
 * 内部流程：UIImage -> RGB565 大端 -> 双字节 RLE -> XTEK 图片格式头 -> 协议分包。
 * Internal flow: UIImage -> RGB565 big-endian -> double-byte RLE -> XTEK image header -> protocol pages.
 *
 * @param inputImage 原始图片，调用方应先缩放到屏幕分辨率 / Source image, expected to match screen resolution.
 * @param pageSize 每个小包大小 / Packet size.
 * @param mirrorHorizontally 是否水平镜像 / Whether to mirror horizontally.
 * @param mirrorVertical 是否垂直镜像 / Whether to mirror vertically.
 * @return 可直接传输的分包数据 / Paged data ready for transmission.
 */
+ (NSMutableArray *)getLCDSendPageDataWithImage:(UIImage *)inputImage
                                       pageSize:(int)pageSize
                           mirrorHorizontally:(BOOL)mirrorHorizontally
                               mirrorVertical:(BOOL)mirrorVertical;

/**
 * 导入图片数据（二维数组），传出分包后的图片数据。
 * Converts two image payloads into paged packets for dual-sided screens.
 * 示例 表示图片宽5像素，高2像素，其中每一行颜色分别是“黑白红黄黑白”
 * Example: width 5 px, height 2 px, each row uses color indexes.
 012301
 012301
 *
 * 默认 RGB 值与序号对应关系如下 黑 0，白 1，红 2，黄 3
 * 颜色类型，黑白 - 0，黑白黄 - 1，黑白红 - 2，黑白红黄 - 3，NCOLOR - 4，E6 - 5
 * Default RGB index mapping: black 0, white 1, red 2, yellow 3.
 * Color type: BW = 0, BWY = 1, BWR = 2, BWRY = 3, NCOLOR = 4, E6 = 5.
 *
 * @param dataOne 图片1数据（双面屏使用，单张图时赋值 picOne）/ Image 1 data; for dual-sided screens, use picOne when only one image is sent.
 * @param dataTwo 图片2数据 / Image 2 data.
 *
 * @return 分包后的图片数据，每一包还分 <=5 个子包 / Paged packet data, each page contains up to five sub-packets.
 */
+ (NSMutableArray *)getPicSendPageDataOne:(XTSendPicDataInfo *)dataOne
                                  dataTwo:(XTSendPicDataInfo *)dataTwo;

/**
 * 获取 Prism 屏刷图的分包数据。
 * Gets paged image packets for prism screen refresh.
 * @param data 传入的图片数据 / Input image data.
 * @param pageSize 每个包的大小 / Packet size.
 * @return 分包后的图片数据 / Paged image data.
 */
+ (NSMutableArray *)getPrismSendPageData:(NSMutableArray *)data pageSize:(int)pageSize;

/**
 * 获取 OTA 升级的分包数据。
 * Gets paged packets for OTA upgrade data.
 * @param data 传入的升级数据 / Input upgrade data.
 * @param pageSize 每个包的大小 / Packet size.
 * @return 分包后的升级数据 / Paged upgrade data.
 */
+ (NSMutableArray *)getOTASendPageData:(NSMutableArray *)data pageSize:(int)pageSize;

/**
 * 获取写入防丢器 Token 的分包数据。
 * Gets paged packets for writing an anti-loss tracker token.
 * @param token 写入的 token / Token to write.
 * @param pageSize 每个包的大小 / Packet size.
 * @return 分包后的 token 数据 / Paged token data.
 */
+ (NSMutableArray *)getFindMyTokenSendPageData:(NSString *)token pageSize:(int)pageSize;

/**
 * 获取需要清空的缓冲区长度。
 * Gets the flash buffer length that needs to be cleared.
 * @param data 传入的数据 / Input data.
 * @return 需要清空的缓冲区长度 / Buffer length to clear.
 */
+ (NSInteger)getDeleteFlashLength:(NSMutableArray *)data;

// MARK: ========================================    抖点    ========================================
/**
 *
 * 将 UIImage 转换为算法结果。
 * Converts a UIImage into algorithm output.
 *
 * 该方法处理输入图像，应用指定的算法和转换，返回直接二进制数据和取数图。
 * 返回的 NSData 主要用于纯 NFC 直接数据场景；普通 BLE 刷图必须使用 previewImage 提取索引并生成分包。
 * 界面预览必须使用带 thresholdImage 的方法返回的 thresholdImage。
 * This method processes the input image, applies the selected algorithm and transforms,
 * then returns direct binary data and an optional data-extraction image.
 * The returned NSData is mainly for pure NFC direct-data flows. For normal BLE refresh,
 * previewImage must be used to extract palette indexes and build BLE pages.
 *
 * @param inputImage 需要转换的原始图像 / Source image to convert.
 * @param previewImage 输出参数，用于返回 BLE 取刷图数据的图 / Output image pointer for BLE data extraction.
 * @param colorDic 支持色字典，用于告诉 SDK 当前设备支持哪些颜色 / Supported color dictionary.
 * @param scanType 扫描模式（0=垂直扫描，1=水平扫描）/ Scan mode: 0 = vertical, 1 = horizontal.
 * @param combineType 图像合成模式（0=替换，1=叠加，2=混合）/ Composition mode: 0 = replace, 1 = overlay, 2 = blend.
 * @param writeImageCount 写入图像序列中的位置索引 / Image slot index to write.
 * @param flipHorizontal 是否水平翻转图像 / Whether to flip horizontally.
 * @param flipVertical 是否垂直翻转图像 / Whether to flip vertically.
 * @param screenColorCode 设备颜色支持代码（"20" 黑白，"30" 黑白红，"31" 黑白黄，"40" 黑白红黄，"60" 黑白红黄绿蓝）/ Device color code.
 * @param algType 算法类型（1=抖点，2=色阶）/ Algorithm type: 1 = dither, 2 = color level.
 *
 * @return 转换后的直接二进制数据，主要用于纯 NFC，失败返回 nil / Direct converted binary data mainly for pure NFC, or nil on failure.
 *
 */
+ (NSData *)getUploadDataWithImage:(UIImage *)inputImage
                      previewImage:(UIImage **)previewImage
                          colorDic:(NSDictionary *)colorDic
                          scanType:(int)scanType
                       combineType:(int)combineType
                   writeImageCount:(int)writeImageCount
                    flipHorizontal:(BOOL)flipHorizontal
                      flipVertical:(BOOL)flipVertical
                   screenColorCode:(NSString *)screenColorCode
                           algType:(NSString *)algType;

// 同上，额外通过 thresholdImage 返回界面预览图。
// Same as above, with an extra threshold/palette preview image output for display.
+ (NSData *)getUploadDataWithImage:(UIImage *)inputImage
                      previewImage:(UIImage **)previewImage
                    thresholdImage:(UIImage **)thresholdImage
                          colorDic:(NSDictionary *)colorDic
                          scanType:(int)scanType
                       combineType:(int)combineType
                   writeImageCount:(int)writeImageCount
                    flipHorizontal:(BOOL)flipHorizontal
                      flipVertical:(BOOL)flipVertical
                   screenColorCode:(NSString *)screenColorCode
                           algType:(NSString *)algType;

/**
 *
 * 复旦微 NFC 图片数据转换。
 * Converts a UIImage into the NFC/Fudan Micro transmission format.
 *
 * 该方法处理输入图像，应用指定的算法和转换，生成纯 NFC 可写入的二进制数据。
 * previewImage 必须用于返回 BLE 取刷图数据的图像；界面预览必须使用带 thresholdImage 的方法返回的 thresholdImage。
 * This method processes the input image, applies the selected algorithm and transforms,
 * then returns writable NFC binary data and an optional BLE data-extraction image.
 *
 * @param inputImage 需要转换的原始图像 / Source image to convert.
 * @param previewImage 输出参数，用于返回 BLE 取刷图数据的图 / Output image pointer for BLE data extraction.
 * @param colorDic 支持色字典，用于告诉 SDK 当前设备支持哪些颜色 / Supported color dictionary.
 * @param scanType 扫描模式（0=垂直扫描，1=水平扫描）/ Scan mode: 0 = vertical, 1 = horizontal.
 * @param combineType 图像合成模式（0=替换，1=叠加，2=混合）/ Composition mode: 0 = replace, 1 = overlay, 2 = blend.
 * @param writeImageCount 写入图像序列中的位置索引 / Image slot index to write.
 * @param flipHorizontal 是否水平翻转图像 / Whether to flip horizontally.
 * @param flipVertical 是否垂直翻转图像 / Whether to flip vertically.
 * @param isZhiHuiXin 是否使用 nfc 支持方案 / Whether to use the NFC support path.
 * @param imageAlgo NFC 图片算法类型 / NFC image algorithm type.
 * @param screenWidth 屏幕宽度 / Screen width.
 * @param screenHeight 屏幕高度 / Screen height.
 * @param screenColorCode 设备颜色支持代码（"20" 黑白，"30" 黑白红，"31" 黑白黄，"40" 黑白红黄，"60" 黑白红黄绿蓝）/ Device color code.
 * @param algType 算法类型（1=抖点，2=色阶）/ Algorithm type: 1 = dither, 2 = color level.
 *
 * @return 转换后的 NFC 直接二进制数据，失败返回 nil / Converted NFC direct binary data, or nil on failure.
 *
 */
+ (NSData *)getNFCUploadDataWithImage:(UIImage *)inputImage
                         previewImage:(UIImage **)previewImage
                             colorDic:(NSDictionary *)colorDic
                             scanType:(int)scanType
                          combineType:(int)combineType
                      writeImageCount:(int)writeImageCount
                       flipHorizontal:(BOOL)flipHorizontal
                         flipVertical:(BOOL)flipVertical
                          isZhiHuiXin:(BOOL)isZhiHuiXin
                            imageAlgo:(int)imageAlgo
                          screenWidth:(int)screenWidth
                         screenHeight:(int)screenHeight
                      screenColorCode:(NSString *)screenColorCode
                              algType:(NSString *)algType;

// 同上，额外通过 thresholdImage 返回界面预览图。
// Same as above, with an extra threshold/palette preview image output for display.
+ (NSData *)getNFCUploadDataWithImage:(UIImage *)inputImage
                         previewImage:(UIImage **)previewImage
                       thresholdImage:(UIImage **)thresholdImage
                             colorDic:(NSDictionary *)colorDic
                             scanType:(int)scanType
                          combineType:(int)combineType
                      writeImageCount:(int)writeImageCount
                       flipHorizontal:(BOOL)flipHorizontal
                         flipVertical:(BOOL)flipVertical
                          isZhiHuiXin:(BOOL)isZhiHuiXin
                            imageAlgo:(int)imageAlgo
                          screenWidth:(int)screenWidth
                         screenHeight:(int)screenHeight
                      screenColorCode:(NSString *)screenColorCode
                              algType:(NSString *)algType;

// 获取颜色字典
// Gets the color dictionary for a screen color code.
+ (NSDictionary *)getColorDictFormColorCode:(NSString *)code;

/**
 * 查找最接近的颜色。
 * Finds the nearest color in the provided color table.
 * @param rgbPixel 像素的 RGB 值数组 / RGB values of the source pixel.
 * @param rgbTripleArray 颜色数组 / Candidate RGB color table.
 * @return 最接近颜色的序号 / Index of the nearest color.
 */
+ (UInt8)findNearestColor:(NSArray *)rgbPixel rgbTripleArray:(NSArray *)rgbTripleArray;

/**
 * 对两个无符号 8 位整数进行加法运算，并处理溢出。
 * Adds two values with unsigned 8-bit truncation.
 * @param a 第一个无符号 8 位整数 / First unsigned 8-bit value.
 * @param b 第二个整数 / Second integer value.
 * @return 加法运算结果，处理溢出 / Truncated addition result.
 */
+ (UInt8)plusTruncateUChar:(UInt8)a b:(int)b;

// MARK: ========================================    指令    ========================================

/**
 * 0x01 指令：获取删除 FLASH 的指令。
 * Command 0x01: builds a delete-FLASH command.
 * @param size 删除的大小 / Size to delete.
 * @return 删除 FLASH 的指令字符串 / Delete-FLASH command string.
 */
+ (NSString *)getDeleteFlashOrder:(int)size;

/**
 * 0x01 指令（大于 300K）：获取删除 FLASH 的指令。
 * Command 0x01 for payloads larger than 300 KB: builds a delete-FLASH command.
 * @param Alllenth 4 字节，所有批量包的总字节大小 / 4 bytes, total batch size.
 * @param offset 4 字节，当前包的偏移 / 4 bytes, current packet offset.
 * @param currentLen 4 字节，当前批量包的字节大小 / 4 bytes, current batch length.
 * @return 删除 FLASH 的指令字符串 / Delete-FLASH command string.
 */
+ (NSString *)getDeleteFlashOrderWithAllBtyeLenth:(NSInteger)Alllenth
                                           offset:(NSInteger)offset
                                       currentLen:(NSInteger)currentLen;

/**
 * 0x02 指令：获取发送数据校验指令。
 * Command 0x02: gets verification data for the current batch when the payload is larger than 300 KB.
 * @return prism 校验指令 / Prism verification command.
 */
+ (NSString *)getBitmapAndFixDataOrder;

/**
 * 0x04 指令：获取 prism 屏刷图的临时指令。
 * Command 0x04: builds a temporary prism screen refresh command.
 * @param index 指令的索引 / Command index.
 * @return prism 屏刷图的临时指令字符串 / Temporary prism refresh command string.
 */
+ (NSString *)getPrismBrushOrder:(int)index;

/**
 * 0x04 指令：获取通知屏幕刷新、获取补包信息指令。
 * Command 0x04: builds a screen refresh or packet-repair query command.
 * @param type 刷新的类型 / Refresh type.
 * @param value 刷新的值 / Refresh value.
 * @return 刷新指令字符串 / Refresh command string.
 */
+ (NSString *)getUpdateOrder:(int)type value:(int)value;

/**
 * 0x04 指令：校验数据完整性，数据完整后开启刷图。
 * Command 0x04: verifies data integrity and starts screen refresh after verification succeeds.
 *
 * @param type 刷新类型（1B）/ Refresh type (1 byte).
 * 单面推图：0:无参数
           1:带参数
 * 消息：       2:无参数
 * 双面推图：3:带参数
 * prism推图: 4:带参数
 * Android手机壳推图：5：带参数
 *
 * @param paramBytes 参数字节（4B，10进制）/ Parameter bytes (4 bytes, decimal values).
 *=>1.单面推图：图片序号（1B）+刷新标志（1B）+ 参数
 *  图片序号：1 ~ 6， 0 时图片全删除
 *  刷新标志：0: 保存并立即刷新，1: 保存但不刷新  2：图片轮播   3：定时任务  4：删除图片
 *  参    数：图片轮播（1B）： 1-255分钟     定时任务（2B）： 时分
 *
 *=>3.双面推图：1:A面，2：B面，3 ：A+B面， 4：A+B面出厂图（标签默认保存该图片）
 *
 *=>4.prism推图：动画类型（1B）: 0:无动画；1-255：不同动画类型
 *
 *=>5.Android手机壳推图：EPD驱动参数： e.g.（T040D002）：高电量：0x1E;  低电量：0x23;
 *
 * @return 刷新指令 / Refresh command string.
 */
+ (NSString *)getBrushScreenOrder:(int)type paramBytes:(NSArray *)paramBytes;

/**
 * 0x05 指令：启动升级 OTA。
 * Command 0x05: starts OTA upgrade.
 * @return 启动升级 OTA 的指令字符串 / OTA start command string.
 */
+ (NSString *)startHardwareUpdateOrder;

/**
 * 0x13 指令：获取手机壳刷图指令。
 * Command 0x13: builds a phone-case image refresh command.
 * @return 刷图指令字符串 / Image refresh command string.
 */
+ (NSString *)getPicRefreshOrder;

/**
 * 0x16 命令（0x15 命令冲突废弃）：Find My 操作命令。
 * Command 0x16 (0x15 is deprecated due to command conflict): Find My operation command.
 * @param cmd 0x16 命令 / Command value 0x16.
 * @param opAndParam 操作类型 + 附加参数 / Operation type plus optional parameters:
 *                   - 传 XT_OP_DISCONNECT（1）= 断开连接（无需附加参数）
 *                   - 传 XT_OP_READ_PARAM（2）= 读取参数（无需附加参数）
 *                   - 传 XT_OP_WRITE_PARAM（3）= 写入参数 (无需附加参数）
 * @return 指令字符串 / Command string.
 */
+ (NSString *)startFindMyOperationOrderWithCmd:(int)cmd
                                    opAndParam:(int)opAndParam;

/**
 * 0x0E 命令：桌牌清屏命令。
 * Command 0x0E: clears a table-card screen.
 * @return 桌牌清屏命令 / Table-card clear-screen command.
 */
+ (NSString *)getNameCardClearOrder;

/**
 * 0x18 命令：配置密钥命令（仅用于手机壳项目）。
 * Command 0x18: configures keys for the phone-case project.
 * @param type 0x00 初始化密钥，0x01 写入 App 公钥，0x02 读取设备公钥 / 0x00 init key, 0x01 write app public key, 0x02 read device public key.
 * @param param 初始化 0B，写入 App 公钥 64B，读取 0B / init: 0B, write app public key: 64B, read: 0B.
 *
 * 指令返回
 * 错误码（第7字节） 255指令执行成功    104指令执行失败   105执行添加成功，对于不能立即返回结果的使用，比如蓝牙连接  106返回广播包   205安全认证失败
 * 失败原因（第8字节）
 * 成功： 初始化、写操作：0； 读操作：设备公钥，64B 、芯片ID，16B；
 * 失败: 失败原因,1B；
 * Response: byte 7 is the error code; byte 8 is the failure reason or returned payload.
 *
 * @return 配置密钥的命令字符串 / Key configuration command string.
 */
+ (NSString *)getConfigKeyOrderForPhoneCaseWithWithType:(int)type
                                                  param:(NSMutableArray *)param;

/**
 * 0x19 命令：验证签名（仅用于手机壳项目）。
 * Command 0x19: verifies signature for the phone-case project.
 * @param param 100B 数据，顺序固定：Hash 32B + 时间戳 4B + 签名 64B / 100 bytes in fixed order: hash 32B, timestamp 4B, signature 64B.
 *
 * 指令返回
 * 错误码（第7字节） 255指令执行成功    104指令执行失败   105执行添加成功，对于不能立即返回结果的使用，比如蓝牙连接  106返回广播包   205安全认证失败
 * 失败原因（第8字节）
 * 成功： 成功： 0；
 * 失败: 失败原因,1B；
 * Response: byte 7 is the error code; byte 8 is the failure reason.
 *
 * @return 验证签名的命令字符串 / Signature verification command string.
 */
+ (NSString *)getVerifySignatureOrderForPhoneCaseWithParam:(NSMutableArray *)param;

/**
 * 0x1A 命令：搜索到设备后，设备播放声音或者灯光响应。
 * Command 0x1A: makes the device respond with sound or light after it is found.
 * @param times 播放声音或者灯光响应的时间 / Response duration or repeat count.
 *
 * @return 0x1A 命令字符串 / Command 0x1A string.
 */
+ (NSString *)getPlayVoiceAndLightWhenFindDeviceWithTimes:(NSInteger )times;

// MARK: ========================================    蓝牙    ========================================
/**
 * 获取兴泰 BLE 蓝牙的服务 UUID。
 * Gets the XingTai BLE service UUID.
 * @return 兴泰 BLE 蓝牙的服务 UUID 字符串 / BLE service UUID string.
 */
+ (NSString *)getBLEServiceUUID;

/**
 * 获取兴泰 BLE 蓝牙的 NOTIFY 特征 UUID。
 * Gets the XingTai BLE notify characteristic UUID.
 *
 * 订阅设备回包/通知时必须使用这个 UUID 调用 setNotifyValue:YES。
 * 兼容说明：旧 SDK 里作为 read 使用的回包特征，在当前动态库里对应的是 NOTIFY 特征。
 *
 * Use this UUID with setNotifyValue:YES when subscribing to device responses/notifications.
 * Compatibility note: the response characteristic previously used as "read" in the old SDK
 * maps to the NOTIFY characteristic in this dynamic framework.
 *
 * @return 兴泰 BLE 蓝牙的通知特征 UUID 字符串 / BLE notify characteristic UUID string.
 */
+ (NSString *)getBLENotifyCharacteristicUUID;

/**
 * 获取兴泰 BLE 蓝牙的 Read 特征 UUID。
 * Gets the XingTai BLE read characteristic UUID.
 *
 * 不要用这个 UUID 订阅设备回包/通知；通知订阅请使用 getBLENotifyCharacteristicUUID。
 * Do not use this UUID to subscribe to device responses/notifications; use getBLENotifyCharacteristicUUID instead.
 *
 * @return 兴泰 BLE 蓝牙的读特征 UUID 字符串 / BLE read characteristic UUID string.
 */
+ (NSString *)getBLEReadCharacteristicUUID;

/**
 * 获取兴泰 BLE 蓝牙的写特征 UUID。
 * Gets the XingTai BLE write characteristic UUID.
 * @return 兴泰 BLE 蓝牙的写特征 UUID 字符串 / BLE write characteristic UUID string.
 */
+ (NSString *)getBLEWriteCharacteristicUUID;

// MARK: ========================================    蓝牙广播解析    ========================================

/**
 * 根据广播内容包获取 MAC 地址。
 * Extracts the MAC address from advertisement manufacturer data.
 * @param data 广播内容包数据 / Advertisement manufacturer data.
 * @return 解析得到的 MAC 地址字符串 / Parsed MAC address string.
 */
+ (NSString *)getBleMacFromCBAdvDataManufacturerData:(NSData *)data;

/**
 * 根据广播名字获取 MAC 地址。
 * Extracts the MAC address from advertisement local name.
 * @param name 广播名字 / Advertisement local name.
 * @return 解析得到的 MAC 地址字符串 / Parsed MAC address string.
 */
+ (NSString *)getBleMacFromCBAdvDataLocalName:(NSString *)name;

/**
 * 兼容旧调用；当前业务只使用索引 0 的 MAC，设备编号不再参与屏幕选择和刷图逻辑。
 * Legacy API. Current flows only use index 0 as MAC; device number is not used for screen selection or image transfer.
 */
+ (NSArray *)getBleMacAndDeviceNumberFromCBAdvDataLocalName:(NSString *)name;

/**
 * 广播内容包解析设备信息所有数据。
 * Parses all device information from advertisement manufacturer data.
 * @param data 广播内容包数据 / Advertisement manufacturer data.
 * @return 包含设备信息的可变字典 / Mutable dictionary containing parsed device information.
 */
+ (NSMutableDictionary *)getDeviceBleInfoFromCBAdvDataManufacturerData:(NSData *)data;

/**
 * 获取版本号。
 * Extracts the firmware/version string from advertisement manufacturer data.
 * @param data 广播内容包数据 / Advertisement manufacturer data.
 * @return 解析得到的版本号字符串 / Parsed version string.
 */
+ (NSString *)getVersionFromCBAdvDataManufacturerData:(NSData *)data;

/**
 * 根据设备编号返回标签的设备信息。
 * Returns tag device details for a device number.
 * @param deviceNumber 设备编号 / Device number.
 * @return 包含设备详细信息的数组 / Device detail array.
 */
+ (NSArray *)getDeviceDetailInfoWithDeviceNumber:(NSInteger)deviceNumber;

/**
 * 判断设备规格是否允许绑定。
 * Checks whether a device specification is allowed to bind.
 * @param deviceNumber 兼容旧调用，当前不参与支持判断 / Legacy argument, ignored by support checks.
 * @param screenWidth 屏幕宽度 / Screen width.
 * @param screenHeight 屏幕高度 / Screen height.
 * @param screenColorCode 设备颜色支持代码（"20" 黑白，"40" 黑白红黄，"60" 黑白红黄绿蓝）/ Device color code.
 * @return YES 表示允许绑定，NO 表示不允许绑定 / YES if binding is allowed.
 */
+ (BOOL)isSupportedBindingDeviceWithDeviceNumber:(NSInteger)deviceNumber
                                     screenWidth:(NSInteger)screenWidth
                                    screenHeight:(NSInteger)screenHeight
                                 screenColorCode:(NSString *)screenColorCode;

// MARK: ========================================    蓝牙返回解析    ========================================

/**
 * 获取发送时返回的结果，删除 FLASH 时返回 1 表示成功；刷图成功返回 1 个值，失败返回 2 个值。
 * Parses the send response. Delete-FLASH success returns one value; image refresh success returns one value and failure returns two values.
 * @param data 发送时返回的数据 / Response data.
 * @return 包含发送结果的可变数组 / Mutable array containing parsed result values.
 */
+ (NSMutableArray *)getBleSendResult:(NSData *)data;

/// 解析蓝牙返回的 NSData，返回解析对象和状态字符串。
/// Parses BLE response data and returns the parsed model plus status string.
/// @param data 蓝牙原始数据 / Raw BLE data.
/// @param resultStr 传出参数，接收解析状态（错误信息或成功提示）/ Output status string, either error message or success text.
+ (XTBleResultDataModel *)parseBleData:(NSData *)data resultString:(NSString **)resultStr;

// MARK: ========================================    日志    ========================================

/**
 * 测试日志接口，用于输出日志信息，暂时无用。
 * Test log API for debug output; currently unused.
 * @param info 要输出的日志信息 / Log message.
 * @param index 日志的索引 / Log index.
 * @return 返回一个 NSInteger 类型的值，可能用于表示日志输出的状态 / Integer status value.
 */
+ (NSInteger)XTLog:(NSString *)info index:(NSInteger)index;

// MARK: ========================================    测试数据    ========================================
/**
 * 获取临时图片数据，图片规格为 240*416，颜色模式为黑白红黄，用于测试。
 * Gets temporary 240*416 BWRY test image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData;

/**
 * 获取临时图片数据，图片规格为 768*528，颜色模式为黑白红黄。
 * Gets temporary 768*528 BWRY image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData1;

/**
 * 获取临时图片数据，图片规格为 768*528，颜色模式为黑白红黄。
 * Gets temporary 768*528 BWRY image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData2;

/**
 * 获取临时图片数据，图片规格为 768*528，颜色模式为黑白红黄。
 * Gets temporary 768*528 BWRY image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData3;

/**
 * 获取临时图片数据，图片规格为 768*528，颜色模式为黑白红黄。
 * Gets temporary 768*528 BWRY image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData4;

/**
 * 获取临时图片数据，图片规格为 240*416，颜色模式为 4 色。
 * Gets temporary 240*416 4-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData10;

/**
 * 获取临时图片数据，图片规格为 240*416，颜色模式为 4 色。
 * Gets temporary 240*416 4-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData11;

/**
 * 获取临时图片数据，图片规格为 240*416，颜色模式为 4 色。
 * Gets temporary 240*416 4-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData12;

/**
 * 获取临时图片数据，图片规格为 400*600，颜色模式为 6 色。
 * Gets temporary 400*600 6-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData20;

/**
 * 获取临时图片数据，图片规格为 400*600，颜色模式为 6 色。
 * Gets temporary 400*600 6-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData21;

/**
 * 获取临时图片数据，图片规格为 400*600，颜色模式为 6 色。
 * Gets temporary 400*600 6-color image data.
 * @return 包含图片数据的可变数组 / Mutable array containing image data.
 */
+ (NSMutableArray *)getTemporaryPicData22;

@end
