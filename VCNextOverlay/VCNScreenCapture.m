#import "VCNScreenCapture.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef IOSurfaceRef (*CARenderServerRenderDisplayFn)(int, CFStringRef, IOSurfaceRef, int, int);

@implementation VCNScreenCapture {
    CARenderServerRenderDisplayFn _renderFunc;
}

- (instancetype)init {
    if ((self = [super init])) {
        _renderFunc = dlsym(RTLD_DEFAULT, "CARenderServerRenderDisplay");
    }
    return self;
}

- (IOSurfaceRef)captureScreen {
    if (!_renderFunc) return NULL;

    if (!_captureSurface || _captureWidth <= 0 || _captureHeight <= 0) {
        [self _createSurface];
    }
    if (!_captureSurface) return NULL;

    _renderFunc(0, NULL, _captureSurface, 0, 0);
    return _captureSurface;
}

- (void)_createSurface {
    if (_captureWidth <= 0 || _captureHeight <= 0) {
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat scale = [UIScreen mainScreen].scale;
        _captureWidth = (NSInteger)(CGRectGetWidth(screen) * scale);
        _captureHeight = (NSInteger)(CGRectGetHeight(screen) * scale);
    }

    size_t bpe = 4;
    size_t bpr = IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, _captureWidth * bpe);
    size_t totalSize = IOSurfaceAlignProperty(kIOSurfaceAllocSize, bpr * _captureHeight);

    NSDictionary *props = @{
        @"IOSurfaceWidth":          @(_captureWidth),
        @"IOSurfaceHeight":         @(_captureHeight),
        @"IOSurfaceBytesPerElement": @(bpe),
        @"IOSurfaceBytesPerRow":    @(bpr),
        @"IOSurfaceAllocSize":      @(totalSize),
        @"IOSurfacePixelFormat":    @(0x42475241), // 'BGRA'
    };

    _captureSurface = IOSurfaceCreate((__bridge CFDictionaryRef)props);
}

- (void)invalidate {
    if (_captureSurface) {
        CFRelease(_captureSurface);
        _captureSurface = NULL;
    }
}

- (void)dealloc {
    [self invalidate];
}

@end
