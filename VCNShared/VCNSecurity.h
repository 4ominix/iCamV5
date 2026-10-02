#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface VCNSecurity : NSObject

+ (SecKeyRef)generateECKeyPair;
+ (BOOL)generateECKeyPairPublicKey:(SecKeyRef *)publicKey privateKey:(SecKeyRef *)privateKey;
+ (NSData *)publicKeyDataFromPrivateKey:(SecKeyRef)privateKey;
+ (NSData *)signData:(NSData *)data withKey:(SecKeyRef)privateKey;
+ (NSData *)ecdsaSignData:(NSData *)data withPrivateKey:(SecKeyRef)privateKey;
+ (BOOL)verifySignature:(NSData *)signature forData:(NSData *)data withKey:(SecKeyRef)publicKey;
+ (BOOL)verifyRSASignature:(NSData *)signature forData:(NSData *)data withKey:(SecKeyRef)publicKey;

+ (NSData *)hmacSHA256:(NSData *)data key:(NSData *)key;
+ (NSData *)sha256:(NSData *)data;
+ (NSString *)sha256HexString:(NSString *)input;
+ (NSData *)aesEncrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv;
+ (NSData *)aesDecrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv;

+ (BOOL)saveToKeychain:(NSData *)data service:(NSString *)service account:(NSString *)account;
+ (NSData *)loadFromKeychain:(NSString *)service account:(NSString *)account;
+ (SecKeyRef)loadKeyFromKeychain:(NSString *)tag;
+ (BOOL)saveKeyToKeychain:(SecKeyRef)key withTag:(NSString *)tag;
+ (BOOL)deleteFromKeychain:(NSString *)service account:(NSString *)account;
+ (BOOL)updateKeychain:(NSData *)data service:(NSString *)service account:(NSString *)account;

+ (SecKeyRef)publicKeyFromCertificateData:(NSData *)certData;
+ (SecKeyRef)publicKeyFromTrust:(SecTrustRef)trust;
+ (BOOL)evaluateTrust:(SecTrustRef)trust;

@end
