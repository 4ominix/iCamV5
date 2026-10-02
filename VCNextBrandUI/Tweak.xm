// CONFIRMED FROM BINARY: "V4HCAM Next" and "VcamNextPlus" string constants
// CONFIRMED FROM BINARY: UIViewController, UILabel class references
// CONFIRMED FROM BINARY: __attribute__((constructor)) pattern, no %hook
// CONFIRMED: Filter plist scopes to com.vcnext.app bundle only
// RECONSTRUCTED: Swizzle implementation details (method_setImplementation approach)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kBrandName = @"VcamNextPlus";
static NSString *const kInternalName = @"V4HCAM Next";

static IMP orig_setTitle = NULL;
static IMP orig_setText  = NULL;

static void swizzled_setTitle(id self, SEL _cmd, NSString *title) {
    if ([title isKindOfClass:[NSString class]] && [title isEqualToString:kInternalName]) {
        title = kBrandName;
    }
    ((void(*)(id, SEL, NSString *))orig_setTitle)(self, _cmd, title);
}

static void swizzled_setText(id self, SEL _cmd, NSString *text) {
    if ([text isKindOfClass:[NSString class]] && [text isEqualToString:kInternalName]) {
        text = kBrandName;
    }
    ((void(*)(id, SEL, NSString *))orig_setText)(self, _cmd, text);
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleID isEqualToString:@"com.vcnext.app"]) return;

        Method m1 = class_getInstanceMethod([UIViewController class], @selector(setTitle:));
        if (m1) {
            orig_setTitle = method_getImplementation(m1);
            method_setImplementation(m1, (IMP)swizzled_setTitle);
        }

        Method m2 = class_getInstanceMethod([UILabel class], @selector(setText:));
        if (m2) {
            orig_setText = method_getImplementation(m2);
            method_setImplementation(m2, (IMP)swizzled_setText);
        }
    }
}
