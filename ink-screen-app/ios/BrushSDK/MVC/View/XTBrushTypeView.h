//
//  XTBrushTypeView.h
//  PaperVersion
//
//  Created by XTMacMini on 2025/3/24.
//

#import <UIKit/UIKit.h>
#import "XTBaseRoundedView.h"

NS_ASSUME_NONNULL_BEGIN

@interface XTBrushTypeView : XTBaseRoundedView

@property(nonatomic, copy) NSString *title;

@property(nonatomic,getter=isSelected) BOOL selected;

@end

NS_ASSUME_NONNULL_END
