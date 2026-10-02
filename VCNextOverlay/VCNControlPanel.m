#import "VCNControlPanel.h"
#import "VCNConfig.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"

@implementation VCNControlPanel {
    UILabel  *_statusLabel;
    UIButton *_toggleBtn;
    UIButton *_streamBtn;
    UIButton *_sourceBtn;
    UIButton *_colorBtn;
    UIStackView *_stack;
}

- (instancetype)init {
    if ((self = [super initWithFrame:CGRectMake(0, 70, 220, 280)])) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        self.layer.cornerRadius = 16;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        self.layer.borderWidth = 1;
        self.clipsToBounds = YES;

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.text = @"VCam: Idle";

        _toggleBtn  = [self actionButtonWithTitle:@"Enable" symbol:@"power" color:[UIColor systemGreenColor]];
        _streamBtn  = [self actionButtonWithTitle:@"Stream" symbol:@"antenna.radiowaves.left.and.right" color:[UIColor systemBlueColor]];
        _sourceBtn  = [self actionButtonWithTitle:@"Source" symbol:@"photo.on.rectangle" color:[UIColor systemOrangeColor]];
        _colorBtn   = [self actionButtonWithTitle:@"Color"  symbol:@"paintpalette" color:[UIColor systemPurpleColor]];

        _stack = [[UIStackView alloc] initWithArrangedSubviews:@[_statusLabel, _toggleBtn, _streamBtn, _sourceBtn, _colorBtn]];
        _stack.axis = UILayoutConstraintAxisVertical;
        _stack.spacing = 8;
        _stack.alignment = UIStackViewAlignmentFill;
        _stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stack];

        [NSLayoutConstraint activateConstraints:@[
            [_stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
            [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        ]];
    }
    return self;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIFontWeightSemibold];
    UIImage *img = [UIImage systemImageNamed:symbol withConfiguration:cfg];
    [btn setImage:img forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    btn.tintColor = color;
    btn.backgroundColor = [color colorWithAlphaComponent:0.15];
    btn.layer.cornerRadius = 8;
    [btn.heightAnchor constraintEqualToConstant:40].active = YES;
    [btn addTarget:self action:@selector(_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIButton *)iconButton:(NSString *)systemName command:(NSString *)cmd label:(NSString *)label {
    UIButton *btn = [self actionButtonWithTitle:label symbol:systemName color:[UIColor whiteColor]];
    btn.accessibilityLabel = cmd;
    return btn;
}

- (void)_buttonTapped:(UIButton *)sender {
    NSString *cmd = nil;
    if (sender == _toggleBtn)  cmd = @"toggle";
    else if (sender == _streamBtn) cmd = @"stream";
    else if (sender == _sourceBtn) cmd = @"source";
    else if (sender == _colorBtn)  cmd = @"color";

    if (cmd) {
        if (self.commandHandler) {
            self.commandHandler(cmd);
        } else {
            [self _handleCommand:cmd];
        }
    }
}

- (void)_handleCommand:(NSString *)cmd {
    if ([cmd isEqualToString:@"toggle"]) {
        NSDictionary *config = [VCNConfig cameraConfiguration] ?: @{};
        NSMutableDictionary *mutable = [config mutableCopy];
        mutable[@"enabled"] = @(![config[@"enabled"] boolValue]);
        [VCNConfig setCameraConfiguration:mutable];
    }
}

- (void)updateWithConfig:(NSDictionary *)config
                  status:(NSDictionary *)status
              capability:(NSDictionary *)capability {
    BOOL enabled = [config[@"enabled"] boolValue];
    BOOL injected = [status[@"injected"] boolValue];
    NSString *source = config[@"source"] ?: @"none";

    NSString *stateText;
    UIColor *stateColor;

    if (!injected) {
        stateText = @"Not Injected";
        stateColor = [UIColor systemRedColor];
    } else if (!enabled) {
        stateText = @"Disabled";
        stateColor = [UIColor systemYellowColor];
    } else if ([source isEqualToString:@"stream"]) {
        NSDictionary *server = [VCNConfig serverStatus];
        NSString *sState = server[@"state"] ?: @"idle";
        if ([sState isEqualToString:@"listening"]) {
            stateText = @"Stream: Listening";
            stateColor = [UIColor systemBlueColor];
        } else if ([sState isEqualToString:@"streaming"]) {
            stateText = @"Stream: Live";
            stateColor = [UIColor systemGreenColor];
        } else {
            stateText = [NSString stringWithFormat:@"Stream: %@", sState.capitalizedString];
            stateColor = [UIColor systemOrangeColor];
        }
    } else {
        stateText = @"Active: Media";
        stateColor = [UIColor systemGreenColor];
    }

    _statusLabel.text = [NSString stringWithFormat:@"VCam: %@", stateText];
    _statusLabel.textColor = stateColor;

    [_toggleBtn setTitle:enabled ? @" Disable" : @" Enable" forState:UIControlStateNormal];
    _toggleBtn.tintColor = enabled ? [UIColor systemRedColor] : [UIColor systemGreenColor];
}

@end
