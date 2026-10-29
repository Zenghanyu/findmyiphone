//
//  XTMBManager.m
//  MBProgressDemo
//
//  Created by hungryBoy on 16/1/23.
//  Copyright © 2016年 hungryBoy. All rights reserved.
//

#import "XTMBManager.h"
#import <UIKit/UIKit.h>
#import "XTTool.h"

#define XTCOLORA(c,a)               [UIColor colorWithRed:((float)((c & 0xFF0000) >> 16))/255.0 green:((float)((c & 0xFF00) >> 8))/255.0 blue:((float)(c & 0xFF))/255.0 alpha:a]

#ifndef XTViewBgColor
#define XTViewBgColor [UIColor clearColor]
#endif

// 屏幕尺寸宏
#define kScreen_height  [[UIScreen mainScreen] bounds].size.height
#define kScreen_width   [[UIScreen mainScreen] bounds].size.width
#define kDefaultRect     CGRectMake(0, 0, kScreen_width, kScreen_height)
#define kDefaultView    [XTTool getKeyWindow]

// 蒙层颜色宏
#define kGloomyBlackColor  [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]
#define kGloomyClearCloler  [UIColor colorWithRed:1 green:1 blue:1 alpha:0]

/* 默认网络提示，可在这统一修改 */
static NSString *const kLoadingMessage = @"loading ...";
/* 默认简短提示语显示的时间，在这统一修改 */
static CGFloat const   kShowTime  = 4.0f;
/* 默认超时时间，30s后自动去除提示框 */
static NSTimeInterval const interval = 30.0f;
/* 手势是否可用，默认yes，轻触屏幕提示框隐藏 */
static BOOL isAvalibleTouch = NO;

// 全局静态变量
static BOOL isShowGloomy; //是否显示深色背景
static UIView *prestrainView; //预加载view

@implementation XTMBManager

#pragma mark - 核心修复：gloomyView 懒加载（避免生命周期失控）
+ (UIView *)gloomyView {
    static UIView *_gloomyView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _gloomyView = [[GloomyView alloc] initWithFrame:kDefaultRect];
        _gloomyView.backgroundColor = kGloomyBlackColor;
        _gloomyView.hidden = YES;
        _gloomyView.tag = 9999; // 唯一标识，方便dismiss精准查找
    });
    return _gloomyView;
}

#pragma mark - 新增：安全dismiss（解决主线程同步派发死锁）
+ (void)safeDismiss {
    if ([NSThread isMainThread]) {
        [self dismiss];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self dismiss];
        });
    }
}

#pragma mark - 类初始化（修复：仅初始化状态，不创建gloomyView）
+ (void)initialize {
    if (self == [XTMBManager self]) {
        // 仅初始化全局状态，避免单次创建gloomyView导致后续nil问题
        isShowGloomy = NO;
        isAvalibleTouch = NO;
    }
}

#pragma mark - 外部方法：控制是否显示深色背景
+ (void)showGloomy:(BOOL)isShow {
    isShowGloomy = isShow;
}

#pragma mark - 1. 简短提示语
+ (void)showBriefAlert:(NSString *)message view:(UIView *) view{
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view ?:kDefaultView animated:YES];
        hud.label.text = message;
        UIFont *font = [UIFont fontWithName:@"PingFangSC-Medium"size:15];//9.0以后自带的平方字体
        if(font != nil) hud.label.font = font;
        hud.contentColor = [UIColor whiteColor];
        hud.animationType = MBProgressHUDAnimationZoom;
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, 0.7);
        
        hud.mode = MBProgressHUDModeText;
        hud.margin = 10.f;
        [hud setOffset:CGPointMake(0, -150)];
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:YES afterDelay:kShowTime];
    });
}

#pragma mark - 2. 长时间的提示语
+ (void)showPermanentMessage:(NSString *)message view:(UIView *) view{
    isAvalibleTouch = YES;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];

    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:gv animated:YES];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, .7);
        hud.label.text = message;
        hud.label.numberOfLines = 0;
        hud.contentColor = [UIColor whiteColor];
        hud.label.adjustsFontSizeToFitWidth = YES;
        hud.animationType = MBProgressHUDAnimationZoom;
        hud.mode = MBProgressHUDModeText;
        hud.removeFromSuperViewOnHide = YES;
        
        [gv addSubview:hud];
        [self showClearGloomyView];
        [hud showAnimated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismiss];
        });
    });
}

#pragma mark - 3. 长时间长文本的提示语
+ (void) showLongTitle:(NSString *)title message:(NSString *)message textAlignment:(NSTextAlignment)textAlignment viewColor:(UIColor *)viewColor wordColor:(UIColor *)wordColor view:(UIView *)view
{
    isAvalibleTouch = YES;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];

    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:gv animated:YES];
        hud.backgroundView.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.7];
        
        if (viewColor != nil) {
            hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
            hud.bezelView.backgroundColor = viewColor;
        }
        
        if (wordColor != nil) {
            hud.contentColor = wordColor;//字的颜色
        }else{
            hud.contentColor = [UIColor whiteColor];//字的颜色
        }

        hud.label.text = title;
        hud.label.font = [UIFont systemFontOfSize:20.f];
        hud.detailsLabel.text = message;
        hud.detailsLabel.textAlignment = textAlignment;
        hud.detailsLabel.font = [UIFont systemFontOfSize:16.f];
        
        hud.animationType = MBProgressHUDAnimationZoom;
        hud.mode = MBProgressHUDModeText;
        hud.removeFromSuperViewOnHide = YES;
        
        [gv addSubview:hud];
        [self showClearGloomyView];
        [hud showAnimated:YES];
    });
}

#pragma mark - 4. 网络加载提示（基础版）
+ (void)showLoadingInView:(UIView *) view{
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];

    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:gv];
        hud.label.text = kLoadingMessage;
        hud.contentColor = [UIColor whiteColor];
        hud.removeFromSuperViewOnHide = YES;
        
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        if (isShowGloomy) {
            [self showBlackGloomyView];
        }else {
            [self showClearGloomyView];
        }
        
        [gv addSubview:hud];
        [hud showAnimated:YES];
        [self dismissDelay];
    });
}

#pragma mark - 5. 带延迟的等待提示
+ (void)showWaitingWithTitle:(NSString *)title view:(UIView *)view delay:(NSInteger)delay {
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];

    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:gv];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, 0.7);
        hud.label.text = title;
        hud.contentColor = [UIColor whiteColor];
        hud.backgroundView.color = [UIColor clearColor];
        hud.removeFromSuperViewOnHide = YES;
        
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        if (isShowGloomy) {
            [self showBlackGloomyView];
        }else {
            [self showClearGloomyView];
        }
        
        [gv addSubview:hud];
        [hud showAnimated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismiss];
        });
    });
}

#pragma mark - 6. 基础等待提示（核心修复）
+ (void)showWaitingWithTitle:(NSString *)title view:(UIView *)view {
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:gv];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, 0.7);
        hud.label.text = title;
        hud.contentColor = [UIColor whiteColor];
        hud.backgroundView.color = [UIColor clearColor];
        hud.removeFromSuperViewOnHide = YES;
        
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        if (isShowGloomy) {
            [self showBlackGloomyView];
        }else {
            [self showClearGloomyView];
        }
        
        [gv addSubview:hud];
        [hud showAnimated:YES];
    });
}

#pragma mark - 7. 自定义图片提示
+(void)showAlertWithCustomImage:(NSString *)imageName title:(NSString *)title view:(UIView *)view imgFrame:(CGRect)imgFrame
{
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];

    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        gv.frame = view ? CGRectMake(0, 0, view.frame.size.width, view.frame.size.height): kDefaultRect;
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view ?:kDefaultView animated:YES];
        UIImageView *littleView = [[UIImageView alloc] initWithFrame:imgFrame];
        littleView.image = [UIImage imageNamed:imageName];
        hud.customView = littleView;
        hud.removeFromSuperViewOnHide = YES;
        hud.animationType = MBProgressHUDAnimationZoom;
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, 0.7);
        hud.detailsLabel.text = title;
        hud.contentColor = [UIColor whiteColor];
        hud.mode = MBProgressHUDModeCustomView;
        
        [hud showAnimated:YES];
        [hud hideAnimated:YES afterDelay:kShowTime];
    });
}

#pragma mark - 8. 带Y轴偏移的加载提示
+ (void)showLoadingInView:(UIView *)view Y:(CGFloat)Y
{
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:gv];
        UIImage  *image = [UIImage new]; // 项目中替换为实际GIF图
        UIImageView  *gifview = [[UIImageView alloc]initWithFrame:CGRectMake(0,0,image.size.width/2.0, image.size.height/2.0)];
        gifview.contentMode = UIViewContentModeScaleAspectFill;
        gifview.image = image;
        
        hud.backgroundColor = XTViewBgColor;
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor; //去掉背景透明白色layer
        hud.bezelView.backgroundColor = XTViewBgColor;//默认颜色
        hud.mode = MBProgressHUDModeCustomView;
        hud.customView = gifview;
        hud.removeFromSuperViewOnHide = YES;
        
        gv.frame = view && view.bounds.size.width != 0 ? CGRectMake(0, Y, view.bounds.size.width, view.bounds.size.height - Y) : kDefaultRect;
        [hud setOffset:CGPointMake(0, -30)];

        if (isShowGloomy) {
            [self showBlackGloomyView];
        }else {
            [self showClearGloomyView];
        }
        
        [gv addSubview:hud];
        [hud showAnimated:YES];
        [self dismissDelay];
    });
}

#pragma mark - 9. 带Y轴偏移+增量的加载提示
+ (void)showLoadingInView:(UIView *)view Y:(CGFloat)Y increment:(CGFloat)increment
{
    isAvalibleTouch = NO;
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        prestrainView = view;
        UIView *gv = [self gloomyView];
        
        // 移除旧HUD，避免叠加
        MBProgressHUD *oldHud = [self HUDForView:gv];
        if (oldHud) {
            [oldHud removeFromSuperview];
        }
        
        MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:gv];
        UIImage *image = [UIImage new]; // 项目中替换为实际GIF图
        UIImageView  *gifview = [[UIImageView alloc]initWithFrame:CGRectMake(0,0,image.size.width/2.0, image.size.height/2.0)];
        gifview.contentMode = UIViewContentModeScaleAspectFill;
        gifview.image = image;
        
        hud.backgroundColor = XTViewBgColor;
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor; //去掉背景透明白色layer
        hud.bezelView.backgroundColor = XTViewBgColor;//默认颜色
        hud.mode = MBProgressHUDModeCustomView;
        hud.customView = gifview;
        hud.removeFromSuperViewOnHide = YES;
        
        gv.frame = view && view.bounds.size.width != 0 ? CGRectMake(0, Y, view.bounds.size.width, view.bounds.size.height - Y) : CGRectMake(0, Y, kScreen_width, kScreen_height - Y - increment);
        [hud setOffset:CGPointMake(0, -30)];

        if (isShowGloomy) {
            [self showBlackGloomyView];
        }else {
            [self showClearGloomyView];
        }
        
        [gv addSubview:hud];
        [hud showAnimated:YES];
    });
}

#pragma mark - 10. 自动隐藏的文本提示（核心业务用）
+ (void)showAlertViewWithText:(NSString *)text delayHid:(NSTimeInterval)delay {
    // 替换为safeDismiss，避免死锁
    [self safeDismiss];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[XTTool getKeyWindow] animated:YES];
        hud.detailsLabel.text = text;
        hud.detailsLabel.font = [UIFont fontWithName:@"PingFangSC-Regular"size:14];;
        hud.contentColor = [UIColor whiteColor];
        hud.animationType = MBProgressHUDAnimationZoom;
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = XTCOLORA(0x000000, 0.7);
        hud.mode = MBProgressHUDModeText;
        hud.margin = 10.f;
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:YES afterDelay:delay];
    });
}

#pragma mark - 简化调用：加载在Window上的提示框
+(void)showLoading{
    [self showLoadingInView:nil];
}

+ (void)showWaitingWithTitle:(NSString *)title{
    [self showWaitingWithTitle:title view:nil];
}

+(void)showBriefAlert:(NSString *)alert{
    [self showBriefAlert:alert view:nil];
}

+(void)showPermanentAlert:(NSString *)alert{
    [self showPermanentMessage:alert view:nil];
}

+(void)showAlertWithCustomImage:(NSString *)imageName title:(NSString *)title imgFrame:(CGRect)imgFrame{
    [self showAlertWithCustomImage:imageName title:title view:nil imgFrame:imgFrame];
}

+(void)showSuccessOK:(NSString *)title{
    [self showAlertWithCustomImage:@"Checkmark" title:title view:nil imgFrame:CGRectMake(0, 0, 37, 37)];
}

+(void)showSuccess:(NSString *)title{
    [self showAlertWithCustomImage:@"success" title:title view:nil imgFrame:CGRectMake(0, 0, 37, 37)];
}

+(void)showError:(NSString *)title{
    [self showAlertWithCustomImage:@"error" title:title view:nil imgFrame:CGRectMake(0, 0, 37, 37)];
}

+(void)showTongxulu:(NSString *)title{
    [self showAlertWithCustomImage:@"mine_tongxunlu_ok" title:title view:nil imgFrame:CGRectMake(0, 0, 37, 37)];
}

#pragma mark - 蒙层背景色设置
+ (void)showBlackGloomyView {
    UIView *gv = [self gloomyView];
    gv.backgroundColor = kGloomyBlackColor;
    [self gloomyConfig];
}

+ (void)showClearGloomyView {
    UIView *gv = [self gloomyView];
    gv.backgroundColor = kGloomyClearCloler;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self gloomyConfig];
    });
}

#pragma mark - 修复：蒙层添加逻辑（避免重复添加）
+ (void)gloomyConfig {
    UIView *targetView = prestrainView ?: [XTTool getKeyWindow];
    UIView *gv = [self gloomyView];
    
    gv.hidden = NO;
    gv.alpha = 1;
    
    // 关键修复：检查是否已添加到目标视图，避免重复添加
    if (gv.superview != targetView) {
        [gv removeFromSuperview]; // 先从旧父视图移除
        [targetView addSubview:gv];
    }
}

#pragma mark - 核心修复：dismiss方法（全覆盖移除蒙层+HUD + 修复NSSet过滤）
+(void)dismiss{
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. 定义目标标识：gloomyView的tag + HUD类
        NSArray *targetTags = @[@9999];
        Class hudClass = [MBProgressHUD class];
        NSMutableArray *allTargetViews = [NSMutableArray array];
        
        // 2. 获取所有可能的载体（兼容iOS13+，修复NSSet转NSArray问题）
        UIWindow *keyWindow = [XTTool getKeyWindow];
        if (@available(iOS 13.0, *)) {
            // 核心修复：NSSet<UIScene *>转NSArray后再过滤
            NSArray *scenes = [[UIApplication sharedApplication] connectedScenes].allObjects;
            NSArray *activeScenes = [scenes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                if ([obj isKindOfClass:[UIWindowScene class]]) {
                    return [(UIWindowScene *)obj activationState] == UISceneActivationStateForegroundActive;
                }
                return NO;
            }]];
            UIWindowScene *activeScene = activeScenes.firstObject;
            if (activeScene) {
                keyWindow = activeScene.windows.firstObject;
            }
        }
        UIView *preView = prestrainView ?: keyWindow;
        
        // 3. 递归收集所有目标视图（避免漏删）
        [self collectTargetViews:keyWindow targetTags:targetTags targetClass:hudClass result:allTargetViews];
        [self collectTargetViews:preView targetTags:targetTags targetClass:hudClass result:allTargetViews];
        
        // 4. 批量移除（避免遍历中修改数组）
        for (UIView *view in allTargetViews) {
            if (view.superview) {
                [view removeFromSuperview];
            }
        }
        
        // 5. 重置状态（不销毁gloomyView，仅隐藏）
        [self gloomyView].hidden = YES;
        prestrainView = nil;
        isAvalibleTouch = NO;
    });
}

#pragma mark - 新增：递归查找目标视图（核心修复）
+ (void)collectTargetViews:(UIView *)rootView targetTags:(NSArray<NSNumber *> *)tags targetClass:(Class)cls result:(NSMutableArray *)result {
    if (!rootView || !result) return;
    // 匹配tag或类
    if ([tags containsObject:@(rootView.tag)] || [rootView isKindOfClass:cls]) {
        if (![result containsObject:rootView]) {
            [result addObject:rootView];
        }
    }
    // 递归子视图（覆盖所有层级）
    for (UIView *subview in rootView.subviews) {
        [self collectTargetViews:subview targetTags:tags targetClass:cls result:result];
    }
}

#pragma mark - 超时自动隐藏
+ (void)dismissDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

#pragma mark - 获取view上的HUD
+ (MBProgressHUD *)HUDForView:(UIView *)view {
    if (!view) return nil;
    NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview isKindOfClass:[MBProgressHUD class]]) {
            return (MBProgressHUD *)subview;
        }
    }
    return nil;
}

#pragma mark - 顶部tip（占位，保留原有接口）
+ (void)showTopTipMessage:(NSString *)msg {
    [self showTopTipMessage:msg isWindow:NO];
}

+ (void)showTopTipMessage:(NSString *)msg isWindow:(BOOL) isWindow
{
    [self safeDismiss]; // 替换为safeDismiss
}

@end

#pragma mark - 修复：GloomyView手势逻辑
@implementation GloomyView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    // 安全校验，避免空调用
    if (isAvalibleTouch && [XTMBManager class]) {
        [XTMBManager dismiss];
    }
}

@end
