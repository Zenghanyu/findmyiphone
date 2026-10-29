//
//  NewPrismBrushCell.h
//  BrushSDK
//
//  Created by xthh on 2025/1/15.
//

#import <UIKit/UIKit.h>
#import "PrismModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XTPrismBrushCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *shapeView;

- (void)refreshUIWithdata:(PrismDetailModel *)model;

- (void)refreshOldPrsimUIWithdata:(NSString *)imgName;

@end

NS_ASSUME_NONNULL_END
