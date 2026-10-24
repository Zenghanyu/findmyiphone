//
//  XTScreenSpecConfig.h
//  BrushSDK
//
//  Created by XTMacMini on 2026/8/21.
//

#import <Foundation/Foundation.h>
#import "XTEnum.h"
#import <XTDitherBleProtocol/XTImageDataProcessType.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  @brief SDK内置屏幕规格编号 | Built-in screen specification number.
 *  @discussion
 *  编号对应绑定弹窗中的1-9号屏，新增屏幕时优先在这里增加枚举。
 *  The value maps to Screen 1-9 in the binding picker. Add new screen numbers here first.
 */
typedef NS_ENUM(NSInteger, XTScreenSpecNumber) {
    XTScreenSpecNumber154FourColor = 1,
    XTScreenSpecNumber154FourColorAntiLost = 2,
    XTScreenSpecNumber154SixColor = 3,
    XTScreenSpecNumber154SixColorAntiLost = 4,
    XTScreenSpecNumber169SixColor = 5,
    XTScreenSpecNumber169SixColorAntiLost = 6,
    XTScreenSpecNumber37SixColor = 7,
    XTScreenSpecNumber589SixColor = 8,
    XTScreenSpecNumber40FourColor = 9,
};

/**
 *  @brief 单个屏幕规格配置 | Single screen specification.
 *  @discussion
 *  只描述屏幕自身能力，不包含设备MAC、绑定状态或后台设备编号。
 *  Describes screen capability only; it does not include MAC, bind state, or backend device number.
 */
@interface XTScreenSpec : NSObject

/// 屏幕编号 | Screen number.
@property (nonatomic, assign, readonly) XTScreenSpecNumber number;
/// 国际化文案key | Localization key for display title.
@property (nonatomic, copy, readonly) NSString *titleKey;
/// 屏幕宽度，单位：像素 | Screen width in pixels.
@property (nonatomic, assign, readonly) NSInteger width;
/// 屏幕高度，单位：像素 | Screen height in pixels.
@property (nonatomic, assign, readonly) NSInteger height;
/// 屏幕颜色能力，如BWRY、BWRYGB | Color capability, such as BWRY or BWRYGB.
@property (nonatomic, copy, readonly) NSString *color;
/// Explicit panel association for photograph processing; nil uses the SDK path.
/// Confirm this association when replacing the physical panel with another model.
@property (nonatomic, copy, readonly, nullable) NSString *photoPanelProfile;
/// 刷图扫描方向 | Image packing scan direction.
@property (nonatomic, assign, readonly) ScanType scanType;
/// 刷图数据打包处理类型 | Image data packing mode.
@property (nonatomic, assign, readonly) XTImageDataProcessType imageDataProcessType;
/// 防丢器刷图前是否需要先切换刷图模式 | Whether FindMy/anti-lost mode must switch to brush mode before upload.
@property (nonatomic, assign, readonly) BOOL needsFindMyBrushModeSwitch;
/// 是否为防丢器屏幕规格 | Whether this screen spec is for an anti-lost device.
@property (nonatomic, assign, readonly) BOOL antiLostDevice;

@end

/**
 *  @brief 屏幕规格集中配置入口 | Centralized screen specification provider.
 *  @discussion
 *  后续新增屏幕时，只维护XTScreenSpecNumber和defaultScreenSpecs中的配置表。
 *  For new screens, update XTScreenSpecNumber and the table in defaultScreenSpecs only.
 */
@interface XTScreenSpecConfig : NSObject

/// 获取SDK默认支持的屏幕列表 | Returns all default screen specs supported by the SDK demo.
+ (NSArray<XTScreenSpec *> *)defaultScreenSpecs;
/// 按屏幕编号获取规格 | Finds one screen spec by screen number.
+ (nullable XTScreenSpec *)screenSpecWithNumber:(XTScreenSpecNumber)number;

@end

NS_ASSUME_NONNULL_END
