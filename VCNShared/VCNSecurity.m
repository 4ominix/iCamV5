// CONFIRMED FROM BINARY: SecKeyCreateRandomKey, kSecAttrKeyTypeECSECPrimeRandom
// CONFIRMED FROM BINARY: SecKeyCreateSignature, kSecKeyAlgorithmECDSASignatureMessageX962SHA256
// CONFIRMED FROM BINARY: SecKeyVerifySignature, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256
// CONFIRMED FROM BINARY: CCHmac (kCCHmacAlgSHA256), CC_SHA256
// CONFIRMED FROM BINARY: CCCrypt (kCCAlgorithmAES, kCCOptionPKCS7Padding)
// CONFIRMED FROM BINARY: SecItemAdd, SecItemCopyMatching, SecItemDelete, SecItemUpdate
// CONFIRMED FROM BINARY: SecTrustEvaluateWithError, SecCertificateCopyKey

#import "VCNSecurity.h"
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation VCNSecurity

+ (SecKeyRef)generateECKeyPair {
    NSDictionary *attrs = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeySizeInBits: @256,
    };
    CFErrorRef error = NULL;
    SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &error);
    if (error) { CFRelease(error); }
    return key;
}

+ (BOOL)generateECKeyPairPublicKey:(SecKeyRef *)publicKey privateKey:(SecKeyRef *)privateKey {
    SecKeyRef priv = [self generateECKeyPair];
    if (!priv) return NO;
    if (privateKey) *privateKey = priv;
    if (publicKey) *publicKey = SecKeyCopyPublicKey(priv);
    return YES;
}

+ (NSData *)publicKeyDataFromPrivateKey:(SecKeyRef)privateKey {
    if (!privateKey) return nil;
    SecKeyRef pubKey = SecKeyCopyPublicKey(privateKey);
    if (!pubKey) return nil;
    CFErrorRef error = NULL;
    CFDataRef data = SecKeyCopyExternalRepresentation(pubKey, &error);
    CFRelease(pubKey);
    if (error) { CFRelease(error); return nil; }
    return CFBridgingRelease(data);
}

+ (NSData *)signData:(NSData *)data withKey:(SecKeyRef)privateKey {
    if (!data || !privateKey) return nil;
    CFErrorRef error = NULL;
    CFDataRef sig = SecKeyCreateSignature(
        privateKey,
        kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
        (__bridge CFDataRef)data, &error
    );
    if (error) { CFRelease(error); return nil; }
    return CFBridgingRelease(sig);
}

+ (NSData *)ecdsaSignData:(NSData *)data withPrivateKey:(SecKeyRef)privateKey {
    return [self signData:data withKey:privateKey];
}

+ (BOOL)verifySignature:(NSData *)signature forData:(NSData *)data withKey:(SecKeyRef)publicKey {
    if (!signature || !data || !publicKey) return NO;
    CFErrorRef error = NULL;
    BOOL result = SecKeyVerifySignature(
        publicKey,
        kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
        (__bridge CFDataRef)data,
        (__bridge CFDataRef)signature, &error
    );
    if (error) CFRelease(error);
    return result;
}

+ (BOOL)verifyRSASignature:(NSData *)signature forData:(NSData *)data withKey:(SecKeyRef)publicKey {
    if (!signature || !data || !publicKey) return NO;
    CFErrorRef error = NULL;
    BOOL result = SecKeyVerifySignature(
        publicKey,
        kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
        (__bridge CFDataRef)data,
        (__bridge CFDataRef)signature, &error
    );
    if (error) CFRelease(error);
    return result;
}

+ (NSData *)hmacSHA256:(NSData *)data key:(NSData *)key {
    if (!data || !key) return nil;
    NSMutableData *mac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA256, key.bytes, key.length);
    CCHmacUpdate(&ctx, data.bytes, data.length);
    CCHmacFinal(&ctx, mac.mutableBytes);
    return mac;
}

+ (NSData *)sha256:(NSData *)data {
    if (!data) return nil;
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
    return hash;
}

+ (NSString *)sha256HexString:(NSString *)input {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hash = [self sha256:data];
    const unsigned char *bytes = hash.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:hash.length * 2];
    for (NSUInteger i = 0; i < hash.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

+ (NSData *)aesEncrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv {
    if (!data || !key) return nil;
    size_t outLen = 0;
    size_t bufLen = data.length + kCCBlockSizeAES128;
    NSMutableData *out = [NSMutableData dataWithLength:bufLen];
    CCCryptorStatus status = CCCrypt(
        kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
        key.bytes, key.length,
        iv.bytes,
        data.bytes, data.length,
        out.mutableBytes, bufLen, &outLen
    );
    if (status != kCCSuccess) return nil;
    out.length = outLen;
    return out;
}

+ (NSData *)aesDecrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv {
    if (!data || !key) return nil;
    size_t outLen = 0;
    size_t bufLen = data.length + kCCBlockSizeAES128;
    NSMutableData *out = [NSMutableData dataWithLength:bufLen];
    CCCryptorStatus status = CCCrypt(
        kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
        key.bytes, key.length,
        iv.bytes,
        data.bytes, data.length,
        out.mutableBytes, bufLen, &outLen
    );
    if (status != kCCSuccess) return nil;
    out.length = outLen;
    return out;
}

+ (BOOL)saveToKeychain:(NSData *)data service:(NSString *)service account:(NSString *)account {
    [self deleteFromKeychain:service account:account];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    };
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

+ (NSData *)loadFromKeychain:(NSString *)service account:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return nil;
    return CFBridgingRelease(result);
}

+ (SecKeyRef)loadKeyFromKeychain:(NSString *)tag {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag: [tag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecReturnRef: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return NULL;
    return (SecKeyRef)result;
}

+ (BOOL)saveKeyToKeychain:(SecKeyRef)key withTag:(NSString *)tag {
    NSDictionary *delQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag: [tag dataUsingEncoding:NSUTF8StringEncoding],
    };
    SecItemDelete((__bridge CFDictionaryRef)delQuery);
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecValueRef: (__bridge id)key,
        (__bridge id)kSecAttrApplicationTag: [tag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    };
    return SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL) == errSecSuccess;
}

+ (BOOL)deleteFromKeychain:(NSString *)service account:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
    };
    return SecItemDelete((__bridge CFDictionaryRef)query) == errSecSuccess;
}

+ (BOOL)updateKeychain:(NSData *)data service:(NSString *)service account:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
    };
    NSDictionary *update = @{ (__bridge id)kSecValueData: data };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
    if (status == errSecItemNotFound) {
        return [self saveToKeychain:data service:service account:account];
    }
    return status == errSecSuccess;
}

+ (SecKeyRef)publicKeyFromCertificateData:(NSData *)certData {
    if (!certData) return NULL;
    SecCertificateRef cert = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)certData);
    if (!cert) return NULL;
    SecKeyRef key = SecCertificateCopyKey(cert);
    CFRelease(cert);
    return key;
}

+ (SecKeyRef)publicKeyFromTrust:(SecTrustRef)trust {
    if (!trust) return NULL;
    return SecTrustCopyKey(trust);
}

+ (BOOL)evaluateTrust:(SecTrustRef)trust {
    if (!trust) return NO;
    CFErrorRef error = NULL;
    BOOL result = SecTrustEvaluateWithError(trust, &error);
    if (error) CFRelease(error);
    return result;
}

@end
