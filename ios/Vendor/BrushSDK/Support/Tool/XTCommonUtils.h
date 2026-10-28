#import <UIKit/UIKit.h>

@interface XTCommonUtils : NSObject

/**
 *  @brief 将十六进制字符串转换为NSMutableData对象 | Convert hex string to NSMutableData object
 *
 *  @param hexString 要转换的十六进制字符串 | Hex string to be converted
 *  @return 转换后的NSMutableData对象，如果转换失败可能返回nil | Converted NSMutableData object, may return nil if conversion fails
 */
+ (NSMutableData *)convertHexStringToData:(NSString *)hexString;

/**
 *  @brief 将NSData对象转换为十六进制字符串 | Convert NSData object to hex string
 *
 *  @param data 要转换的NSData对象 | NSData object to be converted
 *  @return 转换后的十六进制字符串，如果输入为nil则可能返回空字符串 | Converted hex string, may return empty string if input is nil
 */
+ (NSString *)convertDataToHexString:(NSData *)data;

/**
 *  @brief 将NSData对象转换为带空格分隔的十六进制字符串 | Convert NSData object to hex string with space separation
 *
 *  @param data 要转换的NSData对象 | NSData object to be converted
 *  @return 带空格分隔的十六进制字符串，输入为nil则返回空字符串 | Hex string with space separation, return empty string if input is nil
 */
+ (NSString *)convertDataToHexStringWithSpace:(NSData *)data;

/**
 *  @brief 将十进制数的字符串表示转换为二进制数的字符串表示 | Convert decimal string to binary string
 *
 *  @param decimal 十进制数的字符串表示 | String representation of decimal number
 *  @return 对应的二进制数的字符串表示，如果输入不合法可能返回空字符串 | Corresponding binary string, may return empty string if input is invalid
 */
+ (NSString *)convertDecimalStringToBinaryString:(NSString *)decimal;

/**
 *  @brief 将二进制数的字符串表示转换为十进制数的字符串表示 | Convert binary string to decimal string
 *
 *  @param binary 二进制数的字符串表示 | String representation of binary number
 *  @return 对应的十进制数的字符串表示，如果输入不合法可能返回空字符串 | Corresponding decimal string, may return empty string if input is invalid
 */
+ (NSString *)convertBinaryStringToDecimalString:(NSString *)binary;

/**
 *  @brief 将整数转换为NSString类型的字符串 | Convert integer to NSString type string
 *
 *  @param integer 要转换的整数 | Integer to be converted
 *  @return 转换后的字符串表示 | Converted string representation
 */
+ (NSString *)convertIntToString:(int)integer;

/**
 *  @brief 将浮点数转换为NSString类型的字符串 | Convert float number to NSString type string
 *
 *  @param floatNumber 要转换的浮点数 | Float number to be converted
 *  @return 转换后的字符串表示 | Converted string representation
 */
+ (NSString *)convertFloatToString:(float)floatNumber;

/**
 *  @brief 将NSString类型的字符串转换为整数 | Convert NSString type string to integer
 *
 *  @param string 要转换的字符串 | String to be converted
 *  @return 转换后的整数，如果转换失败可能返回0 | Converted integer, may return 0 if conversion fails
 */
+ (int)convertStringToInt:(NSString *)string;

/**
 *  @brief 对输入的十六进制字符串逐位取反 | Invert each bit of the input hex string
 *
 *  @param hexString 要取反的十六进制字符串 | Hex string to be inverted
 *  @return 取反后的十六进制字符串，如果输入不合法可能返回原字符串 | Inverted hex string, may return original string if input is invalid
 */
+ (NSString *)invertHexadecimalString:(NSString *)hexString;

/**
 *  @brief 将十六进制字符串表示的数转换为对应的十进制NSInteger类型的数值 | Convert hex string to decimal NSInteger value
 *
 *  @param hexString 十六进制字符串 | Hex string
 *  @return 对应的十进制数值，如果转换失败可能返回0 | Corresponding decimal value, may return 0 if conversion fails
 */
+ (NSInteger)convertHexStringToDecimal:(NSString *)hexString;

/**
 *  @brief 把十进制整数转换为指定位数的十六进制字符串 | Convert decimal integer to hex string with specified digit count
 *
 *  @param decimal 十进制整数 | Decimal integer
 *  @param digit 要求的十六进制字符串位数 | Required digit count of hex string
 *  @return 转换后的十六进制字符串，如果位数不足会在前面补0 | Converted hex string, pad with 0 in front if digit count is insufficient
 */
+ (NSString *)convertDecimalToHexStringWithDigit:(NSInteger)decimal digit:(NSInteger)digit;

/**
 *  @brief 对两字节长度的十六进制字符串进行大端和小端的转换 | Convert big-endian to little-endian (or vice versa) for 2-byte hex string
 *
 *  @param hexSource 两字节的十六进制字符串（长度为4的十六进制字符串）| 2-byte hex string (hex string with length 4)
 *  @return 转换后的十六进制字符串，如果输入长度不是4则返回原字符串 | Converted hex string, return original string if input length is not 4
 */
+ (NSString *)revertTwoBytesHexString:(NSString *)hexSource;

/**
 *  @brief 将单个十六进制字符转换为对应的十进制数值的字符串表示 | Convert single hex character to decimal string
 *
 *  @param hexChar 十六进制字符（0-9, A-F, a-f）| Hex character (0-9, A-F, a-f)
 *  @return 对应的十进制数值的字符串表示，如果输入不是合法十六进制字符可能返回错误信息 | Corresponding decimal string, may return error info if input is invalid hex character
 */
+ (NSString *)convertHexCharToDecimalString:(unichar)hexChar;

/**
 *  @brief 将NSNumber对象转换为int类型的数值 | Convert NSNumber object to int value
 *
 *  @param number 要转换的NSNumber对象 | NSNumber object to be converted
 *  @return 转换后的int类型数值 | Converted int value
 */
+ (int)convertNumberToInt:(NSNumber *)number;

/**
 *  @brief 将包含数值的可变数组转换为对应的十六进制字符串 | Convert mutable array containing numbers to hex string
 *
 *  @param array 包含数值的可变数组（元素为NSNumber/int/float等数值类型）| Mutable array containing numbers (elements are NSNumber/int/float etc.)
 *  @return 转换后的十六进制字符串，如果数组为空可能返回空字符串 | Converted hex string, may return empty string if array is empty
 */
+ (NSString *)convertArrayToHexString:(NSMutableArray *)array;

/**
 *  @brief 获取当前时间的时间戳，单位为秒，以字符串形式返回 | Get current timestamp in seconds, return as string
 *
 *  @return 当前时间的时间戳字符串 | Current timestamp string (in seconds)
 */
+ (NSString *)getCurrentTimestampInSeconds;

/**
 *  @brief 把指定格式的时间字符串转换为对应的时间戳（秒数）| Convert formatted time string to timestamp (seconds)
 *
 *  @param formattedTime 时间字符串 | Time string
 *  @param format 时间字符串的格式，如 "yyyy-MM-dd HH:mm:ss" | Format of time string, e.g. "yyyy-MM-dd HH:mm:ss"
 *  @return 对应的时间戳，如果转换失败可能返回0 | Corresponding timestamp, may return 0 if conversion fails
 */
+ (NSInteger)convertFormattedTimeToTimestamp:(NSString *)formattedTime andFormatter:(NSString *)format;

/**
 *  @brief 将时间戳（秒数）转换为指定格式的时间字符串 | Convert timestamp (seconds) to formatted time string
 *
 *  @param timestamp 时间戳（秒数）| Timestamp (seconds)
 *  @param format 要转换的时间格式，如 "yyyy-MM-dd HH:mm:ss" | Target time format, e.g. "yyyy-MM-dd HH:mm:ss"
 *  @return 转换后的时间字符串，如果转换失败可能返回空字符串 | Converted time string, may return empty string if conversion fails
 */
+ (NSString *)convertTimestampToFormattedTime:(NSInteger)timestamp andFormatter:(NSString *)format;

/**
 *  @brief 在数组中查找与指定文本相等的元素，并返回其索引 | Find element equal to specified text in array and return its index
 *
 *  @param array 要查找的数组（元素为NSString类型）| Array to search (elements are NSString type)
 *  @param text 要查找的文本 | Text to find
 *  @return 元素的索引，如果未找到则返回NSNotFound | Index of element, return NSNotFound if not found
 */
+ (NSInteger)getIndexInArray:(NSArray *)array forText:(NSString *)text;

/**
 *  @brief 数据填充方法，将输入数据复制到缓冲区 | Data filling method, copy input data to buffer
 *
 *  @param data 输入数据指针 | Input data pointer
 *  @param length 输入数据的长度 | Length of input data
 *  @param buffer 目标缓冲区指针 | Target buffer pointer
 *  @return 填充后的数据长度 | Length of filled data
 */
+ (uint32_t)fillData:(uint8_t *)data length:(uint32_t)length buffer:(uint8_t *)buffer;

#pragma mark - 二进制异或 | Binary XOR
/**
 *  @brief 对两个NSData对象进行按位异或操作 | Perform bitwise XOR operation on two NSData objects
 *
 *  @param sourceData 源数据 | Source data
 *  @param xorData 用于异或的数据 | Data for XOR operation
 *  @return 异或后的NSData对象，如果输入长度不一致可能返回nil | XORed NSData object, may return nil if input lengths are inconsistent
 */
+ (NSData *)performXorOnData:(NSData *)sourceData withXorData:(NSData *)xorData;

/**
 *  @brief 根据输入的代码返回对应的屏幕颜色的字符串表示 | Return corresponding screen color string by input code
 *
 *  @param code 颜色代码 | Color code
 *  @return 对应的屏幕颜色字符串，如果代码无匹配可能返回空字符串 | Corresponding screen color string, may return empty string if no match for code
 */
+ (NSString *)getScreenColorByCode:(NSString *)code;

/**
 *  @brief 判断当前设备是否为iPhone X系列机型（含X/XR/XS/XS Max/11/12/13/14等刘海屏机型）| Judge if current device is iPhone X series (including X/XR/XS/XS Max/11/12/13/14 etc. notch screen models)
 *
 *  @return 如果是iPhone X系列机型返回YES，否则返回NO | Return YES if it's iPhone X series, otherwise NO
 */
+ (BOOL)isIPhoneXSeries;

/**
 *  @brief 根据输入的代码返回对应的厂商名称 | Return corresponding manufacturer name by input code
 *
 *  @param code 厂商代码 | Manufacturer code
 *  @return 对应的厂商名称，如果代码无匹配可能返回空字符串 | Corresponding manufacturer name, may return empty string if no match for code
 */
+ (NSString *)getManufacturerNameByCode:(NSString *)code;

@end
