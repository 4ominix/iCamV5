#import "VCNCameraHooks.h"
#import <objc/runtime.h>
#import <substrate.h>

void VCNInstallCameraHooks(void) {
    // Hooks are installed via Logos %hook in Tweak.xm
    // This function exists as the original binary's exported entry point
    // for explicit hook installation in non-Substrate scenarios.
    //
    // The original binary uses MSHookMessageEx to hook:
    //   BWImageQueueSinkNode       -renderSampleBuffer:forInput:
    //   BWPreviewSinkNode          -renderSampleBuffer:forInput:
    //   BWRemoteQueueSinkNode      -renderSampleBuffer:forInput:
    //   BWStillImageSampleBufferSinkNode -renderSampleBuffer:forInput:
    //   BWPhotoEncoderNode         -renderSampleBuffer:forInput:
    //   BWNodeOutput               -emitSampleBuffer:
    //
    // With Logos, all hooks are installed automatically at load time.
}
