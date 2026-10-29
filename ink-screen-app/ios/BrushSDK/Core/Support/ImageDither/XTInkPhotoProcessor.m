#import "XTInkPhotoProcessor.h"
#import "XTInkPhotoCore.h"
#import "XTDeviceConfig.h"
#import "XTScreenSpecConfig.h"
#import <stdlib.h>

static void XTInkReleasePixels(void *info,const void *data,size_t size) { free((void *)data); }

// Takes ownership even on failure. BGRA matches the existing exact RGB reader.
static UIImage *XTInkImage(uint8_t *pixels,size_t w,size_t h) {
    for(size_t i=0;i<w*h;i++) {uint8_t r=pixels[i*4];pixels[i*4]=pixels[i*4+2];pixels[i*4+2]=r;}
    CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,pixels,w*h*4,XTInkReleasePixels);
    if(!provider) {free(pixels);return nil;}
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef cg=CGImageCreate(w,h,8,32,w*4,space,kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst,
                                provider,NULL,false,kCGRenderingIntentDefault);
    UIImage *result=cg?[UIImage imageWithCGImage:cg scale:1 orientation:UIImageOrientationUp]:nil;
    if(cg) CGImageRelease(cg);
    CGColorSpaceRelease(space);CGDataProviderRelease(provider);return result;
}

@implementation XTInkPhotoProcessor
+ (BOOL)usesHinkProfile:(XTDeviceConfig *)config {
    // Model association is explicit in the spec table, never inferred from size
    // alone. Pure NFC has no documented direct-index packing entry in this SDK.
    XTScreenSpec *spec=[XTScreenSpecConfig screenSpecWithNumber:config.screenSpecNumber];
    return config && config.brushType==brushWithBle &&
           [spec.photoPanelProfile isEqualToString:@"HINK-T0154A10-A2"] &&
           config.screenWidth==240 && config.screenHeight==240 &&
           [config.screenColorCode isEqualToString:COLOR_BWRYGB_CODE];
}

+ (BOOL)processImage:(UIImage *)image deviceConfig:(XTDeviceConfig *)config dither:(BOOL)dither
           dataImage:(UIImage **)dataImage displayImage:(UIImage **)displayImage {
    if(dataImage) *dataImage=nil;if(displayImage) *displayImage=nil;
    if(![self usesHinkProfile:config] || !image.CGImage ||
       CGImageGetWidth(image.CGImage)!=240 || CGImageGetHeight(image.CGImage)!=240 ||
       image.imageOrientation!=UIImageOrientationUp) return NO;
    const size_t w=240,h=240;
    uint8_t *source=calloc(h,w*4),*codes=malloc(w*h),*markers=malloc(w*h*4),*physical=malloc(w*h*4);
    if(!source || !codes || !markers || !physical) {free(source);free(codes);free(markers);free(physical);return NO;}
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context=CGBitmapContextCreate(source,w,h,8,w*4,space,
                                               kCGBitmapByteOrder32Big|kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(!context) {free(source);free(codes);free(markers);free(physical);return NO;}
    CGContextSetRGBFillColor(context,1,1,1,1);CGContextFillRect(context,CGRectMake(0,0,w,h));
    CGContextTranslateCTM(context,0,h);CGContextScaleCTM(context,1,-1);
    CGContextSetInterpolationQuality(context,kCGInterpolationNone);
    UIGraphicsPushContext(context);[image drawInRect:CGRectMake(0,0,w,h)];UIGraphicsPopContext();
    CGContextRelease(context);
    // DPID already enhances structure using source pixels; do not sharpen the
    // low-resolution image a second time. Keep the same six-colour conversion.
    BOOL ok=XTInkQuantizeRGBA(source,w,h,w*4,codes,w,dither,0,.55) &&
            XTInkRenderIndices(codes,w,h,w,markers,w*4,0,config.flipHorizontal,config.flipVertical) &&
            XTInkRenderIndices(codes,w,h,w,physical,w*4,1,0,0);
    free(source);free(codes);
    if(!ok) {free(markers);free(physical);return NO;}
    UIImage *data=XTInkImage(markers,w,h),*display=XTInkImage(physical,w,h);
    if(!data || !display) return NO;
    if(dataImage) *dataImage=data;if(displayImage) *displayImage=display;
    return YES;
}
@end
