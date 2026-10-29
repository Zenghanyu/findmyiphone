//
//  FMGetDESMac.m
//
//  Created by gaolailong on 2018/4/11.
//

#import "FMGetDESMac.h"
#import "XTCommonUtils.h"

@implementation FMGetDESMac

#pragma mark - 获取DESMAC
+ (NSString *)MacFromDESSrc:(NSString *)src AndKey:(NSString *)key IV:(NSString *)iv
{
    //分块求异或并进行TDES加密的区域块大小
    NSInteger DataFiled = 4;
    
    NSData *sourceData = [self DesWithCCOperation:kCCEncrypt AndCCMode:kCCModeCBC AndCCAlgorithm:kCCAlgorithm3DES AndKey:key andInput:src IV:iv];
    //加密结果最后16字节
    NSData *subData = [sourceData subdataWithRange:NSMakeRange([sourceData length] - 16, 16)];
    //初始向量
    NSRange range = NSMakeRange(0, DataFiled);
    NSData *DataXOr = [subData subdataWithRange:range];
    range.location += range.length;
    range.length = DataFiled;
    
    for (int i = 0; i < 3; i++) {
        
        NSData *temData = [subData subdataWithRange:range];
        range.location += range.length;
        range.length = DataFiled;
        
        //异或操作
        DataXOr = [XTCommonUtils performXorOnData:temData withXorData:DataXOr];
    }
    
    return [XTCommonUtils convertDataToHexString:DataXOr];
}

#pragma mark - ***************************

+ (NSData *)DesWithCCOperation:(CCOperation)operation AndCCMode:(CCMode)mode AndCCAlgorithm:(CCAlgorithm)algorithm AndKey:(NSString *)keyString andInput:(NSString *)inputStr IV:(NSString *)iv
{
    NSData *inputData = [XTCommonUtils convertHexStringToData:inputStr];
    NSData *keyData =[XTCommonUtils convertHexStringToData:keyString];
    
    char *cIv;
    
    if (algorithm == kCCAlgorithm3DES && keyData.length < 24) {
        NSMutableData *keyDataTem = [NSMutableData dataWithData:keyData];
        [keyDataTem appendData:[keyData subdataWithRange:NSMakeRange(0, 8)]];
        keyData = keyDataTem;
    }
    
    CCCryptorRef cryptor = NULL;
    
    uint32_t size;
    switch (algorithm) {
        case kCCAlgorithm3DES:
            size = kCCKeySize3DES;
            break;
        default:
            size = kCCKeySizeDES;
            break;
    }
    switch (mode) {
        case kCCModeCBC:
            cIv = (char *)[[XTCommonUtils convertHexStringToData:iv] bytes];
            break;
        default:
            break;
    }
    
    //创建加密器
    CCCryptorStatus ccret = CCCryptorCreateWithMode(operation, mode, algorithm, ccNoPadding, cIv, [keyData bytes], size, NULL, 0, 0, 0, &cryptor);
    if (ccret != kCCSuccess) {
        NSLog(@"CCCryptorCreateWithMode failed");
        return nil;
    }
    
    size_t buffersize = 0;
    size_t moved = 0;
    size_t total = 0;
    
    //获取最大长度
    buffersize = CCCryptorGetOutputLength(cryptor, [inputData length], true);
    char *buffer = (char *)malloc(buffersize);
    bzero(buffer, buffersize);
    
    //加密
    ccret = CCCryptorUpdate(cryptor, [inputData bytes], [inputData length], buffer, buffersize, &moved);
    
    total += moved;
    if (ccret != kCCSuccess) {
        NSLog(@"CCCryptorUpdate failed");
        return nil;
    }
    
    //处理最后的模块
    ccret = CCCryptorFinal(cryptor, buffer+total, buffersize-total, &moved);
    if (ccret != kCCSuccess) {
        NSLog(@"CCCryptorFinal failed");
        return nil;
    }
    total += moved;
    CCCryptorRelease(cryptor);
    NSData *data = [NSData dataWithBytes:buffer length:total];
    free(buffer);
    return data;
}

@end
