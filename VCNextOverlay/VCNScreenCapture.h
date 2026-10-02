// CONFIRMED FROM BINARY: IOSurfaceCreate import
// CONFIRMED FROM BINARY: dlsym + "CARenderServerRenderDisplay" string
// RECONSTRUCTED: Class name, capture method interface

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct __IOSurface *IOSurfaceRef;

CF_EXPORT IOSurfaceRef IOSurfaceCreate(CFDictionaryRef properties);
CF_EXPORT size_t IOSurfaceAlignProperty(CFStringRef property, size_t value);
CF_EXPORT const CFStringRef kIOSurfaceBytesPerRow;
CF_EXPORT const CFStringRef kIOSurfaceAllocSize;

@interface VCNScreenCapture : NSObject

@property (nonatomic, assign) NSInteger captureWidth;
@property (nonatomic, assign) NSInteger captureHeight;
@property (nonatomic, assign) IOSurfaceRef captureSurface;

- (IOSurfaceRef)captureScreen;
- (void)invalidate;

@end
