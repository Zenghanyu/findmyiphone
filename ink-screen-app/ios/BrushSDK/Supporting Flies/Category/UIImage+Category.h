
/*
 *   Copyright (c) 2014年 唐斌. All rights reserved.
 * 
 * 项目名称: SmallPudding
 * 文件名称: UIImage+Category.h
 * 文件标识: 
 * 摘要描述:
 *
 * 当前版本:
 * 作者姓名: 唐斌
 * 创建日期: 14-5-15 下午4:07
 */



#import <UIKit/UIKit.h>
typedef enum
{
    CapLeft          = 0,
    CapMiddle        = 1,
    CapRight         = 2,
    CapLeftAndRight  = 3
} CapLocation;

@interface UIImage (Category)

+ (UIImage *)imageWithColor:(UIColor *)color;

+ (UIImage *)scaleToSize:(UIImage *)img size:(CGSize)size;

+ (UIImage *)imageWithImageSimple:(UIImage *)image scaledToSize:(CGSize)newSize;

+ (void) saveImage:(UIImage *)tempImage WithName:(NSString *)imageName;

/**
 * 调整图片的大小
 */
+ (UIImage *)resizeableImage:(UIImage *)image capInsets:(UIEdgeInsets)capInsets leftCapWidth:(NSInteger)leftCapWith topCapHeight:(NSInteger)topCapHeight;

/**
 * 将图片变成圆角
 */
+ (id)createRoundedRectImage:(UIImage*)image size:(CGSize)size radius:(NSInteger)r;

/**
 * 裁剪图片 1
 */
+ (UIImage *)getCroppedImage:(UIImage *)image cropRect:(CGRect)croprect;

+ (UIImage*)image:(UIImage*)image withCap:(CapLocation)location capWidth:(NSUInteger)capWidth buttonWidth:(NSUInteger)buttonWidth;

/**
 *  根据颜色得到图片
 *
 *  @param color 颜色
 *  @param frame 图片大小
 *
 *  @return 返回图片UIImage
 */
+ (UIImage *) buttonImageFromColor:(UIColor *)color buttonFrame:(CGRect)frame;

//
//
////获取图片某一点的颜色
//+ (UIColor *)colorAtPixel:(CGPoint)point;

/**
 *  根据view获得
 *
 *
 *  @return 返回图片UIImage
 */
+ (UIImage*)imageWithUIView:(UIView*) view;

/**
 *  根据view获得
 *
 */
+ (UIImage *)fixOrientation:(UIImage *)aImage;

//第一个参数为 需要虚线边框视图的大小， 第二个为 边框颜色， 第三个为 边框粗细。
+ (UIImage *)imageWithSize:(CGSize)size borderColor:(UIColor *)color borderWidth:(CGFloat)borderWidth;

/*
 *  加载bundle里面的的图片
 */
+ (UIImage *)imageNamed:(NSString *)name ofBundle:(NSString *)bundleName;


#pragma - mark  加载gif

+ (UIImage *)sd_animatedGIFNamed:(NSString *)name;

+ (UIImage *)sd_animatedGIFWithData:(NSData *)data;

- (UIImage *)sd_animatedImageByScalingAndCroppingToSize:(CGSize)size;

@end
