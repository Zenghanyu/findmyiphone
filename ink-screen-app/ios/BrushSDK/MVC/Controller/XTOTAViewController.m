//
//  XTOTAViewController.m
//  BrushSDK
//
//  Created by Codex on 2026/7/3.
//

#import "XTOTAViewController.h"
#import "Masonry.h"
#import "UtilsMacros.h"
#import "XTMBManager.h"
#import "XTBleWriteHelper.h"
#import "NFCHelper.h"

#define kOTAAccent XTCOLOR(0x2F6BFF)
#define kOTAText XTCOLOR(0x172033)
#define kOTASubText XTCOLOR(0x667085)
#define kOTABorder XTCOLOR(0xE5E7EB)
#define kOTABg XTCOLOR(0xF4F6FB)

@interface XTOTAViewController ()<UIDocumentPickerDelegate,NFCHelperDelegate>

@property(nonatomic, strong) XTDeviceConfig *deviceConfig;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UILabel *configLabel;
@property(nonatomic, strong) UILabel *fileStatusLabel;
@property(nonatomic, strong) UILabel *stageLabel;
@property(nonatomic, strong) UILabel *logLabel;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UIButton *selectButton;
@property(nonatomic, strong) UIButton *startButton;
@property(nonatomic, strong) NSData *selectedFileData;
@property(nonatomic, copy) NSString *selectedFileName;

@end

@implementation XTOTAViewController

- (instancetype)initWithDeviceConfig:(XTDeviceConfig *)deviceConfig {
    self = [super init];
    if (self) {
        _deviceConfig = deviceConfig;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = kOTABg;
    self.title = @"OTA";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self buildUI];
    [self refreshState];
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
    
    UILabel *titleLabel = [self labelWithText:XTLS(@"XT_Firmware_Update") font:[UIFont systemFontOfSize:24 weight:UIFontWeightBold] color:kOTAText];
    self.subtitleLabel = [self labelWithText:@"" font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kOTASubText];
    
    UIView *configCard = [self cardView];
    UIImageView *configIcon = [self iconViewWithName:@"display"];
    UILabel *configTitle = [self labelWithText:XTLS(@"XT_Basic_Info") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kOTAText];
    self.configLabel = [self labelWithText:@"" font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kOTASubText];
    self.configLabel.numberOfLines = 0;
    
    UIView *fileCard = [self cardView];
    UIImageView *fileIcon = [self iconViewWithName:@"doc"];
    UILabel *fileTitle = [self labelWithText:XTLS(@"XT_Update_File") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kOTAText];
    self.fileStatusLabel = [self labelWithText:@"" font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kOTASubText];
    self.fileStatusLabel.numberOfLines = 0;
    
    UIView *progressCard = [self cardView];
    self.stageLabel = [self labelWithText:XTLS(@"XT_Wait_Select_Bin_File") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kOTAAccent];
    self.stageLabel.numberOfLines = 2;
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progressTintColor = kOTAAccent;
    self.progressView.trackTintColor = XTCOLOR(0xE6EAF2);
    
    UIView *logCard = [self cardView];
    UILabel *logTitle = [self labelWithText:XTLS(@"XT_Log") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kOTAText];
    self.logLabel = [self labelWithText:XTLS(@"XT_No_Operation") font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] color:kOTASubText];
    self.logLabel.numberOfLines = 0;
    
    [contentView addSubview:titleLabel];
    [contentView addSubview:self.subtitleLabel];
    [contentView addSubview:configCard];
    [configCard addSubview:configIcon];
    [configCard addSubview:configTitle];
    [configCard addSubview:self.configLabel];
    [contentView addSubview:fileCard];
    [fileCard addSubview:fileIcon];
    [fileCard addSubview:fileTitle];
    [fileCard addSubview:self.fileStatusLabel];
    [fileCard addSubview:self.selectButton];
    [fileCard addSubview:self.startButton];
    [contentView addSubview:progressCard];
    [progressCard addSubview:self.stageLabel];
    [progressCard addSubview:self.progressView];
    [contentView addSubview:logCard];
    [logCard addSubview:logTitle];
    [logCard addSubview:self.logLabel];
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(contentView).offset(18);
        make.left.right.equalTo(contentView).inset(16);
    }];
    [self.subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLabel.mas_bottom).offset(6);
        make.left.right.equalTo(titleLabel);
    }];
    [configCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.subtitleLabel.mas_bottom).offset(16);
        make.left.right.equalTo(titleLabel);
    }];
    [configIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(configCard).offset(14);
        make.top.equalTo(configCard).offset(16);
        make.width.height.mas_equalTo(28);
    }];
    [configTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(configCard).offset(14);
        make.left.equalTo(configIcon.mas_right).offset(12);
        make.right.equalTo(configCard).inset(14);
    }];
    [self.configLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(configTitle.mas_bottom).offset(6);
        make.left.equalTo(configTitle);
        make.right.bottom.equalTo(configCard).inset(14);
    }];
    [fileCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(configCard.mas_bottom).offset(12);
        make.left.right.equalTo(titleLabel);
    }];
    [fileIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(fileCard).offset(14);
        make.top.equalTo(fileCard).offset(16);
        make.width.height.mas_equalTo(28);
    }];
    [fileTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(fileCard).offset(14);
        make.left.equalTo(fileIcon.mas_right).offset(12);
        make.right.equalTo(fileCard).inset(14);
    }];
    [self.fileStatusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(fileTitle.mas_bottom).offset(6);
        make.left.equalTo(fileTitle);
        make.right.equalTo(fileCard).inset(14);
    }];
    [self.selectButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.fileStatusLabel.mas_bottom).offset(14);
        make.left.equalTo(fileCard).offset(14);
        make.right.equalTo(self.startButton.mas_left).offset(-10);
        make.bottom.equalTo(fileCard).inset(14);
        make.height.mas_equalTo(44);
        make.width.equalTo(self.startButton);
    }];
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.selectButton);
        make.right.equalTo(fileCard).inset(14);
    }];
    [progressCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(fileCard.mas_bottom).offset(12);
        make.left.right.equalTo(titleLabel);
    }];
    [self.stageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(progressCard).inset(14);
    }];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.stageLabel.mas_bottom).offset(12);
        make.left.right.bottom.equalTo(progressCard).inset(14);
        make.height.mas_equalTo(6);
    }];
    [logCard mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(progressCard.mas_bottom).offset(12);
        make.left.right.equalTo(titleLabel);
        make.bottom.equalTo(contentView).inset(20);
    }];
    [logTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(logCard).inset(14);
    }];
    [self.logLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(logTitle.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(logCard).inset(14);
        make.height.mas_greaterThanOrEqualTo(60);
    }];
}

- (UIView *)cardView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor whiteColor];
    view.layer.cornerRadius = 8;
    view.layer.borderColor = kOTABorder.CGColor;
    view.layer.borderWidth = 1;
    return view;
}

- (UIImageView *)iconViewWithName:(NSString *)name {
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:name]];
    iconView.tintColor = kOTAAccent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    return iconView;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title filled:(BOOL)filled action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:filled ? [UIColor whiteColor] : kOTAAccent forState:UIControlStateNormal];
    [button setTitleColor:XTCOLOR(0x98A2B3) forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.backgroundColor = filled ? kOTAAccent : [UIColor whiteColor];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = (filled ? kOTAAccent : kOTABorder).CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshState {
    BOOL supportsOTA = [self supportsOTAForCurrentDevice];
    self.subtitleLabel.text = XTLS(@"XT_OTA_Subtitle");
    NSString *color = [self.deviceConfig.screenColorName stringByReplacingOccurrencesOfString:@"FM_C_" withString:@""] ?: @"-";
    self.configLabel.text = [NSString stringWithFormat:@"%@: %@\n%@: %ld x %ld\n%@: %@\n%@: %@",
                             XTLS(@"XT_MAC"),
                             [self deviceMacText],
                             XTLS(@"XT_Resolution"),
                             (long)self.deviceConfig.screenWidth,
                             (long)self.deviceConfig.screenHeight,
                             XTLS(@"XT_Color"),
                             color,
                             XTLS(@"XT_Communication_Method"),
                             [self communicationText]];
    self.fileStatusLabel.text = supportsOTA ? (self.selectedFileName.length > 0 ? [NSString stringWithFormat:XTLS(@"XT_File_Selected_Format"), self.selectedFileName] : XTLS(@"XT_Select_Bin_File_Tips")) : XTLS(@"XT_NFC_Device_Unsupported_OTA");
    self.selectButton.enabled = supportsOTA;
    self.selectButton.alpha = self.selectButton.enabled ? 1.0 : 0.45;
    self.startButton.enabled = supportsOTA && self.selectedFileData.length > 0;
    self.startButton.alpha = self.startButton.enabled ? 1.0 : 0.45;
    if (!supportsOTA) {
        self.stageLabel.text = XTLS(@"XT_NFC_Device_Unsupported_OTA");
        self.progressView.progress = 0;
    }
}

- (BOOL)supportsOTAForCurrentDevice {
    return self.deviceConfig && self.deviceConfig.brushType != brushWithNfc;
}

- (NSString *)communicationText {
    if (self.deviceConfig.brushType == brushWithBle) {
        return @"BLE";
    }
    if (self.deviceConfig.brushType == brushWithNfc) {
        return @"NFC";
    }
    return XTLS(@"XT_NFC_Powered_BLE_Transfer");
}

- (NSString *)deviceMacText {
    if (self.deviceConfig.uuID.length > 0) {
        return self.deviceConfig.uuID;
    }
    if (self.deviceConfig.appID.length > 0) {
        return self.deviceConfig.appID;
    }
    return @"-";
}

#pragma mark - Actions
- (void)selectBinFile {
    NSArray *allowedTypes = @[@"com.apple.binary-data", @"public.data"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:allowedTypes inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)startOTA {
    if (!self.deviceConfig) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Please_Bind_Device") delayHid:1.5];
        return;
    }
    if (self.selectedFileData.length == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Select_Bin_File_First") delayHid:1.5];
        return;
    }
    if (![self supportsOTAForCurrentDevice]) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_NFC_Device_Unsupported_OTA") delayHid:1.5];
        [self appendLog:XTLS(@"XT_NFC_Device_Unsupported_OTA")];
        return;
    }
    
    NSMutableArray *otaData = [NSMutableArray arrayWithCapacity:self.selectedFileData.length];
    const unsigned char *bytes = self.selectedFileData.bytes;
    for (NSUInteger i = 0; i < self.selectedFileData.length; i++) {
        [otaData addObject:@(bytes[i])];
    }
    
    self.stageLabel.text = XTLS(@"XT_OTA_Started");
    self.progressView.progress = 0.2;
    [self appendLog:[NSString stringWithFormat:XTLS(@"XT_OTA_Start_Log_Format"), self.selectedFileName, self.selectedFileData.length / 1024.0]];
    
    if (self.deviceConfig.brushType == brushWithBle) {
        [[XTBleWriteHelper shareInstance] importOTADataToDeviceWithOtaHexData:otaData
                                                                 deviceConfig:self.deviceConfig
                                                                     sendSize:244];
        [self appendLog:[NSString stringWithFormat:XTLS(@"XT_Transfer_Method_Format"), @"BLE"]];
        return;
    }
    
    NFCHelper *instance = [NFCHelper shareInstance];
    if(instance.isReading){
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Processing") delayHid:1.5];
        return;
    }
    instance.delegate = self;
    NSString *response = [instance importOTAToDevice:@"OTA"
                                           imageData:self.selectedFileData
                                         imageDataXT:otaData
                                           screenCfg:self.deviceConfig
                                  imageSectionNumber:0
                                                 pin:nil
                                            PageSize:10
                                        IntervalTime:10];
    [self appendLog:[NSString stringWithFormat:XTLS(@"XT_Transfer_Method_Format"), @"NFCHelper"]];
    if(response.length > 0){
        [XTMBManager showAlertViewWithText:response delayHid:1.5];
        [self appendLog:response];
    }
}

- (void)appendLog:(NSString *)log {
    NSString *oldText = self.logLabel.text.length > 0 ? self.logLabel.text : @"";
    if ([oldText isEqualToString:XTLS(@"XT_No_Operation")]) {
        oldText = @"";
    }
    NSString *line = [NSString stringWithFormat:@"%@%@", oldText.length > 0 ? @"\n" : @"", log ?: @""];
    self.logLabel.text = [oldText stringByAppendingString:line];
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) {
        return;
    }
    BOOL authorized = [url startAccessingSecurityScopedResource];
    if (!authorized) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_nopermission") delayHid:1.5];
        return;
    }
    
    NSString *fileName = url.lastPathComponent ?: @"";
    if ([[fileName pathExtension] caseInsensitiveCompare:@"bin"] != NSOrderedSame) {
        [url stopAccessingSecurityScopedResource];
        [XTMBManager showAlertViewWithText:XTLS(@"XT_filetypeerror") delayHid:1.5];
        return;
    }
    
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
    [url stopAccessingSecurityScopedResource];
    if (!data || error) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_readotaerror") delayHid:1.5];
        return;
    }
    
    self.selectedFileData = data;
    self.selectedFileName = fileName;
    self.stageLabel.text = XTLS(@"XT_File_Ready");
    self.progressView.progress = 0;
    [self appendLog:[NSString stringWithFormat:XTLS(@"XT_File_Selected_Log_Format"), fileName]];
    [self refreshState];
}

#pragma mark - Lazy
- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (UIButton *)selectButton {
    if (!_selectButton) {
        _selectButton = [self actionButtonWithTitle:XTLS(@"XT_Select_Bin") filled:NO action:@selector(selectBinFile)];
    }
    return _selectButton;
}

- (UIButton *)startButton {
    if (!_startButton) {
        _startButton = [self actionButtonWithTitle:XTLS(@"XT_Start_OTA") filled:YES action:@selector(startOTA)];
    }
    return _startButton;
}

@end
