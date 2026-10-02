// CONFIRMED FROM BINARY: CIColorKernel import
// RECONSTRUCTED: Class name, RGB shift method signature
// INFERRED: Region enum values (Full/Forehead/Chin/Sides from UI string refs)

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

typedef NS_ENUM(NSInteger, VCNColorSyncRegion) {
    VCNColorSyncRegionFull      = 0,
    VCNColorSyncRegionForehead  = 1,
    VCNColorSyncRegionChin      = 2,
    VCNColorSyncRegionSides     = 3,
};

@interface VCNColorSync : NSObject

@property (nonatomic, assign) CGFloat colorPickerPointX;
@property (nonatomic, assign) CGFloat colorPickerPointY;

- (CIImage *)applyColorSync:(CIImage *)image
                         red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
                      region:(VCNColorSyncRegion)region;

@end
