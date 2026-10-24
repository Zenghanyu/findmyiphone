//
//  SLGridView.h
//
//  Created by wsl on 2019/10/27.
//  Copyright © 2019 wsl. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SLGridView;

/**
 网格视图尺寸调整代理协议
 提供网格拖拽调整过程中的生命周期回调方法
 Grid View Resize Delegate Protocol
 Provide lifecycle callback methods during grid drag resize process
 */
@protocol SLGridViewDelegate <NSObject>
@optional

/// 开始调整网格大小（拖拽开始） | Start resizing grid view (drag begin)
- (void)gridViewDidBeginResizing:(SLGridView *)gridView;

/// 正在调整网格大小（拖拽中） | Resizing grid view (dragging)
- (void)gridViewDidResizing:(SLGridView *)gridView;

/// 结束调整网格大小（拖拽结束） | End resizing grid view (drag end)
- (void)gridViewDidEndResizing:(SLGridView *)gridView;

@end

/**
 图片裁剪专用网格视图
 核心功能：提供可拖拽缩放的裁剪网格框、尺寸边界限制、遮罩层展示，适配图片裁剪场景的网格调整能力
 Special Grid View For Image Cropping
 Core Function: Provide draggable & scalable crop grid frame, size boundary limit, mask layer display, adapt grid adjust for image crop scene
 */
@interface SLGridView : UIView

/// 网格裁剪区域 Rect | Grid crop area rect，Default: CGRectInset(self.bounds, 20, 20)
@property (nonatomic, assign) CGRect gridRect;

/// 网格允许缩小的最小尺寸 | Minimum zoom size of grid，Default: CGSizeMake(60, 60)
@property (nonatomic, assign) CGSize minGridSize;

/// 网格允许放大的最大区域 | Maximum zoom area of grid，Default: CGRectInset(self.bounds, 20, 20)
@property (nonatomic, assign) CGRect maxGridRect;

/// 网格初始化原始尺寸 | Grid init original size，Default: CGRectInset(self.bounds, 20, 20).size
@property (nonatomic, assign) CGSize originalGridSize;

/// 网格尺寸调整代理对象 | Grid resize delegate object
@property (nonatomic, weak) id<SLGridViewDelegate> delegate;

/// 是否显示裁剪遮罩层(半透明黑色蒙层) | Whether to show crop mask layer (translucent black)，Default: YES
@property (nonatomic, assign) BOOL showMaskLayer;

/// 是否正在拖动调整网格(只读) | Is dragging to adjust grid (readonly)
@property(nonatomic,assign,readonly) BOOL dragging;

/**
 带最大区域限制的初始化方法
 初始化网格视图并指定最大可调整的网格区域
 Init method with max grid rect limit
 Init grid view and specify the maximum adjustable grid area
 @param frame 视图布局尺寸 | View frame size
 @param maxGridRect 网格最大可调整区域 | Grid maximum adjustable area
 @return 网格视图实例 | Grid view instance
 */
- (instancetype)initWithFrame:(CGRect)frame maxGridRect:(CGRect)maxGridRect;

@end
NS_ASSUME_NONNULL_END
