#import "XTCommonUtils.h"
#import "sys/utsname.h"
#import "UtilsMacros.h"
#import "XTEnum.h"

@interface XTCommonUtils()

@end

@implementation XTCommonUtils

/**
 *  将十六进制字符串转换为NSMutableData对象。
 *
 *  @param hexString 要转换的十六进制字符串。
 *  @return 转换后的NSMutableData对象，如果转换失败可能返回nil。
 */
+ (NSMutableData *)convertHexStringToData:(NSString *)hexString {
    if (!hexString || [hexString length] == 0) {
        return nil;
    }
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([hexString length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [hexString length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [hexString substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    
    //   FMLog(@"hexdata: %@", hexData);
    return hexData;
}

/**
 *  将NSData对象转换为十六进制字符串。
 *
 *  @param data 要转换的NSData对象。
 *  @return 转换后的十六进制字符串，如果输入为nil则可能返回空字符串。
 */
+ (NSString *)convertDataToHexString:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    return [string uppercaseString];
}

+ (NSString *)convertDataToHexStringWithSpace:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *hexString = [[NSMutableString alloc] initWithCapacity:[data length] * 3];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char *)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *singleByteHex = [NSString stringWithFormat:@"%02x", dataBytes[i] & 0xff];
            [hexString appendFormat:@"%@ ", singleByteHex];
        }
    }];
    
    // 修复：用 setString: 修改可变字符串内容，避免类型不兼容
    if ([hexString length] > 0) {
        NSString *trimmedString = [hexString substringToIndex:[hexString length] - 1];
        [hexString setString:trimmedString];
    }
    
    return [hexString uppercaseString];
}

/**
 *  将十进制数的字符串表示转换为二进制数的字符串表示。
 *
 *  @param decimal 十进制数的字符串表示。
 *  @return 对应的二进制数的字符串表示，如果输入不合法可能返回空字符串。
 */
+ (NSString *)convertDecimalStringToBinaryString:(NSString *)decimal {
    NSInteger num = [decimal intValue];
    NSInteger remainder = 0;      //余数
    NSInteger divisor = 0;        //除数
    NSString * prepare = @"";
    
    while (true) {
        remainder = num%2;
        divisor = num/2;
        num = divisor;
        prepare = [prepare stringByAppendingFormat:@"%ld",remainder];
        if (divisor == 0) {
            break;
        }
    }
    NSString * result = @"";
    for (NSInteger i = prepare.length - 1; i >= 0; i --){
        result = [result stringByAppendingFormat:@"%@",
                  [prepare substringWithRange:NSMakeRange(i , 1)]];
    }
    return result;
}

/**
 *  将二进制数的字符串表示转换为十进制数的字符串表示。
 *
 *  @param binary 二进制数的字符串表示。
 *  @return 对应的十进制数的字符串表示，如果输入不合法可能返回空字符串。
 */
+ (NSString *)convertBinaryStringToDecimalString:(NSString *)binary {
    NSInteger ll = 0 ;
    NSInteger  temp = 0 ;
    for (NSInteger i = 0; i < binary.length; i ++){
        temp = [[binary substringWithRange:NSMakeRange(i, 1)] intValue];
        temp = temp * powf(2, binary.length - i - 1);
        ll += temp;
    }
    NSString * result = [NSString stringWithFormat:@"%ld",ll];
    return result;
}

/**
 *  将整数转换为NSString类型的字符串。
 *
 *  @param integer 要转换的整数。
 *  @return 转换后的字符串表示。
 */
+ (NSString *)convertIntToString:(int)integer {
   return  [NSString stringWithFormat:@"%d",integer];
}

/**
 *  将浮点数转换为NSString类型的字符串。
 *
 *  @param floatNumber 要转换的浮点数。
 *  @return 转换后的字符串表示。
 */
+ (NSString *)convertFloatToString:(float)floatNumber {
   return [NSString stringWithFormat:@"%f",floatNumber];
}

/**
 *  将NSString类型的字符串转换为整数。
 *
 *  @param string 要转换的字符串。
 *  @return 转换后的整数，如果转换失败可能返回0。
 */
+ (int)convertStringToInt:(NSString *)string {
   return [string intValue];
}

/**
 *  对输入的十六进制字符串逐位取反。
 *
 *  @param hexString 要取反的十六进制字符串。
 *  @return 取反后的十六进制字符串，如果输入不合法可能返回原字符串。
 */
+ (NSString *)invertHexadecimalString:(NSString *)hexString {
    if (!hexString || [hexString length] == 0) {
        return nil;
    }
    NSString *resultStr = @"";
    NSRange range;
    if ([hexString length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [hexString length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [hexString substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        
        Byte invertChar = ~(Byte)anInt;
        resultStr = [NSString stringWithFormat:@"%@%X", resultStr, invertChar];
        range.location += range.length;
        range.length = 2;
    }
    return resultStr;
}

/**
 *  把十进制整数转换为指定位数的十六进制字符串。
 *
 *  @param decimal 十进制整数。
 *  @param digit 要求的十六进制字符串位数。
 *  @return 转换后的十六进制字符串，如果位数不足会在前面补0。
 */
+ (NSString *)convertDecimalToHexStringWithDigit:(NSInteger)decimal digit:(NSInteger)digit  {
    NSString *hex = @"";
    NSString *letter;
    NSInteger number;
    BOOL isFinished = NO;
    while (!isFinished)
    {
        number = decimal % 16;
        decimal = decimal / 16;
        switch (number) {
                
            case 10:
                letter =@"A"; break;
            case 11:
                letter =@"B"; break;
            case 12:
                letter =@"C"; break;
            case 13:
                letter =@"D"; break;
            case 14:
                letter =@"E"; break;
            case 15:
                letter =@"F"; break;
            default:
                letter = [NSString stringWithFormat:@"%ld", number];
        }
        hex = [letter stringByAppendingString:hex];
        if (decimal == 0) {
            isFinished = YES;
        }
    }
    NSInteger fillCount = digit - hex.length;
    if(fillCount>0){
        for(int i=0;i<fillCount;i++){
            hex = [NSString stringWithFormat:@"0%@", hex];
        }
    }
    return hex;
}

// 大端与小端互转，仅限两字节
/**
 *  对两字节长度的十六进制字符串进行大端和小端的转换。
 *
 *  @param hexSource 两字节的十六进制字符串。
 *  @return 转换后的十六进制字符串，如果输入长度不是4则返回原字符串。
 */
+ (NSString *)revertTwoBytesHexString:(NSString *)hexSource {
    // 检查输入是否为有效的十六进制字符串
    NSCharacterSet *hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    NSString *trimmedString = [hexSource stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedString rangeOfCharacterFromSet:[hexCharacterSet invertedSet]].location != NSNotFound) {
        // 输入包含非十六进制字符，抛出异常
        @throw [NSException exceptionWithName:@"InvalidHexStringException" reason:@"输入的字符串包含非十六进制字符" userInfo:nil];
    }
    
    // 检查字符串长度是否为 4
    if (trimmedString.length == 4) {
        // 交换前后两部分
        return [NSString stringWithFormat:@"%@%@", [trimmedString substringWithRange:NSMakeRange(2, 2)], [trimmedString substringWithRange:NSMakeRange(0, 2)]];
    } else {
        // 长度不是 4，返回原字符串
        return trimmedString;
    }
}

/**
 *  将单个十六进制字符转换为对应的十进制数值的字符串表示。
 *
 *  @param hexChar 十六进制字符。
 *  @return 对应的十进制数值的字符串表示，如果输入不是合法十六进制字符可能返回错误信息。
 */
+ (NSString *)convertHexCharToDecimalString:(unichar)hexChar {
    switch (hexChar) {
        case '0':
            return @"0";
        case '1':
            return @"1";
        case '2':
            return @"2";
        case '3':
            return @"3";
        case '4':
            return @"4";
        case '5':
            return @"5";
        case '6':
            return @"6";
        case '7':
            return @"7";
        case '8':
            return @"8";
        case '9':
            return @"9";
        case 'a':
            return @"10";
        case 'b':
            return @"11";
        case 'c':
            return @"12";
        case 'd':
            return @"13";
        case 'e':
            return @"14";
        case 'f':
            return @"15";
        default:
            return @"0";
    }
}

/**
 *  将NSNumber对象转换为int类型的数值。
 *
 *  @param number 要转换的NSNumber对象。
 *  @return 转换后的int类型数值。
 */
+ (int)convertNumberToInt:(NSNumber *)number
{
    return [number intValue];
}

/**
 *  将包含数值的可变数组转换为对应的十六进制字符串。
 *
 *  @param array 包含数值的可变数组。
 *  @return 转换后的十六进制字符串，如果数组为空可能返回空字符串。
 */
+ (NSString *)convertArrayToHexString:(NSMutableArray *)array {
    NSString *strResult = [NSString new];
    for (int i = 0; i < array.count; i++) {
        NSString *hexStr = [NSString stringWithFormat:@"%x", [XTCommonUtils convertNumberToInt:(array[i])] & 0xff];
//        NSString *temp = [NSString new];
        if ([hexStr length] == 2) {
            strResult = [NSString stringWithFormat:@"%@%@", strResult, hexStr];
        } else {
            hexStr = [NSString stringWithFormat:@"%@%@", @"0", hexStr];
            strResult = [NSString stringWithFormat:@"%@%@", strResult, hexStr];
        }
    }
    return [strResult uppercaseString];
}

/**
 *  将十六进制字符串表示的数转换为对应的十进制NSInteger类型的数值。
 *
 *  @param hexString 十六进制字符串。
 *  @return 对应的十进制数值，如果转换失败可能返回0。
 */
+ (NSInteger)convertHexStringToDecimal:(NSString *)hexString {
    const char *hexChar = [hexString cStringUsingEncoding:NSUTF8StringEncoding];
    int hexNumber;
    sscanf(hexChar, "%x", &hexNumber);
    return (NSInteger)hexNumber;
}

/**
 *  获取当前时间的时间戳，单位为秒，以字符串形式返回。
 *
 *  @return 当前时间的时间戳字符串。
 */
+ (NSString *)getCurrentTimestampInSeconds {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init] ;
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    //设置你想要的格式,hh与HH的区别:分别表示12小时制,24小时制
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    //设置时区,这个对于时间的处理有时很重要
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"Asia/Beijing"];
    [formatter setTimeZone:timeZone];
    //现在时间,你可以输出来看下是什么格式
    NSDate *datenow = [NSDate date];
    NSString *timeSp = [NSString stringWithFormat:@"%ld", (long)[datenow timeIntervalSince1970]];
    return timeSp;
}

/**
 *  把指定格式的时间字符串转换为对应的时间戳（秒数）。
 *
 *  @param formattedTime 时间字符串。
 *  @param format 时间字符串的格式，如 "yyyy-MM-dd HH:mm:ss"。
 *  @return 对应的时间戳，如果转换失败可能返回0。
 */
+ (NSInteger)convertFormattedTimeToTimestamp:(NSString *)formattedTime andFormatter:(NSString *)format
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:format];
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"Asia/Beijing"];
    [formatter setTimeZone:timeZone];
    NSDate* date = [formatter dateFromString:format];
    //时间转时间戳的方法:
    NSInteger timeSp = [[NSNumber numberWithDouble:[date timeIntervalSince1970]] integerValue];
    //时间戳的值
    return timeSp;
}

/**
 *  将时间戳（秒数）转换为指定格式的时间字符串。
 *
 *  @param timestamp 时间戳（秒数）。
 *  @param format 要转换的时间格式，如 "yyyy-MM-dd HH:mm:ss"。
 *  @return 转换后的时间字符串，如果转换失败可能返回空字符串。
 */
+ (NSString *)convertTimestampToFormattedTime:(NSInteger)timestamp andFormatter:(NSString *)format
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:format];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"Asia/Beijing"];
    [formatter setTimeZone:timeZone];
    NSDate *confromTimesp = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSString *confromTimespStr = [formatter stringFromDate:confromTimesp];
    return confromTimespStr;
}

/**
 *  在数组中查找与指定文本相等的元素，并返回其索引。
 *
 *  @param array 要查找的数组。
 *  @param text 要查找的文本。
 *  @return 元素的索引，如果未找到则返回NSNotFound。
 */
+ (NSInteger)getIndexInArray:(NSArray *)array forText:(NSString *)text {
    NSInteger result = 0;
    NSString *itemStr;
    for(int i=0;i<array.count;i++){
        itemStr = [array objectAtIndex:i];
        if([itemStr isEqualToString:text]){
            result = i;
        }
    }
    return result;
}

#pragma mark - 数据填充
/**
 *  数据填充方法，将输入数据复制到缓冲区。
 *
 *  @param data 输入数据。
 *  @param length 输入数据的长度。
 *  @param buffer 目标缓冲区。
 *  @return 填充后的数据长度。
 */
+ (uint32_t)fillData:(uint8_t *)data length:(uint32_t)length buffer:(uint8_t *)buffer
{
    uint8_t lrc;
    uint32_t i, l, t;
    
    l = 0;
    buffer[l++] = length>>8;
    buffer[l++] = length;
    memcpy(buffer+2, data, length);
    l += length;
    lrc = 0;
    for(i=0; i<l; i++)
        lrc ^= buffer[i];
    lrc ^= 0xff;
    buffer[l++] = lrc;
    t = (l+15)/16*16;    // 返回数据长度
    buffer[l++] = 0x80;
    if(l>=t)
        return t;
    while(1)
    {
        buffer[l++] = 0;
        if(l==t)
            return t;
    }
}

#pragma mark - 二进制异或
/**
 *  对两个NSData对象进行按位异或操作。
 *
 *  @param sourceData 源数据。
 *  @param xorData 用于异或的数据。
 *  @return 异或后的NSData对象，如果输入长度不一致可能返回nil。
 */
+ (NSData *)performXorOnData:(NSData *)sourceData withXorData:(NSData *)xorData
{
    NSMutableData *outData = [NSMutableData dataWithCapacity:0];
    
    for (int i = 0; i < [sourceData length]; i++) {
        char *srcChar = (char *)[sourceData bytes];
        char *xorChar = (char *)[xorData bytes];
        
        Byte byte = srcChar[i] ^ xorChar[i];
        
        [outData appendBytes:&byte length:1];
    }
    return outData;
}

/**
 *  判断当前设备是否为iPhone X系列机型。
 *
 *  @return 如果是iPhone X系列机型返回YES，否则返回NO。
 */
+ (BOOL)isIPhoneXSeries {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machineType = [NSString stringWithFormat:@"%s", systemInfo.machine];
    //3是国行/日行，5是美版，全球版
    if([machineType isEqualToString:@"iPhone10,3"]||[machineType isEqualToString:@"iPhone10,6"]){
        return YES;
    } else{
        return NO;
    }
}

/**
 *  根据输入的代码返回对应的屏幕颜色的字符串表示。
 *
 *  @param code 颜色代码。
 *  @return 对应的屏幕颜色字符串，如果代码无匹配可能返回空字符串。
 */
+ (NSString *)getScreenColorByCode:(NSString *)code {
    NSString *screenColor = XTLS(@"XT_C_UNKOWN");
    if([code isEqualToString:COLOR_BW_CODE]){
        screenColor = XTLS(@"XT_C_BW");
    }
    else if([code isEqualToString:COLOR_BWR_CODE]){
        screenColor = XTLS(@"XT_C_BWR");
    }
    else if([code isEqualToString:COLOR_BWY_CODE]){
        screenColor = XTLS(@"XT_C_BWY");
    }
    else if([code isEqualToString:COLOR_BWRY_CODE]){
        screenColor = XTLS(@"XT_C_BWRY");
    }
    else if([code isEqualToString:COLOR_BWRYGB_CODE]){
        screenColor = XTLS(@"XT_C_BWRYGB");
    }
    return screenColor;
}

/**
 *  根据输入的代码返回对应的厂商名称。
 *
 *  @param code 厂商代码。
 *  @return 对应的厂商名称，如果代码无匹配可能返回空字符串。
 */
+(NSString *)getManufacturerNameByCode:(NSString *)code {
    NSString *manufacturerName = XTLS(@"XT_OTHER");
    if([code isEqualToString:@"00"]){
        manufacturerName = XTLS(@"XT_JIAXIAN");
    }
    else if([code isEqualToString:@"10"]){
        manufacturerName = XTLS(@"XT_YUANTAI");
    }
    else if([code isEqualToString:@"20"]){
        manufacturerName = XTLS(@"XT_AOYI");
    }
    else if([code isEqualToString:@"30"]){
        manufacturerName = XTLS(@"XT_WEIFENG");
    }
    else if([code isEqualToString:@"40"]){
        manufacturerName = XTLS(@"XT_PDI");
    }
    else if([code isEqualToString:@"60"]){
        manufacturerName = XTLS(@"XT_JINGDONGFANG");
    }
    else if([code isEqualToString:@"70"]){
        manufacturerName = XTLS(@"XT_DKE");
    }
    else if([code isEqualToString:@"80"]){
        manufacturerName = XTLS(@"XT_WEIXINNUO");
    }
    return manufacturerName;
}

@end
