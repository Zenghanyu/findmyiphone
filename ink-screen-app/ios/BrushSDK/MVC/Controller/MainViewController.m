//
//  MainViewController.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import "MainViewController.h"
#import "XTBleBindViewController.h"
#import "LYFPhotosManager.h"
#import "SLImageClipController.h"
#import "BrushScreenController.h"
#import "XTPhotoResampler.h"
#import "XTInkPhotoProcessor.h"
#import "PrismBrushController.h"
#import "XTOTAViewController.h"
#import "XTImageStorageViewController.h"
#import "Masonry.h"
#import "UtilsMacros.h"
#import "XTMBManager.h"
#import "NFCHelper.h"
#import "XTTool.h"
#import "XTScreenSpecConfig.h"

#define kMainAccent      XTCOLOR(0x2F6BFF)
#define kMainText        XTCOLOR(0x172033)
#define kSubText         XTCOLOR(0x667085)
#define kCardBorder      XTCOLOR(0xE5E7EB)
#define kPageBg          XTCOLOR(0xF4F6FB)

@interface MainViewController ()<NFCHelperDelegate, XTBleBindViewControllerDelegate, UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *contentStack;
@property(nonatomic, strong) UILabel *subtitleLabel;
@property(nonatomic, strong) UIView *deviceIconBackgroundView;
@property(nonatomic, strong) UIImageView *deviceArrowView;
@property(nonatomic, strong) UILabel *deviceTitleLabel;
@property(nonatomic, strong) UILabel *deviceBadgeLabel;
@property(nonatomic, strong) UILabel *deviceStatusLabel;
@property(nonatomic, strong) UILabel *deviceMetaLabel;
@property(nonatomic, strong) UIControl *bindModuleButton;
@property(nonatomic, strong) UIControl *brushModuleButton;
@property(nonatomic, strong) UIControl *storageModuleButton;
@property(nonatomic, strong) UIControl *otaModuleButton;
@property(nonatomic, strong) XTDeviceConfig *currentInfo;
@property(nonatomic, copy) NSString *pendingBindMac;
@property(nonatomic, assign) XTBrushType pendingBindBrushType;
@property(nonatomic, copy) NSArray<XTScreenSpec *> *screenPickerOptions;
@property(nonatomic, weak) UIViewController *screenPickerController;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = kPageBg;
    self.title = XTLS(@"XT_Device_Manager");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageClippingComplete:) name:@"sl_ImageClippingComplete" object:nil];
    [self buildUI];
    [self loadLocalDevice];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI

- (void)buildUI {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentStack];
    
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    }];
    [self.contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.scrollView).inset(18);
        make.left.right.equalTo(self.view).inset(16);
    }];
    
    UILabel *titleLabel = [self labelWithText:@"BrushSDK Demo" font:[UIFont systemFontOfSize:26 weight:UIFontWeightBold] color:kMainText];
    self.subtitleLabel = [self labelWithText:XTLS(@"XT_SDK_Module_Subtitle") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kSubText];
    [self.contentStack addArrangedSubview:titleLabel];
    [self.contentStack addArrangedSubview:self.subtitleLabel];
    [self.contentStack setCustomSpacing:16 afterView:self.subtitleLabel];
    
    UIControl *deviceCard = [self deviceSummaryCard];
    [self.contentStack addArrangedSubview:deviceCard];
    [self.contentStack setCustomSpacing:18 afterView:deviceCard];
    
    UILabel *sectionLabel = [self labelWithText:XTLS(@"XT_Function_Modules") font:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:kMainText];
    [self.contentStack addArrangedSubview:sectionLabel];
    [self.contentStack setCustomSpacing:8 afterView:sectionLabel];
    
    [self.contentStack addArrangedSubview:self.bindModuleButton];
    [self.contentStack addArrangedSubview:self.brushModuleButton];
    [self.contentStack addArrangedSubview:self.storageModuleButton];
    [self.contentStack addArrangedSubview:self.otaModuleButton];
    
    [self refreshDeviceInfoUI:nil];
}

- (UIControl *)deviceSummaryCard {
    UIControl *card = [self cardControlWithAction:@selector(deviceDetailModuleClicked:)];
    
    UIView *iconBackground = [[UIView alloc] init];
    iconBackground.backgroundColor = XTCOLOR(0xEEF4FF);
    iconBackground.layer.cornerRadius = 10;
    iconBackground.userInteractionEnabled = NO;
    self.deviceIconBackgroundView = iconBackground;
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"display"]];
    iconView.tintColor = kMainAccent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    
    UILabel *deviceTitleLabel = [self labelWithText:XTLS(@"XT_Current_Device") font:[UIFont systemFontOfSize:13 weight:UIFontWeightMedium] color:kSubText];
    deviceTitleLabel.numberOfLines = 1;
    deviceTitleLabel.adjustsFontSizeToFitWidth = YES;
    deviceTitleLabel.minimumScaleFactor = 0.85;
    deviceTitleLabel.userInteractionEnabled = NO;
    self.deviceTitleLabel = deviceTitleLabel;
    
    self.deviceBadgeLabel = [self badgeLabelWithText:XTLS(@"XT_Unbound")];
    self.deviceStatusLabel = [self labelWithText:XTLS(@"XT_No_Device_Bound") font:[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold] color:kMainText];
    self.deviceStatusLabel.numberOfLines = 1;
    self.deviceStatusLabel.adjustsFontSizeToFitWidth = YES;
    self.deviceStatusLabel.minimumScaleFactor = 0.85;
    self.deviceStatusLabel.userInteractionEnabled = NO;
    
    self.deviceMetaLabel = [self labelWithText:XTLS(@"XT_Tap_Bind_Device_Below") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kSubText];
    self.deviceMetaLabel.numberOfLines = 2;
    self.deviceMetaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.deviceMetaLabel.userInteractionEnabled = NO;

    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    arrowView.tintColor = XTCOLOR(0x98A2B3);
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.userInteractionEnabled = NO;
    self.deviceArrowView = arrowView;
    
    [card addSubview:iconBackground];
    [iconBackground addSubview:iconView];
    [card addSubview:deviceTitleLabel];
    [card addSubview:self.deviceBadgeLabel];
    [card addSubview:self.deviceStatusLabel];
    [card addSubview:self.deviceMetaLabel];
    [card addSubview:arrowView];
    
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(iconBackground);
        make.width.height.mas_equalTo(24);
    }];
    [self remakeDeviceSummaryConstraintsForBound:NO showBadge:YES];
    [card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_greaterThanOrEqualTo(72);
    }];
    
    return card;
}

- (void)remakeDeviceSummaryConstraintsForBound:(BOOL)bound showBadge:(BOOL)showBadge {
    UIView *card = self.deviceTitleLabel.superview;
    if (!card) {
        return;
    }
    
    [self.deviceIconBackgroundView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(card).offset(14);
        make.centerY.equalTo(card);
        make.width.height.mas_equalTo(44);
    }];
    [self.deviceArrowView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(card).inset(14);
        make.centerY.equalTo(card);
        make.width.height.mas_equalTo(16);
    }];
    [self.deviceBadgeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (showBadge) {
            if (bound) {
                make.left.equalTo(self.deviceTitleLabel.mas_right).offset(8);
                make.right.lessThanOrEqualTo(self.deviceArrowView.mas_left).offset(-10);
            } else {
                make.right.equalTo(self.deviceArrowView.mas_left).offset(-10);
            }
            make.centerY.equalTo(bound ? self.deviceTitleLabel : card);
            make.width.mas_greaterThanOrEqualTo(72);
            make.height.mas_equalTo(24);
        } else {
            make.right.equalTo(self.deviceArrowView.mas_left);
            make.centerY.equalTo(self.deviceTitleLabel);
            make.width.height.mas_equalTo(0);
        }
    }];
    [self.deviceTitleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.deviceIconBackgroundView.mas_right).offset(12);
        if (showBadge) {
            make.right.lessThanOrEqualTo(self.deviceBadgeLabel.mas_left).offset(-8);
        } else {
            make.right.lessThanOrEqualTo(self.deviceArrowView.mas_left).offset(-12);
        }
        make.height.mas_equalTo(20);
        if (bound) {
            make.top.equalTo(card).offset(14);
        } else {
            make.centerY.equalTo(card);
        }
    }];
    [self.deviceStatusLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.deviceTitleLabel);
        make.right.equalTo(self.deviceArrowView.mas_left).offset(-12);
        if (bound) {
            make.top.equalTo(self.deviceTitleLabel.mas_bottom).offset(8);
            make.height.mas_greaterThanOrEqualTo(24);
        } else {
            make.top.equalTo(self.deviceTitleLabel.mas_bottom);
            make.height.mas_equalTo(0);
        }
    }];
    [self.deviceMetaLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.deviceTitleLabel);
        make.right.equalTo(self.deviceArrowView.mas_left).offset(-12);
        if (bound) {
            make.top.equalTo(self.deviceStatusLabel.mas_bottom).offset(4);
            make.bottom.equalTo(card).inset(14);
        } else {
            make.top.equalTo(self.deviceStatusLabel.mas_bottom);
            make.height.mas_equalTo(0);
        }
    }];
}

- (void)fillCard:(UIView *)card views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.userInteractionEnabled = NO;
    [card addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(card).inset(14);
    }];
}

- (UIView *)cardView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.whiteColor;
    view.layer.cornerRadius = 8;
    view.layer.borderWidth = 1;
    view.layer.borderColor = kCardBorder.CGColor;
    return view;
}

- (UIControl *)cardControlWithAction:(SEL)action {
    UIControl *control = [[UIControl alloc] init];
    control.backgroundColor = UIColor.whiteColor;
    control.layer.cornerRadius = 8;
    control.layer.borderWidth = 1;
    control.layer.borderColor = kCardBorder.CGColor;
    [control addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return control;
}

- (UILabel *)badgeLabelWithText:(NSString *)text {
    UILabel *label = [self labelWithText:text font:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold] color:kSubText];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = XTCOLOR(0xF2F4F7);
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    label.layer.cornerRadius = 7;
    label.layer.masksToBounds = YES;
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_greaterThanOrEqualTo(72);
        make.height.mas_equalTo(24);
    }];
    return label;
}

- (UIView *)headerRowWithLeftView:(UIView *)leftView rightView:(UIView *)rightView {
    UIView *row = [[UIView alloc] init];
    [row addSubview:leftView];
    [row addSubview:rightView];
    [leftView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(row);
        make.right.lessThanOrEqualTo(rightView.mas_left).offset(-12);
        make.height.mas_greaterThanOrEqualTo(24);
    }];
    [rightView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.centerY.equalTo(row);
    }];
    return row;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UILabel *)valueLabelWithText:(NSString *)text {
    UILabel *label = [self labelWithText:text.length > 0 ? text : @"-" font:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold] color:kMainText];
    label.textAlignment = NSTextAlignmentRight;
    return label;
}

- (UIView *)infoRowWithTitle:(NSString *)title valueLabel:(UILabel *)valueLabel {
    UIView *row = [[UIView alloc] init];
    UILabel *titleLabel = [self labelWithText:title font:[UIFont systemFontOfSize:14 weight:UIFontWeightRegular] color:kSubText];
    [row addSubview:titleLabel];
    [row addSubview:valueLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(row);
        make.height.mas_greaterThanOrEqualTo(24);
    }];
    [valueLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLabel.mas_right).offset(12);
        make.right.top.bottom.equalTo(row);
        make.width.mas_greaterThanOrEqualTo(160);
    }];
    return row;
}

- (UIControl *)screenPickerButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIControl *button = [[UIControl alloc] init];
    button.backgroundColor = UIColor.whiteColor;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = kCardBorder.CGColor;
    
    UILabel *label = [self labelWithText:title font:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular] color:color];
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.85;
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    [button addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(button).inset(18);
        make.centerY.equalTo(button);
    }];
    
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(52);
    }];
    return button;
}

- (UIControl *)moduleButtonWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageName:(NSString *)imageName action:(SEL)action {
    UIControl *button = [[UIControl alloc] init];
    button.backgroundColor = UIColor.whiteColor;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = kCardBorder.CGColor;
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:imageName]];
    iconView.tintColor = kMainAccent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    
    UILabel *titleLabel = [self labelWithText:title font:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:kMainText];
    titleLabel.numberOfLines = 1;
    titleLabel.userInteractionEnabled = NO;
    UILabel *subtitleLabel = [self labelWithText:subtitle font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] color:kSubText];
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    subtitleLabel.userInteractionEnabled = NO;
    
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.userInteractionEnabled = NO;
    
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    arrowView.tintColor = XTCOLOR(0x98A2B3);
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.userInteractionEnabled = NO;
    
    [button addSubview:iconView];
    [button addSubview:textStack];
    [button addSubview:arrowView];
    
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(button).offset(14);
        make.centerY.equalTo(button);
        make.width.height.mas_equalTo(24);
    }];
    [arrowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(button).inset(14);
        make.centerY.equalTo(button);
        make.width.height.mas_equalTo(16);
    }];
    [textStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconView.mas_right).offset(12);
        make.right.equalTo(arrowView.mas_left).offset(-12);
        make.centerY.equalTo(button);
    }];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(72);
    }];
    return button;
}

- (UIControl *)moduleButtonWithTitle:(NSString *)title subtitle:(NSString *)subtitle warning:(NSString *)warning imageName:(NSString *)imageName action:(SEL)action {
    UIControl *button = [[UIControl alloc] init];
    button.backgroundColor = UIColor.whiteColor;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = kCardBorder.CGColor;
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:imageName]];
    iconView.tintColor = kMainAccent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    
    UILabel *titleLabel = [self labelWithText:title font:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:kMainText];
    titleLabel.numberOfLines = 1;
    titleLabel.userInteractionEnabled = NO;
    UILabel *subtitleLabel = [self labelWithText:subtitle font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] color:kSubText];
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    subtitleLabel.userInteractionEnabled = NO;
    UILabel *warningLabel = [self labelWithText:warning font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] color:XTCOLOR(0xD92D20)];
    warningLabel.numberOfLines = 2;
    warningLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    warningLabel.userInteractionEnabled = NO;
    
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel, warningLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.userInteractionEnabled = NO;
    
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    arrowView.tintColor = XTCOLOR(0x98A2B3);
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.userInteractionEnabled = NO;
    
    [button addSubview:iconView];
    [button addSubview:textStack];
    [button addSubview:arrowView];
    
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(button).offset(14);
        make.centerY.equalTo(button);
        make.width.height.mas_equalTo(24);
    }];
    [arrowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(button).inset(14);
        make.centerY.equalTo(button);
        make.width.height.mas_equalTo(16);
    }];
    [textStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(iconView.mas_right).offset(12);
        make.right.equalTo(arrowView.mas_left).offset(-12);
        make.centerY.equalTo(button);
    }];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(92);
    }];
    return button;
}

- (void)loadLocalDevice {
    XTDeviceConfig *info = [XTDeviceConfig readLocalCfg];
    if (info) {
        self.currentInfo = info;
        [self refreshDeviceInfoUI:info];
    }
}

- (void)refreshDeviceInfoUI:(XTDeviceConfig *)config {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL hasDevice = config != nil;
        if (!hasDevice) {
            self.subtitleLabel.text = XTLS(@"XT_Bind_First_Then_Use_Modules");
            self.deviceBadgeLabel.text = XTLS(@"XT_Unbound");
            self.deviceBadgeLabel.hidden = NO;
            self.deviceBadgeLabel.textColor = kSubText;
            self.deviceBadgeLabel.backgroundColor = XTCOLOR(0xF2F4F7);
            self.deviceStatusLabel.text = @"";
            self.deviceMetaLabel.text = @"";
            self.deviceStatusLabel.hidden = YES;
            self.deviceMetaLabel.hidden = YES;
            [self remakeDeviceSummaryConstraintsForBound:NO showBadge:YES];
            return;
        }
        
        NSString *size = [NSString stringWithFormat:@"%ld x %ld", (long)config.screenWidth, (long)config.screenHeight];
        NSString *color = [self colorTextWithConfig:config];
        NSString *mac = [self deviceMacText:config].length > 0 ? [self deviceMacText:config] : @"-";
        BOOL isAntiLostDevice = config.antiLostDevice || [config isFindMyAndNeedSendChangeToBrushMode];
        self.subtitleLabel.text = XTLS(@"XT_Device_Bound_Use_Modules");
        self.deviceBadgeLabel.hidden = !isAntiLostDevice;
        self.deviceBadgeLabel.text = isAntiLostDevice ? XTLS(@"XT_Anti_Lost_Device") : @"";
        self.deviceBadgeLabel.textColor = isAntiLostDevice ? XTCOLOR(0xB54708) : kMainAccent;
        self.deviceBadgeLabel.backgroundColor = isAntiLostDevice ? XTCOLOR(0xFFFAEB) : XTCOLOR(0xEEF4FF);
        self.deviceStatusLabel.hidden = NO;
        self.deviceMetaLabel.hidden = NO;
        [self remakeDeviceSummaryConstraintsForBound:YES showBadge:isAntiLostDevice];
        self.deviceStatusLabel.text = [NSString stringWithFormat:@"%@ · %@", size, color];
        self.deviceMetaLabel.text = [NSString stringWithFormat:@"MAC %@", mac];
    });
}

#pragma mark - Actions

- (void)bindModuleClicked:(UIControl *)button {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:XTLS(@"XT_Bind_Device") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:XTLS(@"XT_BLE_Bind_Short") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self startBLEBind];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:XTLS(@"XT_NFC_Bind_Short") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self startNFCBind];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:XTLS(@"XT_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    popover.sourceView = button ?: self.view;
    popover.sourceRect = button ? button.bounds : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds), 1, 1);
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startNFCBind {
    NFCHelper *nfcAdapter = [NFCHelper shareInstance];
    if (nfcAdapter.isReading) {
        return;
    }
    nfcAdapter.delegate = self;
    [nfcAdapter getDeviceConfig:XTLS(@"XT_Close_To_Equipment") isNeedScanTip:YES];
}

- (void)startBLEBind {
    XTBleBindViewController *vc = [[XTBleBindViewController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)deviceDetailModuleClicked:(UIControl *)button {
    if (!self.currentInfo) {
        [self bindModuleClicked:button];
        return;
    }
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = XTLS(@"XT_Device_Detail");
    vc.view.backgroundColor = kPageBg;
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [vc.view addSubview:scrollView];
    [scrollView addSubview:stack];
    [scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(vc.view.mas_safeAreaLayoutGuideTop);
        make.left.right.equalTo(vc.view);
        make.bottom.equalTo(vc.view.mas_safeAreaLayoutGuideBottom);
    }];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(scrollView).inset(16);
        make.left.right.equalTo(vc.view).inset(16);
    }];
    
    UILabel *titleLabel = [self labelWithText:XTLS(@"XT_Device_Detail") font:[UIFont systemFontOfSize:24 weight:UIFontWeightBold] color:kMainText];
    [stack addArrangedSubview:titleLabel];
    
    UIView *baseCard = [self cardView];
    [self fillCard:baseCard views:@[
        [self infoRowWithTitle:@"MAC" valueLabel:[self valueLabelWithText:[self deviceMacText:self.currentInfo]]],
        [self infoRowWithTitle:XTLS(@"XT_Resolution") valueLabel:[self valueLabelWithText:[NSString stringWithFormat:@"%ld x %ld", (long)self.currentInfo.screenWidth, (long)self.currentInfo.screenHeight]]],
        [self infoRowWithTitle:XTLS(@"XT_Color") valueLabel:[self valueLabelWithText:[self colorTextWithConfig:self.currentInfo]]],
        [self infoRowWithTitle:XTLS(@"XT_Communication_Method") valueLabel:[self valueLabelWithText:[self communicationTextWithConfig:self.currentInfo]]],
        [self infoRowWithTitle:XTLS(@"XT_Support_Status") valueLabel:[self valueLabelWithText:[self.currentInfo isSupportedBindingDevice] ? XTLS(@"XT_Bindable") : XTLS(@"XT_Unsupported")]],
        [self infoRowWithTitle:XTLS(@"XT_Firmware_Version") valueLabel:[self valueLabelWithText:self.currentInfo.version.length > 0 ? self.currentInfo.version : @"-"]],
        [self infoRowWithTitle:XTLS(@"XT_Battery") valueLabel:[self valueLabelWithText:self.currentInfo.power.length > 0 ? self.currentInfo.power : @"-"]]
    ]];
    [stack addArrangedSubview:baseCard];
    
    UIView *paramCard = [self cardView];
    [self fillCard:paramCard views:@[
        [self infoRowWithTitle:XTLS(@"XT_Color_Count") valueLabel:[self valueLabelWithText:[NSString stringWithFormat:@"%ld", (long)self.currentInfo.colorCount]]],
        [self infoRowWithTitle:XTLS(@"XT_Image_Capacity") valueLabel:[self valueLabelWithText:[NSString stringWithFormat:@"%ld", (long)self.currentInfo.imageCount]]],
        [self infoRowWithTitle:XTLS(@"XT_Write_Area_Count") valueLabel:[self valueLabelWithText:[NSString stringWithFormat:@"%ld", (long)self.currentInfo.writeImageCount]]],
        [self infoRowWithTitle:XTLS(@"XT_Scan_Direction") valueLabel:[self valueLabelWithText:self.currentInfo.scanType == VerticalType ? XTLS(@"XT_Vertical") : XTLS(@"XT_Horizontal")]]
    ]];
    [stack addArrangedSubview:paramCard];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)directBrushModuleClicked:(UIControl *)button {
    if (![self ensureBoundDevice]) {
        return;
    }
    if ([self.currentInfo isPrismDeviceConfig]) {
        [self openPrismBrush];
        return;
    }
    [self selectImageForDirectBrush];
}

- (void)selectImageForDirectBrush {
    __weak typeof(self) weakSelf = self;
    [LYFPhotosManager showPhotosManager:self withMaxImageCount:10 selectComplete:^(UIImage *selectedImage){
        if (selectedImage) {
            SLImageClipController *imageClipController = [[SLImageClipController alloc] init];
            imageClipController.modalPresentationStyle = UIModalPresentationFullScreen;
            imageClipController.image = selectedImage;
            imageClipController.deviceConfig = weakSelf.currentInfo;
            [weakSelf presentViewController:imageClipController animated:NO completion:nil];
        } else {
            [[NFCHelper shareInstance] alertMsg:XTLS(@"XT_Download_From_Icloud")];
        }
    }];
}

- (void)imageStorageModuleClicked:(UIControl *)button {
    if (![self ensureBoundDevice]) {
        return;
    }
    if ([self.currentInfo isPrismDeviceConfig] || self.currentInfo.imageStorage == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Image_Storage_Carousel_Unsupported") delayHid:1.5];
        return;
    }
    
    XTImageStorageViewController *vc = [[XTImageStorageViewController alloc] initWithDeviceConfig:self.currentInfo];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)otaModuleClicked:(UIControl *)button {
    if (![self ensureBoundDevice]) {
        return;
    }
    
    XTOTAViewController *vc = [[XTOTAViewController alloc] initWithDeviceConfig:self.currentInfo];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openPrismBrush {
    if (![self.currentInfo isPrismDeviceConfig]) {
        [XTMBManager showAlertViewWithText:NSLocalizedString(@"XT_notsupported", nil) delayHid:1.5];
        return;
    }
    
    PrismBrushController *pvc = [[PrismBrushController alloc] init];
    pvc.deviceInfo = self.currentInfo;
    [self.navigationController pushViewController:pvc animated:YES];
}

- (BOOL)ensureBoundDevice {
    if (!self.currentInfo) {
        [XTMBManager showAlertViewWithText:NSLocalizedString(@"XT_Please_Bind_Device", nil) delayHid:1.5];
        return NO;
    }
    return YES;
}

#pragma mark - Image Clip

- (void)imageClippingComplete:(NSNotification *)notification {
    UIImage *clipImage = notification.userInfo[@"image"];
    if (!clipImage || !self.currentInfo) {
        return;
    }
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] init];
    backItem.title = XTLS(@"XT_Back");
    self.navigationItem.backBarButtonItem = backItem;
    
    XTDeviceConfig *config = self.currentInfo;
    [XTMBManager showWaitingWithTitle:XTLS(@"XT_Processing_Image") view:[XTTool getKeyWindow]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            CGSize targetSize = CGSizeMake(config.screenWidth, config.screenHeight);
            UIImage *inputImage = [XTInkPhotoProcessor usesHinkProfile:config]
                ? [XTPhotoResampler resizeImageUsingDPID:clipImage toSize:targetSize]
                : [XTPhotoResampler resizeImage:clipImage toSize:targetSize];
            BOOL roundPanel = config.screenWidth == 400 && config.screenHeight == 400;
            UIImage *roundInput = roundPanel ? [XTPhotoResampler roundPanelImage:clipImage
                                                                        toSize:CGSizeMake(config.screenWidth, config.screenHeight)
                                                               rotationDegrees:69.7] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [XTMBManager safeDismiss];
                if (self.currentInfo != config || self.navigationController.topViewController != self) return;
                if (!inputImage || (roundPanel && !roundInput)) {
                    [XTMBManager showAlertViewWithText:XTLS(@"XT_Convert_Image_Fail") delayHid:1.5];
                    return;
                }
                BrushScreenController *childController = [[BrushScreenController alloc] init];
                childController.orignImage = inputImage;
                childController.roundPanelInputImage = roundInput;
                childController.deviceConfig = config;
                [self.navigationController pushViewController:childController animated:YES];
            });
        }
    });
}

- (UIImage *)scaledImageFormImage:(UIImage *)image toSize:(CGSize)size {
    return [XTPhotoResampler resizeImage:image toSize:size];
}

#pragma mark - Device Text

- (NSString *)deviceMacText:(XTDeviceConfig *)config {
    if (config.uuID.length > 0) {
        return config.uuID;
    }
    if (config.appID.length > 0) {
        return config.appID;
    }
    return @"";
}

- (NSString *)colorTextWithConfig:(XTDeviceConfig *)config {
    NSString *color = [config.screenColorName stringByReplacingOccurrencesOfString:@"FM_C_" withString:@""];
    return color.length > 0 ? color : @"-";
}

- (NSString *)communicationTextWithConfig:(XTDeviceConfig *)config {
    if (config.brushType == brushWithBle) {
        return @"BLE";
    }
    if (config.brushType == brushWithNfc) {
        return @"NFC";
    }
    return XTLS(@"XT_NFC_Powered_BLE_Transfer");
}

#pragma mark - Bind Screen

/**
 *  @brief 进入选屏绑定流程 | Starts the screen selection bind flow.
 *  @discussion
 *  NFC或BLE绑定入口只负责拿到MAC，真正的分辨率、颜色、扫描方向来自用户选择的屏幕规格。
 *  NFC/BLE binding only provides the MAC. Resolution, color capability, and scan direction come from the selected screen spec.
 */
- (void)beginScreenSelectionWithMac:(NSString *)mac brushType:(XTBrushType)brushType {
    NSString *cleanMac = [[mac ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([XTTool isBlankString:cleanMac]) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Invalid_MAC") delayHid:1.5];
        return;
    }
    self.pendingBindMac = cleanMac;
    self.pendingBindBrushType = brushType;
    [self showScreenPickerWithMac:cleanMac];
}

/**
 *  @brief 弹出屏幕规格选择面板 | Presents the screen spec picker.
 *  @discussion
 *  面板数据来自XTScreenSpecConfig，页面不直接维护屏幕参数，避免后续新增屏幕时改UI逻辑。
 *  The picker is driven by XTScreenSpecConfig, so adding screens does not require UI logic changes.
 */
- (void)showScreenPickerWithMac:(NSString *)mac {
    NSArray<XTScreenSpec *> *screenOptions = [self.class screenSpecOptions];
    if (screenOptions.count == 0) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_No_Screen_Options") delayHid:1.5];
        return;
    }
    
    UIViewController *picker = [[UIViewController alloc] init];
    picker.modalPresentationStyle = UIModalPresentationOverFullScreen;
    picker.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    picker.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    
    UIView *sheet = [[UIView alloc] init];
    sheet.backgroundColor = UIColor.whiteColor;
    sheet.layer.cornerRadius = 12;
    sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [picker.view addSubview:sheet];
    [sheet mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(picker.view);
        make.top.greaterThanOrEqualTo(picker.view.mas_safeAreaLayoutGuideTop).offset(48);
    }];
    
    UILabel *titleLabel = [self labelWithText:XTLS(@"XT_Select_Screen") font:[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold] color:kMainText];
    UILabel *macLabel = [self labelWithText:mac.length > 0 ? mac : @"-" font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular] color:kSubText];
    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, macLabel]];
    headerStack.axis = UILayoutConstraintAxisVertical;
    headerStack.spacing = 4;
    
    self.screenPickerOptions = screenOptions;
    self.screenPickerController = picker;
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.backgroundColor = UIColor.whiteColor;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 52;
    tableView.estimatedRowHeight = 52;
    tableView.scrollEnabled = screenOptions.count > 9;
    tableView.separatorInset = UIEdgeInsetsMake(0, 18, 0, 18);
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0;
    }
    
    UIControl *cancelButton = [self screenPickerButtonWithTitle:XTLS(@"XT_Cancel") color:kSubText];
    
    [sheet addSubview:headerStack];
    [sheet addSubview:tableView];
    [sheet addSubview:cancelButton];
    
    [headerStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(sheet).offset(18);
        make.left.right.equalTo(sheet).inset(18);
    }];
    [cancelButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(sheet).inset(12);
        make.bottom.equalTo(picker.view.mas_safeAreaLayoutGuideBottom).inset(8);
        make.height.mas_equalTo(48);
    }];
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(headerStack.mas_bottom).offset(12);
        make.left.right.equalTo(sheet);
        make.bottom.equalTo(cancelButton.mas_top).offset(-18);
        make.height.mas_equalTo(MIN(screenOptions.count, 9) * 52);
    }];
    
    __weak UIViewController *weakPicker = picker;
    [cancelButton addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        [weakPicker dismissViewControllerAnimated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [[self topVisibleViewController] presentViewController:picker animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.screenPickerOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"ScreenPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = UIColor.whiteColor;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        cell.textLabel.textColor = kMainText;
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.85;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    if (indexPath.row < self.screenPickerOptions.count) {
        XTScreenSpec *spec = self.screenPickerOptions[indexPath.row];
        cell.textLabel.text = [self screenSpecTitle:spec];
    } else {
        cell.textLabel.text = @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.screenPickerOptions.count) {
        return;
    }
    
    XTScreenSpec *spec = self.screenPickerOptions[indexPath.row];
    __weak typeof(self) weakSelf = self;
    [self.screenPickerController dismissViewControllerAnimated:YES completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf bindPendingMacWithScreenSpec:spec];
    }];
}

- (UIViewController *)topVisibleViewController {
    UIViewController *controller = self.navigationController ?: self;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

/**
 *  @brief 根据选中的屏幕规格生成并保存设备配置 | Builds and saves device config from the selected screen spec.
 *  @discussion
 *  当前版本不再通过后台设备表推导屏幕能力；这里显式把屏幕宽高、颜色、扫描方向写入XTDeviceConfig。
 *  The current flow does not infer screen capability from a backend device table; it writes width, height, color, and scan type explicitly.
 */
- (void)bindPendingMacWithScreenSpec:(XTScreenSpec *)spec {
    XTDeviceConfig *config = [XTTool getBindDeviceDataWithDeviceNumber:0
                                                                   mac:self.pendingBindMac
                                                           screenWidth:spec.width
                                                          screenHeight:spec.height
                                                                 color:spec.color
                                                      allowUnsupported:YES];
    if (!config) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Screen_Config_Failed") delayHid:1.5];
        return;
    }
    config.brushType = self.pendingBindBrushType;
    config.appID = self.pendingBindMac;
    config.uuID = self.pendingBindMac;
    config.screenSpecNumber = spec.number;
    config.imageDataProcessType = spec.imageDataProcessType;
    config.scanType = spec.scanType;
    config.needsFindMyBrushModeSwitch = spec.needsFindMyBrushModeSwitch;
    config.antiLostDevice = spec.antiLostDevice;
    DLog(@"bind screen spec: number=%ld size=%ldx%ld color=%@ scanType=%ld antiLost=%@ findMySwitch=%@ mac=%@",
         (long)spec.number,
         (long)spec.width,
         (long)spec.height,
         spec.color,
         (long)spec.scanType,
         spec.antiLostDevice ? @"YES" : @"NO",
         spec.needsFindMyBrushModeSwitch ? @"YES" : @"NO",
         self.pendingBindMac);
    self.currentInfo = config;
    [XTDeviceConfig saveLocalCfg:config];
    [self refreshDeviceInfoUI:config];
    [XTMBManager showAlertViewWithText:XTLS(@"XT_bindsuccess") delayHid:1.5];
}

/**
 *  @brief 选屏列表数据源 | Data source for the screen picker.
 */
+ (NSArray<XTScreenSpec *> *)screenSpecOptions {
    return [XTScreenSpecConfig defaultScreenSpecs];
}

/**
 *  @brief 生成屏幕选项展示文案 | Builds display text for one screen option.
 */
- (NSString *)screenSpecTitle:(XTScreenSpec *)spec {
    NSString *titleKey = spec.titleKey;
    NSString *title = titleKey.length > 0 ? XTLS(titleKey) : XTLS(@"XT_Screen");
    return [NSString stringWithFormat:XTLS(@"XT_Screen_Spec_Title_Format"),
            title,
            @(spec.width),
            @(spec.height)];
}

#pragma mark - Delegate

/**
 *  @brief NFC读取到MAC后进入选屏流程 | Enters screen selection after NFC reads the MAC.
 */
- (void)NfcReadConfigComplete:(XTDeviceConfig *)config {
    if (!config) {
        return;
    }
    NSString *mac = [self deviceMacText:config];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self beginScreenSelectionWithMac:mac brushType:config.brushType];
    });
}

- (void)backBindMac:(NSString *)mac {
    if ([XTTool isBlankString:mac]) {
        [XTMBManager showAlertViewWithText:XTLS(@"BindingFailed") delayHid:1.5];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self beginScreenSelectionWithMac:mac brushType:brushWithBle];
    });
}

#pragma mark - Lazy

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
        _contentStack.spacing = 12;
    }
    return _contentStack;
}

- (UIControl *)bindModuleButton {
    if (!_bindModuleButton) {
        _bindModuleButton = [self moduleButtonWithTitle:XTLS(@"XT_Bind_Device") subtitle:XTLS(@"XT_Bind_Device_Subtitle") imageName:@"link" action:@selector(bindModuleClicked:)];
    }
    return _bindModuleButton;
}

- (UIControl *)brushModuleButton {
    if (!_brushModuleButton) {
        _brushModuleButton = [self moduleButtonWithTitle:XTLS(@"XT_Direct_Brush") subtitle:XTLS(@"XT_Direct_Brush_Subtitle") imageName:@"photo" action:@selector(directBrushModuleClicked:)];
    }
    return _brushModuleButton;
}

- (UIControl *)storageModuleButton {
    if (!_storageModuleButton) {
        _storageModuleButton = [self moduleButtonWithTitle:XTLS(@"XT_Image_Manager_Carousel") subtitle:XTLS(@"XT_Image_Manager_Carousel_Subtitle") warning:XTLS(@"XT_Image_Manager_Firmware_Warning") imageName:@"rectangle.stack" action:@selector(imageStorageModuleClicked:)];
    }
    return _storageModuleButton;
}

- (UIControl *)otaModuleButton {
    if (!_otaModuleButton) {
        _otaModuleButton = [self moduleButtonWithTitle:XTLS(@"XT_OTA") subtitle:XTLS(@"XT_OTA_Subtitle") imageName:@"arrow.up.circle" action:@selector(otaModuleClicked:)];
    }
    return _otaModuleButton;
}

@end
