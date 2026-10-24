//
//  PrismModel.h
//  NewTool
//
//  Created by XTMacMini on 2025/2/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Prism设备效果图详情数据模型
 存储单张Prism效果图的ID、关联ID、排序号、图片资源地址等信息
 Prism Device Effect Image Detail Data Model
 Store single prism effect image's ID, relation ID, sort number, image resource path
 */
@interface PrismDetailModel: NSObject

/// 数据主键ID | Data Primary Key ID
@property (nonatomic, assign) NSInteger     idid;
/// 关联Prism设备ID | Relation Prism Device ID
@property (nonatomic, assign) NSInteger     prismId;
/// 效果图展示排序号 | Effect Image Display Sort Number
@property (nonatomic, assign) NSInteger     sort;
/// 效果图本地资源名称/网络地址 | Effect Image Local Resource Name / Network Url
@property (nonatomic, copy) NSString        *imgUrl;

@end

/**
 Prism设备主数据模型
 存储Prism设备型号、模板地址、描述、效果图列表等核心数据
 Prism Device Main Data Model
 Store prism device number, template path, description, effect image list core data
 */
@interface PrismModel: NSObject

/// Prism设备型号编号(83/89/90/93) | Prism Device Number (83/89/90/93)
@property (nonatomic, assign) NSInteger     deviceNumber;
/// 数据主键ID | Data Primary Key ID
@property (nonatomic, assign) NSInteger     idid;
/// Prism模板图片本地资源名称 | Prism Template Image Local Resource Name
@property (nonatomic, copy) NSString        *mubanUrl;
/// 设备描述信息 | Device Description Info
@property (nonatomic, copy) NSString        *des;
/// Prism效果图详情模型数组 | Prism Effect Image Detail Model Array
@property (nonatomic, strong) NSArray <PrismDetailModel *> *rows;

@end

NS_ASSUME_NONNULL_END
