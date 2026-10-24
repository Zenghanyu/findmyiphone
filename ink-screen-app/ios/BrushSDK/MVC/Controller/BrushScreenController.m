//
//  BrushScreenController.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import "BrushScreenController.h"
#import <Photos/Photos.h>

#import "XTBrushTypeView.h"
#import "XTCommonUtils.h"

#import "XTBleWriteHelper.h"
#import "NFCHelper.h"
#import "XTImageDitherUtils.h"
#import "XTPhotoResampler.h"
#import "XTScreenSpecConfig.h"

#import "UIImage+Rotate.h"
#import "UIImage+Category.h"
#import "UIImage+Extension.h"
#import "UIDevice+ModelIdentifier.h"
#import "UtilsMacros.h"
#import "Masonry.h"
#import "XTTool.h"
#import "XTMBManager.h"

@interface BrushScreenController ()<UIDocumentPickerDelegate,NFCHelperDelegate>
/// 根容器视图-适配安全区
/// Root container view - fit safe area
@property(nonatomic, strong) UIView                *bgView;
@property(nonatomic, strong) UIScrollView          *scrollView;
@property(nonatomic, strong) UIStackView           *contentStack;
@property(nonatomic, strong) UIButton              *floatingLogButton;
@property(nonatomic, strong) UIView                *logOverlayView;
@property(nonatomic, strong) UIView                *logDialogView;
@property(nonatomic, strong) UITextView            *logTextView;
/// 写屏图像展示视图
/// Image display view for screen brush
@property(nonatomic, strong) UIImageView           *imageView;
/// 图片底层背景视图
/// Background view for image display
@property(nonatomic, strong) UIView                *imageBgView;
/// 图片展示高度-设备分辨率适配计算
/// Image display height - calculated by device resolution adaption
@property(nonatomic, assign) CGFloat               imgHeight;

/// 色阶模式选择视图
/// Color level mode select view
@property(nonatomic, strong) XTBrushTypeView       *colorLevelBtn;
/// 抖点模式选择视图
/// Dither mode select view
@property(nonatomic, strong) XTBrushTypeView       *ditheringBrushOneBtn;

/// 普通刷写按钮
/// Normal screen brush button
@property(nonatomic, strong) UIButton              *writeBtn;
/// 快速刷写按钮
/// Fast screen brush button
@property(nonatomic, strong) UIButton              *fastWriteBtn;

/// 当前使用的抖动算法标识
/// Current dithering algorithm type
@property(nonatomic, copy) NSString                *currentAlgorithm;
/// 最终刷写至设备的图像
/// Final image for device screen brush
@property(nonatomic, strong) UIImage               *brushImage;
/// 生成 BLE 图片数组用的取色结果图
/// Palette/threshold image for BLE data extraction
@property(nonatomic, strong) UIImage               *brushDataImage;
/// 纯NFC直刷使用的二进制数据；BLE普通刷图不要用它，BLE使用brushDataImage重新取色分包。
/// Binary data for pure NFC direct write; BLE refresh uses brushDataImage for palette extraction and paging.
@property(nonatomic, strong) NSData                *outputData;

@end

@implementation BrushScreenController

#pragma mark - Lifecycle 生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = XTViewBgColor;
    self.title = XTLS(@"XT_Import_Preview");
    // Default use dither algorithm.
    _currentAlgorithm = ALG_TYPE_DITHER;
   
    // 关闭视图延伸布局-适配导航栏
    // Disable view extend layout - fit navigation bar
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [self createView];
    [self getNewImageFormNewParameter];
    [self addShadowForImageView];

    // 点击空白处收起键盘手势
    // Tap gesture for dismiss keyboard when click blank area
    UITapGestureRecognizer *keyboardDismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
    keyboardDismissTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:keyboardDismissTap];
}

/// 页面显示-禁用侧滑返回手势
/// View appear - Disable interactive pop gesture
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

/// 页面消失-恢复侧滑返回手势
/// View disappear - Resume interactive pop gesture
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    };
}

#pragma mark - UI Event 界面事件
/// 点击空白处收起键盘
/// Tap blank area to dismiss keyboard
- (void)viewTapped:(UITapGestureRecognizer*)tap {
    [self.view endEditing:YES];
}

#pragma mark - UI Create 界面创建
/// 创建所有子视图及布局约束
/// Create all subviews and layout constraints
- (void)createView {
    // 按设备分辨率计算图片展示宽高
    // Calculate image display size by device resolution
    CGFloat availableWidth = XTScreenWidth - 64;
    CGFloat imaH = availableWidth * _deviceConfig.screenHeight / MAX(_deviceConfig.screenWidth, 1);
    // 计算图片展示最大高度-适配屏幕
    // Calculate max image display height - fit screen
    CGFloat maxH = 360;
    _imgHeight = MIN(MAX(imaH, 160), maxH);
    // 按高度反算图片展示宽度-保持比例
    // Calculate image display width by height - keep aspect ratio
    CGFloat imgWidth = _imgHeight * _deviceConfig.screenWidth / MAX(_deviceConfig.screenHeight, 1);
    imgWidth = MIN(imgWidth, availableWidth);

    [self.view addSubview: self.bgView];
    [self.bgView addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentStack];

    [_bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.bgView);
    }];
    [self.contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.scrollView).inset(16);
        make.left.right.equalTo(self.view).inset(16);
    }];
    
    UIView *previewCard = [self sdkCardView];
    [self.imageBgView addSubview:self.imageView];
    [self.imageBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(imgWidth);
        make.height.mas_equalTo(_imgHeight);
    }];
    [_imageBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_lessThanOrEqualTo(availableWidth);
    }];
    [_imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.imageBgView);
    }];
    UIStackView *previewCenter = [[UIStackView alloc] initWithArrangedSubviews:@[self.imageBgView]];
    previewCenter.axis = UILayoutConstraintAxisVertical;
    previewCenter.alignment = UIStackViewAlignmentCenter;
    [self fillSdkCard:previewCard views:@[[self sdkLabelWithText:XTLS(@"XT_Image_Preview") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:XTCOLOR(0x172033)], previewCenter]];
    [self.contentStack addArrangedSubview:previewCard];
    
    UIView *algorithmCard = [self sdkCardView];
    UIStackView *algorithmRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.ditheringBrushOneBtn,
        self.colorLevelBtn
    ]];
    algorithmRow.axis = UILayoutConstraintAxisHorizontal;
    algorithmRow.spacing = 10;
    algorithmRow.distribution = UIStackViewDistributionFillEqually;
    [self fillSdkCard:algorithmCard views:@[
        [self sdkLabelWithText:XTLS(@"XT_Algorithm_Select") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:XTCOLOR(0x172033)],
        algorithmRow
    ]];
    [self.contentStack addArrangedSubview:algorithmCard];
    [_ditheringBrushOneBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(50);
    }];
    [_colorLevelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(50);
    }];

    UIStackView *actionRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.writeBtn, self.fastWriteBtn]];
    actionRow.axis = UILayoutConstraintAxisHorizontal;
    actionRow.spacing = 10;
    actionRow.distribution = UIStackViewDistributionFillEqually;
    [actionRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(50);
    }];
    [self.contentStack addArrangedSubview:actionRow];
    [self setupFloatingLogView];
}

- (UIView *)sdkCardView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.whiteColor;
    view.layer.cornerRadius = 8;
    view.layer.borderWidth = 1;
    view.layer.borderColor = XTCOLOR(0xE5E7EB).CGColor;
    return view;
}

- (UILabel *)sdkLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (void)fillSdkCard:(UIView *)card views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    [card addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(card).inset(14);
    }];
}

- (void)setupFloatingLogView {
    [self.view addSubview:self.floatingLogButton];
    [self.floatingLogButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view).offset(-18);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-18);
        make.width.mas_equalTo(64);
        make.height.mas_equalTo(44);
    }];
    
    [self.view addSubview:self.logOverlayView];
    [self.logOverlayView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.logOverlayView addSubview:self.logDialogView];
    [self.logDialogView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.logOverlayView).inset(24);
        make.centerY.equalTo(self.logOverlayView);
        make.height.mas_equalTo(MIN(360, XTScreenHeight * 0.48));
    }];
    
    UILabel *titleLabel = [self sdkLabelWithText:XTLS(@"XT_Log") font:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] color:XTCOLOR(0x172033)];
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setTitle:@"x" forState:UIControlStateNormal];
    [closeButton setTitleColor:XTCOLOR(0x667085) forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    closeButton.layer.cornerRadius = 15;
    closeButton.backgroundColor = XTCOLOR(0xF2F4F7);
    [closeButton addTarget:self action:@selector(hideLogDialog) forControlEvents:UIControlEventTouchUpInside];
    
    [self.logDialogView addSubview:titleLabel];
    [self.logDialogView addSubview:closeButton];
    [self.logDialogView addSubview:self.logTextView];
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.logDialogView).inset(16);
        make.right.lessThanOrEqualTo(closeButton.mas_left).offset(-12);
    }];
    [closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.right.equalTo(self.logDialogView).inset(14);
        make.width.height.mas_equalTo(30);
    }];
    [self.logTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.logDialogView).inset(16);
        make.top.equalTo(titleLabel.mas_bottom).offset(12);
    }];
}

- (void)showLogDialog {
    self.logOverlayView.hidden = NO;
    self.floatingLogButton.hidden = YES;
    if (self.logTextView.text.length > 0) {
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length - 1, 1)];
    }
}

- (void)hideLogDialog {
    self.logOverlayView.hidden = YES;
    self.floatingLogButton.hidden = NO;
}

- (NSString *)buildBrushConfigSummary {
    NSString *mac = self.deviceConfig.uuID.length > 0 ? self.deviceConfig.uuID : self.deviceConfig.appID;
    NSString *color = [self.deviceConfig.screenColorName stringByReplacingOccurrencesOfString:@"FM_C_" withString:@""];
    NSString *communication = self.deviceConfig.brushType == brushWithBle ? @"BLE" : self.deviceConfig.brushType == brushWithNfc ? @"NFC" : XTLS(@"XT_NFC_Powered_BLE_Transfer");
    return [NSString stringWithFormat:XTLS(@"XT_Brush_Device_Info_Format"),
            mac.length > 0 ? mac : @"-",
            (long)self.deviceConfig.screenWidth,
            (long)self.deviceConfig.screenHeight,
            color.length > 0 ? color : @"-",
            communication];
}

- (void)setBrushStage:(NSString *)stage progress:(CGFloat)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *safeStage = stage.length > 0 ? stage : XTLS(@"XT_Processing");
        CGFloat safeProgress = MAX(0, MIN(progress, 1));
        [self appendBrushLog:[NSString stringWithFormat:@"%@ %.0f%%", safeStage, safeProgress * 100]];
    });
}

- (void)appendBrushLog:(NSString *)log {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *safeLog = log ?: @"";
        if (safeLog.length == 0) {
            return;
        }
        NSString *oldText = self.logTextView.text.length > 0 ? self.logTextView.text : @"";
        if ([oldText isEqualToString:XTLS(@"XT_No_Operation")]) {
            oldText = @"";
        }
        self.logTextView.text = oldText.length > 0 ? [oldText stringByAppendingFormat:@"\n%@", safeLog] : safeLog;
        if (!self.logOverlayView.hidden && self.logTextView.text.length > 0) {
            [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length - 1, 1)];
        }
    });
}

#pragma mark - Business Event 业务事件
/// 普通刷写按钮点击回调
/// Normal screen brush button click callback
- (void)wirteScreenClicked:(UIButton *)btn {
    if (!_deviceConfig) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Please_Bind_Device") delayHid:1.5];
        return;
    }
    [self setBrushStage:XTLS(@"XT_Generating_Brush_Data") progress:0.15];
    [self appendBrushLog:XTLS(@"XT_Brush_Task_Started")];
    
    UIImage *displayImage = _imageView.image;
    UIImage *brushDataImage = _brushDataImage;
    
    if (!displayImage || !brushDataImage) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_DitheringFailed") delayHid:1.5];
        return;
    }
    _brushImage = displayImage;
    _brushDataImage = brushDataImage;

    // 图像转换为设备可识别的数据流
    // Convert image to data stream for device
    NSMutableArray *picData = [XTImageDitherUtils getUploadDataFromDitherImage:brushDataImage
                                                                     deviceCfg:_deviceConfig];
    [self setBrushStage:XTLS(@"XT_Brush_Data_Generated") progress:0.3];
    // 区分蓝牙/NFC两种刷写方式
    // Distinguish BLE/NFC two screen brush modes
    if (_deviceConfig.brushType == brushWithBle) {
        // 特定设备+非iPhone13及以上机型-走NFC前置配置
        // Special device + non-iPhone13 or later - use NFC pre-config
        if (NO) {
            NFCHelper *nfc = [NFCHelper shareInstance];
            if(nfc.isReading) return;
            nfc.delegate = self;
            [nfc getDeviceConfig:XTLS(@"XT_Close_To_Equipment") isNeedScanTip:NO];
        } else {
            // 蓝牙方式刷写图像数据到设备
            // BLE mode - send image data to device
            if ([_deviceConfig isNameCardDevice]) {
                [[XTBleWriteHelper shareInstance] importImageDataToDeviceWithImageHexDataArrA:picData
                                                                                  hexDataArrB:picData
                                                                                 deviceConfig:_deviceConfig
                                                                                     sendSize:244
                                                                              writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
                    [self setBrushStage:isSuccess ? XTLS(@"XT_Brush_Complete") : XTLS(@"XT_Brush_Failed") progress:isSuccess ? 1.0 : 0.3];
                    [self appendBrushLog:isSuccess ? XTLS(@"XT_BLE_Write_Complete") : (error ?: XTLS(@"XT_BLE_Write_Failed"))];
                } advData:^(NSString * _Nonnull RSSI, NSString * _Nonnull power, NSString * _Nonnull version) {
                    [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Brush_RSSI_Log_Format"), RSSI ?: @"-", power ?: @"-", version ?: @"-"]];
                }];
            } else {
                [[XTBleWriteHelper shareInstance] importImageDataToDeviceWithImageHexDataArr:picData
                                                                                deviceConfig:_deviceConfig
                                                                                    sendSize:244
                                                                             writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
                    [self setBrushStage:isSuccess ? XTLS(@"XT_Brush_Complete") : XTLS(@"XT_Brush_Failed") progress:isSuccess ? 1.0 : 0.3];
                    [self appendBrushLog:isSuccess ? XTLS(@"XT_BLE_Write_Complete") : (error ?: XTLS(@"XT_BLE_Write_Failed"))];
                } advData:^(NSString * _Nonnull RSSI, NSString * _Nonnull power, NSString * _Nonnull version) {
                    [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Brush_RSSI_Log_Format"), RSSI ?: @"-", power ?: @"-", version ?: @"-"]];
                }];
            }
        }
    } else {
        // NFC方式刷写图像数据到设备
        // NFC mode - send image data to device
        NFCHelper *instance = [NFCHelper shareInstance];
        if(instance.isReading){
            [XTMBManager showAlertViewWithText:XTLS(@"XT_Processing") delayHid:1.5];
            return;
        }
        // NFC刷写时间间隔
        // NFC screen brush interval time
        int intervalTime = 10;
        [self setBrushStage:XTLS(@"XT_Waiting_NFC_Device") progress:0.45];
        // _outputData只给纯NFC直刷使用；imageDataXT/picData是BLE路径的分包数据。
        // _outputData is only for pure NFC direct write; imageDataXT/picData is the BLE packet path.
        NSString *response = [instance importImageToDevice:XTLS(@"XT_Close_To_Equipment")
                                                 imageData:_outputData
                                               imageDataXT:picData
                                                 screenCfg:_deviceConfig
                                        imageSectionNumber:0
                                                       pin:nil
                                                  PageSize:244
                                              IntervalTime:intervalTime];
        if (response.length > 0) {
            [XTMBManager showAlertViewWithText:response delayHid:1.5];
            [self setBrushStage:XTLS(@"XT_Brush_Failed") progress:0.45];
            [self appendBrushLog:response];
        } else {
            [self setBrushStage:XTLS(@"XT_NFC_Task_Submitted") progress:1.0];
            [self appendBrushLog:XTLS(@"XT_NFC_Write_Task_Submitted")];
        }
    }
}

/// 快速刷写按钮点击回调
/// Fast screen brush button click callback
- (void)fastWriteBtnClicked:(UIButton *)btn {
    if (!_deviceConfig) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Please_Bind_Device") delayHid:1.5];
        return;
    }
    
    UIImage *displayImage =  _imageView.image;
    UIImage *brushDataImage = _brushDataImage;
    
    if (!displayImage || !brushDataImage) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_DitheringFailed") delayHid:1.5];
        return;
    }
    _brushImage = displayImage;
    _brushDataImage = brushDataImage;
    
    // 快速刷写统一走NFC前置配置
    // Fast brush - unify use NFC pre-config
    [self setBrushStage:XTLS(@"XT_Waiting_NFC_Fast_Broadcast") progress:0.35];
    [self appendBrushLog:XTLS(@"XT_Fast_Brush_Task_Started")];
    NFCHelper *nfc = [NFCHelper shareInstance];
    if(nfc.isReading) return;
    nfc.delegate = self;
    [nfc getDeviceConfig:XTLS(@"XT_Close_To_Equipment") isNeedScanTip:NO];
}

#pragma mark - Business Logic 核心业务逻辑
/// 1.69寸圆屏界面显示正常抖点图，实际下发使用旋转原图后重新算法转换得到的RGB取值图。
/// 1.69-inch round screens display the normal dithered preview, but upload data from a rotated source image.
- (BOOL)shouldUseRotatedPayloadImageForDeviceConfig:(XTDeviceConfig *)deviceConfig {
    return deviceConfig.screenWidth == 400 && deviceConfig.screenHeight == 400;
}

/// 针对特殊屏幕生成下发用的旋转图，逻辑对齐ChromaInk：先旋转/裁剪原图，再按当前算法生成previewImage。
/// Builds the rotated upload image aligned with ChromaInk: rotate/crop the source image first, then run the current algorithm.
- (UIImage *)rotatedImageWithDeviceConfig:(XTDeviceConfig *)deviceConfig
                           brushDataImage:(UIImage **)brushDataImage {
    if (!_orignImage || !deviceConfig) {
        return nil;
    }
    
    UIImage *scaledImage = self.roundPanelInputImage;
    if (!scaledImage) {
        scaledImage = [XTPhotoResampler roundPanelImage:_orignImage
                                               toSize:CGSizeMake(deviceConfig.screenWidth, deviceConfig.screenHeight)
                                      rotationDegrees:69.7];
    }
    if (!scaledImage) return nil;
    UIImage *previewImage = nil;
    NSData *imageData = [XTImageDitherUtils convertToUploadData:scaledImage
                                                   previewImage:&previewImage
                                                      deviceCfg:deviceConfig
                                                        algType:_currentAlgorithm];
    // imageData/_outputData只给纯NFC直刷使用；旋转后的previewImage才是BLE刷图取值图。
    // imageData/_outputData is only for pure NFC direct write; rotated previewImage is the BLE data image.
    _outputData = imageData;
    if (brushDataImage) {
        *brushDataImage = previewImage;
    }
    return previewImage;
}

/// 图片尺寸缩放适配
/// Scale image to target size
- (UIImage *)scaledImageFormImage:(UIImage *)image toSize:(CGSize)size {
    return [XTPhotoResampler resizeImage:image toSize:size];
}

/// 更新图片展示视图的内容
/// Update content of image display view
- (void)loadImageFinished:(UIImage *)image {
    _imageView.image = image;
}

/// 保存图片到系统相册
/// Save image to system photo library
- (void)saveImageToLibrary:(UIImage *)image {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            DLog(@"图片保存成功 | Image save to library success");
        } else {
            DLog(@"图片保存失败：%@ | Image save to library fail：%@", error.localizedDescription, error.localizedDescription);
        }
    }];
}

/// 保存图片到系统文件应用
/// Save image to system Files App
- (void)saveImageToFilesApp:(UIImage *)image {
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        DLog(@"无法将图片转换为数据 | Convert image to data fail");
        return;
    }
    // 生成临时文件路径
    // Generate temp file path
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp_image.png"];
    if ([imageData writeToFile:tempFilePath atomically:YES]) {
        NSURL *tempFileURL = [NSURL fileURLWithPath:tempFilePath];
        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:tempFileURL inMode:UIDocumentPickerModeExportToService];
        documentPicker.delegate = self;
        [self presentViewController:documentPicker animated:YES completion:nil];
    } else {
        DLog(@"无法将图片数据保存到临时文件 | Save image data to temp file fail");
    }
}

/// 按当前选中的算法转换图像数据
/// Convert image data with currently selected algorithm
- (void)getNewImageFormNewParameter {
    UIImage *previewImage = nil;
    UIImage *thresholdImage = nil;
    NSData *imageData = [XTImageDitherUtils convertToUploadData:_orignImage
                                                   previewImage:&previewImage
                                                 thresholdImage:&thresholdImage
                                                      deviceCfg:_deviceConfig
                                                        algType:_currentAlgorithm];
    // imageData/_outputData只给纯NFC直刷使用；BLE普通刷图使用previewImage生成分包，界面显示thresholdImage。
    // imageData/_outputData is only for pure NFC direct write; BLE uses previewImage for packets and thresholdImage for UI.
    _outputData = imageData;
    BOOL missingDirectNFCData = _deviceConfig.brushType != brushWithBle && (!_outputData || _outputData.length == 0);
    if(missingDirectNFCData || !previewImage || !thresholdImage){
        _outputData = nil;
        _brushDataImage = nil;
        if (!_imageView.image) {
            _imageView.image = _orignImage;
        }
        [self setBrushStage:XTLS(@"XT_Convert_Image_Fail") progress:0];
        [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Brush_Convert_Failed_Log_Format"),
                              _orignImage.size.width,
                              _orignImage.size.height,
                              _deviceConfig.screenColorCode ?: @"-"]];
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Convert_Image_Fail") delayHid:1.5];
        return;
    }
    UIImage *brushDataImage = previewImage;
    if ([self shouldUseRotatedPayloadImageForDeviceConfig:_deviceConfig]) {
        UIImage *rotatedBrushDataImage = nil;
        [self rotatedImageWithDeviceConfig:_deviceConfig
                            brushDataImage:&rotatedBrushDataImage];
        if (!rotatedBrushDataImage) {
            _outputData = nil;
            _brushDataImage = nil;
            [self setBrushStage:XTLS(@"XT_Convert_Image_Fail") progress:0];
            [XTMBManager showAlertViewWithText:XTLS(@"XT_Convert_Image_Fail") delayHid:1.5];
            return;
        }
        brushDataImage = rotatedBrushDataImage;
    }
    _brushDataImage = brushDataImage;
    _imageView.image = thresholdImage;
}

/// 给图片视图添加圆角/圆形样式
/// Add corner radius / circle style for image view
- (void)addShadowForImageView {
    BOOL isCirclePreview = [self shouldUseCirclePreviewMask];
    CGFloat cornerRadius = isCirclePreview ? _imgHeight / 2.0 : 10 * XTScale;
    _imageView.layer.cornerRadius = cornerRadius;
    _imageView.layer.masksToBounds = YES;
    _imageBgView.layer.cornerRadius = cornerRadius;
    _imageBgView.layer.masksToBounds = YES;
}

/// 1.69寸圆屏预览按圆形裁切；刷图数据仍使用完整400x400图像。
/// 1.69-inch round screen uses a circular preview mask; upload data still uses the full 400x400 image.
- (BOOL)shouldUseCirclePreviewMask {
    return _deviceConfig.screenWidth == 400 && _deviceConfig.screenHeight == 400;
}

/// 抖动算法模式切换点击回调
/// Dithering algorithm mode switch tap callback
- (void)brushTypeViewTap:(UITapGestureRecognizer *)tap {
    // 重置所有模式的选中状态
    // Reset selected state of all modes
    for (int i = 1000; i < 1003; i++) {
        XTBrushTypeView *view = (XTBrushTypeView *)[self.view viewWithTag:i];
        view.selected = NO;
    }
  
    // 设置当前点击模式为选中状态
    // Set current tap mode to selected state
    XTBrushTypeView *sview = (XTBrushTypeView *)tap.view;
    sview.selected = YES;
  
    // 按视图Tag切换对应的图像算法
    // Switch image algorithm by view tag
    _currentAlgorithm = tap.view.tag == 1002 ? ALG_TYPE_COLOR : ALG_TYPE_DITHER;
    [self setBrushStage:XTLS(@"XT_Generating_Preview") progress:0.1];
    [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Switch_Algorithm_Log_Format"), sview.title ?: @""]];
   
    // 重新按新算法转换图像
    // Reconvert image with new algorithm
    [self getNewImageFormNewParameter];
    [self setBrushStage:XTLS(@"XT_Preview_Updated") progress:0.2];
}

#pragma mark - UIDocumentPickerDelegate 文件选择代理
/// 图片保存到文件应用成功回调
/// Image save to Files App success callback
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(nonnull NSArray<NSURL *> *)urls {
    DLog(@"图片保存到文件应用成功，路径：%@ | Image save to Files App success, path：%@", urls.firstObject.absoluteString, urls.firstObject.absoluteString);
}

/// 取消保存图片到文件应用回调
/// Cancel save image to Files App callback
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    DLog(@"用户取消了文件保存操作 | User cancel save image to Files App");
}

#pragma mark - NFCHelperDelegate NFC代理
/// NFC读取设备配置完成回调
/// NFC read device config complete callback
- (void)NfcReadConfigComplete:(XTDeviceConfig *)config {
    if (!_brushImage || !_brushDataImage) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Data_Error") delayHid:1.5];
        return;
    }
    // NFC only wakes BLE fast advertising; wait for the 1s advertising interval before BLE write.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableArray *picData = [XTImageDitherUtils getUploadDataFromDitherImage:_brushDataImage
                                                                         deviceCfg:_deviceConfig];
        if ([_deviceConfig isNameCardDevice]) {
            [[XTBleWriteHelper shareInstance] importImageDataToDeviceWithImageHexDataArrA:picData
                                                                              hexDataArrB:picData
                                                                             deviceConfig:_deviceConfig
                                                                                 sendSize:244
                                                                          writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
                [self setBrushStage:isSuccess ? XTLS(@"XT_Brush_Complete") : XTLS(@"XT_Brush_Failed") progress:isSuccess ? 1.0 : 0.45];
                [self appendBrushLog:isSuccess ? XTLS(@"XT_NFC_Activated_BLE_Write_Complete") : (error ?: XTLS(@"XT_NFC_Activated_BLE_Write_Failed"))];
            } advData:^(NSString * _Nonnull RSSI, NSString * _Nonnull power, NSString * _Nonnull version) {
                [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Brush_RSSI_Log_Format"), RSSI ?: @"-", power ?: @"-", version ?: @"-"]];
            }];
        } else {
            [[XTBleWriteHelper shareInstance] importImageDataToDeviceWithImageHexDataArr:picData
                                                                            deviceConfig:_deviceConfig
                                                                                sendSize:244
                                                                         writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
                [self setBrushStage:isSuccess ? XTLS(@"XT_Brush_Complete") : XTLS(@"XT_Brush_Failed") progress:isSuccess ? 1.0 : 0.45];
                [self appendBrushLog:isSuccess ? XTLS(@"XT_NFC_Activated_BLE_Write_Complete") : (error ?: XTLS(@"XT_NFC_Activated_BLE_Write_Failed"))];
            } advData:^(NSString * _Nonnull RSSI, NSString * _Nonnull power, NSString * _Nonnull version) {
                [self appendBrushLog:[NSString stringWithFormat:XTLS(@"XT_Brush_RSSI_Log_Format"), RSSI ?: @"-", power ?: @"-", version ?: @"-"]];
            }];
        }
    });
}

#pragma mark - Lazy Load 懒加载
- (UIView *)bgView {
    if(!_bgView){
        _bgView = [UIView new];
        _bgView.backgroundColor = XTCOLOR(0xF6F7FB);
    }
    return _bgView;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (UIStackView *)contentStack {
    if (!_contentStack) {
        _contentStack = [[UIStackView alloc] init];
        _contentStack.axis = UILayoutConstraintAxisVertical;
        _contentStack.spacing = 14;
    }
    return _contentStack;
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.backgroundColor = [UIColor clearColor];
        _imageView.contentMode = UIViewContentModeScaleToFill;
    }
    return _imageView;
}

- (UIView *)imageBgView {
    if (!_imageBgView) {
        _imageBgView = [[UIView alloc] init];
        _imageBgView.backgroundColor = [UIColor whiteColor];
    }
    return _imageBgView;
}

- (XTBrushTypeView *)ditheringBrushOneBtn {
    if (!_ditheringBrushOneBtn) {
        _ditheringBrushOneBtn = [[XTBrushTypeView alloc] initWithFrame:CGRectMake(0, 0, XTScreenWidth - 80, 50)];
        _ditheringBrushOneBtn.title = XTLS(@"XT_Dither");
        _ditheringBrushOneBtn.selected = YES;
        _ditheringBrushOneBtn.tag = 1000;
        [_ditheringBrushOneBtn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(brushTypeViewTap:)]];
    }
    return _ditheringBrushOneBtn;
}

- (XTBrushTypeView *)colorLevelBtn {
    if (!_colorLevelBtn) {
        _colorLevelBtn = [[XTBrushTypeView alloc] initWithFrame:CGRectMake(0, 0, XTScreenWidth - 80, 50)];
        _colorLevelBtn.title = XTLS(@"XT_Color_Level");
        _colorLevelBtn.tag = 1002;
        [_colorLevelBtn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(brushTypeViewTap:)]];
    }
    return _colorLevelBtn;
}

- (UIButton *)writeBtn {
    if (!_writeBtn) {
        _writeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_writeBtn setTitle:XTLS(@"XT_Import_Image") forState:UIControlStateNormal];
        [_writeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _writeBtn.backgroundColor = XTCOLOR(0x3B72E8);
        _writeBtn.titleLabel.font = XTPFMediumFont(16);
        _writeBtn.layer.cornerRadius = 10 * XTScale;
        [_writeBtn addTarget:self action:@selector(wirteScreenClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _writeBtn;
}

/*
 // 支持NFC激活蓝牙快速广播（3s->100ms）显示快速刷写按钮，否则隐藏，按钮无效
 // Show fast write button only for BLE mode with NFC active fast broadcast (3s→100ms), hide it otherwise (button invalid)
 */
- (UIButton *)fastWriteBtn {
    if (!_fastWriteBtn) {
        _fastWriteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_fastWriteBtn setImage:[UIImage imageNamed:@"icn_nfc_fast"] forState:UIControlStateNormal];
        _fastWriteBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        _fastWriteBtn.backgroundColor = XTCOLOR(0x3B72E8);
        _fastWriteBtn.layer.cornerRadius = 10 * XTScale;
        [_fastWriteBtn addTarget:self action:@selector(fastWriteBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        _fastWriteBtn.hidden = _deviceConfig.brushType != brushWithBle;
    }
    return _fastWriteBtn;
}

- (UIButton *)floatingLogButton {
    if (!_floatingLogButton) {
        _floatingLogButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_floatingLogButton setTitle:XTLS(@"XT_Log") forState:UIControlStateNormal];
        [_floatingLogButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _floatingLogButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _floatingLogButton.backgroundColor = XTCOLOR(0x172033);
        _floatingLogButton.layer.cornerRadius = 22;
        _floatingLogButton.layer.shadowColor = [UIColor blackColor].CGColor;
        _floatingLogButton.layer.shadowOpacity = 0.18;
        _floatingLogButton.layer.shadowOffset = CGSizeMake(0, 6);
        _floatingLogButton.layer.shadowRadius = 12;
        [_floatingLogButton addTarget:self action:@selector(showLogDialog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _floatingLogButton;
}

- (UIView *)logOverlayView {
    if (!_logOverlayView) {
        _logOverlayView = [[UIView alloc] init];
        _logOverlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
        _logOverlayView.hidden = YES;
    }
    return _logOverlayView;
}

- (UIView *)logDialogView {
    if (!_logDialogView) {
        _logDialogView = [[UIView alloc] init];
        _logDialogView.backgroundColor = UIColor.whiteColor;
        _logDialogView.layer.cornerRadius = 8;
        _logDialogView.layer.masksToBounds = YES;
    }
    return _logDialogView;
}

- (UITextView *)logTextView {
    if (!_logTextView) {
        _logTextView = [[UITextView alloc] init];
        _logTextView.text = XTLS(@"XT_No_Operation");
        _logTextView.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _logTextView.textColor = XTCOLOR(0x667085);
        _logTextView.backgroundColor = XTCOLOR(0xF8FAFC);
        _logTextView.layer.cornerRadius = 8;
        _logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
        _logTextView.editable = NO;
    }
    return _logTextView;
}

@end
