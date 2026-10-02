#import "VCNMainViewController.h"
#import "VCNAccountManager.h"
#import "VCNMediaPicker.h"
#import "VCNCameraConfigController.h"
#import "VCNConfig.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"

typedef NS_ENUM(NSInteger, VCNMainSection) {
    VCNMainSectionAccount = 0,
    VCNMainSectionCamera,
    VCNMainSectionMedia,
    VCNMainSectionServer,
    VCNMainSectionCount,
};

@interface VCNMainViewController () <VCNMediaPickerDelegate>
@property (nonatomic, strong) VCNMediaPicker *mediaPicker;
@property (nonatomic, strong) NSDictionary *serverStatus;
@property (nonatomic, strong) NSDictionary *capabilityLease;
@end

@implementation VCNMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"VcamNextPlus";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.mediaPicker = [[VCNMediaPicker alloc] init];
    self.mediaPicker.delegate = self;
    self.mediaPicker.presentingViewController = self;

    [self refreshStatus];

    VCNObserveDarwinNotification(VCNAuthSessionChangedNotification, statusChangedCB, (__bridge const void *)self);
    VCNObserveDarwinNotification(VCNCameraConfigChangedNotification, statusChangedCB, (__bridge const void *)self);
    VCNObserveDarwinNotification(VCNCapabilityChangedNotification, statusChangedCB, (__bridge const void *)self);
    VCNObserveDarwinNotification(VCNServerStatusChangedNotification, statusChangedCB, (__bridge const void *)self);

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshPulled) forControlEvents:UIControlEventValueChanged];
}

- (void)dealloc {
    VCNRemoveDarwinObserver((__bridge const void *)self);
}

static void statusChangedCB(CFNotificationCenterRef center, void *observer,
                             CFNotificationName name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        VCNMainViewController *vc = (__bridge VCNMainViewController *)observer;
        [vc refreshStatus];
        [vc.tableView reloadData];
    });
}

- (void)refreshPulled {
    [self refreshStatus];
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)refreshStatus {
    self.serverStatus = [VCNConfig serverStatus];
    self.capabilityLease = [VCNConfig capabilityLease];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return VCNMainSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case VCNMainSectionAccount: return @"Account";
        case VCNMainSectionCamera: return @"Camera";
        case VCNMainSectionMedia: return @"Media";
        case VCNMainSectionServer: return @"Server Status";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case VCNMainSectionAccount: return [VCNAccountManager shared].isLoggedIn ? 2 : 1;
        case VCNMainSectionCamera: return 2;
        case VCNMainSectionMedia: return 2;
        case VCNMainSectionServer: return 3;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"main"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"main"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];

    switch (indexPath.section) {
        case VCNMainSectionAccount: {
            if ([VCNAccountManager shared].isLoggedIn) {
                if (indexPath.row == 0) {
                    cell.textLabel.text = @"Logged in as";
                    cell.detailTextLabel.text = [VCNAccountManager shared].username;
                } else {
                    cell.textLabel.text = @"Log Out";
                    cell.textLabel.textColor = [UIColor systemRedColor];
                }
            } else {
                cell.textLabel.text = @"Log In";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
        case VCNMainSectionCamera: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Camera Status";
                NSDictionary *camStatus = [VCNConfig cameraStatus];
                cell.detailTextLabel.text = [camStatus[@"active"] boolValue] ? @"Active" : @"Inactive";
            } else {
                cell.textLabel.text = @"Camera Config";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
        case VCNMainSectionMedia: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Import from Photos";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"Import from Files";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
        case VCNMainSectionServer: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"RTMP Server";
                    cell.detailTextLabel.text = self.serverStatus[@"state"] ?: @"unknown";
                    break;
                case 1:
                    cell.textLabel.text = @"Port";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", self.serverStatus[@"port"] ?: @1935];
                    break;
                case 2:
                    cell.textLabel.text = @"Capability";
                    cell.detailTextLabel.text = [self.capabilityLease[@"streamEnabled"] boolValue] ? @"Granted" : @"None";
                    break;
            }
            break;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case VCNMainSectionAccount: {
            if ([VCNAccountManager shared].isLoggedIn && indexPath.row == 1) {
                [[VCNAccountManager shared] logout];
                [tableView reloadData];
            } else if (![VCNAccountManager shared].isLoggedIn) {
                [self showLoginDialog];
            }
            break;
        }
        case VCNMainSectionCamera: {
            if (indexPath.row == 1) {
                VCNCameraConfigController *configVC = [[VCNCameraConfigController alloc] initWithStyle:UITableViewStyleGrouped];
                [self.navigationController pushViewController:configVC animated:YES];
            }
            break;
        }
        case VCNMainSectionMedia: {
            if (indexPath.row == 0) {
                [self.mediaPicker presentPhotoLibraryPicker];
            } else {
                [self.mediaPicker presentFilePicker];
            }
            break;
        }
    }
}

#pragma mark - Login

- (void)showLoginDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Login"
                                                                  message:@"Enter your credentials"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Username";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Password";
        tf.secureTextEntry = YES;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *user = alert.textFields[0].text;
        NSString *pass = alert.textFields[1].text;
        if (!user.length || !pass.length) return;

        [[VCNAccountManager shared] loginWithUsername:user password:pass completion:^(BOOL success, NSString *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.tableView reloadData];
                } else {
                    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                                     message:error ?: @"Login failed"
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                    [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:errAlert animated:YES completion:nil];
                }
            });
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - VCNMediaPickerDelegate

- (void)mediaPicker:(id)picker didSelectMediaAtPath:(NSString *)path type:(NSString *)type {
    NSMutableDictionary *config = [[VCNConfig cameraConfig] mutableCopy] ?: [NSMutableDictionary dictionary];
    config[@"mediaPath"] = path;
    config[@"sourceType"] = type;
    [VCNConfig setCameraConfig:config];
    VCNPostDarwinNotification(VCNCameraConfigChangedNotification);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Media Imported"
                                                                  message:[path lastPathComponent]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)mediaPickerDidCancel:(id)picker {
    // nothing
}

@end
