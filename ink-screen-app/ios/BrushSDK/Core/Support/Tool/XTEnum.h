//
//  XTEnum.h
//  NewTool
//
//  Created by XTMacMini on 2025/3/14.
//

#ifndef XTEnum_h
#define XTEnum_h

/**
 @brief 设备支持的颜色
 */
typedef NS_ENUM(NSUInteger, XTDeviceColorType) {
    BLACK_WHITE                 = 0,        /* 黑白 */
    BLACK_WHITE_YELLOW          = 1,        /* 黑白黄 */
    BLACK_WHITE_RED             = 2,        /* 黑白黄 */
    BLACK_WHITE_RED_YELLOW      = 3,        /* 黑白红黄 */
    N_COLOR                     = 4,        /* 黑白红黄蓝绿橙 7色 */
    E6                          = 5,        /* 黑白红黄蓝绿 6色的，231120要求修改 *///
    NONE                        = 6,
};

/**
 @brief 图像扫描模式
 */
typedef NS_ENUM(NSUInteger, ScanType) {
    HorizontalType          = 0,        //水平扫描
    VerticalType            = 1         //垂直扫描
};

/**
 @brief 图像颜色类型
 */
typedef NS_ENUM(NSUInteger, ColorType) {
    BlackColor              = 0,        //黑色
    WhiteColor              = 1,        //白色
    RedColor                = 2,        //红色
    YellowColor             = 3         //黄色
};

/**
 @brief 图像合成模式
 */
typedef NS_ENUM(NSUInteger, CombineType) {
    SingleType              = 0,        //单图合成模式
    ComplexType             = 1,        //双图合成模式
    Color4Type              = 2,        //旧四色模式
    GeneralType             = 3         //三色以上通用模式
};

/**
 @brief 图像刷图模式
 */
typedef NS_ENUM(NSUInteger, XTBrushType) {
    brushWithNfcAndBle      = 0,        //nfc供电+蓝牙刷图
    brushWithNfc            = 1,        //nfc供电 + nfc刷图
    brushWithBle            = 2,        //蓝牙刷图
};

//像素颜色 //复旦微用
#define COLOR_BW_CODE               @"20"               //黑白
#define COLOR_BWR_CODE              @"30"               //黑白红
#define COLOR_BWY_CODE              @"31"               //黑白黄
#define COLOR_BWRY_CODE             @"40"               //黑白红黄
#define COLOR_BWRYGB_CODE           @"60"               //黑白红黄绿蓝

//ndef指令格式
#define CMD_CODE_LENGTH             4
#define NDEF_SUCCESS                @"9000"                 //apdu执行成功，返回代码
#define REFRESH_POWER_CMD           @"F0D481%@00"           //有源刷新屏幕图像，参数为屏幕序号，从0开始
#define REFRESH_SCREEN_CMD          @"F0D481%@00"           //无源刷新屏幕图像，参数为屏幕序号，从0开始
#define GET_REFRESH_STATUS          @"F0DE000001"           //无源刷新时获取刷频状态
#define GET_CONFIG_INFO_CMD         @"00D1000000"           //获取设备信息
#define CHECK_NEED_PIN_CMD          @"F0D8000005000000000E" //检查是否需要pin码，黑白双色判断是否四色
#define GET_RANDOM_CMD              @"0084000004"           //获取四字节随机数
#define VERIFY_PIN_CMD              @"00200001%@%@"         //验pin
#define GET_CONVERT_INFO            @"00eb000002"           //获取图像的翻转信息

//TLV标签
#define TLV_A0                      @"A0"               //屏幕信息
#define TLV_A1                      @"A1"               //双色三色颜色参数
#define TLV_B1                      @"B1"               //图片存储数量
#define TLV_B2                      @"B2"               //用户数据长度
#define TLV_B3                      @"B3"               //供电模式
#define TLV_C0                      @"C0"               //APPID
#define TLV_C1                      @"C1"               //UUID
#define TLV_D1                      @"D1"               //RFU
#define TLV_E0                      @"E0"               //三色以上颜色配置

#define VALUE_SINGLE_MODE           1                   //单图模式
#define VALUE_COMPLEX_MODE          2                   //双图模式

//数据传输模式
#define PARALLEL_TRANS_MODE         0                   //并行
#define SERIAL_TRANS_MODE           1                   //串行


#define VALUE_BLACK                 0x00                //黑色
#define VALUE_WHITE                 0x01                //白色
#define VALUE_RED                   0x02                //红色
#define VALUE_YELLOW                0x03                //黄色
#define VALUE_ORANGE                0x04                //橙色
#define VALUE_GREEN                 0x05                //绿色
#define VALUE_QING                  0x06                //青色
#define VALUE_BLUE                  0x07                //蓝色
#define VALUE_PURPLE                0x08                //紫色

#define DIC_KEY_BLACK               @"00"               //黑色
#define DIC_KEY_WHITE               @"01"               //白色
#define DIC_KEY_RED                 @"02"               //红色
#define DIC_KEY_YELLOW              @"03"               //黄色
#define DIC_KEY_ORANGE              @"04"               //橙色
#define DIC_KEY_GREEN               @"05"               //绿色
#define DIC_KEY_QING                @"06"               //青色
#define DIC_KEY_BLUE                @"07"               //蓝色
#define DIC_KEY_PURPLE              @"08"               //紫色

#define SCREEN_SIZE_ERROR           @"R0"               //屏幕尺寸错误
#define COLOR_MODE_ERROR            @"R1"               //颜色模式错误
#define SCAN_MODE_ERROR             @"R2"               //扫描模式错误
#define COMBINE_MODE_ERROR          @"R3"               //混合模式错误
#define COLOR_COUNT_ERROR           @"R4"               //颜色数量错误
#define COLOR_VALUE_ERROR           @"R5"               //颜色值错误
#define PIN_CHECK_ERROR             @"R6"               //是否带pin校验错误
#define VERSION_CHECK_ERROR         @"R7"               //版本号校验错误

//颜色代码
#define COLOR_RGB_BLACK             0                   //黑
#define COLOR_RGB_WHITE             1                   //白
#define COLOR_RGB_THIRD             2                   //红或黄

//图像生成算法
#define ALG_TYPE_DITHER     @"1"      // 抖点算法
#define ALG_TYPE_COLOR      @"2"      // 色阶算法

#endif /* XTEnum_h */
