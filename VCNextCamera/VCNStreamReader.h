// CONFIRMED FROM BINARY: "incoming.flv", "latest.flv", "FLV" (0x464C56) strings
// RECONSTRUCTED: Class name, FLV parsing + NAL extraction logic
// INFERRED: Timer-based polling mechanism for file reads

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "VCNFrameProcessor.h"
#import "VCNVideoDecoder.h"

@interface VCNStreamReader : NSObject

@property (nonatomic, weak) VCNFrameProcessor *frameProcessor;
@property (nonatomic, readonly) BOOL isReading;

- (void)startReadingFromPath:(NSString *)path;
- (void)stopReading;

@end
