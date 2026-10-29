//
//  SLScrollView.h
//
//  Created by wsl on 2019/10/27.
//  Copyright © 2019 wsl. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SLImageZoomView;

/**
 图片缩放视图代理协议
 提供图片拖拽移动过程中的生命周期回调方法
 Image Zoom View Delegate Protocol
 Provide lifecycle callback methods during image drag move process
 */
@protocol SLImageZoomViewDelegate <NSObject>
@optional

/// 开始拖拽移动图片（滑动/拖拽开始） | Start dragging and moving image (scroll/drag begin)
- (void)zoomViewDidBeginMoveImage:(SLImageZoomView *)zoomView;

/// 结束拖拽移动图片（滑动/拖拽结束） | End dragging and moving image (scroll/drag end)
- (void)zoomViewDidEndMoveImage:(SLImageZoomView *)zoomView;

@end

/**
 图片编辑专用缩放视图
 继承UIScrollView实现图片的自由缩放、拖拽移动、适配展示功能，专为图片裁剪/编辑场景封装
 Image Edit Special Zoom View
 Inherit UIScrollView to realize image free zoom, drag move, adapt display, encapsulated for image crop/edit scene
 */
@interface SLImageZoomView : UIScrollView

/// 待编辑展示的原始图片 | Original image for edit and display
@property (nonatomic, strong) UIImage *image;

/// 承载图片的核心展示视图 | Core display view for loading image
@property (nonatomic, strong) UIImageView *imageView;

/// 缩放视图代理对象 | Zoom view delegate object
@property (nonatomic, weak) id<SLImageZoomViewDelegate> zoomViewDelegate;

/// 视图初始化的原始内容尺寸 | Original content size when view initialized
@property (nonatomic, assign) CGSize originalContentSize;

@end

NS_ASSUME_NONNULL_END
