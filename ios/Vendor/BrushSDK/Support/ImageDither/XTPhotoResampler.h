#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Source-photo preparation only. Never apply this to SDK palette/dither output.
@interface XTPhotoResampler : NSObject

/// Rect in the displayed image's normalized coordinates; rotation is applied AFTER cropping.
/// Keeps source pixels rather than taking a screenshot of an image view.
+ (nullable UIImage *)cropImage:(UIImage *)image
                normalizedRect:(CGRect)rect
                   orientation:(UIImageOrientation)orientation;

/// Exact device pixels, scale=1, orientation=up, opaque sRGB on white.
/// Antialiased Lanczos-3 + bounded luminance detail; same-size images are not sharpened.
+ (nullable UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size;
+ (nullable UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size;
/// Explicit control of the generic post-resize luminance enhancement.
+ (nullable UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength;
+ (nullable UIImage *)aspectFillImage:(UIImage *)image toSize:(CGSize)size detailStrength:(double)strength;

/// Aggressive DPID-style source-contrast sampling: exponent 1.5, weight ratio
/// 32, adaptive blend .9. No additional post-resize sharpening.
+ (nullable UIImage *)resizeImageUsingDPID:(UIImage *)image toSize:(CGSize)size;
+ (nullable UIImage *)aspectFillImageUsingDPID:(UIImage *)image toSize:(CGSize)size;

/// Preserve the existing 400x400 round-panel 69.7 degree/399px crop geometry,
/// but rotate the source photo before reducing it to device resolution.
+ (nullable UIImage *)roundPanelImage:(UIImage *)image
                              toSize:(CGSize)size
                     rotationDegrees:(CGFloat)degrees;
@end

NS_ASSUME_NONNULL_END
