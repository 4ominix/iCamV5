#import <Foundation/Foundation.h>

@interface VCNAccountManager : NSObject

@property (nonatomic, readonly) BOOL isLoggedIn;
@property (nonatomic, readonly) NSString *username;

+ (instancetype)shared;
- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(BOOL success, NSString *error))completion;
- (void)logout;
- (void)refreshAuthSession;

@end
