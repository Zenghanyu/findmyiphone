@interface FMCompressUtils : NSObject

//huffman数据压缩
+ (void)FMCompressByHuffman:(unsigned char *)inData inLen:(size_t)inLen outData:(unsigned char *)outData outLen:(size_t *)outLen;

//数据压缩
+ (BOOL)FMCompressData:(unsigned char *)inData inLen:(size_t)inLen outData:(unsigned char *)outData outLen:(size_t *)outLen;

//数据解压缩
+ (BOOL)FMDecompressData:(unsigned char *)inData inLen:(size_t)inLen outData:(unsigned char *)outData outLen:(size_t *)outLen;

@end
