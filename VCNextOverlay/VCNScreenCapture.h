// CONFIRMED FROM BINARY: IOSurfaceCreate import
// CONFIRMED FROM BINARY: dlsym + "CARenderServerRenderDisplay" string
// RECONSTRUCTED: Class name, capture method interface

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <CoreGraphics/CoreGraphics.h>

@interface VCNScreenCapture : NSObject

@property (nonatomic, assign) NSInteger captureWidth;
@property (nonatomic, assign) NSInteger captureHeight;
@property (nonatomic, assign) IOSurfaceRef captureSurface;

- (IOSurfaceRef)captureScreen;
- (void)invalidate;

@end
