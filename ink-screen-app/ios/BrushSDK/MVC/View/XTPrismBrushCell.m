//
//  NewPrismBrushCell.m
//  BrushSDK
//
//  Created by xthh on 2025/1/15.
//

#import "XTPrismBrushCell.h"
#import "Masonry.h"

@implementation XTPrismBrushCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.contentView.backgroundColor = [UIColor whiteColor];
    [self.contentView addSubview:self.shapeView];
    
    self.contentView.layer.cornerRadius = 10;
    self.contentView.layer.masksToBounds = YES;
    
    [_shapeView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.contentView);
    }];
}

//MARK: Methods
- (void)refreshUIWithdata:(nonnull PrismDetailModel *)model {
    _shapeView.image = [UIImage imageNamed:model.imgUrl];
}

- (void)refreshOldPrsimUIWithdata:(NSString *)imgName {
    _shapeView.image = [UIImage imageNamed:imgName];
}

//MARK: Lazyload
- (UIImageView *)shapeView {
    if (!_shapeView) {
        _shapeView = [[UIImageView alloc] init];
        _shapeView.backgroundColor = [UIColor whiteColor];
    }
    return _shapeView;
}

@end
