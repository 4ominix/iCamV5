#import <Foundation/Foundation.h>
#import "VCNHTTPClient.h"

@interface VCNAuthHeartbeat : NSObject

@property (nonatomic, strong) VCNHTTPClient *httpClient;
@property (nonatomic, assign) NSTimeInterval heartbeatInterval;
@property (nonatomic, assign, readonly) BOOL authenticated;

- (instancetype)initWithHTTPClient:(VCNHTTPClient *)client;
- (void)startHeartbeat;
- (void)stopHeartbeat;
- (void)authenticateWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)refreshCapabilityLease;
- (void)handleAuthNotification;

@end
