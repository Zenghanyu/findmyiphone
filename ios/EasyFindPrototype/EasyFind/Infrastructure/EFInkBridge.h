#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/// Immutable preview and protocol payload produced by one conversion.
@interface EFInkPreparedImage : NSObject
@property (nonatomic, strong, readonly) UIImage *preview;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Objective-C vendor boundary. No screen, navigation or HUD is created here.
@interface EFInkBridge : NSObject
@property (nonatomic, copy, nullable) void (^progress)(double value);
@property (nonatomic, copy, nullable) void (^status)(NSString *message);
/// Local processing only: does not scan, connect or transmit to a device.
+ (void)prepareImage:(UIImage *)image
            antiLost:(BOOL)antiLost
          completion:(void (^)(EFInkPreparedImage * _Nullable, NSString * _Nullable))completion;
- (void)scan:(void (^)(NSArray<NSDictionary<NSString *, NSString *> *> *, NSError * _Nullable))completion;
- (BOOL)bind:(NSString *)mac antiLost:(BOOL)antiLost;
- (void)uploadPreparedImage:(EFInkPreparedImage *)image
               completion:(void (^)(BOOL accepted, NSString * _Nullable error))completion;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
