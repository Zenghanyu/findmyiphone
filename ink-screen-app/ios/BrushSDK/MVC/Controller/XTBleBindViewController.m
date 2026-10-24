//
//  XTBleBindViewController.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/3/5.
//

#import "XTBleBindViewController.h"
#import "Masonry.h"
#import "UtilsMacros.h"
#import "XTMBManager.h"
#import "XTBleWriteHelper.h"
#import "XTTool.h"

#define kBindAccent      XTCOLOR(0x2F6BFF)
#define kBindText        XTCOLOR(0x172033)
#define kBindSubText     XTCOLOR(0x667085)
#define kBindBorder      XTCOLOR(0xE5E7EB)
#define kBindBg          XTCOLOR(0xF4F6FB)
#define kBindDanger      XTCOLOR(0xD92D20)

@interface XTBleBindViewController ()<UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *contentStack;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIActivityIndicatorView *activityView;
@property(nonatomic, strong) UIButton *clearFilterButton;
@property(nonatomic, strong) UIButton *colorFilterButton;
@property(nonatomic, strong) UIButton *resolutionFilterButton;
@property(nonatomic, strong) UIButton *deviceNumberFilterButton;
@property(nonatomic, strong) UILabel *emptyLabel;
@property(nonatomic, strong) UIStackView *deviceListStack;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableArray<XTBleScannedDevice *> *allDevices;
@property(nonatomic, copy) NSString *selectedColorFilter;
@property(nonatomic, copy) NSString *selectedResolutionFilter;
@property(nonatomic, copy) NSString *selectedDeviceNumberFilter;
@property(nonatomic, assign) BOOL scanning;
@property(nonatomic, assign) BOOL needsDeviceListRefresh;

@end

@implementation XTBleBindViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = XTLS(@"XTBLE_Bind");
    self.view.backgroundColor = kBindBg;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:XTLS(@"XT_Rescan")
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(startScan)];
    self.allDevices = [NSMutableArray array];
    self.selectedColorFilter = @"";
    self.selectedResolutionFilter = @"";
    self.selectedDeviceNumberFilter = @"";
    [self buildUI];
    [self startScan];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [[XTBleWriteHelper shareInstance] disconnectCurrentPeripherals];
    }
}

#pragma mark - UI

- (void)buildUI {
    [self.view addSubview:self.contentStack];
    [self.view addSubview:self.tableView];
    
    [self.contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(16);
        make.left.right.equalTo(self.view).inset(16);
    }];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentStack.mas_bottom).offset(12);
        make.left.right.equalTo(self.view).inset(16);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).inset(16);
    }];
    
    UILabel *titleLabel = [self labelWithText:XTLS(@"XT_BLE_Bind_Page_Title") font:[UIFont systemFontOfSize:24 weight:UIFontWeightBold] color:kBindText];
    UILabel *subtitleLabel = [self labelWithText:XTLS(@"XT_BLE_Bind_Subtitle") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kBindSubText];
    [self.contentStack addArrangedSubview:titleLabel];
    [self.contentStack addArrangedSubview:subtitleLabel];
    [self.contentStack setCustomSpacing:14 afterView:subtitleLabel];
    
    UIView *statusCard = [self cardView];
    UILabel *statusTitle = [self labelWithText:XTLS(@"XT_Scan_Status") font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] color:kBindText];
    UIStackView *statusRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.activityView, self.statusLabel]];
    statusRow.axis = UILayoutConstraintAxisHorizontal;
    statusRow.spacing = 10;
    statusRow.alignment = UIStackViewAlignmentCenter;
    [self fillCard:statusCard views:@[statusTitle, statusRow]];
    [self.contentStack addArrangedSubview:statusCard];
    
    UILabel *listTitle = [self labelWithText:XTLS(@"XT_MAC_List") font:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:kBindText];
    [self.contentStack addArrangedSubview:listTitle];
    [self.contentStack addArrangedSubview:self.emptyLabel];
    
    [self refreshDeviceList];
}

- (void)fillCard:(UIView *)card views:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
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
    view.layer.borderColor = kBindBorder.CGColor;
    return view;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIStackView *)horizontalStackWithViews:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10;
    stack.distribution = UIStackViewDistributionFillEqually;
    return stack;
}

- (UIButton *)plainButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:kBindAccent forState:UIControlStateNormal];
    button.backgroundColor = UIColor.whiteColor;
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 2;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = kBindAccent.CGColor;
    if (action) {
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    }
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
    }];
    return button;
}

- (UIButton *)filledButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [self plainButtonWithTitle:title action:action];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor = kBindAccent;
    return button;
}

#pragma mark - Scan

- (void)startScan {
    self.scanning = YES;
    self.needsDeviceListRefresh = NO;
    [self.allDevices removeAllObjects];
    self.statusLabel.text = XTLS(@"XT_Scanning_MAC_Status");
    [self.activityView startAnimating];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self refreshDeviceList];
    
    __weak typeof(self) weakSelf = self;
    [[XTBleWriteHelper shareInstance] scanAvailableDevicesWithUpdate:^(XTBleScannedDevice *device) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !device) {
            return;
        }
        [strongSelf upsertDevice:device];
    } completion:^(NSArray<XTBleScannedDevice *> *devices, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.scanning = NO;
        [strongSelf.activityView stopAnimating];
        strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
        if (error) {
            strongSelf.statusLabel.text = error.localizedDescription.length > 0 ? error.localizedDescription : XTLS(@"XT_Scan_Failed");
        } else {
            strongSelf.statusLabel.text = [NSString stringWithFormat:XTLS(@"XT_Scan_Result_Format"), (long)strongSelf.allDevices.count];
        }
        if (strongSelf.allDevices.count == 0) {
            [strongSelf refreshDeviceList];
        }
    }];
}

- (void)upsertDevice:(XTBleScannedDevice *)device {
    NSInteger oldIndex = [self indexOfDeviceWithMac:device.mac];
    if (oldIndex == NSNotFound) {
        [self.allDevices addObject:device];
    } else {
        self.allDevices[oldIndex] = device;
    }
    
    [self sortDevicesByRSSI];
    self.emptyLabel.hidden = YES;
    self.tableView.hidden = NO;
    [self scheduleDeviceListRefresh];
}

- (void)sortDevicesByRSSI {
    [self.allDevices sortUsingComparator:^NSComparisonResult(XTBleScannedDevice *left, XTBleScannedDevice *right) {
        NSInteger leftRSSI = left.rssi.integerValue;
        NSInteger rightRSSI = right.rssi.integerValue;
        if (leftRSSI != rightRSSI) {
            return leftRSSI > rightRSSI ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left.mac compare:right.mac options:NSCaseInsensitiveSearch];
    }];
}

- (NSInteger)indexOfDeviceWithMac:(NSString *)mac {
    if (mac.length == 0) {
        return NSNotFound;
    }
    for (NSInteger i = 0; i < self.allDevices.count; i++) {
        if ([self.allDevices[i].mac caseInsensitiveCompare:mac] == NSOrderedSame) {
            return i;
        }
    }
    return NSNotFound;
}

#pragma mark - Filter

- (NSArray<XTBleScannedDevice *> *)filteredDevices {
    return self.allDevices;
}

- (void)showColorFilter {
    [self showFilterWithTitle:XTLS(@"XT_Color") options:[self collectOptionsWithType:@"color"] selected:self.selectedColorFilter handler:^(NSString *value) {
        self.selectedColorFilter = value;
        [self refreshFilterButtons];
        [self refreshDeviceList];
    }];
}

- (void)showResolutionFilter {
    [self showFilterWithTitle:XTLS(@"XT_Resolution") options:[self collectOptionsWithType:@"resolution"] selected:self.selectedResolutionFilter handler:^(NSString *value) {
        self.selectedResolutionFilter = value;
        [self refreshFilterButtons];
        [self refreshDeviceList];
    }];
}

- (void)showDeviceNumberFilter {
    [self showFilterWithTitle:XTLS(@"XT_Device_Number") options:[self collectOptionsWithType:@"deviceNumber"] selected:self.selectedDeviceNumberFilter handler:^(NSString *value) {
        self.selectedDeviceNumberFilter = value;
        [self refreshFilterButtons];
        [self refreshDeviceList];
    }];
}

- (void)showFilterWithTitle:(NSString *)title
                    options:(NSArray<NSString *> *)options
                   selected:(NSString *)selected
                    handler:(void(^)(NSString *value))handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:XTLS(@"XT_All") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (handler) handler(@"");
    }]];
    for (NSString *option in options) {
        if (option.length == 0 || [option isEqualToString:@"-"]) {
            continue;
        }
        NSString *titleText = [option isEqualToString:selected] ? [NSString stringWithFormat:@"✓ %@", option] : option;
        [alert addAction:[UIAlertAction actionWithTitle:titleText style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if (handler) handler(option);
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:XTLS(@"XT_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    popover.sourceView = self.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds), 1, 1);
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray<NSString *> *)collectOptionsWithType:(NSString *)type {
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSet];
    for (XTBleScannedDevice *device in self.allDevices) {
        NSString *value = @"";
        if ([type isEqualToString:@"color"]) {
            value = device.colorText;
        } else if ([type isEqualToString:@"resolution"]) {
            value = [device resolutionText];
        } else {
            value = device.deviceNumber > 0 ? [NSString stringWithFormat:@"%ld", (long)device.deviceNumber] : @"";
        }
        if (value.length > 0 && ![value isEqualToString:@"-"]) {
            [set addObject:value];
        }
    }
    return [set.array sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

- (void)clearFilters {
    self.selectedColorFilter = @"";
    self.selectedResolutionFilter = @"";
    self.selectedDeviceNumberFilter = @"";
    [self refreshFilterButtons];
    [self refreshDeviceList];
}

- (void)refreshFilterButtons {
    [self.colorFilterButton setTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Color"), self.selectedColorFilter.length > 0 ? self.selectedColorFilter : XTLS(@"XT_All")] forState:UIControlStateNormal];
    [self.resolutionFilterButton setTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Resolution"), self.selectedResolutionFilter.length > 0 ? self.selectedResolutionFilter : XTLS(@"XT_All")] forState:UIControlStateNormal];
    [self.deviceNumberFilterButton setTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Device_Number"), self.selectedDeviceNumberFilter.length > 0 ? self.selectedDeviceNumberFilter : XTLS(@"XT_All")] forState:UIControlStateNormal];
}

#pragma mark - List

- (void)refreshDeviceList {
    NSArray<XTBleScannedDevice *> *items = [self filteredDevices];
    self.emptyLabel.hidden = items.count > 0;
    self.tableView.hidden = items.count == 0;
    if (items.count == 0) {
        self.emptyLabel.text = XTLS(@"XT_No_Device");
        [self.tableView reloadData];
        self.needsDeviceListRefresh = NO;
        return;
    }
    
    [self.tableView reloadData];
    self.needsDeviceListRefresh = NO;
}

- (void)scheduleDeviceListRefresh {
    if (self.needsDeviceListRefresh) {
        return;
    }
    self.needsDeviceListRefresh = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.needsDeviceListRefresh) {
            return;
        }
        [strongSelf refreshDeviceList];
    });
}

- (UIView *)deviceCardWithDevice:(XTBleScannedDevice *)device {
    UIView *card = [self cardView];
    BOOL canSelect = device.mac.length > 0;
    UIColor *stateColor = canSelect ? kBindAccent : kBindDanger;
    
    UILabel *titleLabel = [self labelWithText:[NSString stringWithFormat:@"MAC %@", device.mac.length > 0 ? device.mac : @"-"] font:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:kBindText];
    UILabel *badgeLabel = [self labelWithText:canSelect ? XTLS(@"XT_Pending_Screen") : XTLS(@"XT_Invalid_MAC") font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold] color:stateColor];
    
    UIStackView *titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, badgeLabel]];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.spacing = 8;
    titleRow.alignment = UIStackViewAlignmentCenter;
    titleRow.distribution = UIStackViewDistributionFill;
    
    UIButton *bindButton = [self filledButtonWithTitle:XTLS(@"XT_Select_Screen") action:nil];
    bindButton.enabled = canSelect;
    bindButton.alpha = bindButton.enabled ? 1.0 : 0.45;
    __weak typeof(self) weakSelf = self;
    [bindButton addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        [weakSelf bindScannedDevice:device];
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [self fillCard:card views:@[
        titleRow,
        [self infoRowWithTitle:@"MAC" value:device.mac.length > 0 ? device.mac : @"-"],
        [self infoRowWithTitle:XTLS(@"XT_Name") value:[self displayNameForDevice:device]],
        [self infoRowWithTitle:@"RSSI" value:device.rssi.length > 0 ? device.rssi : @"-"],
        bindButton
    ]];
    return card;
}

- (UIView *)infoRowWithTitle:(NSString *)title value:(NSString *)value {
    UIView *row = [[UIView alloc] init];
    UILabel *titleLabel = [self labelWithText:title font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kBindSubText];
    UILabel *valueLabel = [self labelWithText:value.length > 0 ? value : @"-" font:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold] color:kBindText];
    valueLabel.textAlignment = NSTextAlignmentRight;
    [row addSubview:titleLabel];
    [row addSubview:valueLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(row);
        make.height.mas_greaterThanOrEqualTo(22);
    }];
    [valueLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLabel.mas_right).offset(12);
        make.right.top.bottom.equalTo(row);
        make.width.mas_greaterThanOrEqualTo(170);
    }];
    return row;
}

- (void)bindScannedDevice:(XTBleScannedDevice *)device {
    if (!device || [XTTool isBlankString:device.mac]) {
        [XTMBManager showAlertViewWithText:XTLS(@"XT_Invalid_MAC") delayHid:1.5];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(backBindMac:)]) {
        [self.delegate backBindMac:device.mac];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIControl *)screenPickerButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIControl *button = [[UIControl alloc] init];
    button.backgroundColor = UIColor.whiteColor;
    
    UILabel *label = [self labelWithText:title font:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular] color:color];
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.85;
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

- (NSString *)displayNameForDevice:(XTBleScannedDevice *)device {
    if (device.deviceName.length > 0) {
        return device.deviceName;
    }
    return @"-";
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.allDevices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"XTBleMacCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = UIColor.whiteColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = kBindText;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = kBindSubText;
        cell.detailTextLabel.numberOfLines = 2;
    }
    
    if (indexPath.row >= self.allDevices.count) {
        cell.textLabel.text = @"-";
        cell.detailTextLabel.text = @"";
        return cell;
    }
    
    XTBleScannedDevice *device = self.allDevices[indexPath.row];
    cell.textLabel.text = device.mac.length > 0 ? device.mac : @"-";
    cell.detailTextLabel.text = [NSString stringWithFormat:XTLS(@"XT_Device_Cell_Detail_Format"),
                                 [self displayNameForDevice:device],
                                 device.rssi.length > 0 ? device.rssi : @"-"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.allDevices.count) {
        return;
    }
    [self bindScannedDevice:self.allDevices[indexPath.row]];
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
        _contentStack.spacing = 14;
    }
    return _contentStack;
}

- (UILabel *)statusLabel {
    if (!_statusLabel) {
        _statusLabel = [self labelWithText:XTLS(@"XT_Waiting_Scan") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kBindSubText];
    }
    return _statusLabel;
}

- (UIActivityIndicatorView *)activityView {
    if (!_activityView) {
        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _activityView.color = kBindAccent;
        [_activityView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(22);
        }];
    }
    return _activityView;
}

- (UIButton *)clearFilterButton {
    if (!_clearFilterButton) {
        _clearFilterButton = [self plainButtonWithTitle:XTLS(@"XT_Clear_Filter") action:@selector(clearFilters)];
    }
    return _clearFilterButton;
}

- (UIButton *)colorFilterButton {
    if (!_colorFilterButton) {
        _colorFilterButton = [self plainButtonWithTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Color"), XTLS(@"XT_All")] action:@selector(showColorFilter)];
    }
    return _colorFilterButton;
}

- (UIButton *)resolutionFilterButton {
    if (!_resolutionFilterButton) {
        _resolutionFilterButton = [self plainButtonWithTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Resolution"), XTLS(@"XT_All")] action:@selector(showResolutionFilter)];
    }
    return _resolutionFilterButton;
}

- (UIButton *)deviceNumberFilterButton {
    if (!_deviceNumberFilterButton) {
        _deviceNumberFilterButton = [self plainButtonWithTitle:[NSString stringWithFormat:XTLS(@"XT_Filter_Value_Format"), XTLS(@"XT_Device_Number"), XTLS(@"XT_All")] action:@selector(showDeviceNumberFilter)];
    }
    return _deviceNumberFilterButton;
}

- (UILabel *)emptyLabel {
    if (!_emptyLabel) {
        _emptyLabel = [self labelWithText:XTLS(@"XT_No_Device") font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:kBindSubText];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.backgroundColor = UIColor.whiteColor;
        _emptyLabel.layer.cornerRadius = 8;
        _emptyLabel.layer.borderWidth = 1;
        _emptyLabel.layer.borderColor = kBindBorder.CGColor;
        _emptyLabel.layer.masksToBounds = YES;
        [_emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_greaterThanOrEqualTo(64);
        }];
    }
    return _emptyLabel;
}

- (UIStackView *)deviceListStack {
    if (!_deviceListStack) {
        _deviceListStack = [[UIStackView alloc] init];
        _deviceListStack.axis = UILayoutConstraintAxisVertical;
        _deviceListStack.spacing = 12;
    }
    return _deviceListStack;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.rowHeight = 64;
        _tableView.estimatedRowHeight = 64;
        _tableView.backgroundColor = UIColor.whiteColor;
        _tableView.layer.cornerRadius = 8;
        _tableView.layer.borderWidth = 1;
        _tableView.layer.borderColor = kBindBorder.CGColor;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
        _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    }
    return _tableView;
}

@end
