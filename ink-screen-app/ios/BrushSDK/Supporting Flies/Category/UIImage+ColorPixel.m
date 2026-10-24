//
//  UIImage+ColorPixel.m
//  BrushSDK
//
//  Created by xthh on 2025/1/13.
//

#import "UIImage+ColorPixel.h"

@implementation ColorPoint

- (NSString *)colordes {
    return [NSString stringWithFormat:@"- red %ld - green %ld - blue %ld - x %f- y %f ----- V %@",self.red,self.green,self.blue,self.locPiont.x,self.locPiont.y,self.resultValue];
}

@end

@implementation UIImage (ColorPixel)

- (UIColor *)colorAtPixelWithAI:(CGPoint)point {
    // 确保点在图片的有效区域内
    if (!CGRectContainsPoint(CGRectMake(0.0f, 0.0f, self.size.width, self.size.height), point)) {
        return nil;
    }
    
    // 将图片转换为CGImageRef
    CGImageRef imageRef = self.CGImage;
    if (imageRef == nil) {
        return nil;
    }
    
    // 获取图片宽度和高度
    CGFloat width = self.size.width;
    CGFloat height = self.size.height;
    
    // 计算点对应的像素位置
    NSInteger pointX = trunc(point.x);
    NSInteger pointY = trunc(point.y);
    
    // 确保像素位置有效
    if (pointX < 0 || pointX >= width || pointY < 0 || pointY >= height) {
        return nil;
    }
    
    // 获取图片指定位置的像素信息
    NSUInteger byteWidth = width * 4;
    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    CFDataRef data = CGDataProviderCopyData(provider);
    const UInt8 *pixels = CFDataGetBytePtr(data);
    NSUInteger offset = (byteWidth * pointY) + pointX * 4;
    UInt8 *colorData = (UInt8 *)(pixels + offset);
    
    // 根据像素信息创建UIColor对象
    CGFloat alpha = colorData[3] / 255.0f;
    CGFloat blue = colorData[2] / 255.0f;
    CGFloat green = colorData[1] / 255.0f;
    CGFloat red = colorData[0] / 255.0f;
    
    UIColor *color = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    
    // 释放资源
    CFRelease(data);
    
    return color;
}

- (UIColor *)colorAtPixel:(CGPoint)point {
    // 确保点在图片的有效区域内
    if (!CGRectContainsPoint(CGRectMake(0.0f, 0.0f, self.size.width, self.size.height), point)) {
        return nil;
    }
    // 将图片转换为CGImageRef
    CGImageRef cgImage = self.CGImage;
    if (cgImage == nil) {
        return nil;
    }
    // 计算点对应的像素位置
    NSInteger pointX = trunc(point.x);
    NSInteger pointY = trunc(point.y);
    
    // 获取图片宽度和高度
    NSUInteger width = self.size.width;
    NSUInteger height = self.size.height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int bytesPerPixel = 4;
    int bytesPerRow = bytesPerPixel * 1;
    NSUInteger bitsPerComponent = 8;
    unsigned char pixelData[4] = { 0, 0, 0, 0 };
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                 1,
                                                 1,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast |     kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextTranslateCTM(context, -pointX, pointY-(CGFloat)height);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), cgImage);
    CGContextRelease(context);
    
    CGFloat red   = (CGFloat)pixelData[0] / 255.0f;
    CGFloat green = (CGFloat)pixelData[1] / 255.0f;
    CGFloat blue  = (CGFloat)pixelData[2] / 255.0f;
    CGFloat alpha = (CGFloat)pixelData[3] / 255.0f;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

//根据图片获取图片的主色调
-(void)getSubjectColor:(void(^)(UIColor*))callBack {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 第一步 先把图片缩小 加快计算速度. 但越小结果误差可能越大
        int bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
        CGSize thumbSize = CGSizeMake(40, 40);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL,thumbSize.width,thumbSize.height, 8, thumbSize.width*4, colorSpace,bitmapInfo);
        CGRect drawRect = CGRectMake(0, 0, thumbSize.width, thumbSize.height);
        CGContextDrawImage(context, drawRect, self.CGImage);
        CGColorSpaceRelease(colorSpace);
        
        // 第二步 取每个点的像素值
        unsigned char* data = CGBitmapContextGetData (context);
        if (data == NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callBack(nil);
            });
        };
        NSCountedSet* cls = [NSCountedSet setWithCapacity: thumbSize.width * thumbSize.height];
        for (int x = 0; x < thumbSize.width; x++) {
            for (int y = 0; y < thumbSize.height; y++) {
                int offset = 4 * (x * y);
                int red = data[offset];
                int green = data[offset + 1];
                int blue = data[offset + 2];
                int alpha =  data[offset + 3];
                // 过滤透明的、基本白色、基本黑色
                if (alpha > 0 && (red < 250 && green < 250 && blue < 250) && (red > 5 && green > 5 && blue > 5)) {
                    NSArray *clr = @[@(red),@(green),@(blue),@(alpha)];
                    [cls addObject:clr];
                }
            }
        }
        CGContextRelease(context);
        
        //第三步 找到出现次数最多的那个颜色
        NSEnumerator *enumerator = [cls objectEnumerator];
        NSArray *curColor = nil;
        NSArray *MaxColor = nil;
        NSUInteger MaxCount = 0;
        while ((curColor = [enumerator nextObject]) != nil){
            NSUInteger tmpCount = [cls countForObject:curColor];
            if ( tmpCount < MaxCount ) continue;
            MaxCount = tmpCount;
            MaxColor = curColor;
        }
        UIColor * subjectColor = [UIColor colorWithRed:([MaxColor[0] intValue]/255.0f) green:([MaxColor[1] intValue]/255.0f) blue:([MaxColor[2] intValue]/255.0f) alpha:([MaxColor[3] intValue]/255.0f)];
        dispatch_async(dispatch_get_main_queue(), ^{
            callBack(subjectColor);
        });
    });
}

//根据图片所有像素点
- (void)getPicAllSubjectPixelColor:(void(^)(NSMutableArray <ColorPoint *> *))callBack {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     self.size.width,
                                                     self.size.height,
                                                     8,
                                                     0,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedLast);
        CGRect drawRect = CGRectMake(0, 0, self.size.width, self.size.height);
        CGContextDrawImage(context, drawRect, self.CGImage);
        CGColorSpaceRelease(colorSpace);
        
        // 第二步 取每个点的像素值
        unsigned char *data = CGBitmapContextGetData(context);
        if (data == NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callBack(nil);
            });
        };
        NSMutableArray *colorP = [NSMutableArray arrayWithCapacity:self.size.width * self.size.height];
        NSInteger count = 0;
        
        for (int x = 0; x < self.size.width; x++) {
            for (int y = 0; y < self.size.height; y++) {
                int offset = 4 * (x * y);
                int red = data[offset];
                int green = data[offset + 1];
                int blue = data[offset + 2];
                
                ColorPoint *p = [[ColorPoint alloc] init];
                p.red = red;
                p.green = green;
                p.blue = blue;
                p.locPiont = CGPointMake(x, y);
                
                BOOL color1 = red == 0 && green == 0 && blue == 255;
                BOOL color2 = red == 0 && green == 0 && blue == 0;
                
                if (!color1 && !color2) {
                    [colorP addObject:p];
                }
            }
        }
        
        CGContextRelease(context);
        //第三步  去重
        NSMutableArray *arr = [self getOutRepeatObjectFrom:colorP];
        NSMutableArray *sortedAry = [arr sortedArrayUsingComparator:^NSComparisonResult(ColorPoint *  _Nonnull obj1, ColorPoint *  _Nonnull obj2) {
            return obj1.blue > obj2.blue;
        }].mutableCopy;
        dispatch_async(dispatch_get_main_queue(), ^{
            callBack(sortedAry);
        });
    });
}

- (NSMutableArray *)getOutRepeatObjectFrom:(NSArray *)arr {
    NSMutableArray *needArr = [[NSMutableArray alloc]init];
    for (ColorPoint *model in arr) {
        __block BOOL isExist = NO;
        __block NSInteger countNum = 0;
        [needArr enumerateObjectsUsingBlock:^(ColorPoint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.red == model.red && obj.green == model.green && obj.blue == model.blue) {//数组中已经存在该对象
                countNum ++;
                *stop = YES;
                isExist = YES;
            }
        }];
        if (!isExist) {//如果不存在就添加进去
            [needArr addObject:model];
        }
    }
    return needArr;
}


- (NSArray *)pixelData {
    CGImageRef imageRef = self.CGImage;
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSMutableArray *pixels = [NSMutableArray arrayWithCapacity:width * height];
    
    // 图片的上下文
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc(width * height * 4, sizeof(unsigned char));
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, 8, width * 4, colorSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
    // 渲染图片到上下文
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // 遍历像素数据
    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {
            NSUInteger offset = 4 * (y * width + x);
            NSInteger blue = rawData[offset + 2];
            NSInteger green = rawData[offset + 1];
            NSInteger red = rawData[offset];
            
            BOOL color1 = red == 0 && green == 0 && blue == 255;
            BOOL color2 = red == 0 && green == 0 && blue == 0;
            
            if (!color1 && !color2) {
                NSString *loc = [NSString stringWithFormat:@"%lu,%lu",(unsigned long)x,(unsigned long)y];
                NSDictionary *pixel = @{@"blue": @(blue), @"loc": loc};
                [pixels addObject:pixel];
            }
        }
    }
    
    free(rawData);
    return [pixels copy];
}

- (void)getPicAllPixelColor:(void(^)(NSMutableArray <ColorPoint *> *))callBack {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageRef imageRef = self.CGImage;
        NSUInteger width = CGImageGetWidth(imageRef);
        NSUInteger height = CGImageGetHeight(imageRef);
        NSMutableArray *pixels = [NSMutableArray arrayWithCapacity:width * height];
        
        // 图片的上下文
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        unsigned char *rawData = (unsigned char *)calloc(width * height * 4, sizeof(unsigned char));
        CGContextRef context = CGBitmapContextCreate(rawData, width, height, 8, width * 4, colorSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(colorSpace);
        
        // 渲染图片到上下文
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        
        // 遍历像素数据
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                NSUInteger offset = 4 * (y * width + x);
                NSInteger blue = rawData[offset + 2];
                NSInteger green = rawData[offset + 1];
                NSInteger red = rawData[offset];
                
                ColorPoint *p = [[ColorPoint alloc] init];
                p.red = red;
                p.green = green;
                p.blue = blue;
                p.locPiont = CGPointMake(x, y);
                BOOL color1 = red == 0 && green == 0 && blue == 255;
                if (!color1) {
                    [pixels addObject:p];
                }
            }
        }
//        DLog(@"aqaaa %ld --- %ld",ocount,tcount);
//
        free(rawData);
        //第三步  排序
        NSMutableArray *sortedAry = [pixels sortedArrayUsingComparator:^NSComparisonResult(ColorPoint *  _Nonnull obj1, ColorPoint *  _Nonnull obj2) {
            return obj1.blue > obj2.blue;
        }].mutableCopy;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callBack(sortedAry);
        });
    });
}

//根据图片所有像素点
- (void)getPicSomePiontSubjectPixelColor:(NSMutableArray *)listArr block:(void(^)(NSMutableDictionary *))callBack {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageRef imageRef = self.CGImage;
        NSUInteger width = CGImageGetWidth(imageRef);
        NSUInteger height = CGImageGetHeight(imageRef);
        
        // 图片的上下文
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        unsigned char *rawData = (unsigned char *)calloc(width * height * 4, sizeof(unsigned char));
        CGContextRef context = CGBitmapContextCreate(rawData, width, height, 8, width * 4, colorSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(colorSpace);
        
        // 渲染图片到上下文
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
        
        for (ColorPoint *p in listArr) {
            NSMutableArray *groupArr = resultDict[@(p.blue)];
            
            NSUInteger offset = 4 * (p.locPiont.y * width + p.locPiont.x);
            NSInteger red = rawData[offset];
            NSInteger green = rawData[offset + 1];
            NSInteger blue = rawData[offset + 2];
            
            ColorPoint *newp = p;
            if (red == 229 && green == 229 && blue == 55) {//黄
                newp.resultValue = @1;
            } else if (red == 0 && green == 0 && blue == 0) { //黑
                newp.resultValue = @4;
            } else if (red == 239 && green == 239 && blue == 239) {//bai
                newp.resultValue = @0;
            } else if (red == 168 && green == 38 && blue == 47) {//红
                newp.resultValue = @3;
            } else if (red == 56 && green == 94 && blue == 178) {//蓝
                newp.resultValue = @2;
            } else if (red == 111 && green == 186 && blue == 47) {//绿
                newp.resultValue = @5;
            } else { // 错误解析
                newp.resultValue = @0;
            }

            //添加对象进数组
            if (groupArr) {
                [groupArr addObject:p];
                [resultDict setObject:groupArr forKey:@(p.blue)];
            } else {
                NSMutableArray *groupArr = @[p].mutableCopy;
                [resultDict setObject:groupArr forKey:@(p.blue)];
            }
        }
        free(rawData);
        dispatch_async(dispatch_get_main_queue(), ^{
//            DLog(@"resultDict key %@",resultDict.allKeys);
            callBack(resultDict);
        });
    });
}

/// 将图片旋转弧度radians
- (UIImage *)sl_imageRotatedByRadians:(CGFloat)radians {
    // calculate the size of the rotated view's containing box for our drawing space
    CGAffineTransform t = CGAffineTransformMakeRotation(radians);
    CGRect clipTransRect = CGRectApplyAffineTransform(CGRectMake(0,0,self.size.width, self.size.height), t);
    CGSize rotatedSize = clipTransRect.size;
    rotatedSize.width = ((int)(rotatedSize.width+0.5)*1.f);
    rotatedSize.height = ((int)(rotatedSize.height+0.5)*1.f);
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    // Rotate the image context
    CGContextRotateCTM(bitmap, radians);
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}
/// 提取图片上某位置像素的颜色
- (UIColor *)sl_colorAtPixel:(CGPoint)point {
    // Cancel if point is outside image coordinates
    if (!CGRectContainsPoint(CGRectMake(0.0f, 0.0f, self.size.width, self.size.height), point)) {
        return nil;
    }
    
    NSInteger pointX = trunc(point.x);
    NSInteger pointY = trunc(point.y);
    CGImageRef cgImage = self.CGImage;
    NSUInteger width = self.size.width;
    NSUInteger height = self.size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int bytesPerPixel = 4;
    int bytesPerRow = bytesPerPixel * 1;
    NSUInteger bitsPerComponent = 8;
    unsigned char pixelData[4] = { 0, 0, 0, 0 };
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                 1,
                                                 1,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    
    // Draw the pixel we are interested in onto the bitmap context
    CGContextTranslateCTM(context, -pointX, pointY-(CGFloat)height);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), cgImage);
    CGContextRelease(context);
    
    // Convert color values [0..255] to floats [0.0..1.0]
    CGFloat red   = (CGFloat)pixelData[0] / 255.0f;
    CGFloat green = (CGFloat)pixelData[1] / 255.0f;
    CGFloat blue  = (CGFloat)pixelData[2] / 255.0f;
    CGFloat alpha = (CGFloat)pixelData[3] / 255.0f;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

/// 图片缩放，针对大图片处理
+ (UIImage *)sl_scaledImageWithData:(NSData *)data withSize:(CGSize)size scale:(CGFloat)scale orientation:(UIImageOrientation)orientation {
    CGFloat maxPixelSize = MAX(size.width, size.height);
    CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)data,nil);
    NSDictionary *optoins = @{(__bridge id)kCGImageSourceCreateThumbnailFromImageAlways:(__bridge id)kCFBooleanTrue,(__bridge id)kCGImageSourceThumbnailMaxPixelSize:[NSNumber numberWithFloat:maxPixelSize]};
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(sourceRef, 0, (__bridge CFDictionaryRef)optoins);
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:scale orientation:orientation];
    CGImageRelease(imageRef);
    CFRelease(sourceRef);
    return image;
}


@end
