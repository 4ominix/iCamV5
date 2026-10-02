#import "VCNColorSync.h"

@implementation VCNColorSync {
    CIColorKernel *_colorKernel;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSString *kernelSource = @"kernel vec4 colorShift(sampler src, float rShift, float gShift, float bShift) {"
            "  vec4 c = sample(src, samplerCoord(src));"
            "  c.r = clamp(c.r + rShift, 0.0, 1.0);"
            "  c.g = clamp(c.g + gShift, 0.0, 1.0);"
            "  c.b = clamp(c.b + bShift, 0.0, 1.0);"
            "  return c;"
            "}";
        _colorKernel = [CIColorKernel kernelWithString:kernelSource];
    }
    return self;
}

- (CIImage *)applyColorSync:(CIImage *)image
                         red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                      region:(VCNColorSyncRegion)region {
    if (!image || !_colorKernel) return image;
    if (red == 0.0 && green == 0.0 && blue == 0.0) return image;

    CIImage *shifted = [_colorKernel applyWithExtent:image.extent
                                           arguments:@[image, @(red), @(green), @(blue)]];
    if (!shifted) return image;

    if (region == VCNColorSyncRegionFull) return shifted;

    CGRect extent = image.extent;
    CGRect regionRect;
    switch (region) {
        case VCNColorSyncRegionForehead:
            regionRect = CGRectMake(extent.origin.x, extent.origin.y + extent.size.height * 0.6,
                                    extent.size.width, extent.size.height * 0.4);
            break;
        case VCNColorSyncRegionChin:
            regionRect = CGRectMake(extent.origin.x, extent.origin.y,
                                    extent.size.width, extent.size.height * 0.3);
            break;
        case VCNColorSyncRegionSides:
            regionRect = CGRectMake(extent.origin.x, extent.origin.y + extent.size.height * 0.2,
                                    extent.size.width, extent.size.height * 0.6);
            break;
        default:
            return shifted;
    }

    CIImage *regionShifted = [shifted imageByCroppingToRect:regionRect];
    CIImage *result = [regionShifted imageByCompositingOverImage:image];

    return result;
}

@end
