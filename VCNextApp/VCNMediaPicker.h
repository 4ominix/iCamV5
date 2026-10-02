#import <UIKit/UIKit.h>

@protocol VCNMediaPickerDelegate <NSObject>
- (void)mediaPicker:(id)picker didSelectMediaAtPath:(NSString *)path type:(NSString *)type;
- (void)mediaPickerDidCancel:(id)picker;
@end

@interface VCNMediaPicker : NSObject

@property (nonatomic, weak) id<VCNMediaPickerDelegate> delegate;
@property (nonatomic, weak) UIViewController *presentingViewController;

- (void)presentPhotoLibraryPicker;
- (void)presentFilePicker;
+ (NSArray<NSString *> *)savedMediaFiles;
+ (void)deleteMediaFile:(NSString *)filename;

@end
