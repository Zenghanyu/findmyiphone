//
//  UIDevice+ModelIdentifier.h
//  NewTool
//
//  Created by XTMacMini on 2025/4/22.
//

#import <UIKit/UIKit.h>
#import <sys/utsname.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (ModelIdentifier)

- (NSString *)modelIdentifier;

- (BOOL)isiPhone13OrLater;

@end

NS_ASSUME_NONNULL_END
