// CONFIRMED FROM BINARY: "anix204.xyz" and "vcnext.corev.bond" domain strings
// CONFIRMED FROM BINARY: +[NSURL URLWithString:] class method reference
// CONFIRMED: Filter plist restricts to VCNNetworkDaemon executable
// RECONSTRUCTED: Swizzle implementation (hasPrefix check + suffix append)

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kOldDomain = @"https://anix204.xyz";
static NSString *const kNewDomain = @"https://vcnext.corev.bond";

static IMP orig_URLWithString = NULL;

static NSURL *swizzled_URLWithString(id self, SEL _cmd, NSString *string) {
    if ([string isKindOfClass:[NSString class]] && [string hasPrefix:kOldDomain]) {
        NSString *suffix = [string substringFromIndex:kOldDomain.length];
        string = [kNewDomain stringByAppendingString:suffix];
    }
    return ((NSURL *(*)(id, SEL, NSString *))orig_URLWithString)(self, _cmd, string);
}

%ctor {
    @autoreleasepool {
        NSString *procName = [NSProcessInfo processInfo].processName;
        if (![procName isEqualToString:@"VCNNetworkDaemon"]) return;

        Method m = class_getClassMethod([NSURL class], @selector(URLWithString:));
        if (m) {
            orig_URLWithString = method_getImplementation(m);
            method_setImplementation(m, (IMP)swizzled_URLWithString);
        }
    }
}
