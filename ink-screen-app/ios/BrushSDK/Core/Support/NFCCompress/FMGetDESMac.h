//
//  FMGetDESMac.h
//
//  Created by gaolailong on 2018/4/11.
//

#import <Foundation/Foundation.h>

#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>


@interface FMGetDESMac : NSObject

#pragma mark - 获取DESMAC
/**
 获取DESMAC
 
 @param src 获取Mac初始数据
 @param key 密钥
 @param iv 初始向量
 @return DESMac
 */
+ (NSString *)MacFromDESSrc:(NSString *)src AndKey:(NSString *)key IV:(NSString *)iv;

/**
 DES加解密
 
 @param operation 加密或解密
 @param mode 加密方式为ECB还是CBC
 @param algorithm 加密方式为TripleDES还是DES
 @param keyString 密钥
 @param inputStr 加密明文数据
 @param iv 初始向量
 @return 密文
 */
+ (NSData *)DesWithCCOperation:(CCOperation)operation AndCCMode:(CCMode)mode AndCCAlgorithm:(CCAlgorithm)algorithm AndKey:(NSString *)keyString andInput:(NSString *)inputStr IV:(NSString *)iv;

@end
