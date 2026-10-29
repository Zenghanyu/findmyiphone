#import "NFCTagObject.h"
#import "XTCommonUtils.h"
#import "UtilsMacros.h"

@interface NFCTagObject()

@end

@implementation NFCTagObject

- (instancetype)initWithTag:(id<NFCTag>) tag {
    if (self = [super init]) {
        self.tag = tag;
    }
    return self;
}

- (NSString *)writeNFCString:(NSString *)content code:(NSInteger *)code errMsg:(NSString **)errMsg{
    __block NSString *resultCmd = nil;
    __block NSString *errorMsg = nil;
    *code = BT_OPERATION_FAILED;
    NSData *cmdData = [XTCommonUtils convertHexStringToData:content];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if(self.tag.type == NFCTagTypeISO7816Compatible){
        __block id<NFCISO7816Tag> blockTag = (id<NFCISO7816Tag>)_tag;
        NFCISO7816APDU *apduData = [[NFCISO7816APDU alloc]initWithData:cmdData];
        [blockTag sendCommandAPDU:apduData
            completionHandler:^(NSData *response, uint8_t sw1, uint8_t sw2, NSError *error){
                if(error != nil){
                    *code = error.code;
                    errorMsg = error.domain;
                    NSLog(@"write data error, data:%@ info:%@", content, error.domain);
                }
                else{
                    resultCmd = [XTCommonUtils convertDataToHexString:response];
                    resultCmd = [NSString stringWithFormat:@"%@%@%@", resultCmd, [XTCommonUtils convertDecimalToHexStringWithDigit:sw1 digit:2], [XTCommonUtils convertDecimalToHexStringWithDigit:sw2 digit:2]];
                    *code = BT_SUCCESS;
                    NSLog(@"send command success, command:%@ data size:%lu response:%@", content, [resultCmd length]/2, resultCmd);
                }
                dispatch_semaphore_signal(sem);
            }];
    } else{
        dispatch_semaphore_signal(sem);
    }
    //等待信号
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    *errMsg = errorMsg;
    return resultCmd;
}

- (NSString *)writeNFCData:(NSData *)content code:(NSInteger *)code errMsg:(NSString **)errMsg{
    __block NSString *resultCmd = nil;
    __block NSString *errorMsg = nil;
    *code = BT_OPERATION_FAILED;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if(self.tag.type == NFCTagTypeISO7816Compatible){
        __block id<NFCISO7816Tag> blockTag = (id<NFCISO7816Tag>)_tag;
        NFCISO7816APDU *apduData = [[NFCISO7816APDU alloc]initWithData:content];
        [blockTag sendCommandAPDU:apduData
            completionHandler:^(NSData *response, uint8_t sw1, uint8_t sw2, NSError *error){
                if(error != nil){
                    *code = error.code;
                    errorMsg = error.domain;
                    NSLog(@"write data error, data:%@ info:%@", content, error.domain);
                }
                else{
                    resultCmd = [XTCommonUtils convertDataToHexString:response];
                    resultCmd = [NSString stringWithFormat:@"%@%@%@", resultCmd, [XTCommonUtils convertDecimalToHexStringWithDigit:sw1 digit:2], [XTCommonUtils convertDecimalToHexStringWithDigit:sw2 digit:2]];
                    *code = BT_SUCCESS;
                    NSLog(@"send command success, command:%@ data size:%lu response:%@", content, [resultCmd length]/2, resultCmd);
                }
                dispatch_semaphore_signal(sem);
            }];
    }
    else{
        dispatch_semaphore_signal(sem);
    }
    //等待信号
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    *errMsg = errorMsg;
    return resultCmd;
}

@end
