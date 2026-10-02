#import "VCNFloatingWindow.h"

@implementation VCNFloatingWindow {
    UIView *_overlayView;
    UIButton *_floatingButton;
    CGPoint _dragStart;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
    if ((self = [super initWithWindowScene:scene])) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor clearColor];
        self.frame = CGRectMake(0, 0, 60, 60);
        self.clipsToBounds = NO;

        _floatingButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _floatingButton.frame = CGRectMake(0, 0, 56, 56);
        _floatingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        _floatingButton.layer.cornerRadius = 28;
        _floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
        _floatingButton.layer.borderWidth = 2;

        UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
        UIImage *camIcon = [UIImage systemImageNamed:@"camera.fill" withConfiguration:symConfig];
        [_floatingButton setImage:camIcon forState:UIControlStateNormal];
        _floatingButton.tintColor = [UIColor whiteColor];
        [_floatingButton addTarget:self action:@selector(commandTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_floatingButton addGestureRecognizer:pan];

        [self addSubview:_floatingButton];
        self.accessibilityElementsHidden = YES;

        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.vcnext.overlay"];
        CGFloat x = [defaults doubleForKey:@"floatingX"];
        CGFloat y = [defaults doubleForKey:@"floatingY"];
        self.center = CGPointMake(x, y);

        [self makeKeyAndVisible];
    }
    return self;
}

- (void)installOverlayInView:(UIView *)overlay {
    _overlayView = overlay;
    _overlayView.hidden = YES;
    _overlayView.alpha = 0;
    [self addSubview:_overlayView];
}

- (void)commandTapped:(UIButton *)sender {
    if (_overlayView) {
        BOOL show = _overlayView.hidden;
        _overlayView.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self->_overlayView.alpha = show ? 1.0 : 0.0;
        } completion:^(BOOL finished) {
            self->_overlayView.hidden = !show;
        }];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview ?: self];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        _dragStart = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(_dragStart.x + translation.x, _dragStart.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        [self dragFloatingButton:gesture];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.vcnext.overlay"];
        [defaults setDouble:self.center.x forKey:@"floatingX"];
        [defaults setDouble:self.center.y forKey:@"floatingY"];
    }
}

- (void)dragFloatingButton:(UIPanGestureRecognizer *)gesture {
    CGRect screen = UIScreen.mainScreen.bounds;
    CGPoint center = self.center;

    CGFloat halfW = self.bounds.size.width / 2;
    CGFloat halfH = self.bounds.size.height / 2;

    center.x = MAX(halfW, MIN(center.x, CGRectGetWidth(screen) - halfW));
    center.y = MAX(halfH + 50, MIN(center.y, CGRectGetHeight(screen) - halfH - 50));

    if (center.x < CGRectGetMidX(screen)) {
        center.x = halfW + 4;
    } else {
        center.x = CGRectGetWidth(screen) - halfW - 4;
    }

    [UIView animateWithDuration:0.3 animations:^{
        self.center = center;
    }];
}

- (void)adjustForOrientation {
    CGRect screen = UIScreen.mainScreen.bounds;
    CGPoint center = self.center;
    CGFloat halfW = self.bounds.size.width / 2;
    CGFloat halfH = self.bounds.size.height / 2;
    center.x = MAX(halfW, MIN(center.x, CGRectGetWidth(screen) - halfW));
    center.y = MAX(halfH, MIN(center.y, CGRectGetHeight(screen) - halfH));
    self.center = center;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil;
    return hit;
}

@end
