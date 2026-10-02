// CONFIRMED FROM BINARY: UIWindow subclass at alert+1 level
// CONFIRMED: UIPanGestureRecognizer for drag behavior
// RECONSTRUCTED: Class name, interface methods
// INFERRED: Edge-snap behavior, 50x50 size, position persistence

#import <UIKit/UIKit.h>

@interface VCNFloatingWindow : UIWindow

- (instancetype)initWithWindowScene:(UIWindowScene *)scene;
- (void)installOverlayInView:(UIView *)overlay;
- (void)adjustForOrientation;

@end
