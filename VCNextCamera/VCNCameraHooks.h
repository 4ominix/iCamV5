#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

void VCNInstallCameraHooks(void);

@interface BWImageQueueSinkNode : NSObject
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input;
@end

@interface BWPreviewSinkNode : NSObject
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input;
@end

@interface BWRemoteQueueSinkNode : NSObject
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input;
@end

@interface BWStillImageSampleBufferSinkNode : NSObject
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input;
@end

@interface BWPhotoEncoderNode : NSObject
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input;
@end

@interface BWNodeOutput : NSObject
- (void)emitSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
