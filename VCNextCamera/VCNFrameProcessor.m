#import "VCNFrameProcessor.h"
#import "VCNFaceDetector.h"
#import "VCNColorSync.h"
#import "VCNConfig.h"
#import "VCNPaths.h"
#import <AVFoundation/AVFoundation.h>

@implementation VCNFrameProcessor {
    CIContext             *_ciContext;
    CIColorKernel         *_colorKernel;
    VCNFaceDetector       *_faceDetector;
    VCNColorSync          *_colorSync;
    VTPixelTransferSessionRef _transferSession;
    dispatch_queue_t       _processQueue;
    NSLock                *_frameLock;
    CIImage               *_currentSourceImage;
    CVPixelBufferRef       _replacementBuffer;
}

- (instancetype)init {
    if ((self = [super init])) {
        _ciContext = [CIContext contextWithOptions:@{
            kCIContextUseSoftwareRenderer: @NO,
            kCIContextHighQualityDownsample: @YES,
        }];
        _faceDetector = [[VCNFaceDetector alloc] init];
        _colorSync    = [[VCNColorSync alloc] init];
        _frameLock    = [[NSLock alloc] init];
        _processQueue = dispatch_queue_create("com.vcnext.frameproc", DISPATCH_QUEUE_SERIAL);

        VTPixelTransferSessionCreate(kCFAllocatorDefault, &_transferSession);
        VTSessionSetProperty(_transferSession, kVTPixelTransferPropertyKey_ScalingMode, kVTScalingMode_Trim);
    }
    return self;
}

- (void)dealloc {
    if (_transferSession) {
        VTPixelTransferSessionInvalidate(_transferSession);
        CFRelease(_transferSession);
    }
    if (_replacementBuffer) CVPixelBufferRelease(_replacementBuffer);
    if (_currentVideoSample) CVPixelBufferRelease(_currentVideoSample);
}

- (void)loadMediaFromPath:(NSString *)path {
    if (!path) return;
    NSURL *url = [NSURL fileURLWithPath:path];

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSNumber *fileSize = attrs[NSFileSize];
    if (!fileSize || fileSize.unsignedLongLongValue == 0) return;

    NSString *ext = path.pathExtension.lowercaseString;
    BOOL isVideo = [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] ||
                   [ext isEqualToString:@"m4v"];

    if (isVideo) {
        [self _loadVideoFromURL:url];
    } else {
        CIImage *image = [CIImage imageWithContentsOfURL:url options:@{kCIImageApplyOrientationProperty: @YES}];
        if (image) {
            [_frameLock lock];
            _currentSourceImage = image;
            [_frameLock unlock];
        }
    }
}

- (void)_loadVideoFromURL:(NSURL *)url {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url
                                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) return;

    AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!videoTrack) return;

    NSDictionary *outputSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                 outputSettings:outputSettings];
    output.alwaysCopiesSampleData = NO;
    if ([reader canAddOutput:output]) {
        [reader addOutput:output];
        [reader startReading];
    }
}

- (CMSampleBufferRef)processOutputBuffer:(CMSampleBufferRef)original {
    return [self _replaceBuffer:original isStill:NO];
}

- (CMSampleBufferRef)processPreviewBuffer:(CMSampleBufferRef)original {
    return [self _replaceBuffer:original isStill:NO];
}

- (CMSampleBufferRef)processStillImageBuffer:(CMSampleBufferRef)original {
    return [self _replaceBuffer:original isStill:YES];
}

- (CMSampleBufferRef)_replaceBuffer:(CMSampleBufferRef)original isStill:(BOOL)isStill {
    CVPixelBufferRef origPB = CMSampleBufferGetImageBuffer(original);
    if (!origPB) return NULL;

    int destW = (int)CVPixelBufferGetWidth(origPB);
    int destH = (int)CVPixelBufferGetHeight(origPB);

    CIImage *sourceImage = nil;
    [_frameLock lock];
    if (_currentVideoSample) {
        sourceImage = [CIImage imageWithCVPixelBuffer:_currentVideoSample];
    } else if (_currentSourceImage) {
        sourceImage = _currentSourceImage;
    }
    [_frameLock unlock];

    if (!sourceImage) return NULL;

    sourceImage = [self preparedImage:sourceImage width:destW height:destH orientation:0 configuration:_cachedConfiguration];

    if (self.colorSyncEnabled) {
        sourceImage = [_colorSync applyColorSync:sourceImage
                                             red:self.colorSyncRed
                                           green:self.colorSyncGreen
                                            blue:self.colorSyncBlue
                                          region:self.colorSyncRegion];
    }

    CVPixelBufferRef destPB = NULL;
    NSDictionary *pbAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    CVPixelBufferCreate(kCFAllocatorDefault, destW, destH,
                        kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef)pbAttrs, &destPB);
    if (!destPB) return NULL;

    [self renderImage:sourceImage intoBGRAPixelBuffer:destPB];

    NSDictionary *origAttachments = (__bridge_transfer NSDictionary *)CMCopyDictionaryOfAttachments(
        kCFAllocatorDefault, original, kCMAttachmentMode_ShouldPropagate
    );

    CMFormatDescriptionRef newFmt = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, destPB, &newFmt);

    CMSampleTimingInfo timing = {
        .duration = CMSampleBufferGetDuration(original),
        .presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(original),
        .decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(original),
    };

    CMSampleBufferRef newBuf = NULL;
    CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault, destPB, newFmt, &timing, &newBuf
    );

    if (origAttachments && newBuf) {
        CMSetAttachments(newBuf, (__bridge CFDictionaryRef)origAttachments, kCMAttachmentMode_ShouldPropagate);
    }

    if (newFmt) CFRelease(newFmt);
    CVPixelBufferRelease(destPB);

    [self setAttachmentSignature:newBuf];

    return newBuf;
}

- (CIImage *)preparedImage:(CIImage *)source width:(int)w height:(int)h
               orientation:(int)orient configuration:(NSDictionary *)config {
    if (!source) return nil;

    source = [self normalizedImage:source];

    CGRect extent = source.extent;
    CGFloat srcW = CGRectGetWidth(extent);
    CGFloat srcH = CGRectGetHeight(extent);
    if (srcW <= 0 || srcH <= 0) return source;

    CGFloat scaleX = w / srcW;
    CGFloat scaleY = h / srcH;
    CGFloat scale = MAX(scaleX, scaleY);

    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    source = [source imageByApplyingTransform:transform];

    CGFloat newW = srcW * scale;
    CGFloat newH = srcH * scale;
    CGFloat cropX = (newW - w) / 2.0;
    CGFloat cropY = (newH - h) / 2.0;
    source = [source imageByCroppingToRect:CGRectMake(cropX, cropY, w, h)];

    return source;
}

- (void)renderImage:(CIImage *)image intoBGRAPixelBuffer:(CVPixelBufferRef)dest {
    if (!image || !dest) return;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    [_ciContext render:image
       toCVPixelBuffer:dest
                bounds:image.extent
            colorSpace:cs];
    CGColorSpaceRelease(cs);
}

- (CIImage *)normalizedImage:(CIImage *)image {
    if (!image) return nil;
    return [image imageByApplyingOrientation:kCGImagePropertyOrientationUp];
}

- (void)setAttachmentSignature:(CMSampleBufferRef)buffer {
    if (!buffer) return;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, true);
    if (!attachments || CFArrayGetCount(attachments) == 0) return;
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionaryRemoveValue(dict, kCMSampleAttachmentKey_NotSync);
}

@end
