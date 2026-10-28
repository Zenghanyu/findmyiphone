#import <UIKit/UIKit.h>
@class XTDeviceConfig;
NS_ASSUME_NONNULL_BEGIN

/// Model-specific six-colour photographs. Never feed the physical preview to
/// exact-RGB upload extraction or through SDK dithering a second time.
@interface XTInkPhotoProcessor : NSObject
+ (BOOL)usesHinkProfile:(XTDeviceConfig *)config;
/// Returns protocol-marker image + nominal physical preview from one index map.
/// Payload mirrors apply only to the marker image, as in the existing SDK API.
+ (BOOL)processImage:(UIImage *)image deviceConfig:(XTDeviceConfig *)config
              dither:(BOOL)dither dataImage:(UIImage * _Nullable * _Nullable)dataImage
        displayImage:(UIImage * _Nullable * _Nullable)displayImage;
@end
NS_ASSUME_NONNULL_END
