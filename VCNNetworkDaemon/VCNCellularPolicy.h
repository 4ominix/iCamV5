#import <Foundation/Foundation.h>

@interface VCNCellularPolicy : NSObject

+ (void)allowCellularDataForBundleId:(NSString *)bundleId;
+ (void)denyCellularDataForBundleId:(NSString *)bundleId;
+ (BOOL)isCellularDataAllowedForBundleId:(NSString *)bundleId;

@end
