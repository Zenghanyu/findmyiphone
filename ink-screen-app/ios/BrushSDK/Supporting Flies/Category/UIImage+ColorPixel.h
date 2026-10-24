//
//  UIImage+ColorPixel.h
//  BrushSDK
//
//  Created by xthh on 2025/1/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ColorPoint : NSObject
@property (nonatomic, assign) NSInteger red;
@property (nonatomic, assign) NSInteger green;
@property (nonatomic, assign) NSInteger blue;
@property (nonatomic, assign) CGPoint locPiont;

@property (nonatomic, assign) NSNumber *resultValue;

@property (nonatomic, copy) NSString *colordes;

@end

@interface UIImage (ColorPixel)

- (UIColor *)colorAtPixel:(CGPoint)point;

- (void)getPicAllSubjectPixelColor:(void(^)(NSMutableArray <ColorPoint *> *))callBack;
   
- (void)getPicSomePiontSubjectPixelColor:(NSMutableArray *)listArr block:(void(^)(NSMutableDictionary *))callBack;

- (NSArray *)pixelData;
- (void)getPicAllPixelColor:(void(^)(NSMutableArray <ColorPoint *> *))callBack;


/// 将图片旋转弧度radians
- (UIImage *)sl_imageRotatedByRadians:(CGFloat)radians;

/// 提取图片上某位置像素的颜色
- (UIColor *)sl_colorAtPixel:(CGPoint)point;
- (UIColor *)sl_colorAtPixel1:(CGPoint)point;

/// 图片缩放，针对大图片处理
+ (UIImage *)sl_scaledImageWithData:(NSData *)data withSize:(CGSize)size scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;

@end

NS_ASSUME_NONNULL_END
