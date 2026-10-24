//
//  UIDevice+ModelIdentifier.m
//  NewTool
//
//  Created by XTMacMini on 2025/4/22.
//

#import "UIDevice+ModelIdentifier.h"

@implementation UIDevice (ModelIdentifier)

- (NSString *)modelIdentifier {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (BOOL)isiPhone13OrLater {
    NSArray *identifiers = @[
        // iPhone 13系列 se3
        @"iPhone14,2", @"iPhone14,3", @"iPhone14,4", @"iPhone14,5", @"iPhone14,6",@"iPhone14,7",@"iPhone14,8",
        // iPhone 14 pro系列 15系列
        @"iPhone15,2", @"iPhone15,3", @"iPhone15,4", @"iPhone15,5", @"iPhone16,1", @"iPhone16,2",
        // iPhone 16系列
        @"iPhone17,1", @"iPhone17,2", @"iPhone17,3", @"iPhone17,4"
        // 后续机型可继续添加对应硬件型号
    ];
    return [identifiers containsObject:self.modelIdentifier];
}

@end
