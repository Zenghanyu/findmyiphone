#import "EFInkBridge.h"
#import "XTBleWriteHelper.h"
#import "XTPhotoResampler.h"
#import "XTImageDitherUtils.h"
#import "XTScreenSpecConfig.h"
#import <XTDitherBleProtocol/XTDitherBleProtocol.h>

@interface EFInkPreparedImage ()
@property (nonatomic, strong, readwrite) UIImage *preview;
@property (nonatomic, copy) NSArray<NSString *> *packets;
@property (nonatomic, assign) NSInteger screenSpecNumber;
- (instancetype)initWithPreview:(UIImage *)preview packets:(NSArray<NSString *> *)packets spec:(NSInteger)spec;
@end

@implementation EFInkPreparedImage
- (instancetype)initWithPreview:(UIImage *)preview packets:(NSArray<NSString *> *)packets spec:(NSInteger)spec {
    if ((self = [super init])) {
        _preview = preview;
        _packets = [packets copy];
        _screenSpecNumber = spec;
    }
    return self;
}
@end

static XTDeviceConfig *EFHinkConfiguration(BOOL antiLost) {
    XTScreenSpec *spec = [XTScreenSpecConfig screenSpecWithNumber:antiLost ? XTScreenSpecNumber154SixColorAntiLost : XTScreenSpecNumber154SixColor];
    XTDeviceConfig *config = [XTDeviceConfig new];
    config.brushType = brushWithBle;
    config.screenSpecNumber = spec.number; config.screenWidth = spec.width; config.screenHeight = spec.height;
    config.screenColorCode = COLOR_BWRYGB_CODE; config.screenColorName = @"BWRYGB"; config.colorCount = 6;
    config.colorDic = @{DIC_KEY_BLACK: @"0", DIC_KEY_WHITE: @"1", DIC_KEY_RED: @"3", DIC_KEY_YELLOW: @"2", DIC_KEY_GREEN: @"6", DIC_KEY_BLUE: @"5"};
    config.imageDataProcessType = spec.imageDataProcessType; config.scanType = spec.scanType;
    config.combineType = GeneralType; config.writeImageCount = 1;
    config.needsFindMyBrushModeSwitch = spec.needsFindMyBrushModeSwitch; config.antiLostDevice = spec.antiLostDevice;
    return config;
}

@interface EFInkBridge ()
@property (nonatomic, strong) XTDeviceConfig *configuration;
@property (nonatomic, assign) NSUInteger generation;
@end

@implementation EFInkBridge
+ (void)prepareImage:(UIImage *)image antiLost:(BOOL)antiLost completion:(void (^)(EFInkPreparedImage *, NSString *))completion {
    XTDeviceConfig *config = EFHinkConfiguration(antiLost);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            UIImage *resized = [XTPhotoResampler aspectFillImageUsingDPID:image toSize:CGSizeMake(config.screenWidth, config.screenHeight)];
            UIImage *markers = nil, *display = nil;
            if (resized) [XTImageDitherUtils convertToUploadData:resized previewImage:&markers thresholdImage:&display deviceCfg:config algType:@"1"];
            NSArray<NSString *> *packets = markers ? [XTImageDitherUtils getUploadDataFromDitherImage:markers deviceCfg:config] : nil;
            EFInkPreparedImage *prepared = display && packets.count ? [[EFInkPreparedImage alloc] initWithPreview:display packets:packets spec:config.screenSpecNumber] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(prepared, prepared ? nil : @"图片处理失败，请重新选择。");
            });
        }
    });
}

- (void)scan:(void (^)(NSArray<NSDictionary<NSString *, NSString *> *> *, NSError *))completion {
    [[XTBleWriteHelper shareInstance] scanAvailableDevicesWithUpdate:nil completion:^(NSArray<XTBleScannedDevice *> *devices, NSError *error) {
        NSMutableArray *result = [NSMutableArray array];
        for (XTBleScannedDevice *device in devices) {
            if (device.mac.length) [result addObject:@{@"id": device.mac, @"name": device.deviceName ?: @"墨水屏", @"rssi": device.rssi ?: @""}];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result, error); });
    }];
}

- (BOOL)bind:(NSString *)mac antiLost:(BOOL)antiLost {
    NSString *clean = [[mac stringByReplacingOccurrencesOfString:@":" withString:@""] uppercaseString];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{12}$" options:0 error:nil];
    if ([pattern numberOfMatchesInString:clean options:0 range:NSMakeRange(0, clean.length)] != 1) return NO;
    XTDeviceConfig *config = EFHinkConfiguration(antiLost);
    config.appID = clean; config.uuID = clean;
    self.configuration = config;
    return YES;
}

- (void)uploadPreparedImage:(EFInkPreparedImage *)image completion:(void (^)(BOOL, NSString *))completion {
    XTDeviceConfig *config = self.configuration;
    if (!config) { completion(NO, @"请先选择并确认墨水屏型号。"); return; }
    if (image.screenSpecNumber != config.screenSpecNumber || !image.packets.count) {
        completion(NO, @"屏幕规格已改变，请重新预览后上传。"); return;
    }
    NSUInteger generation = ++self.generation;
    XTBleWriteHelper *helper = [XTBleWriteHelper shareInstance];
    helper.progressHandler = self.progress; helper.statusHandler = self.status;
    [helper importImageDataToDeviceWithImageHexDataArr:[image.packets mutableCopy] deviceConfig:config sendSize:244 writeImageBlock:^(BOOL accepted, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.generation) completion(accepted, error);
        });
    } advData:nil];
}

- (void)cancel {
    self.generation++;
    XTBleWriteHelper *helper = [XTBleWriteHelper shareInstance];
    helper.progressHandler = nil; helper.statusHandler = nil;
    [helper disconnectCurrentPeripherals];
}
@end
