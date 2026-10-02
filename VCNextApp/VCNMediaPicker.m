#import "VCNMediaPicker.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "VCNPaths.h"
#import "VCNConfig.h"

@interface VCNMediaPicker () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
@end

@implementation VCNMediaPicker

- (void)presentPhotoLibraryPicker {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
        [PHPickerFilter imagesFilter],
        [PHPickerFilter videosFilter],
    ]];

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self.presentingViewController presentViewController:picker animated:YES completion:nil];
}

- (void)presentFilePicker {
    NSArray *types = @[UTTypeImage, UTTypeMovie, UTTypeVideo];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
                                               initForOpeningContentTypes:types];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self.presentingViewController presentViewController:picker animated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        if ([self.delegate respondsToSelector:@selector(mediaPickerDidCancel:)])
            [self.delegate mediaPickerDidCancel:self];
        return;
    }

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;

    if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
        [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier
                                       completionHandler:^(NSURL *url, NSError *error) {
            if (!url) return;
            [self copyMediaFromURL:url type:@"video"];
        }];
    } else if ([provider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
        [provider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier
                                       completionHandler:^(NSURL *url, NSError *error) {
            if (!url) return;
            [self copyMediaFromURL:url type:@"image"];
        }];
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSString *ext = url.pathExtension.lowercaseString;
    NSSet *videoExts = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"mkv"]];
    NSString *type = [videoExts containsObject:ext] ? @"video" : @"image";

    [url startAccessingSecurityScopedResource];
    [self copyMediaFromURL:url type:type];
    [url stopAccessingSecurityScopedResource];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if ([self.delegate respondsToSelector:@selector(mediaPickerDidCancel:)])
        [self.delegate mediaPickerDidCancel:self];
}

#pragma mark - Helpers

- (void)copyMediaFromURL:(NSURL *)sourceURL type:(NSString *)type {
    [VCNConfig ensureDirectoryExists:VCNMediaDirectory];

    NSString *filename = [NSString stringWithFormat:@"vcn_%lld.%@",
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000),
                          sourceURL.pathExtension ?: @"dat"];

    NSString *destPath = [VCNMediaDirectory stringByAppendingPathComponent:filename];
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtPath:sourceURL.path toPath:destPath error:&error];

    if (!error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(mediaPicker:didSelectMediaAtPath:type:)])
                [self.delegate mediaPicker:self didSelectMediaAtPath:destPath type:type];
        });
    }
}

+ (NSArray<NSString *> *)savedMediaFiles {
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:VCNMediaDirectory error:&error];
    if (error) return @[];

    NSMutableArray *sorted = [NSMutableArray array];
    for (NSString *file in files) {
        if ([file hasPrefix:@"."]) continue;
        [sorted addObject:file];
    }
    [sorted sortUsingSelector:@selector(compare:)];
    return sorted;
}

+ (void)deleteMediaFile:(NSString *)filename {
    NSString *path = [VCNMediaDirectory stringByAppendingPathComponent:filename];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end
