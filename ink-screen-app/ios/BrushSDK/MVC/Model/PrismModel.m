//
//  PrismModel.m
//  NewTool
//
//  Created by XTMacMini on 2025/2/18.
//

#import "PrismModel.h"

@implementation PrismDetailModel
+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    return @{@"id": @"idid",@"imgUrl": @"fileUrl"};
}
@end

@implementation PrismModel
+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    return @{@"idid": @"id", @"des": @"description", @"mubanUrl": @"fileUrl"};
}

+ (NSDictionary *)mj_objectClassInArray {
    return @{@"rows": [PrismDetailModel class]};
}

@end
