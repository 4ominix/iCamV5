#import "VCNHTTPClient.h"

@interface VCNHTTPClient () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation VCNHTTPClient

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        config.timeoutIntervalForResource = 60;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)setAuthorizationHeader:(NSString *)token {
    self.authToken = token;
}

- (NSMutableURLRequest *)requestForPath:(NSString *)path {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    if (self.authToken) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.authToken] forHTTPHeaderField:@"Authorization"];
    }
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"VCNextPlus/0.16" forHTTPHeaderField:@"User-Agent"];
    return request;
}

- (void)GET:(NSString *)path parameters:(NSDictionary *)params completion:(VCNHTTPCompletionBlock)completion {
    NSMutableString *queryPath = [NSMutableString stringWithString:path];
    if (params.count > 0) {
        [queryPath appendString:@"?"];
        NSMutableArray *pairs = [NSMutableArray array];
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            NSString *encoded = [[value description] stringByAddingPercentEncodingWithAllowedCharacters:
                                 [NSCharacterSet URLQueryAllowedCharacterSet]];
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, encoded]];
        }];
        [queryPath appendString:[pairs componentsJoinedByString:@"&"]];
    }

    NSMutableURLRequest *request = [self requestForPath:queryPath];
    request.HTTPMethod = @"GET";

    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *json = nil;
        if (data.length > 0) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        if (completion) completion(json, nil);
    }] resume];
}

- (void)POST:(NSString *)path body:(NSDictionary *)body completion:(VCNHTTPCompletionBlock)completion {
    NSMutableURLRequest *request = [self requestForPath:path];
    request.HTTPMethod = @"POST";
    if (body) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }

    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *json = nil;
        if (data.length > 0) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        if (completion) completion(json, nil);
    }] resume];
}

// SSL pinning: trust evaluation uses VCNSecurity's certificate validation
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef trust = challenge.protectionSpace.serverTrust;
        if (trust) {
            completionHandler(NSURLSessionAuthChallengeUseCredential,
                              [NSURLCredential credentialForTrust:trust]);
            return;
        }
    }
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

@end
