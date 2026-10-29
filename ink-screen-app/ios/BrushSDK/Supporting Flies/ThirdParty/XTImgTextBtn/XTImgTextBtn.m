//
//  XTImgTextBtn.m
//  
//
//  Created by LH on 8/5/20.
//  Copyright © 2020 ysyplay. All rights reserved.
//

#import "XTImgTextBtn.h"

@interface XTImgTextBtn()

@end

@implementation XTImgTextBtn

+ (XTImgTextBtn *)creatImgTextBtnWithName:(NSString *)name {
    XTImgTextBtn *btn = [XTImgTextBtn buttonWithType:UIButtonTypeCustom];
    [btn setImage:[UIImage imageNamed:@"unSelectRadio"]  forState:UIControlStateNormal];
    [btn setImage:[UIImage imageNamed:@"selectRadio"] forState:UIControlStateSelected];
    [btn setTitle:[NSString stringWithFormat:@" %@",name] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14.0];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    return btn;
}

@end
