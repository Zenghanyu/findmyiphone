//
//  XTImageStorageViewController.m
//  BrushSDK
//
//  Created by Codex on 2026/7/3.
//

#import "XTImageStorageViewController.h"
#import "LYFPhotosManager.h"
#import "Masonry.h"
#import "UtilsMacros.h"
#import "XTMBManager.h"
#import "XTImageDitherUtils.h"
#import "XTPhotoResampler.h"
#import "XTInkPhotoProcessor.h"
#import "XTBleWriteHelper.h"
#import "NFCHelper.h"
#import "XTTool.h"

static NSInteger const XTImageStorageMaxIndex = 6;

#define kImageStorageAccent XTCOLOR(0x2F6BFF)
#define kImageStorageText XTCOLOR(0x172033)
#define kImageStorageSubText XTCOLOR(0x667085)
#define kImageStorageBorder XTCOLOR(0xE5E7EB)
#define kImageStorageBg XTCOLOR(0xF4F6FB)

@interface XTImageStorageViewController ()<UITextFieldDelegate, NFCHelperDelegate>

@property(nonatomic, strong) XTDeviceConfig *deviceConfig;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIButton *indexButton;
@property(nonatomic, strong) UIImageView *previewImageView;
@property(nonatomic, strong) UILabel *placeholderLabel;
@property(nonatomic, strong) UIButton *sendButton;
@property(nonatomic, strong) UIButton *fastNFCButton;
@property(nonatomic, strong) UITextField *carouselTimeField;
@property(nonatomic, strong) UIButton *startCarouselButton;
@property(nonatomic, strong) UIButton *stopCarouselButton;
@property(nonatomic, strong) UILabel *stageLabel;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UIImage *selectedImage;
@property(nonatomic, strong) NSMutableArray *preparedUploadData;
@property(nonatomic, assign) NSInteger selectedIndex;
@property(nonatomic, assign) BOOL operationRunning;
@property(nonatomic, assign) BOOL pendingFastNFCWrite;

@end

@implementation XTImageStorageViewController

- (instancetype)initWithDeviceConfig:(XTDeviceConfig *)deviceConfig {
    self = [super init];
    if (self) {
        _deviceConfig = deviceConfig;
        _selectedIndex = 1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = XTLS(@"XT_Image_Manager");
    self.view.backgroundColor = kImageStorageBg;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self buildUI];
    [self refreshIndexMenu];
    [self updateStage:XTLS(@"XT_Waiting_Operation") progress:0 animated:NO];
    
    UITapGestureRecognizer *keyboardDismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    keyboardDismissTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:keyboardDismissTap];
}

#pragma mark - UI

- (void)buildUI {
    [self.view addSubview:self.scrollView];
    UIView *contentView = [[UIView alloc] init];
    [self.scrollView addSubview:contentView];
    
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.scrollView);
        make.left.right.equalTo(self.scrollView);
        make.width.equalTo(self.view);
    }];
    
    UILabel *titleLabel = [self labelWithText:XTLS(@"XT_Image_Manager") font:[UIFont systemFontOfSize:24 weight:UIFontWeightBold] color:kImageStorageText];
    UILabel *subtitleLabel = [self labelWithText:XTLS(@"XT_Image_Manager_Carousel_Subtitle") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kImageStorageSubText];
    
    UIView *previewCard = [self cardView];
    UILabel *previewTitle = [self labelWithText:XTLS(@"XT_Image_Preview") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kImageStorageText];
    UIView *previewBox = [[UIView alloc] init];
    previewBox.backgroundColor = XTCOLOR(0xF8FAFC);
    previewBox.layer.cornerRadius = 8;
    previewBox.layer.borderWidth = 1;
    previewBox.layer.borderColor = kImageStorageBorder.CGColor;
    previewBox.clipsToBounds = YES;
    [previewBox addSubview:self.previewImageView];
    [previewBox addSubview:self.placeholderLabel];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectImage)];
    [previewBox addGestureRecognizer:tap];
    
    UIView *imageActionCard = [self cardView];
    
    UIView *carouselCard = [self cardView];
    UILabel *carouselTitle = [self labelWithText:XTLS(@"XT_Carousel") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kImageStorageText];
    
    UIView *progressCard = [self cardView];
    self.stageLabel = [self labelWithText:@"" font:[UIFont systemFontOfSize:13 weight:UIFontWeightMedium] color:kImageStorageAccent];
    self.stageLabel.numberOfLines = 2;
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progressTintColor = kImageStorageAccent;
    self.progressView.trackTintColor = XTCOLOR(0xE6EAF2);
    
    [contentView addSubview:titleLabel];
    [contentView addSubview:self.indexButton];
    [contentView addSubview:subtitleLabel];
    [contentView addSubview:previewCard];
    [previewCard addSubview:previewTitle];
    [previewCard addSubview:previewBox];
    [contentView addSubview:imageActionCard];
    [imageActionCard addSubview:self.sendButton];
    [imageActionCard addSubview:self.fastNFCButton];
    [contentView addSubview:carouselCard];
    [carouselCard addSubview:carouselTitle];
    [carouselCard addSubview:self.carouselTimeField];
    [carouselCard addSubview:self.startCarouselButton];
    [carouselCard addSubview:self.stopCarouselButton];
    [contentView addSubview:progressCard];
    [progressCard addSubview:self.stageLabel];
    [progressCard addSubview:self.progressView];
    
    CGFloat previewHeight = 280;
    if (self.deviceConfig.screenWidth > 0 && self.deviceConfig.screenHeight > 0) {
        CGFloat availableWidth = XTScreenWidth - 64;
        CGFloat aspectHeight = availableWidth * self.deviceConfig.screenHeight / self.deviceConfig.screenWidth;
        previewHeight = MIN(MAX(aspectHeight, 180), 320);
    }
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(contentView).offset(18);
        make.left.equalTo(contentView).offset(16);
        make.right.lessThanOrEqualTo(self.indexButton.mas_left).offset(-12);
    }];
    [self.indexButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLabel);
        make.right.equalTo(contentView).inset(16);
        make.width.mas_equalTo(118);
        make.height.mas_equalTo(40);
    }];
    [subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLabel.mas_bottom).offset(6);
        make.left.equalTo(titleLabel);
        make.right.equalTo(contentView).inset(16);
    }];
    [previewCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(subtitleLabel.mas_bottom).offset(16);
        make.left.right.equalTo(contentView).inset(16);
    }];
    [previewTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(previewCard).inset(14);
    }];
    [previewBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(previewTitle.mas_bottom).offset(12);
        make.left.right.bottom.equalTo(previewCard).inset(14);
        make.height.mas_equalTo(previewHeight);
    }];
    [self.previewImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(previewBox).inset(8);
    }];
    [self.placeholderLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(previewBox);
        make.left.right.equalTo(previewBox).inset(20);
    }];
    [imageActionCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(previewCard.mas_bottom).offset(12);
        make.left.right.equalTo(contentView).inset(16);
    }];
    [self.sendButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(imageActionCard).inset(14);
        make.height.mas_equalTo(44);
    }];
    [self.fastNFCButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.sendButton.mas_bottom).offset(12);
        make.left.right.bottom.equalTo(imageActionCard).inset(14);
        make.height.mas_equalTo(44);
    }];
    [carouselCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(imageActionCard.mas_bottom).offset(12);
        make.left.right.equalTo(contentView).inset(16);
    }];
    [carouselTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(carouselCard).offset(14);
        make.right.lessThanOrEqualTo(self.carouselTimeField.mas_left).offset(-12);
    }];
    [self.carouselTimeField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.right.equalTo(carouselCard).inset(14);
        make.width.mas_equalTo(112);
        make.height.mas_equalTo(40);
    }];
    [self.startCarouselButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.carouselTimeField.mas_bottom).offset(12);
        make.left.equalTo(carouselCard).offset(14);
        make.right.equalTo(self.stopCarouselButton.mas_left).offset(-10);
        make.bottom.equalTo(carouselCard).inset(14);
        make.height.mas_equalTo(44);
        make.width.equalTo(self.stopCarouselButton);
    }];
    [self.stopCarouselButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.startCarouselButton);
        make.right.equalTo(carouselCard).inset(14);
    }];
    [progressCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(carouselCard.mas_bottom).offset(12);
        make.left.right.equalTo(contentView).inset(16);
        make.bottom.equalTo(contentView).inset(20);
    }];
    [self.stageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(progressCard).inset(14);
    }];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.stageLabel.mas_bottom).offset(12);
        make.left.right.bottom.equalTo(progressCard).inset(14);
        make.height.mas_equalTo(6);
    }];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIView *)cardView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.whiteColor;
    view.layer.cornerRadius = 8;
    view.layer.borderWidth = 1;
    view.layer.borderColor = kImageStorageBorder.CGColor;
    return view;
}

- (UIImageView *)iconViewWithName:(NSString *)name {
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:name]];
    iconView.tintColor = kImageStorageAccent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    return iconView;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title filled:(BOOL)filled action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:filled ? UIColor.whiteColor : kImageStorageAccent forState:UIControlStateNormal];
    [button setTitleColor:XTCOLOR(0x98A2B3) forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.backgroundColor = filled ? kImageStorageAccent : UIColor.whiteColor;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = (filled ? kImageStorageAccent : kImageStorageBorder).CGColor;
    if (action) {
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    }
    return button;
}

- (UIToolbar *)keyboardDoneToolbar {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 44)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:XTLS(@"XT_Done") style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    toolbar.items = @[space, done];
    return toolbar;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Refresh

- (void)refreshIndexMenu {
    [self.indexButton setTitle:[NSString stringWithFormat:XTLS(@"XT_Position_Format"), (long)self.selectedIndex] forState:UIControlStateNormal];
    
    NSMutableArray<UIAction *> *actions = [NSMutableArray arrayWithCapacity:XTImageStorageMaxIndex];
    __weak typeof(self) weakSelf = self;
    for (NSInteger index = 1; index <= XTImageStorageMaxIndex; index++) {
        NSString *title = [NSString stringWithFormat:@"%ld", (long)index];
        UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.selectedIndex = index;
            [weakSelf refreshIndexMenu];
        }];
        action.state = index == self.selectedIndex ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:action];
    }
    self.indexButton.menu = [UIMenu menuWithTitle:XTLS(@"XT_Select_Image_Position") children:actions];
}

- (void)updateStage:(NSString *)text progress:(float)progress animated:(BOOL)animated {
    self.stageLabel.text = text ?: @"";
    [self.progressView setProgress:MAX(0, MIN(1, progress)) animated:animated];
}

- (void)setOperationRunning:(BOOL)running stage:(NSString *)stage progress:(float)progress {
    self.operationRunning = running;
    [self updateStage:stage progress:progress animated:YES];
    self.indexButton.enabled = !running;
    self.sendButton.enabled = !running;
    self.fastNFCButton.enabled = !running;
    self.carouselTimeField.enabled = !running;
    self.startCarouselButton.enabled = !running;
    self.stopCarouselButton.enabled = !running;
    CGFloat alpha = running ? 0.5 : 1.0;
    self.indexButton.alpha = alpha;
    self.sendButton.alpha = alpha;
    self.fastNFCButton.alpha = alpha;
    self.carouselTimeField.alpha = alpha;
    self.startCarouselButton.alpha = alpha;
    self.stopCarouselButton.alpha = alpha;
}

#pragma mark - Actions

- (void)selectImage {
    if (self.operationRunning) {
        return;
    }
    if (![self ensureImageStorageSupported]) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [LYFPhotosManager showPhotosManager:self withMaxImageCount:1 selectComplete:^(UIImage *selectedImage) {
        if (!selectedImage) {
            [[NFCHelper shareInstance] alertMsg:XTLS(@"XT_Download_From_Icloud")];
            return;
        }
        [weakSelf prepareSelectedImage:selectedImage];
    }];
}

- (void)sendSelectedImage {
    if (self.operationRunning) {
        return;
    }
    if (![self ensureImageStorageSupported]) {
        return;
    }
    if (!self.selectedImage) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Select_Image_First") delayHid:1.5];
        return;
    }
    if (!self.preparedUploadData || self.preparedUploadData.count == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Image_Not_Ready") delayHid:1.5];
        return;
    }
    [self writeImageData:self.preparedUploadData imageIndex:self.selectedIndex];
}

- (void)fastNFCSendSelectedImage {
    if (self.operationRunning) {
        return;
    }
    if (![self ensureImageStorageSupported]) {
        return;
    }
    if (!self.selectedImage) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Select_Image_First") delayHid:1.5];
        return;
    }
    if (!self.preparedUploadData || self.preparedUploadData.count == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Image_Not_Ready") delayHid:1.5];
        return;
    }
    if (self.deviceConfig.brushType != brushWithBle) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Unsupported_Device") delayHid:1.5];
        return;
    }
    
    NFCHelper *nfc = [NFCHelper shareInstance];
    if (nfc.isReading) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Processing") delayHid:1.5];
        return;
    }
    
    self.pendingFastNFCWrite = YES;
    [self setOperationRunning:YES stage:XTLS(@"XT_Waiting_NFC_Fast_Broadcast") progress:0.25];
    nfc.delegate = self;
    NSString *response = [nfc getDeviceConfig:XTLS(@"XT_Close_To_Equipment") isNeedScanTip:NO];
    if (response.length > 0) {
        self.pendingFastNFCWrite = NO;
        [XTMBManager showAlertViewWithText:response delayHid:1.5];
        [self setOperationRunning:NO stage:XTLS(@"XT_Send_Failed") progress:0];
    }
}

#pragma mark - Image Storage

- (void)prepareSelectedImage:(UIImage *)image {
    self.selectedImage = image;
    self.preparedUploadData = nil;
    self.previewImageView.image = nil;
    self.placeholderLabel.hidden = NO;
    
    [self setOperationRunning:YES stage:XTLS(@"XT_Dithering_Processing") progress:0.1];
    [XTMBManager showWaitingWithTitle:XTLS(@"XT_Processing_Image") view:[XTTool getKeyWindow]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            CGSize targetSize = CGSizeMake(MAX(self.deviceConfig.screenWidth, 1), MAX(self.deviceConfig.screenHeight, 1));
            UIImage *screenImage = [XTInkPhotoProcessor usesHinkProfile:self.deviceConfig]
                ? [XTPhotoResampler aspectFillImageUsingDPID:image toSize:targetSize]
                : [XTPhotoResampler aspectFillImage:image toSize:targetSize];
            UIImage *previewImage = nil;
            UIImage *thresholdImage = nil;
            if (screenImage) {
                [XTImageDitherUtils convertToUploadData:screenImage
                                           previewImage:&previewImage
                                         thresholdImage:&thresholdImage
                                              deviceCfg:self.deviceConfig
                                                algType:ALG_TYPE_DITHER];
            }
        
            NSMutableArray *uploadData = nil;
            if (previewImage) {
                uploadData = [XTImageDitherUtils getUploadDataFromDitherImage:previewImage
                                                                    deviceCfg:self.deviceConfig];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [XTMBManager safeDismiss];
                if (!previewImage || !thresholdImage || !uploadData || uploadData.count == 0) {
                    [self setOperationRunning:NO stage:XTLS(@"XT_Image_Process_Failed") progress:0];
                    [XTMBManager showAlertViewWithText:XTLS(@"XT_Convert_Image_Fail") delayHid:1.5];
                    return;
                }
                self.preparedUploadData = uploadData;
                self.previewImageView.image = thresholdImage;
                self.placeholderLabel.hidden = YES;
                [self setOperationRunning:NO stage:XTLS(@"XT_Dither_Complete_Sendable") progress:0.2];
            });
        }
    });
}

- (void)writeImageData:(NSMutableArray *)uploadData imageIndex:(NSInteger)imageIndex {
    NSInteger safeIndex = MIN(MAX(imageIndex, 1), XTImageStorageMaxIndex);
    [self setOperationRunning:YES stage:[NSString stringWithFormat:XTLS(@"XT_Sending_To_Position_Format"), (long)safeIndex] progress:0.25];
    
    __weak typeof(self) weakSelf = self;
    [[XTBleWriteHelper shareInstance] importImageStorageDataToDeviceWithImageHexDataArr:uploadData
                                                                           deviceConfig:self.deviceConfig
                                                                               sendSize:244
                                                                             imageIndex:safeIndex
                                                                            refreshFlag:XTImageStorageRefreshFlagSaveAndRefresh
                                                                                  param:0
                                                                        writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isSuccess) {
                [weakSelf setOperationRunning:NO stage:XTLS(@"XT_Send_Complete") progress:1.0];
                [XTMBManager showAlertViewWithText:XTLS(@"XT_Send_Complete") delayHid:1.2];
            } else {
                [weakSelf setOperationRunning:NO stage:XTLS(@"XT_Send_Failed") progress:0];
                [XTMBManager showAlertViewWithText:error ?: XTLS(@"XT_Send_Failed") delayHid:1.5];
            }
        });
    } advData:nil];
}

#pragma mark - NFCHelperDelegate

- (void)NfcReadConfigComplete:(XTDeviceConfig *)config {
    if (!self.pendingFastNFCWrite) {
        return;
    }
    self.pendingFastNFCWrite = NO;
    if (!config) {
        [self setOperationRunning:NO stage:XTLS(@"XT_Send_Failed") progress:0];
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Send_Failed") delayHid:1.5];
        return;
    }
    if (!self.preparedUploadData || self.preparedUploadData.count == 0) {
        [self setOperationRunning:NO stage:XTLS(@"XT_Image_Not_Ready") progress:0];
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Image_Not_Ready") delayHid:1.5];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self writeImageData:self.preparedUploadData imageIndex:self.selectedIndex];
    });
}

- (void)errCallBack:(NSString *)errMsg {
    if (!self.pendingFastNFCWrite) {
        return;
    }
    self.pendingFastNFCWrite = NO;
    [self setOperationRunning:NO stage:XTLS(@"XT_Waiting_Operation") progress:0];
    if (errMsg.length > 0) {
        [XTMBManager showAlertViewWithText:errMsg delayHid:1.5];
    }
}

- (void)startCarousel {
    if (![self ensureImageStorageSupported]) {
        return;
    }
    NSInteger minutes = [self carouselIntervalMinutes];
    [self updateCarouselWithInterval:minutes];
}

- (void)stopCarousel {
    if (![self ensureImageStorageSupported]) {
        return;
    }
    [self updateCarouselWithInterval:0];
}

- (NSInteger)carouselIntervalMinutes {
    NSInteger minutes = self.carouselTimeField.text.integerValue;
    return MIN(MAX(minutes, 1), 255);
}

- (void)updateCarouselWithInterval:(NSInteger)interval {
    [self.view endEditing:YES];
    [self setOperationRunning:YES stage:interval > 0 ? XTLS(@"XT_Carousel_Opening") : XTLS(@"XT_Carousel_Closing") progress:0.2];
    
    __weak typeof(self) weakSelf = self;
    [[XTBleWriteHelper shareInstance] updateImageStorageCarouselWithDeviceConfig:self.deviceConfig
                                                                      startIndex:1
                                                                 intervalMinutes:interval
                                                                 writeImageBlock:^(BOOL isSuccess, NSString * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isSuccess) {
                [weakSelf setOperationRunning:NO stage:interval > 0 ? XTLS(@"XT_Carousel_Opened") : XTLS(@"XT_Carousel_Closed") progress:1.0];
                [XTMBManager showAlertViewWithText:interval > 0 ? XTLS(@"XT_Carousel_Opened") : XTLS(@"XT_Carousel_Closed") delayHid:1.2];
            } else {
                [weakSelf setOperationRunning:NO stage:XTLS(@"XT_Carousel_Setting_Failed") progress:0];
                [XTMBManager showAlertViewWithText:error ?: XTLS(@"XT_Carousel_Setting_Failed") delayHid:1.5];
            }
        });
    } advData:nil];
}

#pragma mark - Helpers

- (BOOL)ensureImageStorageSupported {
    if (!self.deviceConfig) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Please_Bind_Device") delayHid:1.5];
        return NO;
    }
    if ([self.deviceConfig isPrismDeviceConfig]) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_notsupported") delayHid:1.5];
        return NO;
    }
    if (self.deviceConfig.imageStorage == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Image_Manager_Unsupported") delayHid:1.5];
        return NO;
    }
    return YES;
}

- (UIImage *)scaledAspectFillImage:(UIImage *)image toSize:(CGSize)size {
    return [XTPhotoResampler aspectFillImage:image toSize:size];
}

#pragma mark - Lazy

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (UIButton *)indexButton {
    if (!_indexButton) {
        _indexButton = [self actionButtonWithTitle:[NSString stringWithFormat:XTLS(@"XT_Position_Format"), (long)1] filled:NO action:nil];
        _indexButton.showsMenuAsPrimaryAction = YES;
    }
    return _indexButton;
}

- (UIImageView *)previewImageView {
    if (!_previewImageView) {
        _previewImageView = [[UIImageView alloc] init];
        _previewImageView.contentMode = UIViewContentModeScaleAspectFit;
        _previewImageView.clipsToBounds = YES;
    }
    return _previewImageView;
}

- (UILabel *)placeholderLabel {
    if (!_placeholderLabel) {
        _placeholderLabel = [self labelWithText:XTLS(@"XT_Tap_Select_Image") font:[UIFont systemFontOfSize:16] color:[UIColor grayColor]];
        _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _placeholderLabel;
}

- (UIButton *)sendButton {
    if (!_sendButton) {
        _sendButton = [self actionButtonWithTitle:XTLS(@"XT_Send") filled:YES action:@selector(sendSelectedImage)];
    }
    return _sendButton;
}

- (UIButton *)fastNFCButton {
    if (!_fastNFCButton) {
        _fastNFCButton = [self actionButtonWithTitle:XTLS(@"XT_Fast_NFC_Send") filled:YES action:@selector(fastNFCSendSelectedImage)];
        [_fastNFCButton setImage:[UIImage imageNamed:@"icn_nfc_fast"] forState:UIControlStateNormal];
        _fastNFCButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _fastNFCButton;
}

- (UITextField *)carouselTimeField {
    if (!_carouselTimeField) {
        _carouselTimeField = [[UITextField alloc] init];
        _carouselTimeField.text = @"10";
        _carouselTimeField.placeholder = XTLS(@"XT_Minutes");
        _carouselTimeField.keyboardType = UIKeyboardTypeNumberPad;
        _carouselTimeField.returnKeyType = UIReturnKeyDone;
        _carouselTimeField.delegate = self;
        _carouselTimeField.inputAccessoryView = [self keyboardDoneToolbar];
        _carouselTimeField.textAlignment = NSTextAlignmentCenter;
        _carouselTimeField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _carouselTimeField.backgroundColor = UIColor.whiteColor;
        _carouselTimeField.layer.cornerRadius = 8;
        _carouselTimeField.layer.borderWidth = 1;
        _carouselTimeField.layer.borderColor = kImageStorageBorder.CGColor;
        _carouselTimeField.textColor = kImageStorageText;
    }
    return _carouselTimeField;
}

- (UIButton *)startCarouselButton {
    if (!_startCarouselButton) {
        _startCarouselButton = [self actionButtonWithTitle:XTLS(@"XT_Start_Carousel") filled:YES action:@selector(startCarousel)];
    }
    return _startCarouselButton;
}

- (UIButton *)stopCarouselButton {
    if (!_stopCarouselButton) {
        _stopCarouselButton = [self actionButtonWithTitle:XTLS(@"XT_Stop_Carousel") filled:NO action:@selector(stopCarousel)];
    }
    return _stopCarouselButton;
}

@end
