//
//  SLImageClipController.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//



#import "SLImageClipController.h"
#import "SLImageZoomView.h"
#import "SLGridView.h"
#import "UIView+SLImage.h"
#import "UIView+SLFrame.h"
#import "UtilsMacros.h"
#import "XTPhotoResampler.h"
#import "XTMBManager.h"

#define KBottomMenuHeight 100  //底部菜单高度
#define KGridTopMargin 40  //顶部间距
#define KGridBottomMargin 20  //底部间距
#define KGridLRMargin 20   //左右边距

@interface SLImageClipController ()<UIScrollViewDelegate, SLGridViewDelegate, SLImageZoomViewDelegate>

// 缩放视图
@property (nonatomic, strong) SLImageZoomView   *zoomView;
//网格视图 裁剪框
@property (nonatomic, strong) SLGridView        *gridView;

//原始位置区域
@property (nonatomic, assign) CGRect originalRect;
//原始contentSize
@property (nonatomic, assign) CGSize originalContentSize;
//图片尺寸大于zoomview网格时的x轴偏移量
@property (nonatomic, assign) CGFloat innerOffsetX;
//图片尺寸大于zoomview网格时的y轴偏移量
@property (nonatomic, assign) CGFloat innerOffsetY;
//zoomview尺寸小于外部视图显示区域时的外部y轴偏移量
@property (nonatomic, assign) CGFloat marginOffsetY;
/// 最大裁剪区域
@property (nonatomic, assign) CGRect maxGridRect;

/// 裁剪区域
//@property (nonatomic, assign) CGRect clipRect;

/// 当前旋转角度
@property (nonatomic, assign) NSInteger rotateAngle;
/// 图像方向
@property (nonatomic, assign) UIImageOrientation imageOrientation;

@property (nonatomic, strong) UIButton *rotateBtn;  //旋转操作
@property (nonatomic, strong) UIButton *cancelClipBtn; //取消操作
@property (nonatomic, strong) UIButton *recoveryBtn; //还原
@property (nonatomic, strong) UIButton *doneClipBtn;  //保存操作
@end

@implementation SLImageClipController

#pragma mark - Override
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setupUI];
}
- (BOOL)prefersStatusBarHidden {
    return YES;
}
- (void)dealloc {
    NSLog(@"SLImageClipController dealloc");
}
#pragma mark - UI
- (void)setupUI {
    //网格最大尺寸,边距+底部按钮高度
//    self.maxGridRect = CGRectMake(KGridLRMargin, KGridTopMargin, self.view.sl_width - KGridLRMargin * 2, self.view.sl_height - KGridTopMargin - KGridBottomMargin- KBottomMenuHeight);
    //图片显示区域的最大宽度 = 视图宽度 - 左右边距
    CGFloat maxViewWidth = self.view.sl_width - KGridLRMargin * 2;
    //图片显示区域的最大高度 = 视图高度 - 上下边距 - 菜单栏高度
    CGFloat maxViewHeight = self.view.sl_height - KGridTopMargin - KGridBottomMargin- KBottomMenuHeight;
    
    //调整后的图片尺寸,图片撑满屏幕宽度，等比例缩放高度
    CGFloat imageNewWidth = maxViewWidth;
    CGFloat imageNewHeight = imageNewWidth*self.image.size.height/self.image.size.width;
//    //如果调整后的图片高度大于显示区域最大高度，则高度调整为显示区域最大高度，宽度等比例缩小
//    if(imageNewWidth > maxViewHeight){
//        imageNewHeight = maxViewHeight;
//        imageNewWidth = imageNewHeight*self.image.size.width/self.image.size.height;
//    }
    
    //网格最大尺寸，按显示屏缩放，宽度撑满
    CGFloat maxGridWidth = imageNewWidth;
    CGFloat maxGridHeight = maxGridWidth*_deviceConfig.screenHeight/_deviceConfig.screenWidth;
    
    //zoomview尺寸小于外部视图显示区域时的外部偏移量
    _marginOffsetY = (maxViewHeight - maxGridHeight)/2.0;
    if(_marginOffsetY < 0){
        _marginOffsetY = 0;
    }
    
    if (!_zoomView) {
        //加载图片的view，可手势缩放，底色为黑色
        _zoomView = [[SLImageZoomView alloc] initWithFrame:CGRectMake(KGridLRMargin, KGridTopMargin+_marginOffsetY, maxGridWidth, maxGridHeight)];
        _zoomView.image = self.image;
        _zoomView.backgroundColor = [UIColor blackColor];
        _zoomView.zoomViewDelegate = self;
        CGFloat scale = maxGridHeight / imageNewHeight;
        if(scale > 1){
            imageNewWidth = imageNewWidth*scale;
            imageNewHeight = imageNewHeight*scale;
        }
        
        //图片尺寸大于zoomview网格时的x轴偏移量
        _innerOffsetX = (imageNewWidth - maxGridWidth)/2.0;
        if(_innerOffsetX < 0){
            _innerOffsetX = 0;
        }
        
        //图片尺寸大于zoomview网格时的y轴偏移量
        _innerOffsetY = (imageNewHeight - maxGridHeight)/2.0;
        if(_innerOffsetY < 0){
            _innerOffsetY = 0;
        }
        _zoomView.contentSize = CGSizeMake(imageNewWidth, imageNewHeight);
        self.originalContentSize = _zoomView.contentSize;
        _zoomView.originalContentSize = _zoomView.contentSize;
        
        //scrollview的子视图会根据contentOffset自动调整位置
        _zoomView.contentOffset = CGPointMake(_innerOffsetX, _innerOffsetY);
        self.zoomView.imageView.frame = CGRectMake(0, 0, imageNewWidth, imageNewHeight);
        
        //关闭弹性滚动
        _zoomView.bounces = NO;
        [self.view addSubview:self.zoomView];
        //原始尺寸，用于恢复还原
        self.originalRect = self.zoomView.frame;
    }
    
    self.maxGridRect = self.zoomView.frame;
    
//    //newSize 图片撑满屏幕宽度，等比例缩放高度
//    CGSize newSize = CGSizeMake(self.view.sl_width - 2 * KGridLRMargin, (self.view.sl_width - 2 * KGridLRMargin)*self.image.size.height/self.image.size.width);
//    //如果newSize高度大于网格最大高度，高度调整为网格最大高度，则宽度等比例缩小
//    if (newSize.height > self.maxGridRect.size.height) {
//        newSize = CGSizeMake(self.maxGridRect.size.height*self.image.size.width/self.image.size.height, self.maxGridRect.size.height);
//        self.zoomView.sl_size = newSize;
//        self.zoomView.sl_y = KGridTopMargin;
//        self.zoomView.sl_centerX = self.view.sl_width/2.0;
//    }else {
//        self.zoomView.sl_size = newSize;
//        self.zoomView.center = CGPointMake(self.view.sl_width/2.0, (self.view.sl_height - KBottomMenuHeight)/2.0);
//    }
    
    if (!_gridView) {
        _gridView = [[SLGridView alloc] initWithFrame:self.view.bounds maxGridRect:self.maxGridRect];
        _gridView.delegate = self;
        //网格初始尺寸
        _gridView.gridRect = self.maxGridRect;
        [self.view addSubview:self.gridView];
    }
    
    
//    [self.view addSubview:self.rotateBtn];
    [self.view addSubview:self.cancelClipBtn];
    [self.view addSubview:self.recoveryBtn];
    [self.view addSubview:self.doneClipBtn];
}

#pragma mark - Getter
//- (SLImageZoomView *)zoomView {
//    if (!_zoomView) {
//        _zoomView = [[SLImageZoomView alloc] initWithFrame:CGRectMake(KGridLRMargin, KGridTopMargin, self.view.sl_width - KGridLRMargin *2,( self.view.sl_width - KGridLRMargin *2)*self.image.size.height/self.image.size.width)];
//        _zoomView.sl_centerY = (self.view.sl_height - KBottomMenuHeight)/2.0;
//        _zoomView.backgroundColor = [UIColor blackColor];
//        _zoomView.zoomViewDelegate = self;
//    }
//    return _zoomView;
//}
//- (SLGridView *)gridView {
//    if (!_gridView) {
//        _gridView = [[SLGridView alloc] initWithFrame:self.view.bounds];
//        _gridView.delegate = self;
//    }
//    return _gridView;
//}
- (UIButton *)rotateBtn {
    if (_rotateBtn == nil) {
        _rotateBtn = [[UIButton alloc] initWithFrame:CGRectMake(30, self.view.sl_height - KBottomMenuHeight, 40, 30)];
        [_rotateBtn setTitle:XTLS(@"XT_rotate") forState:UIControlStateNormal];
        [_rotateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _rotateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_rotateBtn addTarget:self action:@selector(rotateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _rotateBtn;
}
- (UIButton *)cancelClipBtn {
    if (_cancelClipBtn == nil) {
        _cancelClipBtn = [[UIButton alloc] initWithFrame:CGRectMake(30, self.view.sl_height - 30 - 20, 40, 30)];
        [_cancelClipBtn setImage:[UIImage imageNamed:@"EditImageClipCancel"] forState:UIControlStateNormal];
        _cancelClipBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_cancelClipBtn addTarget:self action:@selector(cancelClipClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cancelClipBtn;
}
- (UIButton *)recoveryBtn {
    if (_recoveryBtn == nil) {
        _recoveryBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 30)];
        _recoveryBtn.sl_centerX = self.view.sl_width/2.0;
        _recoveryBtn.sl_centerY = self.cancelClipBtn.center.y;
        [_recoveryBtn setTitle:XTLS(@"XT_Revert") forState:UIControlStateNormal];
        [_recoveryBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _recoveryBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_recoveryBtn addTarget:self action:@selector(recoveryClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _recoveryBtn;
}
- (UIButton *)doneClipBtn {
    if (_doneClipBtn == nil) {
        _doneClipBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.sl_width - 30 - 40, self.view.sl_height - 30 - 20, 40, 30)];
        [_doneClipBtn setImage:[UIImage imageNamed:@"EditImageClipDone"] forState:UIControlStateNormal];
        [_doneClipBtn addTarget:self action:@selector(doneClipClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _doneClipBtn;
}
/// 返回图像方向
- (UIImageOrientation)imageOrientation {
    UIImageOrientation orientation = UIImageOrientationUp;
    switch (_rotateAngle) {
        case 90:
        case -270:
            orientation = UIImageOrientationRight;
            break;
        case -90:
        case 270:
            orientation = UIImageOrientationLeft;
            break;
        case 180:
        case -180:
            orientation = UIImageOrientationDown;
            break;
        default:
            break;
    }
    _imageOrientation = orientation;
    return orientation;
}
#pragma mark - HelpMethods
// 放大zoomView区域到指定网格gridRect区域
- (void)zoomInToRect:(CGRect)gridRect{
//    // 正在拖拽或减速
//    if (self.zoomView.dragging || self.zoomView.decelerating) {
//        return;
//    }
//
//    CGRect imageRect = [self.zoomView convertRect:self.zoomView.imageView.frame toView:self.view];
//    //当网格往图片边缘(x/y轴方向)移动即将出图片边界时，调整self.zoomView.contentOffset和缩放zoomView大小，把网格外的图片区域逐步移到网格内
//    if (!CGRectContainsRect(imageRect,gridRect)) {
//        NSLog(@"超出图片边缘");
//        CGPoint contentOffset = self.zoomView.contentOffset;
//        if (self.imageOrientation == UIImageOrientationRight) {
//            if (CGRectGetMaxX(gridRect) > CGRectGetMaxX(imageRect)) contentOffset.y = 0;
//            if (CGRectGetMinY(gridRect) < CGRectGetMinY(imageRect)) contentOffset.x = 0;
//        }
//        if (self.imageOrientation == UIImageOrientationLeft) {
//            if (CGRectGetMinX(gridRect) < CGRectGetMinX(imageRect)) contentOffset.y = 0;
//            if (CGRectGetMaxY(gridRect) > CGRectGetMaxY(imageRect)) contentOffset.x = 0;
//        }
//        if (self.imageOrientation == UIImageOrientationUp) {
//            if (CGRectGetMinY(gridRect) < CGRectGetMinY(imageRect)) contentOffset.y = 0;
//            if (CGRectGetMinX(gridRect) < CGRectGetMinX(imageRect)) contentOffset.x = 0;
//        }
//        if (self.imageOrientation == UIImageOrientationDown) {
//            if (CGRectGetMaxY(gridRect) > CGRectGetMaxY(imageRect)) contentOffset.y = 0;
//            if (CGRectGetMaxX(gridRect) > CGRectGetMaxX(imageRect)) contentOffset.x = 0;
//        }
//        self.zoomView.contentOffset = contentOffset;
//
////        * 取最大值缩放
//        CGRect myFrame = self.zoomView.frame;
//        myFrame.origin.x = MIN(myFrame.origin.x, gridRect.origin.x);
//        myFrame.origin.y = MIN(myFrame.origin.y, gridRect.origin.y);
//        myFrame.size.width = MAX(myFrame.size.width, gridRect.size.width);
//        myFrame.size.height = MAX(myFrame.size.height, gridRect.size.height);
//        self.zoomView.frame = myFrame;
//
//        [self resetMinimumZoomScale];
//        [self.zoomView setZoomScale:self.zoomView.zoomScale];
//    }
}
//重置最小缩放系数  只要改变了zoomView大小就重置
- (void)resetMinimumZoomScale {
    CGRect rotateoriginalRect = CGRectApplyAffineTransform(self.originalRect, self.zoomView.transform);
    if (CGSizeEqualToSize(rotateoriginalRect.size, CGSizeZero)) {
        /** size为0时候不能继续，否则minimumZoomScale=+Inf，会无法缩放 */
        return;
    }
    //设置最小缩放系数
    CGFloat zoomScale = MAX(CGRectGetWidth(self.zoomView.frame) / CGRectGetWidth(rotateoriginalRect), CGRectGetHeight(self.zoomView.frame) / CGRectGetHeight(rotateoriginalRect));
    self.zoomView.minimumZoomScale = zoomScale;
}

//获取网格区域在图片上的相对位置
- (CGRect)rectOfGridOnImageByGridRect:(CGRect)cropRect {
    CGRect rect = [self.view convertRect:cropRect toView:self.zoomView.imageView];
    return rect;
}

//保存图片完成后调用的方法
- (void)savedPhotoImage:(UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        NSLog(@"save image failed %@", error.localizedDescription);
    } else {
        NSLog(@"save image success");
    }
}
#pragma mark - EventsHandle
- (void)rotateBtnClicked:(id)sender {
    _rotateAngle = (_rotateAngle+=90)%360;
    CGFloat angleInRadians = 0.0f;
    switch (_rotateAngle) {
        case 90:    angleInRadians = M_PI_2;            break;
        case -90:   angleInRadians = -M_PI_2;           break;
        case 180:   angleInRadians = M_PI;              break;
        case -180:  angleInRadians = -M_PI;             break;
        case 270:   angleInRadians = (M_PI + M_PI_2);   break;
        case -270:  angleInRadians = -(M_PI + M_PI_2);  break;
        default:                                        break;
    }
    //旋转前获得网格框在图片上选择的区域
    CGRect gridRectOfImage = [self rectOfGridOnImageByGridRect:self.gridView.gridRect];
    
    /// 旋转变形
    CGAffineTransform transform = CGAffineTransformRotate(CGAffineTransformIdentity, angleInRadians);
    self.zoomView.transform = transform;
    //transform后，bounds不会变，frame会变
    CGFloat width = CGRectGetWidth(self.zoomView.frame);
    CGFloat height = CGRectGetHeight(self.zoomView.frame);
    //计算旋转之后
    CGSize newSize = CGSizeMake(self.view.sl_width - 2 * KGridLRMargin, (self.view.sl_width - 2 * KGridLRMargin)*height/width);
    if (newSize.height > self.gridView.maxGridRect.size.height) {
        newSize = CGSizeMake(self.gridView.maxGridRect.size.height*width/height, self.gridView.maxGridRect.size.height);
        self.zoomView.sl_size = newSize;
        self.zoomView.sl_y = KGridTopMargin;
        self.zoomView.sl_centerX = self.view.sl_width/2.0;
    }else {
        self.zoomView.sl_size = newSize;
        self.zoomView.center = CGPointMake(self.view.sl_width/2.0, (self.view.sl_height - KBottomMenuHeight)/2.0);
    }
    self.gridView.gridRect = self.zoomView.frame;
    
    //重置最小缩放系数
    [self resetMinimumZoomScale];
    CGFloat scale = MIN(CGRectGetWidth(self.zoomView.frame) / width, CGRectGetHeight(self.zoomView.frame) / height);
    [self.zoomView setZoomScale:self.zoomView.zoomScale * scale];
    // 调整contentOffset
    self.zoomView.contentOffset = CGPointMake(gridRectOfImage.origin.x*self.zoomView.zoomScale, gridRectOfImage.origin.y*self.zoomView.zoomScale);
}
- (void)cancelClipClicked:(id)sender {
    [self dismissViewControllerAnimated:NO completion:nil];
}
//还原
- (void)recoveryClicked:(id)sender {
    self.zoomView.minimumZoomScale = 1;
    self.zoomView.zoomScale = 1;
    self.zoomView.transform = CGAffineTransformIdentity;
    self.zoomView.frame = self.originalRect;
    _zoomView.contentSize = self.originalContentSize;
    self.zoomView.contentOffset = CGPointMake(_innerOffsetX, _innerOffsetY);
    self.gridView.gridRect = self.maxGridRect;
    _rotateAngle = 0;
}
//完成编辑
- (void)doneClipClicked:(id)sender {
    if (!self.doneClipBtn.enabled) return;
    CGRect bounds = self.zoomView.imageView.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) return;
    CGRect crop = [self rectOfGridOnImageByGridRect:_gridView.gridRect];
    CGRect normalized = CGRectMake((crop.origin.x - bounds.origin.x) / bounds.size.width,
                                    (crop.origin.y - bounds.origin.y) / bounds.size.height,
                                    crop.size.width / bounds.size.width, crop.size.height / bounds.size.height);
    UIImage *source = self.image;
    UIImageOrientation orientation = self.imageOrientation;
    self.doneClipBtn.enabled = NO;
    self.cancelClipBtn.enabled = NO;
    self.recoveryBtn.enabled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            // Crop the photo's native pixels; never rasterize the on-screen image view.
            UIImage *cropped = [XTPhotoResampler cropImage:source normalizedRect:normalized orientation:orientation];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.doneClipBtn.enabled = YES;
                self.cancelClipBtn.enabled = YES;
                self.recoveryBtn.enabled = YES;
                if (!cropped) {
                    [XTMBManager showAlertViewWithText:XTLS(@"XT_Convert_Image_Fail") delayHid:1.5];
                    return;
                }
                [self dismissViewControllerAnimated:NO completion:^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"sl_ImageClippingComplete"
                                                                        object:nil userInfo:@{@"image": cropped}];
                }];
            });
        }
    });
}

#pragma mark - SLGridViewDelegate
//开始调整
- (void)gridViewDidBeginResizing:(SLGridView *)gridView {
    CGPoint contentOffset = self.zoomView.contentOffset;
    if (self.zoomView.contentOffset.x < 0) contentOffset.x = 0;
    if (self.zoomView.contentOffset.y < 0) contentOffset.y = 0;
    [self.zoomView setContentOffset:contentOffset animated:NO];
}
//正在调整
- (void)gridViewDidResizing:(SLGridView *)gridView {
    //放大到 >= gridRect
    [self zoomInToRect:gridView.gridRect];
}
// 结束调整
- (void)gridViewDidEndResizing:(SLGridView *)gridView {
    // 调整contentOffset
    CGFloat zoomScale = self.maxGridRect.size.width/gridView.gridRect.size.width;
    //大小无变化, 则不处理
    if(zoomScale==1){
        return;
    }
    //居中
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        //裁剪后的区域相对于gridview的坐标
        CGRect gridRectOfImage = [self rectOfGridOnImageByGridRect:gridView.gridRect];
        CGRect localMaxGridRect = [self rectOfGridOnImageByGridRect:self.maxGridRect];
        //重置最小缩放系数
        [self resetMinimumZoomScale];
        gridView.gridRect = self.maxGridRect;
        [self.zoomView setZoomScale:self.zoomView.zoomScale * zoomScale];
        
        self.zoomView.contentSize = CGSizeMake(self.zoomView.contentSize.width, self.zoomView.contentSize.height+2*self.innerOffsetY);
        //计算放大后的scrollview显示区域偏移量
        self.zoomView.contentOffset = CGPointMake(gridRectOfImage.origin.x*self.zoomView.zoomScale, gridRectOfImage.origin.y*self.zoomView.zoomScale-localMaxGridRect.origin.y+self.innerOffsetY);
    } completion:^(BOOL finished) {

    }];
}

#pragma mark - SLZoomViewDelegate
- (void)zoomViewDidBeginMoveImage:(SLImageZoomView *)zoomView {
    self.gridView.showMaskLayer = NO;
}
- (void)zoomViewDidEndMoveImage:(SLImageZoomView *)zoomView {
    self.gridView.showMaskLayer = YES;
}

@end
