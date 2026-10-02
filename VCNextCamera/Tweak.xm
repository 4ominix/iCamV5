// CONFIRMED: Hooks cameracaptured + mediaserverd (filter plist)
// CONFIRMED: All BW* class names from binary string table
// CONFIRMED: -renderSampleBuffer:forInput: and -emitSampleBuffer: selectors
// RECONSTRUCTED: Hook body logic (frame replacement flow inferred from imports)
// RECONSTRUCTED: Config reload mechanism (notification names CONFIRMED, logic INFERRED)

#import <Foundation/Foundation.h>
#import <substrate.h>
#import "VCNCameraHooks.h"
#import "VCNFrameProcessor.h"
#import "VCNStreamReader.h"
#import "VCNPaths.h"
#import "VCNNotifications.h"
#import "VCNConfig.h"

static VCNFrameProcessor *g_frameProcessor = nil;
static VCNStreamReader    *g_streamReader   = nil;
static BOOL                g_cameraActive   = NO;
static NSDictionary       *g_cachedConfig   = nil;
static dispatch_queue_t    g_configQueue    = nil;

static void reloadConfiguration(void) {
    dispatch_async(g_configQueue, ^{
        @synchronized(g_frameProcessor) {
            g_cachedConfig = [VCNConfig cameraConfiguration];
            if (!g_cachedConfig) {
                g_cameraActive = NO;
                return;
            }
            g_cameraActive = [g_cachedConfig[@"enabled"] boolValue];

            NSString *source = g_cachedConfig[@"source"];
            if ([source isEqualToString:@"stream"]) {
                [g_streamReader startReadingFromPath:VCNLiveStreamPath];
            } else if ([source isEqualToString:@"media"]) {
                NSString *mediaPath = g_cachedConfig[@"mediaPath"];
                if (mediaPath) [g_frameProcessor loadMediaFromPath:mediaPath];
            }

            g_frameProcessor.colorSyncEnabled = [g_cachedConfig[@"colorSyncEnabled"] boolValue];
            g_frameProcessor.colorSyncRed     = [g_cachedConfig[@"colorSyncRed"] floatValue];
            g_frameProcessor.colorSyncGreen   = [g_cachedConfig[@"colorSyncGreen"] floatValue];
            g_frameProcessor.colorSyncBlue    = [g_cachedConfig[@"colorSyncBlue"] floatValue];
            g_frameProcessor.colorSyncRegion  = [g_cachedConfig[@"colorSyncRegion"] integerValue];
        }
    });
}

static void configChangedCallback(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    reloadConfiguration();
}

// ─── mediaserverd internal class hooks ───────────────────────────────────────

// BWImageQueueSinkNode - main camera output pipeline node
%hook BWImageQueueSinkNode

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input {
    if (g_cameraActive && sampleBuffer) {
        CMSampleBufferRef replaced = [g_frameProcessor processOutputBuffer:sampleBuffer];
        if (replaced) {
            %orig(replaced, input);
            if (replaced != sampleBuffer) CFRelease(replaced);
            return;
        }
    }
    %orig;
}

%end

// BWPreviewSinkNode - camera preview output
%hook BWPreviewSinkNode

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input {
    if (g_cameraActive && sampleBuffer) {
        CMSampleBufferRef replaced = [g_frameProcessor processPreviewBuffer:sampleBuffer];
        if (replaced) {
            %orig(replaced, input);
            if (replaced != sampleBuffer) CFRelease(replaced);
            return;
        }
    }
    %orig;
}

%end

// BWRemoteQueueSinkNode - FaceTime/remote camera output
%hook BWRemoteQueueSinkNode

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input {
    if (g_cameraActive && sampleBuffer) {
        CMSampleBufferRef replaced = [g_frameProcessor processOutputBuffer:sampleBuffer];
        if (replaced) {
            %orig(replaced, input);
            if (replaced != sampleBuffer) CFRelease(replaced);
            return;
        }
    }
    %orig;
}

%end

// BWStillImageSampleBufferSinkNode - still photo capture
%hook BWStillImageSampleBufferSinkNode

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input {
    if (g_cameraActive && sampleBuffer) {
        CMSampleBufferRef replaced = [g_frameProcessor processStillImageBuffer:sampleBuffer];
        if (replaced) {
            %orig(replaced, input);
            if (replaced != sampleBuffer) CFRelease(replaced);
            return;
        }
    }
    %orig;
}

%end

// BWPhotoEncoderNode - photo encoder pipeline
%hook BWPhotoEncoderNode

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer forInput:(id)input {
    if (g_cameraActive && sampleBuffer) {
        CMSampleBufferRef replaced = [g_frameProcessor processStillImageBuffer:sampleBuffer];
        if (replaced) {
            %orig(replaced, input);
            if (replaced != sampleBuffer) CFRelease(replaced);
            return;
        }
    }
    %orig;
}

%end

// BWNodeOutput - generic camera pipeline node output
%hook BWNodeOutput

- (void)emitSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (g_cameraActive && sampleBuffer) {
        CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
        if (fmt && CMFormatDescriptionGetMediaType(fmt) == kCMMediaType_Video) {
            CMSampleBufferRef replaced = [g_frameProcessor processOutputBuffer:sampleBuffer];
            if (replaced) {
                %orig(replaced);
                if (replaced != sampleBuffer) CFRelease(replaced);
                return;
            }
        }
    }
    %orig;
}

%end

// ─── Constructor ─────────────────────────────────────────────────────────────

%ctor {
    @autoreleasepool {
        g_configQueue = dispatch_queue_create("com.vcnext.camera.config", DISPATCH_QUEUE_SERIAL);
        g_frameProcessor = [[VCNFrameProcessor alloc] init];
        g_streamReader   = [[VCNStreamReader alloc] init];
        g_streamReader.frameProcessor = g_frameProcessor;

        VCNObserveDarwinNotification(VCNStateChangedNotification, configChangedCallback, NULL);
        VCNObserveDarwinNotification(VCNCameraStatusChangedNotification, configChangedCallback, NULL);
        VCNObserveDarwinNotification(VCNCapabilityChangedNotification, configChangedCallback, NULL);

        reloadConfiguration();

        [VCNConfig setCameraStatus:@{
            @"injected": @YES,
            @"process": [NSProcessInfo processInfo].processName,
            @"timestamp": @([NSDate date].timeIntervalSince1970),
        }];
    }
}
