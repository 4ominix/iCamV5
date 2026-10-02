#import <UIKit/UIKit.h>

@interface VCNControlPanel : UIView

@property (nonatomic, copy) void (^commandHandler)(NSString *command);

- (void)updateWithConfig:(NSDictionary *)config
                  status:(NSDictionary *)status
              capability:(NSDictionary *)capability;
- (UIButton *)iconButton:(NSString *)systemName command:(NSString *)cmd label:(NSString *)label;
- (UIButton *)actionButtonWithTitle:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color;

@end
