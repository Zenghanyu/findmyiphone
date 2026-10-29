//
//  XTAlertSheetView.m
//  Templates
//
//  Created by wudan on 2020/4/21.
//  Copyright © 2020 wudan. All rights reserved.
//

#import "XTAlertSheetView.h"
// 按钮高度
static CGFloat KButtonHeight = 55;
// 取消按钮与其他间距
static CGFloat KSpace = 8;
// 圆角
static CGFloat KCornersSpace = 10;

// 屏幕高度
static CGFloat kScreenHeight(void) {
    return [[UIScreen mainScreen] bounds].size.height;
}

// 屏幕宽度
static CGFloat kScreenWidth(void) {
    return [[UIScreen mainScreen] bounds].size.width;
}

// 是否是刘海屏
static BOOL kDevice_iPhoneX(void) {
    BOOL isPhoneX = NO;
    if (@available(iOS 11.0, *)) {
        isPhoneX = [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom > 0.0;
    }
    return isPhoneX;
}

// 主标题颜色
static UIColor * kTitleColor(void) {
    return [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1];
}

// 副标题颜色
static UIColor * kSubTitleColor(void) {
    return [UIColor colorWithRed:0.90 green:0.90 blue:0.90 alpha:1];
}

// 间隙颜色
static UIColor * kSpaceColor(void) {
    return [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1];
}

// 分割线颜色
static UIColor * kSpaceLineColor(void) {
    return [UIColor colorWithRed:0.90 green:0.90 blue:0.90 alpha:1];
}

// 主标题字体
static UIFont * kTitleFont(void) {
    return [UIFont systemFontOfSize:16];
}

// 副标题字体
static UIFont * kSubTitleFont(void) {
    return [UIFont systemFontOfSize:12];
}

@interface XTAlertSheetModel ()
// 文字
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;
// 颜色
@property (nonatomic, strong) UIColor *titleColor;
@property (nonatomic, strong) UIColor *subTitleColor;
// 字体
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIFont *subTitleFont;
@end

@implementation XTAlertSheetModel

+ (XTAlertSheetModel *)setupWithTitle:(NSString *)title {
    return [self setupWithTitle:title titleColor:kTitleColor()];
}

+ (XTAlertSheetModel *)setupWithTitle:(NSString *)title
                             subTitle:(NSString *)subTitle {
    
    return [self setupWithTitle:title
                    titleColor:kTitleColor()
                    titleFont:kTitleFont()
                       subTitle:subTitle
                  subTitleColor:kSubTitleColor()
                  subTitleFont:kSubTitleFont()];
}

+ (XTAlertSheetModel *)setupWithTitle:(NSString *)title
                           titleColor:(UIColor *)titleColor {
    return [self setupWithTitle:title titleColor:titleColor titleFont:kTitleFont()];
}

+ (XTAlertSheetModel *)setupWithTitle:(NSString *)title
                           titleColor:(UIColor *)titleColor
                            titleFont:(UIFont *)titleFont {
    
    return [self setupWithTitle:title
                     titleColor:titleColor
                      titleFont:titleFont
                       subTitle:@""
                  subTitleColor:kSubTitleColor()
                   subTitleFont:kSubTitleFont()];
}


+ (XTAlertSheetModel *)setupWithTitle:(NSString *)title
                           titleColor:(UIColor *)titleColor
                            titleFont:(UIFont *)titleFont
                             subTitle:(NSString *)subTitle
                        subTitleColor:(UIColor *)subTitleColor
                         subTitleFont:(UIFont *)subTitleFont {
    XTAlertSheetModel *model = [[XTAlertSheetModel alloc] init];
    model.title = title;
    model.titleColor = titleColor;
    model.titleFont = titleFont;
    model.subTitle = subTitle;
    model.subTitleColor = subTitleColor;
    model.subTitleFont = subTitleFont;
    return model;
}
@end

@interface XTAlertSheetControl : UIControl

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *totalLayoutConstraints;
@property (nonatomic, strong) UIView *bottomLineView;

@end

@implementation XTAlertSheetControl
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];
        
        _subTitleLabel = [[UILabel alloc] init];
        _subTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subTitleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_subTitleLabel];
        
        _bottomLineView = [[UIView alloc] init];
        _bottomLineView.backgroundColor = kSpaceLineColor();
        [self addSubview:_bottomLineView];
    
        self.totalLayoutConstraints = @[
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:-2],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:2],
        ];
        [self addConstraints:self.totalLayoutConstraints];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _bottomLineView.frame = CGRectMake(0, CGRectGetHeight(self.frame) - 0.5, CGRectGetWidth(self.frame), 0.5);
    
    if (_subTitleLabel.text.length == 0) {
        [self removeConstraints:self.totalLayoutConstraints];
        [self addConstraints:@[
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        ]];
    }
}
@end

@interface XTAlertSheetLastControl : UIControl

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *totalLayoutConstraints;
@property (nonatomic, strong) UIView *bottomView;

@end

@implementation XTAlertSheetLastControl

- (instancetype)init {
    self = [super init];
    if (self) {
        
        self.backgroundColor = [UIColor whiteColor];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];
        
        _subTitleLabel = [[UILabel alloc] init];
        _subTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subTitleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_subTitleLabel];
        
        _bottomView = [[UIView alloc] init];
        _bottomView.translatesAutoresizingMaskIntoConstraints = NO;
        _bottomView.backgroundColor = [UIColor clearColor];
        [self addSubview:_bottomView];
        
        self.totalLayoutConstraints = @[
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:-2 - (kDevice_iPhoneX() ? 34 : 0)],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:2 - (kDevice_iPhoneX() ? 34 : 0)],
        ];
        
        NSMutableArray *array = [NSMutableArray array];
        [array addObjectsFromArray:@[
            [NSLayoutConstraint constraintWithItem:_bottomView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_bottomView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeHeight multiplier:1 constant:kDevice_iPhoneX() ? 34 : 0],
            [NSLayoutConstraint constraintWithItem:_bottomView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_bottomView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]
        ]];
        [array addObjectsFromArray:self.totalLayoutConstraints];
        [self addConstraints:array];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_subTitleLabel.text.length == 0) {
        [self removeConstraints:self.totalLayoutConstraints];
        [self addConstraints:@[
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:- (kDevice_iPhoneX() ? 34 : 0) / 2],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:_subTitleLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:- (kDevice_iPhoneX() ? 34 : 0) / 2],
        ]];
    }
}
@end


@interface XTAlertSheetView ()
@property (nonatomic, strong) UIView *backView;
@property (nonatomic, assign) CGFloat totalHeight;
@property (nonatomic, copy) DidSelectedBlock selectedBlock;

@end

@implementation XTAlertSheetView

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static XTAlertSheetView *view = nil;
    dispatch_once(&onceToken, ^{
        view = [[XTAlertSheetView alloc] init];
        view.frame = [[UIScreen mainScreen] bounds];
    });
    return view;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self addTarget:self action:@selector(hidenView) forControlEvents: UIControlEventTouchUpInside];
    }
    return self;
}

+ (void)showAlterWithTitleItems:(NSArray<NSString *> *)items
                 didSelectBlock:(DidSelectedBlock)selectBlock {
    [self showAlterWithTitleItems:items cancelText:@"" cancelColor:nil didSelectBlock:selectBlock];
}

+ (void)showAlterWithTitleItems:(NSArray<NSString *> *)items
                     cancelText:(NSString *)cancelText
                    cancelColor:(UIColor *)cancelColor
                 didSelectBlock:(DidSelectedBlock)selectBlock {
    
    NSMutableArray<XTAlertSheetModel *> *array = [NSMutableArray arrayWithCapacity:items.count];
    for (NSString *title in items) {
        XTAlertSheetModel *model = [XTAlertSheetModel setupWithTitle:title];
        [array addObject:model];
    }
    [self showAlterWithTitleAttItems:array cancelText:cancelText cancelColor:cancelColor didSelectBlock:selectBlock];
}

+ (void)showAlterWithTitleItems:(NSArray<NSString *> *)items
                     titleText:(NSString *)titleText
                     cancelText:(NSString *)cancelText
                    cancelColor:(UIColor * _Nullable)cancelColor // 默认颜色红色
                 didSelectBlock:(DidSelectedBlock)selectBlock;{
    
    NSMutableArray<XTAlertSheetModel *> *array = [NSMutableArray arrayWithCapacity:items.count];
    if (titleText.length != 0) {
        XTAlertSheetModel *model = [XTAlertSheetModel setupWithTitle:titleText titleColor:[UIColor lightGrayColor]];
        [array addObject:model];
    }
    for (NSString *title in items) {
        XTAlertSheetModel *model = [XTAlertSheetModel setupWithTitle:title];
        [array addObject:model];
    }
    [self showAlterWithTitleAttItems:array cancelText:cancelText cancelColor:cancelColor didSelectBlock:selectBlock];
}

+ (void)showAlterWithTitleAttItems:(NSArray<XTAlertSheetModel *> *)items
                    didSelectBlock:(DidSelectedBlock)selectBlock {
    [self showAlterWithTitleAttItems:items cancelText:@"" cancelColor:nil didSelectBlock:selectBlock];
}

+ (void)showAlterWithTitleAttItems:(NSArray<XTAlertSheetModel *> *)items
                        cancelText:(NSString *)cancelText
                       cancelColor:(UIColor *)cancelColor
                    didSelectBlock:(DidSelectedBlock)selectBlock {

    NSAssert(items.count > 0, @"Thead Reason ===> [XTAlertSheetView · itmes`count not be null]");
       
    XTAlertSheetView *view = [XTAlertSheetView shared];
    view.selectedBlock = selectBlock;
    [view addSubViews];
    
    CGFloat cornersSpace = KCornersSpace;
    if (items.firstObject.subTitle.length == 0) {
        cornersSpace = 0;
    }
    
    NSMutableArray *array = [NSMutableArray arrayWithArray:items];
    if (cancelText.length != 0) {
        XTAlertSheetModel *cancelModel = [XTAlertSheetModel setupWithTitle:cancelText titleColor:cancelColor];
        if (cancelColor == nil) {
            cancelModel = [XTAlertSheetModel setupWithTitle:cancelText titleColor:[UIColor redColor]];
        }
        [array addObject:cancelModel];
    }
    
    [array enumerateObjectsUsingBlock:^(XTAlertSheetModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == array.count - 1) {
            XTAlertSheetLastControl *button = [view createLastButtonWithModel:obj tag:idx];
            if (cancelText.length == 0) {
                if (kDevice_iPhoneX()) {
                    button.frame = CGRectMake(0, KButtonHeight * (items.count - 1) + cornersSpace, kScreenWidth(), KButtonHeight + 34);
                } else {
                    button.frame = CGRectMake(0, KButtonHeight * (items.count - 1) + cornersSpace, kScreenWidth(), KButtonHeight);
                }
            } else {
                if (kDevice_iPhoneX()) {
                    button.frame = CGRectMake(0, KButtonHeight * items.count + KSpace + cornersSpace, kScreenWidth(), KButtonHeight + 34);
                } else {
                    button.frame = CGRectMake(0, KButtonHeight * items.count + KSpace + cornersSpace, kScreenWidth(), KButtonHeight);
                }
            }
            [view.backView addSubview:button];

        } else {
            XTAlertSheetControl *button = [view createButtonWithModel:obj tag:idx];
            if (idx == 0) {
                button.bottomLineView.hidden = idx == items.count - 1;
                button.frame = CGRectMake(0, 0, kScreenWidth(), KButtonHeight + cornersSpace);
            } else {
                button.bottomLineView.hidden = idx == items.count - 1;
                button.frame = CGRectMake(0, cornersSpace + KButtonHeight * idx, kScreenWidth(), KButtonHeight);
            }
            [view.backView addSubview:button];
        }
    }];

    
    [view showView];
    
    CGFloat totoalHeight = KButtonHeight * items.count;
    
    if (cancelText.length != 0) {
        totoalHeight += KSpace + KButtonHeight;
    }
    
    if (kDevice_iPhoneX()) {
        totoalHeight += 34;
    }
    
    view.backView.frame = CGRectMake(0, kScreenHeight(), kScreenWidth(), totoalHeight);

    [UIView animateWithDuration:0.35 animations:^{
        view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        view.backView.frame = CGRectMake(0, kScreenHeight() - totoalHeight, kScreenWidth(), totoalHeight);
    }];
    [self setupRoundedCornersWithView:view.backView];

    view.totalHeight = totoalHeight;
}


#pragma mark - Private

#pragma mark Operation Methods
- (UIView *)kWindowView {
    if ([self viewController].view != nil) {
        return [self viewController].view;
    } else if ([UIApplication sharedApplication].delegate.window != nil) {
        return [UIApplication sharedApplication].delegate.window;
    } else {
        return [UIApplication sharedApplication].keyWindow;
    }
}

- (void)hidenView {
    [UIView animateWithDuration:0.35 animations:^{
        self.backView.frame = CGRectMake(0, kScreenHeight(), kScreenWidth(), self.totalHeight);
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    } completion:^(BOOL finished) {
        [self removeSubViews];
        [self removeFromSuperview];
    }];
}

- (void)showView {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    [[self kWindowView] addSubview:self];
}

- (void)addSubViews {
    _backView = [[UIView alloc] init];
    _backView.backgroundColor = kSpaceColor();
    [self addSubview:_backView];
}

- (void)removeSubViews {
    [_backView removeFromSuperview];
}

#pragma mark Target Action Method
- (void)buttonDidClickTargetAction:(UIControl *)sender {
    sender.backgroundColor = [UIColor whiteColor];

    [self hidenView];
    if (sender.tag != 0) {
        if (self.selectedBlock) {
            self.selectedBlock(sender.tag - 1);
        }
    }
}

- (void)buttonTouchUpOutSideTargetAction:(UIControl *)sender {
    sender.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1];
}

#pragma mark Common UI Create Methods
- (UIButton *)creatButton:(NSString *)title tag:(NSUInteger)tag {
    UIButton *button = [[UIButton alloc] init];
    button.tag = tag;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = kTitleFont();
    button.backgroundColor = [UIColor whiteColor];
    [button addTarget:self action:@selector(buttonDidClickTargetAction:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (XTAlertSheetControl *)createButtonWithModel:(XTAlertSheetModel *)model tag:(NSUInteger)tag {
    XTAlertSheetControl *v = [[XTAlertSheetControl alloc] init];
    v.titleLabel.text = model.title;
    v.titleLabel.textColor = model.titleColor;
    v.titleLabel.font = model.titleFont;
    v.subTitleLabel.text = model.subTitle;
    v.subTitleLabel.textColor = model.subTitleColor;
    v.subTitleLabel.font = model.subTitleFont;
    v.tag = tag;
    [v addTarget:self action:@selector(buttonTouchUpOutSideTargetAction:) forControlEvents:UIControlEventTouchDown];
    [v addTarget:self action:@selector(buttonDidClickTargetAction:) forControlEvents:UIControlEventTouchUpInside];
    return v;
}

- (XTAlertSheetLastControl *)createLastButtonWithModel:(XTAlertSheetModel *)model tag:(NSUInteger)tag {
    XTAlertSheetLastControl *v = [[XTAlertSheetLastControl alloc] init];
    v.titleLabel.text = model.title;
    v.titleLabel.textColor = model.titleColor;
    v.titleLabel.font = model.titleFont;
    v.subTitleLabel.text = model.subTitle;
    v.subTitleLabel.textColor = model.subTitleColor;
    v.subTitleLabel.font = model.subTitleFont;
    v.tag = tag;
    [v addTarget:self action:@selector(buttonTouchUpOutSideTargetAction:) forControlEvents:UIControlEventTouchDown];
    [v addTarget:self action:@selector(buttonDidClickTargetAction:) forControlEvents:UIControlEventTouchUpInside];
    return v;
}

- (UIViewController *)viewController {
    UIResponder *next = [self nextResponder];
    do {
        if ([next isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)next;
        }
        next = [next nextResponder];
    } while (next != nil);
    return nil;
}

#pragma mark - Tool Method
+ (void)setupRoundedCornersWithView:(UIView *)view {
    
    CAShapeLayer *mask = [CAShapeLayer layer];
    UIBezierPath * path = [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                                byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                      cornerRadii:CGSizeMake(15, 15)];
    mask.path = path.CGPath;
    mask.frame = view.bounds;
    
    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.path = path.CGPath;
    borderLayer.fillColor = [UIColor clearColor].CGColor;
    borderLayer.strokeColor = [UIColor clearColor].CGColor;
    borderLayer.lineWidth = 0;
    borderLayer.frame = view.bounds;
    view.layer.mask = mask;
    [view.layer addSublayer:borderLayer];
}
@end
