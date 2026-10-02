// CONFIRMED FROM BINARY: VNDetectFaceRectanglesRequest import
// CONFIRMED FROM BINARY: CIGaussianBlur, CIBlendWithMask string references
// RECONSTRUCTED: Class name, blur-outside-face method signature

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

@interface VCNFaceDetector : NSObject

@property (nonatomic, readonly) CGRect lastFaceBounds;
@property (nonatomic, readonly) BOOL faceDetected;

- (void)detectFaceInPixelBuffer:(CVPixelBufferRef)pixelBuffer
                    orientation:(CGImagePropertyOrientation)orientation
                     completion:(void(^)(CGRect faceBounds, BOOL detected))completion;
- (CIImage *)blurOutsideFace:(CIImage *)image faceBounds:(CGRect)bounds radius:(CGFloat)radius;

@end
