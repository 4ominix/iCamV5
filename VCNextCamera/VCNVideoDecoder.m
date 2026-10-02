#import "VCNVideoDecoder.h"
#import <os/log.h>

static os_log_t vcn_log(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.vcnext.camera", "decoder"); });
    return log;
}

@implementation VCNVideoDecoder {
    VTDecompressionSessionRef _session;
    CMFormatDescriptionRef    _formatDesc;
    CVPixelBufferRef          _lastFrame;
    dispatch_queue_t          _queue;
    NSData                   *_spsData;
    NSData                   *_ppsData;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.vcnext.decoder", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self invalidate];
}

- (void)feedH264SPS:(NSData *)sps PPS:(NSData *)pps {
    _spsData = [sps copy];
    _ppsData = [pps copy];
    [self _createDecompressionSession];
}

- (void)_createDecompressionSession {
    if (_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }

    const uint8_t *paramSets[2] = { _spsData.bytes, _ppsData.bytes };
    size_t paramSizes[2] = { _spsData.length, _ppsData.length };

    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
        kCFAllocatorDefault, 2, paramSets, paramSizes, 4, &_formatDesc
    );
    if (status != noErr) {
        os_log_error(vcn_log(), "Failed to create format description: %d", (int)status);
        return;
    }

    NSDictionary *destAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };

    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = decompressionCallback,
        .decompressionOutputRefCon = (__bridge void *)self,
    };

    status = VTDecompressionSessionCreate(
        kCFAllocatorDefault, _formatDesc, NULL,
        (__bridge CFDictionaryRef)destAttrs, &callback, &_session
    );
    if (status != noErr) {
        os_log_error(vcn_log(), "Failed to create decompression session: %d", (int)status);
        return;
    }

    VTSessionSetProperty(_session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    _isReady = YES;
}

static void decompressionCallback(void *refCon, void *sourceFrameRefCon, OSStatus status,
                                   VTDecodeInfoFlags flags, CVImageBufferRef imageBuffer,
                                   CMTime pts, CMTime duration) {
    if (status != noErr || !imageBuffer) return;
    VCNVideoDecoder *self = (__bridge VCNVideoDecoder *)refCon;
    @synchronized(self) {
        if (self->_lastFrame) CVPixelBufferRelease(self->_lastFrame);
        self->_lastFrame = CVPixelBufferRetain(imageBuffer);
    }
    if (self.frameCallback) {
        self.frameCallback(imageBuffer, pts);
    }
}

- (void)feedNALUnit:(NSData *)nalData timestamp:(CMTime)pts {
    if (!_session || !_formatDesc || !nalData.length) return;

    CMBlockBufferRef blockBuffer = NULL;
    size_t len = nalData.length;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(
        kCFAllocatorDefault, NULL, len, kCFAllocatorDefault,
        NULL, 0, len, 0, &blockBuffer
    );
    if (status != noErr) return;

    status = CMBlockBufferReplaceDataBytes(nalData.bytes, blockBuffer, 0, len);
    if (status != noErr) { CFRelease(blockBuffer); return; }

    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSize = len;
    CMSampleTimingInfo timing = { .duration = kCMTimeInvalid, .presentationTimeStamp = pts, .decodeTimeStamp = kCMTimeInvalid };

    status = CMSampleBufferCreateReady(
        kCFAllocatorDefault, blockBuffer, _formatDesc,
        1, 1, &timing, 1, &sampleSize, &sampleBuffer
    );
    CFRelease(blockBuffer);
    if (status != noErr) return;

    VTDecodeInfoFlags flags = 0;
    VTDecompressionSessionDecodeFrame(_session, sampleBuffer, kVTDecodeFrame_EnableAsynchronousDecompression, NULL, &flags);
    CFRelease(sampleBuffer);
}

- (void)flush {
    if (_session) {
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
    }
}

- (void)invalidate {
    if (_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    @synchronized(self) {
        if (_lastFrame) {
            CVPixelBufferRelease(_lastFrame);
            _lastFrame = NULL;
        }
    }
    _isReady = NO;
}

- (void)clearDecoderKeepingFrame:(BOOL)keepFrame {
    if (_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (!keepFrame) {
        @synchronized(self) {
            if (_lastFrame) {
                CVPixelBufferRelease(_lastFrame);
                _lastFrame = NULL;
            }
        }
    }
    _isReady = NO;
}

@end
