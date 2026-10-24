#import <CoreNFC/CoreNFC.h>

@interface NFCTagObject: NSObject

@property(nonatomic, weak) id<NFCTag> tag;
@property(nonatomic, copy) NSString *tagType;

- (instancetype)initWithTag:(id<NFCTag>) tag;
//发送自定义指令
- (NSString *)writeNFCString:(NSString *)content code:(NSInteger *)code errMsg:(NSString **)errMsg;
- (NSString *)writeNFCData:(NSData *)content code:(NSInteger *)code errMsg:(NSString **)errMsg;
@end
