#import "XTPhotoResampler.h"
#import "XTPhotoResampleCore.h"
#import <math.h>
#import <stdlib.h>

@interface XTPhotoResampler ()
+ (nullable UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size
                   detailStrength:(double)strength useDPID:(BOOL)useDPID;
+ (nullable UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size
                       detailStrength:(double)strength useDPID:(BOOL)useDPID;
@end

static CGSize XTPhotoPixelSize(UIImage *image) {
    if (!image.CGImage) return CGSizeZero;
    size_t w = CGImageGetWidth(image.CGImage), h = CGImageGetHeight(image.CGImage);
    switch (image.imageOrientation) {
        case UIImageOrientationLeft: case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight: case UIImageOrientationRightMirrored:
            return CGSizeMake(h, w);
        default: return CGSizeMake(w, h);
    }
}

static BOOL XTPhotoValidSize(CGSize size) {
    return isfinite(size.width) && isfinite(size.height) &&
           size.width >= 1 && size.height >= 1 && size.width <= 32768 && size.height <= 32768 &&
           size.width * size.height <= 64000000;
}

static CGRect XTPhotoIntegralCrop(CGRect rect) {
    // Normalized mirrored coordinates can land a few ulps above an integer.
    // Do not accidentally include an extra source row/column in that case.
    CGFloat left = floor(CGRectGetMinX(rect) + 1e-7), top = floor(CGRectGetMinY(rect) + 1e-7);
    CGFloat right = ceil(CGRectGetMaxX(rect) - 1e-7), bottom = ceil(CGRectGetMaxY(rect) - 1e-7);
    return CGRectMake(left, top, MAX(1, right - left), MAX(1, bottom - top));
}

static CGContextRef XTPhotoContext(size_t w, size_t h, uint8_t **pixels) {
    *pixels = calloc(h, w * 4);
    if (!*pixels) return NULL;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(*pixels, w, h, 8, w * 4, space,
                                                kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) { free(*pixels); *pixels = NULL; return NULL; }
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, w, h));
    CGContextTranslateCTM(context, 0, h);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    return context;
}

static void XTPhotoReleasePixels(void *info, const void *data, size_t size) { free((void *)data); }

/// Transfers the buffer to a data provider, including on failure.
static UIImage *XTPhotoImage(uint8_t *pixels, size_t w, size_t h) {
    // Keep the UIImage boundary in the BGRA layout normally produced by UIKit.
    // The portable processing core itself always uses explicit RGBA.
    for (size_t i = 0; i < w * h; ++i) {
        uint8_t red = pixels[i * 4];
        pixels[i * 4] = pixels[i * 4 + 2];
        pixels[i * 4 + 2] = red;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, w * h * 4, XTPhotoReleasePixels);
    if (!provider) { free(pixels); return nil; }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef cgImage = CGImageCreate(w, h, 8, 32, w * 4, space,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst,
                                      provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *result = cgImage ? [UIImage imageWithCGImage:cgImage scale:1 orientation:UIImageOrientationUp] : nil;
    if (cgImage) CGImageRelease(cgImage);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return result;
}

@implementation XTPhotoResampler

+ (UIImage *)cropImage:(UIImage *)image normalizedRect:(CGRect)rect orientation:(UIImageOrientation)orientation {
    CGSize sourceSize = XTPhotoPixelSize(image);
    if (!XTPhotoValidSize(sourceSize) || !isfinite(rect.origin.x) || !isfinite(rect.origin.y) ||
        !isfinite(rect.size.width) || !isfinite(rect.size.height) || rect.size.width <= 0 || rect.size.height <= 0) return nil;
    CGRect unitRect = CGRectIntersection(rect, CGRectMake(0, 0, 1, 1));
    if (CGRectIsEmpty(unitRect) || CGRectIsNull(unitRect)) return nil;
    int turns = 0;
    switch (orientation) {
        case UIImageOrientationUp: turns = 0; break;
        case UIImageOrientationRight: turns = 1; break;
        case UIImageOrientationDown: turns = 2; break;
        case UIImageOrientationLeft: turns = 3; break;
        default: return nil;
    }
    double input[4] = {unitRect.origin.x, unitRect.origin.y, unitRect.size.width, unitRect.size.height};
    double raw[4];
    int combinedOrientation = 0;
    if (!XTPhotoMapCrop(input, (int)image.imageOrientation, turns, raw, &combinedOrientation)) return nil;
    size_t rawWidth = CGImageGetWidth(image.CGImage), rawHeight = CGImageGetHeight(image.CGImage);
    CGRect crop = XTPhotoIntegralCrop(CGRectMake(raw[0] * rawWidth, raw[1] * rawHeight,
                                                raw[2] * rawWidth, raw[3] * rawHeight));
    crop = CGRectIntersection(crop, CGRectMake(0, 0, rawWidth, rawHeight));
    if (!XTPhotoValidSize(crop.size)) return nil;
    // CGImage cropping can share the source storage; no full-size screenshot or
    // full-size upright RGBA copy is needed here. Color/alpha conversion happens once at resize.
    CGImageRef cropped = CGImageCreateWithImageInRect(image.CGImage, crop);
    if (!cropped) return nil;
    UIImage *result = [UIImage imageWithCGImage:cropped scale:1 orientation:(UIImageOrientation)combinedOrientation];
    CGImageRelease(cropped);
    return result;
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    return [self resizeImage:image toSize:size detailStrength:.65];
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength {
    return [self resizeImage:image toSize:size detailStrength:strength useDPID:NO];
}

+ (UIImage *)resizeImageUsingDPID:(UIImage *)image toSize:(CGSize)size {
    return [self resizeImage:image toSize:size detailStrength:0 useDPID:YES];
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength useDPID:(BOOL)useDPID {
    CGSize sourceSize = XTPhotoPixelSize(image);
    if (!XTPhotoValidSize(sourceSize) || !XTPhotoValidSize(size)) return nil;
    size_t sw = (size_t)sourceSize.width, sh = (size_t)sourceSize.height;
    size_t dw = (size_t)llround(size.width), dh = (size_t)llround(size.height);
    uint8_t *source = NULL;
    CGContextRef context = XTPhotoContext(sw, sh, &source);
    if (!context) return nil;
    UIGraphicsPushContext(context);
    [image drawInRect:CGRectMake(0, 0, sw, sh)];
    UIGraphicsPopContext();
    CGContextRelease(context);
    uint8_t *output = calloc(dh, dw * 4);
    if (!output) { free(source); return nil; }
    // Portable models: resample.py (Lanczos), dpid.py (source-contrast sampling).
    int ok = useDPID ? XTPhotoDPIDResampleRGBA(source, sw, sh, sw * 4, output, dw, dh, dw * 4, 1.5, 32, .9)
                     : XTPhotoResampleRGBA(source, sw, sh, sw * 4, output, dw, dh, dw * 4, strength);
    free(source);
    if (!ok) { free(output); return nil; }
    return XTPhotoImage(output, dw, dh);
}

+ (UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size {
    return [self aspectFillImage:image toSize:size detailStrength:.65];
}

+ (UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength {
    return [self aspectFillImage:image toSize:size detailStrength:strength useDPID:NO];
}

+ (UIImage *)aspectFillImageUsingDPID:(UIImage *)image toSize:(CGSize)size {
    return [self aspectFillImage:image toSize:size detailStrength:0 useDPID:YES];
}

+ (UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength useDPID:(BOOL)useDPID {
    CGSize source = XTPhotoPixelSize(image);
    if (!XTPhotoValidSize(source) || !XTPhotoValidSize(size)) return nil;
    CGFloat factor = MAX(size.width / source.width, size.height / source.height);
    CGFloat width = size.width / factor / source.width, height = size.height / factor / source.height;
    UIImage *crop = [self cropImage:image normalizedRect:CGRectMake((1 - width) / 2, (1 - height) / 2, width, height)
                         orientation:UIImageOrientationUp];
    return crop ? [self resizeImage:crop toSize:size detailStrength:strength useDPID:useDPID] : nil;
}

+ (UIImage *)roundPanelImage:(UIImage *)image toSize:(CGSize)size rotationDegrees:(CGFloat)degrees {
    CGSize source = XTPhotoPixelSize(image);
    if (!XTPhotoValidSize(source) || !XTPhotoValidSize(size) || size.width <= 1 || size.height <= 1 || !isfinite(degrees)) return nil;
    // The old code crops [referenceSize-1] pixels starting at (rotatedSize-referenceSize)/2.
    // Keep that alignment while performing rotation at source resolution, before downsampling.
    size_t w = (size_t)llround(source.width * (size.width - 1) / size.width);
    size_t h = (size_t)llround(source.height * (size.height - 1) / size.height);
    if (!XTPhotoValidSize(CGSizeMake(w, h))) return nil;
    uint8_t *pixels = NULL;
    CGContextRef context = XTPhotoContext(w, h, &pixels);
    if (!context) return nil;
    CGContextTranslateCTM(context, source.width / 2, source.height / 2);
    CGContextRotateCTM(context, degrees * M_PI / 180);
    UIGraphicsPushContext(context);
    [image drawInRect:CGRectMake(-source.width / 2, -source.height / 2, source.width, source.height)];
    UIGraphicsPopContext();
    CGContextRelease(context);
    UIImage *rotated = XTPhotoImage(pixels, w, h);
    return rotated ? [self resizeImage:rotated toSize:size] : nil;
}
@end
