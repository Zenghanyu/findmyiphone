//
//  XTScreenSpecConfig.m
//  BrushSDK
//
//  Created by XTMacMini on 2026/8/21.
//

#import "XTScreenSpecConfig.h"

@interface XTScreenSpec ()

@property (nonatomic, assign, readwrite) XTScreenSpecNumber number;
@property (nonatomic, copy, readwrite) NSString *titleKey;
@property (nonatomic, assign, readwrite) NSInteger width;
@property (nonatomic, assign, readwrite) NSInteger height;
@property (nonatomic, copy, readwrite) NSString *color;
@property (nonatomic, copy, readwrite, nullable) NSString *photoPanelProfile;
@property (nonatomic, assign, readwrite) ScanType scanType;
@property (nonatomic, assign, readwrite) XTImageDataProcessType imageDataProcessType;
@property (nonatomic, assign, readwrite) BOOL needsFindMyBrushModeSwitch;
@property (nonatomic, assign, readwrite) BOOL antiLostDevice;

@end

/**
 *  @brief 快速创建屏幕规格 | Creates a screen spec in one line.
 *  @discussion
 *  这里保持轻量构造，避免在配置表里出现大量字典key，方便后续新增屏幕。
 *  This keeps the table typed and compact, avoiding dictionary keys scattered in configuration rows.
 */
static XTScreenSpec *XTScreenSpecMake(XTScreenSpecNumber number,
                                      NSString *titleKey,
                                      NSInteger width,
                                      NSInteger height,
                                      NSString *color,
                                      ScanType scanType,
                                      XTImageDataProcessType imageDataProcessType,
                                      BOOL antiLostDevice,
                                      BOOL findMyMode) {
    XTScreenSpec *spec = [[XTScreenSpec alloc] init];
    spec.number = number;
    spec.titleKey = titleKey;
    spec.width = width;
    spec.height = height;
    spec.color = color;
    spec.scanType = scanType;
    spec.imageDataProcessType = imageDataProcessType;
    spec.antiLostDevice = antiLostDevice;
    spec.needsFindMyBrushModeSwitch = findMyMode;
    return spec;
}

@implementation XTScreenSpec

@end

@implementation XTScreenSpecConfig

+ (NSArray<XTScreenSpec *> *)defaultScreenSpecs {
    static NSArray<XTScreenSpec *> *screenSpecs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /*
         *  屏幕配置总表 | Main screen specification table.
         *  新增屏幕时在这里追加一行，并补充对应的中英文XT_Screen_Option_x文案。
         *  To add a new screen, append one row here and add the matching localized XT_Screen_Option_x text.
         */
        screenSpecs = @[
            XTScreenSpecMake(XTScreenSpecNumber154FourColor,         @"XT_Screen_Option_1", 200, 200, @"BWRY",   HorizontalType, XTImageDataProcessTypeDefault,          NO,  NO),
            XTScreenSpecMake(XTScreenSpecNumber154FourColorAntiLost, @"XT_Screen_Option_2", 200, 200, @"BWRY",   HorizontalType, XTImageDataProcessTypeDefault,          YES, NO),
            XTScreenSpecMake(XTScreenSpecNumber154SixColor,          @"XT_Screen_Option_3", 240, 240, @"BWRYGB", HorizontalType, XTImageDataProcessTypeDefault,          NO,  NO),
            XTScreenSpecMake(XTScreenSpecNumber154SixColorAntiLost,  @"XT_Screen_Option_4", 240, 240, @"BWRYGB", HorizontalType, XTImageDataProcessTypeDefault,          YES, NO),
            XTScreenSpecMake(XTScreenSpecNumber169SixColor,          @"XT_Screen_Option_5", 400, 400, @"BWRYGB", HorizontalType, XTImageDataProcessTypeSixColorDualChip, NO,  NO),
            XTScreenSpecMake(XTScreenSpecNumber169SixColorAntiLost,  @"XT_Screen_Option_6", 400, 400, @"BWRYGB", HorizontalType, XTImageDataProcessTypeSixColorDualChip, YES, YES),
            XTScreenSpecMake(XTScreenSpecNumber37SixColor,           @"XT_Screen_Option_7", 480, 720, @"BWRYGB", VerticalType,   XTImageDataProcessTypeDefault,          NO,  NO),
            XTScreenSpecMake(XTScreenSpecNumber589SixColor,          @"XT_Screen_Option_8", 680, 960, @"BWRYGB", HorizontalType, XTImageDataProcessTypeDefault,          NO,  NO),
            XTScreenSpecMake(XTScreenSpecNumber40FourColor,          @"XT_Screen_Option_9", 528, 768, @"BWRY",   VerticalType,   XTImageDataProcessTypeDefault,          NO,  NO),
        ];
        // This project's 1.54-inch six-colour options use the panel supplied by
        // the user. This is an explicit project assignment, not model detection.
        for (XTScreenSpec *spec in screenSpecs) {
            if (spec.number == XTScreenSpecNumber154SixColor || spec.number == XTScreenSpecNumber154SixColorAntiLost) {
                spec.photoPanelProfile = @"HINK-T0154A10-A2";
            }
        }
    });
    return screenSpecs;
}

+ (nullable XTScreenSpec *)screenSpecWithNumber:(XTScreenSpecNumber)number {
    for (XTScreenSpec *screenSpec in [self defaultScreenSpecs]) {
        if (screenSpec.number == number) {
            return screenSpec;
        }
    }
    return nil;
}

@end
