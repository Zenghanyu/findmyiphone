#import "XTImageDitherUtils.h"
#import "XTDeviceConfig.h"
#import "XTScreenSpecConfig.h"
#import "XTInkPhotoProcessor.h"
#import <XTDitherBleProtocol/XTDitherBleProtocol.h>
#import "UtilsMacros.h"

@implementation XTImageDitherUtils

/**
 @brief  兼容旧调用的图片转换入口 | Legacy-compatible image conversion entry.
 @discussion
 旧接口只输出previewImage；内部统一转到新接口，避免两套算法路径产生差异。
 The legacy API only outputs previewImage. It is forwarded to the new entry to keep one single algorithm path.
 */
+ (NSData*)convertToUploadData:(UIImage*)inputImage
                  previewImage:(UIImage **)previewImage
                     deviceCfg:(XTDeviceConfig *)deviceCfg
                       algType:(NSString *)algType {
    return [self convertToUploadData:inputImage
                         previewImage:previewImage
                       thresholdImage:nil
                            deviceCfg:deviceCfg
                              algType:algType];
}

/**
 @brief  图片算法转换统一入口 | Unified image conversion entry.
 @discussion
 thresholdImage用于界面预览；previewImage用于后续RGB取值并生成BLE刷图数组；返回NSData主要给纯NFC流程使用。
 thresholdImage is used for UI preview. previewImage is used for RGB sampling and BLE packet generation. The returned NSData is mainly for pure NFC.
 */
+ (NSData*)convertToUploadData:(UIImage*)inputImage
                  previewImage:(UIImage **)previewImage
                thresholdImage:(UIImage **)thresholdImage
                     deviceCfg:(XTDeviceConfig *)deviceCfg
                       algType:(NSString *)algType {
    NSAssert(inputImage != nil, @"convertToUploadData: inputImage 不能为空");
    NSAssert(deviceCfg != nil, @"convertToUploadData: deviceCfg 不能为空");
    
    if(!inputImage || !deviceCfg) {
        return nil;
    }
    if (previewImage) *previewImage = nil;
    if (thresholdImage) *thresholdImage = nil;
    if (![deviceCfg isSupportedBindingDevice]) {
        DLog(@"convertToUploadData: unsupported device %@x%@ %@", @(deviceCfg.screenWidth), @(deviceCfg.screenHeight), deviceCfg.screenColorCode);
        return nil;
    }
    
    DLog(@"=== convertToUploadData 参数开始 ===");
    if (inputImage) {
        DLog(@"inputImage: 存在，尺寸: %@", NSStringFromCGSize(inputImage.size));
    } else {
        DLog(@"inputImage: 为空");
    }
    DLog(@"previewImage 指针地址: %p", previewImage);
    if (deviceCfg) {
        DLog(@"deviceCfg: 存在");
        DLog(@"  colorDic: %@", deviceCfg.colorDic);
        DLog(@"  brushType: %d", (int)deviceCfg.brushType);
        DLog(@"  scanType: %d", (int)deviceCfg.scanType);
        DLog(@"  combineType: %d", (int)deviceCfg.combineType);
        DLog(@"  writeImageCount: %d", (int)deviceCfg.writeImageCount);
        DLog(@"  screenSpecNumber: %d", (int)deviceCfg.screenSpecNumber);
        DLog(@"  flipHorizontal: %@", deviceCfg.flipHorizontal ? @"YES" : @"NO");
        DLog(@"  flipVertical: %@", deviceCfg.flipVertical ? @"YES" : @"NO");
        DLog(@"  screenColorCode: %@", deviceCfg.screenColorCode);
        DLog(@"  screenSize: %@x%@", @(deviceCfg.screenWidth), @(deviceCfg.screenHeight));
        DLog(@"  needsFindMyBrushModeSwitch: %@", [deviceCfg isFindMyAndNeedSendChangeToBrushMode] ? @"YES" : @"NO");
    } else {
        DLog(@"deviceCfg: 为空");
    }
    DLog(@"algType: %@", algType ?: @"空");
    DLog(@"=== convertToUploadData 参数结束 ===");
    
    if ([XTInkPhotoProcessor usesHinkProfile:deviceCfg]) {
        // BLE consumes the exact marker image below; do not dither it again in
        // the SDK. Physical preview colours are never used for RGB extraction.
        BOOL ok = [XTInkPhotoProcessor processImage:inputImage deviceConfig:deviceCfg
                                           dither:![algType isEqualToString:ALG_TYPE_COLOR]
                                        dataImage:previewImage displayImage:thresholdImage];
        DLog(@"HINK-T0154A10-A2 conversion %@ (nominal D65 palette)", ok ? @"OK" : @"failed");
        // This path does not produce or require pure-NFC binary data.
        return nil;
    } else if (deviceCfg.brushType == brushWithNfc) {
        // 纯NFC使用NFC专用打包入口 | Pure NFC uses the NFC-specific packing entry.
        NSData *data = [XTBleProtocol getNFCUploadDataWithImage:inputImage
                                                 previewImage:previewImage
                                               thresholdImage:thresholdImage
                                                     colorDic:deviceCfg.colorDic
                                                     scanType:(int)deviceCfg.scanType
                                                  combineType:(int)deviceCfg.combineType
                                              writeImageCount:(int)deviceCfg.writeImageCount
                                               flipHorizontal:deviceCfg.flipHorizontal
                                                 flipVertical:deviceCfg.flipVertical
                                                  isZhiHuiXin:deviceCfg.isZhiHuiXin
                                                    imageAlgo:(int)deviceCfg.imageAlgo
                                                  screenWidth:(int)deviceCfg.screenWidth
                                                 screenHeight:(int)deviceCfg.screenHeight
                                              screenColorCode:deviceCfg.screenColorCode
                                                      algType:algType];
        return data;
    } else {
        // BLE/NFC+BLE使用通用打包入口 | BLE and NFC-powered BLE use the general packing entry.
        NSData *data = [XTBleProtocol getUploadDataWithImage:inputImage
                                              previewImage:previewImage
                                            thresholdImage:thresholdImage
                                                  colorDic:deviceCfg.colorDic
                                                  scanType:(int)deviceCfg.scanType
                                               combineType:(int)deviceCfg.combineType
                                           writeImageCount:(int)deviceCfg.writeImageCount
                                            flipHorizontal:deviceCfg.flipHorizontal
                                              flipVertical:deviceCfg.flipVertical
                                           screenColorCode:deviceCfg.screenColorCode
                                                   algType:algType];
        return data;
    }
}

/**
 @brief  将算法图片转换为BLE刷图数组 | Converts the algorithm output image to BLE upload rows.
 @discussion
 这里输入必须使用previewImage，因为BLE取值需要RGB图；thresholdImage只用于界面显示。
 The input must be previewImage because BLE sampling needs the RGB image; thresholdImage is display-only.
 */
+ (NSMutableArray *)getUploadDataFromDitherImage:(UIImage *)inputImage
                                       deviceCfg:(XTDeviceConfig *)deviceCfg {
    NSAssert(inputImage != nil, @"getUploadDataFromDitherImage: inputImage 不能为空");
    NSAssert(deviceCfg != nil, @"getUploadDataFromDitherImage: deviceCfg 不能为空");
    NSAssert(inputImage.size.width > 0 && inputImage.size.height > 0,
             @"getUploadDataFromDitherImage: 图片尺寸无效（宽/高不能为0）");
    
    if (!inputImage || !deviceCfg) {
        DLog(@"getUploadDataFromDitherImage: 入参为空");
        return [NSMutableArray array];
    }
    if (![deviceCfg isSupportedBindingDevice]) {
        DLog(@"getUploadDataFromDitherImage: unsupported device %@x%@ %@", @(deviceCfg.screenWidth), @(deviceCfg.screenHeight), deviceCfg.screenColorCode);
        return [NSMutableArray array];
    }
    
    /*
     *  5.89寸六色屏的数据扫描顺序和普通横扫不同，必须走独立取数逻辑。
     *  这里按屏幕规格判断，不再依赖旧的设备编号。
     *
     *  The 5.89-inch six-color screen uses a different data scanning order from normal horizontal scan.
     *  It is detected by screen spec here, not by legacy device number.
     */
    BOOL isFivePointEightNineScreen = [self _isFivePointEightNineScreenDeviceCfg:deviceCfg];
    if (isFivePointEightNineScreen) {
        DLog(@"检测到5.89屏幕，执行新扫描逻辑");
        return [self _getNewDeviceUploadData:inputImage deviceCfg:deviceCfg];
    } else {
        DLog(@"检测到默认扫描屏幕，执行通用扫描逻辑");
        return [self _getDefaultUploadData:inputImage deviceCfg:deviceCfg];
    }
}

/**
 @brief  判断是否为5.89寸六色屏 | Checks whether the config is a 5.89-inch six-color screen.
 */
+ (BOOL)_isFivePointEightNineScreenDeviceCfg:(XTDeviceConfig *)deviceCfg {
    if (!deviceCfg) {
        return NO;
    }
    return deviceCfg.screenSpecNumber == XTScreenSpecNumber589SixColor;
}

/**
 @brief  私有 - 默认刷图取数逻辑 | Private - default image data extraction logic.
 */
+ (NSMutableArray *)_getDefaultUploadData:(UIImage *)inputImage deviceCfg:(XTDeviceConfig *)deviceCfg {
    CGImageRef imageRef = inputImage.CGImage;
    int width  = (int)CGImageGetWidth(imageRef);
    int height = (int)CGImageGetHeight(imageRef);
    CFDataRef effectedData = nil;
    CFDataRef data = nil;
    NSMutableArray *array = [NSMutableArray array];
    
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    size_t bytesPerPixel = bitsPerPixel / 8;
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    
    NSAssert(bitsPerPixel > 0, @"_getDefaultUploadData: 每像素位数不能为0");
    NSAssert(bytesPerPixel > 0, @"_getDefaultUploadData: 每像素字节数不能为0");
    NSAssert(bytesPerRow > 0, @"_getDefaultUploadData: 每行字节数不能为0");
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    NSAssert(dataProvider != nil, @"_getDefaultUploadData: 图片数据提供者为空");
    
    data = CGDataProviderCopyData(dataProvider);
    NSAssert(data != nil, @"_getDefaultUploadData: 无法获取图片像素数据");
    
    UInt8 *buffer = (UInt8*)CFDataGetBytePtr(data);
    effectedData = CFDataCreate(NULL, buffer, CFDataGetLength(data));
    UInt8 *effectedBuffer = (UInt8*)CFDataGetBytePtr(effectedData);
    NSAssert(effectedBuffer != nil, @"_getDefaultUploadData: 像素数据缓冲区为空");
    
    UInt8 *pixelAddr;
    UInt8 red,green,blue;
    
    if (deviceCfg.scanType == VerticalType) {
        for(int y = width - 1; y >= 0; y--){
            NSMutableString *strLine = [NSMutableString string];
            for(int x = 0; x < height; x++){
                pixelAddr = effectedBuffer + x * bytesPerRow + y * bytesPerPixel;
                blue = *(pixelAddr + 0);
                green = *(pixelAddr + 1);
                red = *(pixelAddr + 2);
                [strLine appendString: [self getPiexsLineWithColorCode:deviceCfg.screenColorCode red:red green:green blue:blue]];
            }
            [array addObject:strLine];
        }
    } else {
        for(int y = 0; y < height; y++) {
            NSMutableString *strLine = [NSMutableString string];
            for(int x = 0; x < width; x++){
                pixelAddr = effectedBuffer + y * bytesPerRow + x * bytesPerPixel;
                blue = *(pixelAddr + 0);
                green = *(pixelAddr + 1);
                red = *(pixelAddr + 2);
                [strLine appendString: [self getPiexsLineWithColorCode:deviceCfg.screenColorCode red:red green:green blue:blue]];
            }
            [array addObject:strLine];
        }
    }
    
    // 释放资源
    if (data) CFRelease(data);
    if (effectedData) CFRelease(effectedData);
    
    return array;
}

/**
 @brief  私有 - 新设备刷图逻辑（下半区域180°旋转+严格资源释放）
 */
+ (NSMutableArray *)_getNewDeviceUploadData:(UIImage *)inputImage deviceCfg:(XTDeviceConfig *)deviceCfg {
    if (!inputImage || !deviceCfg) return [NSMutableArray array];
    
    CGImageRef imageRef = inputImage.CGImage;
    NSInteger imageWidth = (NSInteger)CGImageGetWidth(imageRef);
    NSInteger rawImageHeight = (NSInteger)CGImageGetHeight(imageRef);
        
    // 高度校准为4的整数倍
    NSInteger validImageHeight = [self _calibrateHeightTo4Multiple:rawImageHeight];
    NSAssert(validImageHeight >= 4, @"_getNewDeviceUploadData: 校准后高度无效（需≥4，当前：%ld）", validImageHeight);
    
    // 像素基础参数（从原始CGImage获取，避免从CFData错误获取）
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    size_t bytesPerPixel = bitsPerPixel / 8;
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    
    NSAssert(bitsPerPixel > 0, @"_getNewDeviceUploadData: 每像素位数不能为0");
    NSAssert(bytesPerPixel > 0, @"_getNewDeviceUploadData: 每像素字节数不能为0");
    NSAssert(bytesPerRow > 0, @"_getNewDeviceUploadData: 每行字节数不能为0");
    
    // 获取原始像素数据
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    NSAssert(dataProvider != nil, @"_getNewDeviceUploadData: 图片数据提供者为空");
    
    CFDataRef originalPixelData = CGDataProviderCopyData(dataProvider);
    NSAssert(originalPixelData != nil, @"_getNewDeviceUploadData: 无法获取图片像素数据");
    
    // 生成下半区域180°旋转后的像素数据（传入正确的bytesPerRow/bytesPerPixel）
    NSInteger partHeight = validImageHeight / 4;
    CFDataRef rotatedLowerHalfPixelData = [self _rotatePixelData180ForLowerHalf:originalPixelData
                                                                    imageWidth:imageWidth
                                                                    imageHeight:validImageHeight
                                                                    partHeight:partHeight
                                                                    bytesPerRow:bytesPerRow
                                                                  bytesPerPixel:bytesPerPixel];
    NSAssert(rotatedLowerHalfPixelData != nil, @"_getNewDeviceUploadData: 下半区域像素旋转失败");
    
    // 原始缓冲区 & 旋转后缓冲区
    UInt8 *originalBuffer = (UInt8 *)CFDataGetBytePtr(originalPixelData);
    UInt8 *rotatedLowerBuffer = (UInt8 *)CFDataGetBytePtr(rotatedLowerHalfPixelData);
    
    NSMutableArray *uploadDataArray = [NSMutableArray array];
    NSAssert(partHeight > 0, @"_getNewDeviceUploadData: 图片每份高度无效（需>0，当前：%ld）", partHeight);
    
    // 4阶段扫描配置：上半区域（1-2阶段）正常读取，下半区域（3-4阶段）用旋转后数据
    NSArray<NSDictionary<NSString *, NSNumber *> *> *scanStages = @[
        // 上半区域 - 第一阶段：递减（0~partHeight-1）
        @{@"startY": @(partHeight - 1), @"endY": @0,                @"isDesc": @YES,  @"isLowerHalf": @NO},
        // 上半区域 - 第二阶段：递增（partHeight~2*partHeight-1）
        @{@"startY": @(partHeight),     @"endY": @(2*partHeight - 1), @"isDesc": @NO,  @"isLowerHalf": @NO},
        // 下半区域 - 第三阶段：递减（2*partHeight~3*partHeight-1）→ 用180°旋转后数据
        @{@"startY": @(3*partHeight - 1), @"endY": @(2*partHeight), @"isDesc": @YES,  @"isLowerHalf": @YES},
        // 下半区域 - 第四阶段：递增（3*partHeight~validImageHeight-1）→ 用180°旋转后数据
        @{@"startY": @(3*partHeight),   @"endY": @(validImageHeight - 1), @"isDesc": @NO,  @"isLowerHalf": @YES}
    ];
    
    // 处理所有扫描阶段
    for (NSInteger stageIdx = 0; stageIdx < scanStages.count; stageIdx++) {
        NSDictionary<NSString *, NSNumber *> *stage = scanStages[stageIdx];
        NSInteger startY = [stage[@"startY"] integerValue];
        NSInteger endY = [stage[@"endY"] integerValue];
        BOOL isDesc = [stage[@"isDesc"] boolValue];
        BOOL isLowerHalf = [stage[@"isLowerHalf"] boolValue];
        
        // 边界防护
        startY = MAX(0, MIN(startY, validImageHeight - 1));
        endY = MAX(0, MIN(endY, validImageHeight - 1));
        
        if ((isDesc && startY < endY) || (!isDesc && startY > endY)) continue;
        
        // 选择对应的像素缓冲区（上半=原始，下半=旋转后）
        UInt8 *targetBuffer = isLowerHalf ? rotatedLowerBuffer : originalBuffer;
        
        if (isDesc) {
            // 递减遍历
            for (NSInteger y = startY; y >= endY; y--) {
                NSMutableString *lineStr = [NSMutableString stringWithCapacity:imageWidth];
                for (NSInteger x = 0; x < imageWidth; x++) {
                    if (y >= rawImageHeight) {
                        [lineStr appendString:@"1"];
                        continue;
                    }
                    // 读取对应缓冲区的像素
                    UInt8 blue, green, red;
                    UInt8 *pixelAddr = targetBuffer + y * bytesPerRow + x * bytesPerPixel;
                    blue = *(pixelAddr + 0);
                    green = *(pixelAddr + 1);
                    red = *(pixelAddr + 2);
                    [lineStr appendString:[self getPiexsLineWithColorCode:deviceCfg.screenColorCode
                                                                       red:red
                                                                     green:green
                                                                      blue:blue]];
                }
                [uploadDataArray addObject:lineStr];
            }
        } else {
            // 递增遍历
            for (NSInteger y = startY; y <= endY; y++) {
                NSMutableString *lineStr = [NSMutableString stringWithCapacity:imageWidth];
                for (NSInteger x = 0; x < imageWidth; x++) {
                    if (y >= rawImageHeight) {
                        [lineStr appendString:@"1"];
                        continue;
                    }
                    // 读取对应缓冲区的像素
                    UInt8 blue, green, red;
                    UInt8 *pixelAddr = targetBuffer + y * bytesPerRow + x * bytesPerPixel;
                    blue = *(pixelAddr + 0);
                    green = *(pixelAddr + 1);
                    red = *(pixelAddr + 2);
                    [lineStr appendString:[self getPiexsLineWithColorCode:deviceCfg.screenColorCode
                                                                       red:red
                                                                     green:green
                                                                      blue:blue]];
                }
                [uploadDataArray addObject:lineStr];
            }
        }
    }
    
    // ========== 严格释放所有临时资源 ==========
    if (originalPixelData) CFRelease(originalPixelData);
    if (rotatedLowerHalfPixelData) CFRelease(rotatedLowerHalfPixelData);
    
    return uploadDataArray;
}

/**
 @brief  私有辅助 - 对下半区域（2*partHeight ~ validImageHeight-1）的像素进行180°旋转
 @param originalPixelData 原始像素数据（CFData）
 @param width 图片宽度
 @param totalHeight 校准后的总高度
 @param partHeight 每份高度（totalHeight/4）
 @param bytesPerRow 每行字节数（从原始CGImage传入）
 @param bytesPerPixel 每像素字节数（从原始CGImage传入）
 @return 旋转后的像素数据（CFData，需外部释放）
 */
+ (CFDataRef)_rotatePixelData180ForLowerHalf:(CFDataRef)originalPixelData
                                   imageWidth:(NSInteger)width
                                   imageHeight:(NSInteger)totalHeight
                                   partHeight:(NSInteger)partHeight
                                   bytesPerRow:(size_t)bytesPerRow
                                 bytesPerPixel:(size_t)bytesPerPixel {
    NSAssert(originalPixelData != nil, @"_rotatePixelData180ForLowerHalf: 原始像素数据为空");
    NSAssert(width > 0 && totalHeight > 0 && partHeight > 0, @"_rotatePixelData180ForLowerHalf: 参数无效");
    NSAssert(bytesPerRow > 0 && bytesPerPixel > 0, @"_rotatePixelData180ForLowerHalf: 像素参数无效");
    
    // 下半区域起始/结束行（删除未使用的lowerHalfHeight变量）
    NSInteger lowerHalfStartY = 2 * partHeight;
    NSInteger lowerHalfEndY = totalHeight - 1;
    
    // 原始像素缓冲区
    UInt8 *originalBuffer = (UInt8 *)CFDataGetBytePtr(originalPixelData);
    NSAssert(originalBuffer != NULL, @"_rotatePixelData180ForLowerHalf: 原始像素缓冲区为空");
    
    // 总字节数 = 每行字节数 * 总高度
    size_t totalBytes = bytesPerRow * totalHeight;
    // 分配旋转后的数据缓冲区（malloc后由CFData接管）
    UInt8 *rotatedBuffer = (UInt8 *)malloc(totalBytes);
    NSAssert(rotatedBuffer != NULL, @"_rotatePixelData180ForLowerHalf: 内存分配失败");
    
    // 1. 先拷贝上半区域数据（保持不变）
    memcpy(rotatedBuffer, originalBuffer, lowerHalfStartY * bytesPerRow);
    
    // 2. 处理下半区域：180°旋转（水平+垂直翻转）
    for (NSInteger y = lowerHalfStartY; y <= lowerHalfEndY; y++) {
        // 垂直翻转：当前行对应下半区域的反向行
        NSInteger flippedY = lowerHalfEndY - (y - lowerHalfStartY);
        for (NSInteger x = 0; x < width; x++) {
            // 水平翻转：当前列对应反向列
            NSInteger flippedX = width - 1 - x;
            
            // 原始像素地址（翻转后的位置）
            UInt8 *srcPixel = originalBuffer + flippedY * bytesPerRow + flippedX * bytesPerPixel;
            // 目标像素地址（当前位置）
            UInt8 *dstPixel = rotatedBuffer + y * bytesPerRow + x * bytesPerPixel;
            
            // 拷贝RGB值（180°旋转核心）
            dstPixel[0] = srcPixel[0]; // B
            dstPixel[1] = srcPixel[1]; // G
            dstPixel[2] = srcPixel[2]; // R
        }
    }
    
    // 创建CFData（接管malloc的缓冲区，无需手动free）
    CFDataRef rotatedData = CFDataCreateWithBytesNoCopy(NULL, rotatedBuffer, totalBytes, kCFAllocatorMalloc);
    NSAssert(rotatedData != nil, @"_rotatePixelData180ForLowerHalf: 创建旋转后数据失败");
    
    return rotatedData;
}

/**
 @brief  私有辅助 - 高度向上取整为4的整数倍
 */
+ (NSInteger)_calibrateHeightTo4Multiple:(NSInteger)rawHeight {
    NSAssert(rawHeight >= 0, @"_calibrateHeightTo4Multiple: 原始高度不能为负数（当前：%ld）", rawHeight);
    
    if (rawHeight <= 0) return 4;
    NSInteger remainder = rawHeight % 4;
    if (remainder == 0) return rawHeight;
    NSInteger calibratedHeight = rawHeight + (4 - remainder);
    DLog(@"新设备高度校准：原始%ld → 校准后%ld（余数%ld）", rawHeight, calibratedHeight, remainder);
    return calibratedHeight;
}

/**
 @brief  颜色编码转换
 */
+ (NSString *)getPiexsLineWithColorCode:(NSString *)colorCode red:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue {
    NSAssert(colorCode != nil, @"getPiexsLineWithColorCode: colorCode 不能为空");
    NSAssert((red >= 0 && red <= 255) && (green >= 0 && green <= 255) && (blue >= 0 && blue <= 255),
             @"getPiexsLineWithColorCode: RGB值超出有效范围（R：%ld, G：%ld, B：%ld）", red, green, blue);
    
    NSString *pixelCode = @"";
    if([colorCode isEqualToString:COLOR_BWRYGB_CODE]) {
        if (red == 255 && green == 255 && blue == 255)
            pixelCode = @"1";
        else if (red == 255 && green == 0 && blue == 0)
            pixelCode = @"3";
        else if (red == 255 && green == 255 && blue == 0)
            pixelCode = @"2";
        else if (red == 0 && green == 255 && blue == 0)
            pixelCode = @"6";
        else if (red == 0 && green == 0 && blue == 255)
            pixelCode = @"5";
        else
            pixelCode = @"0";
    } else if([colorCode isEqualToString:COLOR_BWRY_CODE]) {
        if (red == 255 && green == 255 && blue == 255)
            pixelCode = @"1";
        else if (red == 255 && green == 0 && blue == 0)
            pixelCode = @"3";
        else if (red == 255 && green == 255 && blue == 0)
            pixelCode = @"2";
        else
            pixelCode = @"0";
    } else if([colorCode isEqualToString:COLOR_BWR_CODE]){
        if (red == 255 && green == 255 && blue == 255)
            pixelCode = @"1";
        else if (red == 255 && green == 0 && blue == 0)
            pixelCode = @"3";
        else
            pixelCode = @"0";
    } else if([colorCode isEqualToString:COLOR_BWY_CODE]){
        if (red == 255 && green == 255 && blue == 255)
            pixelCode = @"1";
        else if (red == 255 && green == 255 && blue == 0)
            pixelCode = @"2";
        else
            pixelCode = @"0";
    } else if([colorCode isEqualToString:COLOR_BW_CODE]){
        if (red == 255 && green == 255 && blue == 255)
            pixelCode = @"1";
        else
            pixelCode = @"0";
    }
    return pixelCode;
}

@end
