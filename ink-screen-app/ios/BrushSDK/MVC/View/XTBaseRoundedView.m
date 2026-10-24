//
//  XTBaseRoundedView.m
//  PaperVersion
//
//  Created by XTMacMini on 2025/3/21.
//

#import "XTBaseRoundedView.h"

@implementation XTBaseRoundedView

// 实现设置圆角的方法
- (void)setRoundedCornersWithRadius:(CGFloat)radius {
    [self setRoundedCorners:UIRectCornerAllCorners radius:radius];
}

- (void)setRoundedCorners:(UIRectCorner)corners radius:(CGFloat)radius {
    // 参数有效性检查
    if (radius < 0) {
        radius = 0;
    }
    
    // 创建一个与视图边界相同的圆角贝塞尔路径
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds byRoundingCorners:corners cornerRadii:CGSizeMake(radius, radius)];
    
    // 创建或复用形状图层作为遮罩层
    CAShapeLayer *maskLayer = nil;
    if (![self.layer.mask isKindOfClass:[CAShapeLayer class]]) {
        maskLayer = [CAShapeLayer layer];
        self.layer.mask = maskLayer;
    } else {
        maskLayer = (CAShapeLayer *)self.layer.mask;
    }
    
    // 设置形状图层的框架与视图的框架相同
    maskLayer.frame = self.bounds;
    // 将贝塞尔路径转换为 Core Graphics 路径并赋值给形状图层
    maskLayer.path = maskPath.CGPath;
}

// 实现设置圆角的方法
- (void)setRoundedCornersWithRadius:(CGFloat)radius borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor {
    [self setRoundedCorners:UIRectCornerAllCorners radius:radius borderWidth:borderWidth borderColor:borderColor];
}

- (void)setRoundedCorners:(UIRectCorner)corners radius:(CGFloat)radius borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor {
    // 参数有效性检查
    if (radius < 0) {
        radius = 0;
    }
    if (borderWidth < 0) {
        borderWidth = 0;
    }
    if (!borderColor) {
        borderColor = [UIColor clearColor];
    }
    
    // 创建一个与视图边界相同的圆角贝塞尔路径
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds byRoundingCorners:corners cornerRadii:CGSizeMake(radius, radius)];
    
    // 创建或复用形状图层作为遮罩层
    CAShapeLayer *maskLayer = nil;
    if (![self.layer.mask isKindOfClass:[CAShapeLayer class]]) {
        maskLayer = [CAShapeLayer layer];
        self.layer.mask = maskLayer;
    } else {
        maskLayer = (CAShapeLayer *)self.layer.mask;
    }
    
    // 设置形状图层的框架与视图的框架相同
    maskLayer.frame = self.bounds;
    // 将贝塞尔路径转换为 Core Graphics 路径并赋值给形状图层
    maskLayer.path = maskPath.CGPath;
    
    // 创建或复用用于绘制边框的形状图层
    CAShapeLayer *borderLayer = nil;
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:[CAShapeLayer class]] && sublayer.name && [sublayer.name isEqualToString:@"BorderLayer"]) {
            borderLayer = (CAShapeLayer *)sublayer;
            break;
        }
    }
    if (!borderLayer) {
        borderLayer = [CAShapeLayer layer];
        borderLayer.name = @"BorderLayer";
        [self.layer addSublayer:borderLayer];
    }
    
    // 设置边框图层的路径为圆角矩形路径
    borderLayer.path = maskPath.CGPath;
    // 设置边框的线宽
    borderLayer.lineWidth = borderWidth;
    // 设置边框的颜色
    borderLayer.strokeColor = borderColor.CGColor;
    // 设置填充颜色为透明，只绘制边框
    borderLayer.fillColor = [UIColor clearColor].CGColor;
    // 设置边框图层的框架与视图的框架相同
    borderLayer.frame = self.bounds;
}
@end
