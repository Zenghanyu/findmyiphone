//
//  XTBaseRoundedView.h
//  PaperVersion
//
//  Created by XTMacMini on 2025/3/21.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XTBaseRoundedView : UIView

/**
 * @brief 设置视图的全角圆角 (无边框)
 *        Set view full rounded corners (no border)
 *
 * 此方法通过创建贝塞尔路径和形状图层，为视图添加四角统一的圆角效果，无边框样式，无离屏渲染卡顿问题。
 * This method adds unified rounded corners for all view corners by creating bezier path and shape layer, no border style, no off-screen rendering lag.
 *
 * @param radius 圆角的半径值 | Corner radius value
 */
- (void)setRoundedCornersWithRadius:(CGFloat)radius;

/**
 * @brief 设置视图的全角圆角和边框样式
 *        Set view full rounded corners and border style
 *
 * 此方法通过创建贝塞尔路径和形状图层，为视图添加四角统一的圆角效果，同时自定义配置边框宽度与边框颜色。
 * This method adds unified rounded corners for all view corners by creating bezier path and shape layer, and custom setting border width and color.
 *
 * @param radius 圆角的半径值 | Corner radius value
 * @param borderWidth 边框的宽度值 | Border width value
 * @param borderColor 边框的颜色对象 | Border color object
 */
- (void)setRoundedCornersWithRadius:(CGFloat)radius borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor;

/**
 * @brief 设置视图的指定角圆角和边框样式
 *        Set view specified corner rounded & border style
 *
 * 此方法通过创建贝塞尔路径和形状图层，为视图指定单个/多个角添加圆角效果，同时自定义配置边框宽度与边框颜色，适配按需圆角的业务场景。
 * This method adds rounded corners for specified single/multiple view corners by creating bezier path and shape layer, custom setting border width and color, suitable for on-demand corner business scenarios.
 *
 * @param corners 指定的圆角位置(枚举)，可组合传值如：UIRectCornerTopLeft|UIRectCornerTopRight | Specified corner position (enumeration), can pass combined value
 * @param radius 圆角的半径值 | Corner radius value
 * @param borderWidth 边框的宽度值 | Border width value
 * @param borderColor 边框的颜色对象 | Border color object
 */
- (void)setRoundedCorners:(UIRectCorner)corners radius:(CGFloat)radius borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor;

@end

NS_ASSUME_NONNULL_END
