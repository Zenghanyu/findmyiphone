//
//  UtilsMacros.h
//  fatereason
//
//  Created by QiGe on 2018/3/2.
//  Copyright © 2018年 mingrikongjian002. All rights reserved.
//

#ifndef UtilsMacros_h //工具类的宏
#define UtilsMacros_h

// 添加这个宏，就不用带mas_前缀
#define MAS_SHORTHAND
// 添加这个宏，equalTo就等价于mas_equalTo
#define MAS_SHORTHAND_GLOBALS

//多语言
#define XTLS(key) NSLocalizedString(key, nil)

/*
 *  常规单列
 */
#pragma mark - 常规单列

/** 整个APP */
#define KApplication                        [UIApplication sharedApplication]

/** AppDelegate */
#define KAppDelegate                        ((AppDelegate *)[UIApplication sharedApplication].delegate)

/** UserDefaults */
#define KUserDefaults                       [NSUserDefaults standardUserDefaults]

/** 获取通知中心 */
#define KNotificationCenter                 [NSNotificationCenter defaultCenter]

/** 主屏 */
#define KWindowView                         [[UIApplication sharedApplication] keyWindow]

/*
 *  常用
 */
#pragma mark - 常用

/** APP名字 */
#define KAppName                            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"]

/** APP Verison版本号 */
#define KAppVersion                         [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]

/** APP build版本号 */
#define KLocalCurVersion                    [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]

//判断是否为横竖屏
#define KIsPortrait ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait || [UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)

/** 系统版本号 */
#define KSystemVersion                      [[UIDevice currentDevice] systemVersion]

/** 获取当前语言 */
#define KCurrentLanguage                    ([[NSLocale preferredLanguages] objectAtIndex:0])

/** 判断是否为iPhone */
#define KIsiPhone                           (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

// 标准弱引用宏
#define XTWeakSelf                          __weak typeof(self) weakSelf = self;

// 标准强引用宏
#define XTStrongSelf                        __strong typeof(weakSelf) strongSelf = weakSelf;

/** 转成字符串 */
#define KStringWithFormat(format,...)       [NSString stringWithFormat:format,##__VA_ARGS__]

/** 获取图片资源 */
#define kGetImage(imageName)                [UIImage imageNamed:[NSString stringWithFormat:@"%@",imageName]]

/** 把对象负值为nil */
#define CC_SAFE_NULL(p)                     do { if(p) { (p) = nil; } } while(0)

/** 对象是否为空 */
#define IsNilOrNull(_ref)                   (((_ref) == nil) || ([(_ref) isEqual:[NSNull null]]))

/** 角度转弧度 */
#define DEGREES_TO_RADIANS(x)               (M_PI * (x) / 180.0)

/** 角度转弧度 */
#define RADIANS_TO_DEGREES(radian)          (radian * 180.0)/(M_PI)

/** 适配隐藏导航栏有刷新的页面 AdjustsScrollViewInsetNever */
#define AdjustsScrollViewInsetNever(controller,view) (if(@available(iOS 11.0, *)) {view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;} else if([controller isKindOfClass:[UIViewController class]]) {controller.automaticallyAdjustsScrollViewInsets = false;})

/** 设置view 圆角 */
#define KViewBorderRadius(View, Radius)\
\
[View.layer setCornerRadius:(Radius)];\
[View.layer setMasksToBounds:YES];

/** 设置view 圆角和边框 */
#define KViewBorderRadiusLine(View, Radius, Width, Color)\
\
[View.layer setCornerRadius:(Radius)];\
[View.layer setMasksToBounds:YES];\
[View.layer setBorderWidth:(Width)];\
[View.layer setBorderColor:[Color CGColor]]

/** 单例 */
#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) \
\
static classname *shared##classname = nil; \
\
+ (classname *)shared##classname \
{ \
@synchronized(self) \
{ \
if (shared##classname == nil) \
{ \
shared##classname = [[self alloc] init]; \
} \
} \
\
return shared##classname; \
} \
\
+ (id)allocWithZone:(NSZone *)zone \
{ \
@synchronized(self) \
{ \
if (shared##classname == nil) \
{ \
shared##classname = [super allocWithZone:zone]; \
return shared##classname; \
} \
} \
\
return nil; \
} \
\
- (id)copyWithZone:(NSZone *)zone \
{ \
return self; \
} \
\

/* tableView不会向下偏移 */
#define  adjustsScrollViewInsets_NO(scrollView,vc)\
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
if ([UIScrollView instancesRespondToSelector:NSSelectorFromString(@"setContentInsetAdjustmentBehavior:")]) {\
[scrollView   performSelector:NSSelectorFromString(@"setContentInsetAdjustmentBehavior:") withObject:@(2)];\
} else {\
vc.automaticallyAdjustsScrollViewInsets = NO;\
}\
_Pragma("clang diagnostic pop") \
} while (0)


/*
 *  系统版本判断
 */
#pragma mark - 系统版本判断

/** iOS 9~ */
#define KiOS9OrLater                        ([[UIDevice currentDevice].systemVersion doubleValue] >= 9.0)

/** iOS 10~ */
#define KiOS10OrLater                       ([[UIDevice currentDevice].systemVersion doubleValue] >= 10.0)

/** iOS 11~ */
#define KiOS11OrLater                       ([[UIDevice currentDevice].systemVersion doubleValue] >= 11.0)

/** iOS 12~ */
#define KiOS12OrLater                       ([[UIDevice currentDevice].systemVersion doubleValue] >= 12.0)

/** iOS 13~ */
#define KiOS13OrLater                       ([[UIDevice currentDevice].systemVersion doubleValue] >= 13.0)

/** 等于 */
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)

/** 大于 */
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

/** 大于等于 */
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

/** 小于 */
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

/** 小于等于 */
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

/*
 *   打印
 */
#pragma mark - 打印
#ifdef DEBUG
#define DLog(fmt, ...) do { \
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; \
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS"; \
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]; \
    NSString *timeStr = [formatter stringFromDate:[NSDate date]]; \
    NSLog(@">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n[%@] %s [Line %d] \n" fmt @"\n\n", timeStr, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
} while(0)
#else
#define DLog(...)
#endif

/** 控制台打印不完全的解决方法 -【带时间戳+分隔线+修复所有bug+末尾回车】 */
/** 提示用 */
#ifdef DEBUG
#define XTCLog(format, ...)  do { \
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; \
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS"; \
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]; \
    NSString *timeStr = [formatter stringFromDate:[NSDate date]]; \
    NSString *filePath = [NSString stringWithUTF8String:__FILE__]; \
    NSString *fileName = [filePath lastPathComponent]; \
    NSString *logContent = [NSString stringWithFormat:format, ##__VA_ARGS__] ?: @""; \
    NSString *fullLog = [NSString stringWithFormat:@"\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n[%@] class: <%s:(%d) > method: %s \n%@\n", timeStr, fileName.UTF8String, __LINE__, __PRETTY_FUNCTION__, logContent]; \
    printf("%s", fullLog.UTF8String); \
} while (0)
#else
#define XTCLog(format, ...)
#endif

/*
 *  网络请求
 */

/** 获取网络数据，执行请求之后的回调函数 */
#define DECLARE_ASI_FUNCTION(funName, varType) \
- (void)funName##Done:(varType)request; \
- (void)funName##Failed:(varType)request;

/** 执行服务端请求后，回调函数，返回数组 */
#define DECLARE_ASI_ARRAY_FUNCATION(funName) \
- (void)responseWith##funName##NetStatus:(int)netStatus respArray:(NSArray *)respArray;

#define DECLARE_UI_ARRAY_FUNCTION(funName) \
- (void)funName##NetStatus:(int)netStatus respArray:(NSArray *)respArray;

/** 执行服务端请求后，回调函数，返回键值对 */
#define DECLARE_ASI_DICTIONARY_FUNCATION(funName) \
- (void)responseWith##funName##NetStatus:(int)netStatus respDict:(NSDictionary *)respDict;

/** 执行，返回id类型 */
#define DECLARE_ASI_ID_FUNCATION(funName) \
- (void)responseWith##funName##NetStatus:(int)netStatus respId:(id)respId;

#define DECLARE_UI_DICTIONARY_FUNCATION(funName) \
- (void)funName##NetStatus:(int)netStatus respDict:(NSDictionary *)respDict;

#define DECLARE_UI_STRING_FUNCATION(funName) \
- (void)funName##NetStatus:(int)netStatus respStr:(NSString *)respStr;

#define DECLARE_UI_INT_FUNCATION(funName) \
- (void)funName##NetStatus:(int)netStatus respId:(NSInteger)respId;

#define DECLARE_UI_ID_FUNCATION(funName) \
- (void)funName##NetStatus:(int)netStatus respId:(id)respid;

/** 执行服务端请求后，回调函数，返回状态值 */
#define DECLARE_ASI_STATUS_FUNCATION(funName) \
- (void)responseWith##funName##NetStatus:(int)netStatus respStatus:(int)respStatus;

#define DECLARE_UI_STATUS_FUNCATION(funName) \
- (void)funName##NetStatus:(int)netStatus respStatus:(int)respStatus;

//错误码定义
#define BT_SUCCESS                  0   //操作成功
#define BT_OPERATION_FAILED         1   //操作失败

#define XTCOLOR(c)                  [UIColor colorWithRed:((float)((c & 0xFF0000) >> 16))/255.0 green:((float)((c & 0xFF00) >> 8))/255.0 blue:((float)(c & 0xFF))/255.0 alpha:1.0f]

#define XTViewBgColor               XTCOLOR(0xf8f8f8)

#define XTScreenWidth               [UIScreen mainScreen].bounds.size.width

#define XTScreenHeight              [UIScreen mainScreen].bounds.size.height

#define XTScale                     ([[UIScreen mainScreen] bounds].size.width / 390.0)

#define XTNavigationHeight          44.0

#define XTStatusBarAndNavigationHeight   [XTTool getStatusBarHight] + XTNavigationHeight

#define XTPFRegularFont(SIZE)       [UIFont fontWithName:@"PingFangSC-Regular" size:SIZE]

/** 苹方-简 中黑体 */
#define XTPFMediumFont(SIZE)        [UIFont fontWithName:@"PingFangSC-Medium" size:SIZE]

/** 弱引用 */
#define XTWeakSelf  __weak typeof(self) weakSelf = self;

/** 强引用 */
#define XTStrongSelf  __strong typeof(weakSelf) strongSelf = weakSelf;

#endif /* UtilsMacros_h */
