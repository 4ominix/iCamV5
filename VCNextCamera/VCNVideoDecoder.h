// CONFIRMED FROM BINARY: VTDecompressionSessionCreate, VTDecompressionSessionDecodeFrame
// CONFIRMED FROM BINARY: CMVideoFormatDescriptionCreateFromH264ParameterSets
// RECONSTRUCTED: Class name (original obfuscated), method signatures from imports

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

@interface VCNVideoDecoder : NSObject

@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic, copy) void (^frameCallback)(CVPixelBufferRef pixelBuffer, CMTime pts);

- (void)feedNALUnit:(NSData *)nalData timestamp:(CMTime)pts;
- (void)feedH264SPS:(NSData *)sps PPS:(NSData *)pps;
- (void)flush;
- (void)invalidate;
- (void)clearDecoderKeepingFrame:(BOOL)keepFrame;

@end
