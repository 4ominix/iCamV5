#import <Foundation/Foundation.h>

typedef void (^VCNHTTPCompletionBlock)(NSDictionary *response, NSError *error);

@interface VCNHTTPClient : NSObject

@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *authToken;

- (instancetype)initWithBaseURL:(NSString *)baseURL;
- (void)GET:(NSString *)path parameters:(NSDictionary *)params completion:(VCNHTTPCompletionBlock)completion;
- (void)POST:(NSString *)path body:(NSDictionary *)body completion:(VCNHTTPCompletionBlock)completion;
- (void)setAuthorizationHeader:(NSString *)token;

@end
