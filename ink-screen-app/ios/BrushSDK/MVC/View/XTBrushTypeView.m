//
//  XTBrushTypeView.m
//  PaperVersion
//
//  Created by XTMacMini on 2025/3/24.
//

#import "XTBrushTypeView.h"
#import "UtilsMacros.h"
#import "Masonry.h"

@interface XTBrushTypeView ()

@property(nonatomic, strong) UILabel        *titleL;

@property(nonatomic, strong) UIImageView    *selectImgView;

@end

@implementation XTBrushTypeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self creatUI];
        [self layoutUI];
        self.backgroundColor = [UIColor whiteColor];
        [self setRoundedCornersWithRadius:10 borderWidth:0.5 borderColor:XTCOLOR(0xDCDCDC)];
    }
    return self;
}

- (void)creatUI {
    [self addSubview:self.titleL];
    [self addSubview:self.selectImgView];
}

- (void)layoutUI {
    [_titleL makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.centerX);
        make.centerY.equalTo(self);
    }];
    
    [_selectImgView makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_titleL);
        make.width.height.equalTo(16);
        make.right.equalTo(_titleL.left).offset(-20);
    }];
}

#pragma mark - setter/getter
- (void)setSelected:(BOOL)selected {
    _selected = selected;
    _selectImgView.image = _selected ? [UIImage imageNamed:@"select_selected"] : [UIImage imageNamed:@"select_nor"];
}

- (void)setTitle:(NSString *)title {
    _title = title;
    _titleL.text = title;
}

#pragma mark - methods

#pragma mark - lazyload
- (UILabel *)titleL {
    if (!_titleL) {
        _titleL = [[UILabel alloc] init];
        _titleL.textColor = XTCOLOR(0x444444);
        _titleL.font = XTPFRegularFont(14);
    }
    return _titleL;
}

- (UIImageView *)selectImgView {
    if (!_selectImgView) {
        _selectImgView = [[UIImageView alloc] init];
        _selectImgView.image = [UIImage imageNamed:@"select_nor"];
    }
    return _selectImgView;
}

@end
