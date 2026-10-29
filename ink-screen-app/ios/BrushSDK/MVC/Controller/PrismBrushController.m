//
//  PrismBrushController.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import "PrismBrushController.h"
#import "XTAlertSheetView.h"
#import "XTPrismBrushCell.h"

#import "NFCHelper.h"
#import "XTCommonUtils.h"

#import "PrismModel.h"
#import "Masonry.h"
#import "UtilsMacros.h"
#import "UIImage+ColorPixel.h"
#import "XTMBManager.h"

/**
 Prism设备刷图核心页面
 核心功能：Prism设备模板加载、本地效果图展示、像素颜色解析、NFC刷图指令下发、刷图动画选择
 Prism Device Screen Brush Core Controller
 Core Function: Prism Template Load、Local Effect Image Show、Pixel Color Analysis、NFC Send Brush Cmd、Brush Animation Select
 */
@interface PrismBrushController () <NFCHelperDelegate,UICollectionViewDelegate,UICollectionViewDataSource>

@property(nonatomic, strong) UICollectionView   *myCollectionView;  // 效果图展示列表 | Effect Image Display CollectionView
@property(nonatomic, strong) PrismModel         *currentModel;      // Prism设备数据模型 | Prism Device Data Model
@property(nonatomic, assign) NSInteger          animationNum;       // 刷图动画类型编号 | Screen Brush Animation Type Number

@end

@implementation PrismBrushController

#pragma mark - 页面生命周期方法 | ViewController Life Cycle
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/**
 页面加载完成回调
 初始化数据模型、页面标题、列表布局、加载本地Prism数据
 View Load Complete Callback
 Init Data Model、Page Title、CollectionView Layout、Load Local Prism Data
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    
    PrismModel *current = [[PrismModel alloc] init];
    _currentModel = current;
    
    // 页面标题-国际化配置 | Page Title - Localization Config
    self.title = XTLS(@"XT_Prism_Title");
   
    [self.view addSubview:self.myCollectionView];
    [self.myCollectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(1);
        make.left.bottom.right.equalTo(self.view);
    }];
    
    // 初始化本地Prism设备数据 | Init Local Prism Device Data
    [self initLocalData];
}

#pragma mark - 数据初始化方法 | Data Initialization Method
/**
 初始化本地Prism模板+效果图数据
 根据设备型号匹配对应模板名称、加载对应数量的本地效果图资源
 Init Local Prism Template & Effect Image Data
 Match Template Name By Device Model、Load Corresponding Local Effect Images
 */
- (void)initLocalData {
    // 初始化模板名称 | Init Template Name
    _currentModel.mubanUrl = [NSString stringWithFormat:@"prism_%ld",_deviceInfo.deviceNumber];
    
    // 初始化效果图数据源 | Init Effect Image Data Source
    NSMutableArray *dataSource = [NSMutableArray array];
    NSString *typeLocStr = [NSString stringWithFormat:@"prism_%ld",_deviceInfo.deviceNumber];
    
    // 根据设备型号匹配本地内置效果图数量 | Match Local Image Count By Device Number
    NSInteger imageCount = _deviceInfo.deviceNumber == 89 ? 11 : _deviceInfo.deviceNumber == 90 ? 11 : _deviceInfo.deviceNumber == 93 ? 9 : 11;
    for (int i = 1; i < imageCount; i++) {
        PrismDetailModel *model = [[PrismDetailModel alloc] init];
        model.imgUrl = [NSString stringWithFormat:@"%d_%@",i,typeLocStr];
        [dataSource addObject: model];
    }
    _currentModel.rows = dataSource;
    [_myCollectionView reloadData];
}

#pragma mark - 核心刷图业务逻辑 | Core Screen Brush Business Logic
/**
 触发Prism刷图主方法
 传入选中的效果图模型，开始加载本地模板并解析像素
 Trigger Prism Screen Brush Main Method
 Load Local Template And Parse Pixel With Selected Effect Image Model
 @param model 选中的效果图数据模型 | Selected Effect Image Data Model
 */
- (void)brushWithModel:(PrismDetailModel *)model {
    // Load template from local resource
    DLog(@"muban form local ...");
    [self getMuBanFormLocalWithModel:model];
}

/**
 从本地加载Prism设备模板图片
 根据设备型号匹配模板文件，解析模板图片的全量像素坐标色值
 Load Prism Template Image From Local Bundle
 Match Template File By Device Model、Parse Full Pixel Color Of Template Image
 @param model 选中的效果图数据模型 | Selected Effect Image Data Model
 */
- (void)getMuBanFormLocalWithModel:(PrismDetailModel *)model {
    XTWeakSelf
   
    // 匹配对应设备的模板名称 | Match Template Name For Current Device
    NSString *mubanLocStr = _currentModel.mubanUrl;
    if (_currentModel.mubanUrl.length == 0) {
        mubanLocStr = [NSString stringWithFormat:@"prism_%ld",_deviceInfo.deviceNumber];
    }
    
    // 加载本地模板图片文件 | Load Local Template Image File
    NSString *filePath = [[NSBundle mainBundle] pathForResource:mubanLocStr ofType:@"png"];
    UIImage *getimage = [UIImage imageWithContentsOfFile:filePath];
    
    // 解析模板图片的所有像素色值 | Parse All Pixel Color Of Template Image
    [getimage getPicAllPixelColor:^(NSMutableArray<ColorPoint *> * listData) {
        [weakSelf brashNetWorkPicDataWithModelData:listData model: model];
    }];
}

/**
 加载选中的效果图并关联模板像素数据
 读取本地效果图资源，准备进行像素色值匹配解析
 Load Selected Effect Image & Bind Template Pixel Data
 Read Local Effect Image Resource、Prepare Pixel Color Matching Analysis
 @param listData 模板图片的像素坐标数据 | Template Image Pixel Coordinate Data
 @param model 选中的效果图数据模型 | Selected Effect Image Data Model
 */
- (void)brashNetWorkPicDataWithModelData:(NSMutableArray *)listData model:(PrismDetailModel *)model {
    // 加载本地效果图文件 | Load Local Effect Image File
    NSString *filePath = [[NSBundle mainBundle] pathForResource:model.imgUrl ofType:@"png"];
    UIImage *getimage = [UIImage imageWithContentsOfFile:filePath];
    [self getBrushWithImage:getimage list:listData];
}

/**
 核心像素解析与匹配
 解析效果图指定坐标的像素色值，与模板像素做匹配分组，生成刷图指令数据
 Core Pixel Analysis & Matching
 Parse Effect Image Pixel Color By Template Coordinate、Match & Group Pixel Data、Generate Brush Cmd Data
 @param brushImage 选中的效果图 | Selected Effect Image
 @param listData 模板图片的像素坐标数据 | Template Image Pixel Coordinate Data
 */
- (void)getBrushWithImage:(UIImage *)brushImage list:(NSMutableArray *)listData {
    __weak typeof(self) weakSelf = self;
    [brushImage getPicSomePiontSubjectPixelColor:listData block:^(NSMutableDictionary * _Nonnull resultDict) {
        // 对解析后的像素数据进行分组处理 | Group Parsed Pixel Data
        NSDictionary *resDict = [weakSelf sameArrayGroupWithData:resultDict];
        // 对分组数据按键值升序排序 | Sort Group Data By Key Asc
        NSArray *keyArr = [resDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *  _Nonnull obj1, NSNumber *  _Nonnull obj2) {
            return [obj1 intValue] > [obj2 intValue];
        }];
        
        // 组装最终的刷图指令字节数组 | Assemble Final Brush Cmd Byte Array
        NSMutableArray *brushArr = [NSMutableArray array];
        if (_deviceInfo.deviceNumber == 83 || _deviceInfo.deviceNumber == 93) {
            [brushArr addObject:@(0x21)];
        }
        for (NSNumber *num in keyArr) {
            NSNumber *vau = resDict[num];
            [brushArr addObject:vau];
        }
        if (_deviceInfo.deviceNumber == 93) {
            // 126/127模板颜色一致，补充最后一位数据 | 126/127 Template Color Same, Append Last Data
            [brushArr addObject:brushArr.lastObject];
        }
        if (_deviceInfo.deviceNumber == 89 || _deviceInfo.deviceNumber == 90) {
            [brushArr addObject:@(0x21)];
        }
        // 下发刷图指令 | Send Brush Cmd To Device
        [weakSelf startBrushWithData:brushArr];
    }];
}

/**
 像素数据分组优化处理
 对解析后的像素色值进行随机取样校验，筛选匹配度最高的色值，生成键值对数据
 Pixel Data Group & Optimize
 Random Sample Check For Parsed Pixel Color、Filter Highest Match Color、Generate Key-Value Data
 @param resultDict 原始像素解析字典 | Original Pixel Parse Dictionary
 @return 分组优化后的像素数据字典 | Optimized Group Pixel Data Dictionary
 */
- (NSDictionary *)sameArrayGroupWithData:(NSMutableDictionary *)resultDict {
    // Calculate the most frequent resultValue corresponding to the blue value
    // TODU: Optimize this method later
    NSMutableDictionary *backDict = [NSMutableDictionary dictionary];
    for (id key in resultDict) {
        NSArray *valueArr = resultDict[key];
        int randomNum1 = (int)(valueArr.count) / 2;
        int randomNum2 = (int)(valueArr.count) / 4;

        ColorPoint *p1 = valueArr[randomNum1];
        ColorPoint *p2 = valueArr[randomNum2];
        
        if ([p1.resultValue intValue] == [p2.resultValue intValue]) {
            [backDict setObject:p1.resultValue forKey:@(p1.blue)];
        } else {
            int randomNum3 = (int)(valueArr.count) / 6;
            ColorPoint *p3 = valueArr[randomNum3];
            [backDict setObject:p3.resultValue forKey:@(p3.blue)];
        }
    }
    return backDict;
}

/**
 下发Prism刷图指令到设备
 通过NFC工具类发送刷图数据，配置分包大小/间隔时间，校验NFC工作状态
 Send Prism Brush Cmd To Device
 Send Brush Data By NFC Helper、Config Page Size/Interval Time、Check NFC Working Status
 @param bytes 组装完成的刷图指令字节数组 | Assembled Brush Cmd Byte Array
 */
- (void)startBrushWithData:(NSMutableArray *)bytes {
    NFCHelper *instance = [NFCHelper shareInstance];
    if(instance.isReading) {
        [XTMBManager showAlertViewWithText:NSLocalizedString(@"XT_NFCisdoing", nil) delayHid:2];
        return;
    }
    instance.delegate = self;
    
    int pageSize = 10;
    int intervalTime = 10;

    NSData *outputData = [NSJSONSerialization dataWithJSONObject:bytes options:0 error:nil];
    if (!outputData) {
        outputData = [NSData data];
    }
    [instance importImageToDevice:NSLocalizedString(@"XT_Close_To_Equipment", nil)
                                             imageData:outputData
                                           imageDataXT:bytes
                                             screenCfg:_deviceInfo
                                    imageSectionNumber:_animationNum
                                                   pin:nil
                                              PageSize:pageSize
                                          IntervalTime:intervalTime];
}

/**
 恢复列表点击交互权限
 延迟解锁列表点击，防止NFC指令下发中重复点击导致异常
 Restore CollectionView Click Interaction Permission
 Delay Unlock Click To Avoid Exception Caused By Repeat Click When NFC Cmd Sending
 */
- (void)collectionViwAllowClick {
    DLog(@" -- You can click the cell again. -- ");
    _myCollectionView.userInteractionEnabled = YES;
}

#pragma mark - UICollectionView Delegate & DataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _currentModel.rows.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    XTPrismBrushCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"XTPrismBrushCell" forIndexPath:indexPath];
    [cell refreshUIWithdata:_currentModel.rows[indexPath.row]];
    return cell;
}

/**
 列表单元格选中事件
 弹出动画选择弹窗，选择刷图动画类型，临时禁用列表点击防止重复操作
 CollectionView Cell Selected Event
 Pop Animation Select Sheet、Choose Brush Animation Type、Disable Click To Avoid Repeat Operation
 */
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PrismDetailModel *model = _currentModel.rows[indexPath.row];
    __weak typeof(self) weakSelf = self;
    // 刷图动画选项-项目已国际化，直接沿用 | Brush Animation Option - Use Project Localization Key
    NSArray *animotionTitle = @[NSLocalizedString(@"XT_Synchronous", nil),
                                NSLocalizedString(@"XT_S", nil),
                                NSLocalizedString(@"XT_N", nil),
                                NSLocalizedString(@"XT_Center", nil),
                                NSLocalizedString(@"XT_Fan_in", nil),
                                NSLocalizedString(@"XT_Clockwise", nil)];
    [XTAlertSheetView showAlterWithTitleItems:animotionTitle
                                    titleText:NSLocalizedString(@"XT_BrushAnmationTitle", nil)
                                   cancelText:NSLocalizedString(@"XT_Cancel", nil)
                                  cancelColor:nil
                               didSelectBlock:^(NSUInteger index) {
        if (animotionTitle.count != index) {
            // 禁用列表点击 | Disable CollectionView Click
            weakSelf.myCollectionView.userInteractionEnabled = NO;
            // 延迟恢复点击 | Delay Restore Click
            [weakSelf performSelector:@selector(collectionViwAllowClick) withObject:nil afterDelay:2];
            weakSelf.animationNum = index;
            [weakSelf brushWithModel:model];
        }
    }];
}

#pragma mark - Lazy Load 懒加载
/**
 懒加载初始化效果图列表
 配置列表布局、行列间距、单元格尺寸、注册单元格、设置样式属性
 Lazy Load Init Effect Image CollectionView
 Config Layout、Spacing、Cell Size、Register Cell、Set Style Attr
 */
- (UICollectionView *)myCollectionView {
    if (!_myCollectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        CGFloat width = (XTScreenWidth - 60.1)/2.0;
        CGFloat imageHeight = (_currentModel.deviceNumber == 83 || _currentModel.deviceNumber == 93) ? 403.0 : 430.0;
        CGFloat height = width * 728.0 /imageHeight;
        
        layout.itemSize = CGSizeMake(width, height);
        layout.minimumInteritemSpacing = 20;
        layout.minimumLineSpacing = 20;

        _myCollectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout: layout];
        _myCollectionView.delegate = self;
        _myCollectionView.dataSource = self;
        _myCollectionView.bounces = NO;
        _myCollectionView.contentInset = UIEdgeInsetsMake(20, 20, 20, 20);
        [_myCollectionView registerClass:[XTPrismBrushCell class] forCellWithReuseIdentifier:@"XTPrismBrushCell"];
        _myCollectionView.backgroundColor = XTViewBgColor;
    }
    return _myCollectionView;
}

@end
