#import "VCNFaceDetector.h"
#import <Vision/Vision.h>

@implementation VCNFaceDetector {
    dispatch_queue_t _detectionQueue;
    NSMutableSet *_activeRequests;
}

- (instancetype)init {
    if ((self = [super init])) {
        _detectionQueue = dispatch_queue_create("com.vcnext.facedetect", DISPATCH_QUEUE_SERIAL);
        _activeRequests = [NSMutableSet new];
    }
    return self;
}

- (void)detectFaceInPixelBuffer:(CVPixelBufferRef)pixelBuffer
                    orientation:(CGImagePropertyOrientation)orientation
                     completion:(void(^)(CGRect, BOOL))completion {
    if (!pixelBuffer) { if (completion) completion(CGRectZero, NO); return; }

    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(_detectionQueue, ^{
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc]
            initWithCVPixelBuffer:pixelBuffer orientation:orientation options:@{}];

        VNDetectFaceRectanglesRequest *request = [[VNDetectFaceRectanglesRequest alloc]
            initWithCompletionHandler:^(VNRequest *req, NSError *err) {
                CGRect bounds = CGRectZero;
                BOOL detected = NO;
                if (!err && req.results.count > 0) {
                    VNFaceObservation *face = req.results.firstObject;
                    bounds = face.boundingBox;
                    detected = YES;
                }
                self->_lastFaceBounds = bounds;
                self->_faceDetected = detected;
                if (completion) completion(bounds, detected);
        }];

        NSError *error = nil;
        [handler performRequests:@[request] error:&error];
        CVPixelBufferRelease(pixelBuffer);
    });
}

- (CIImage *)blurOutsideFace:(CIImage *)image faceBounds:(CGRect)bounds radius:(CGFloat)radius {
    if (!image || CGRectIsEmpty(bounds)) return image;

    CGRect extent = image.extent;
    CGFloat x = bounds.origin.x * extent.size.width;
    CGFloat y = bounds.origin.y * extent.size.height;
    CGFloat w = bounds.size.width * extent.size.width;
    CGFloat h = bounds.size.height * extent.size.height;

    CGFloat inset = MAX(w, h) * 0.15;
    CGRect faceRect = CGRectInset(CGRectMake(x, y, w, h), -inset, -inset);
    faceRect = CGRectIntersection(faceRect, extent);
    if (CGRectIsNull(faceRect) || CGRectIsEmpty(faceRect)) return image;

    CIImage *blurred = [image imageByApplyingFilter:@"CIGaussianBlur"
                              withInputParameters:@{kCIInputRadiusKey: @(radius)}];

    CIImage *mask = [CIImage imageWithColor:[CIColor colorWithRed:1 green:1 blue:1 alpha:1]];
    mask = [mask imageByCroppingToRect:faceRect];

    CIImage *result = [blurred imageByApplyingFilter:@"CIBlendWithMask"
                               withInputParameters:@{
                                   kCIInputBackgroundImageKey: blurred,
                                   kCIInputMaskImageKey: mask
                               }];

    return [image imageByCompositingOverImage:result];
}

@end
