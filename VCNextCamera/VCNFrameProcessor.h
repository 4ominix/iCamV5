// CONFIRMED FROM BINARY: CIContext, CIImage, VTPixelTransferSession imports
// CONFIRMED FROM BINARY: kCVPixelFormatType_32BGRA format usage
// RECONSTRUCTED: Class name (original obfuscated VCN[hex20]), interface shape
// INFERRED: Property names and method signatures from selector strings

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <VideoToolbox/VideoToolbox.h>

@interface VCNFrameProcessor : NSObject

@property (nonatomic, assign) BOOL colorSyncEnabled;
@property (nonatomic, assign) CGFloat colorSyncRed;
@property (nonatomic, assign) CGFloat colorSyncGreen;
@property (nonatomic, assign) CGFloat colorSyncBlue;
@property (nonatomic, assign) NSInteger colorSyncRegion;

@property (nonatomic, strong) CIImage *cachedStillImage;
@property (nonatomic, assign) CFAbsoluteTime cachedStillImageStamp;
@property (nonatomic, strong) NSDictionary *cachedConfiguration;
@property (nonatomic, assign) CVPixelBufferRef currentVideoSample;

- (void)loadMediaFromPath:(NSString *)path;
- (CMSampleBufferRef)processOutputBuffer:(CMSampleBufferRef)original;
- (CMSampleBufferRef)processPreviewBuffer:(CMSampleBufferRef)original;
- (CMSampleBufferRef)processStillImageBuffer:(CMSampleBufferRef)original;
- (CIImage *)preparedImage:(CIImage *)source width:(int)w height:(int)h
               orientation:(int)orient configuration:(NSDictionary *)config;
- (void)renderImage:(CIImage *)image intoBGRAPixelBuffer:(CVPixelBufferRef)dest;
- (CIImage *)normalizedImage:(CIImage *)image;
- (void)setAttachmentSignature:(CMSampleBufferRef)buffer;

@end
