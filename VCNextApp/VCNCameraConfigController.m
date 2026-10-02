#import "VCNCameraConfigController.h"
#import "VCNConfig.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"

typedef NS_ENUM(NSInteger, VCNCameraSection) {
    VCNCameraSectionSource = 0,
    VCNCameraSectionColorSync,
    VCNCameraSectionFaceDetection,
    VCNCameraSectionCount,
};

@interface VCNCameraConfigController ()
@property (nonatomic, strong) NSMutableDictionary *config;
@end

@implementation VCNCameraConfigController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Camera Config";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self loadConfig];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                              target:self action:@selector(saveConfig)];
}

- (void)loadConfig {
    NSDictionary *saved = [VCNConfig cameraConfig];
    self.config = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)saveConfig {
    [VCNConfig setCameraConfig:self.config];
    VCNPostDarwinNotification(VCNCameraConfigChangedNotification);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Saved"
                                                                  message:@"Camera configuration updated"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return VCNCameraSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case VCNCameraSectionSource: return @"Media Source";
        case VCNCameraSectionColorSync: return @"Color Sync";
        case VCNCameraSectionFaceDetection: return @"Face Detection";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case VCNCameraSectionSource: return 3;
        case VCNCameraSectionColorSync: return 5;
        case VCNCameraSectionFaceDetection: return 2;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    switch (indexPath.section) {
        case VCNCameraSectionSource: {
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"Enabled";
                    UISwitch *sw = [[UISwitch alloc] init];
                    sw.on = [self.config[@"enabled"] boolValue];
                    sw.tag = 100;
                    [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = sw;
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"Source Type";
                    cell.detailTextLabel.text = self.config[@"sourceType"] ?: @"image";
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    break;
                }
                case 2: {
                    cell.textLabel.text = @"Media Path";
                    NSString *path = self.config[@"mediaPath"];
                    cell.detailTextLabel.text = path ? [path lastPathComponent] : @"None";
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    break;
                }
            }
            break;
        }
        case VCNCameraSectionColorSync: {
            NSArray *labels = @[@"Enabled", @"Red Shift", @"Green Shift", @"Blue Shift", @"Region"];
            cell.textLabel.text = labels[indexPath.row];
            if (indexPath.row == 0) {
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = [self.config[@"colorSyncEnabled"] boolValue];
                sw.tag = 200;
                [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
            } else if (indexPath.row <= 3) {
                NSArray *keys = @[@"", @"redShift", @"greenShift", @"blueShift"];
                NSNumber *val = self.config[keys[indexPath.row]];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f", val ? val.floatValue : 0.0f];
            } else {
                cell.detailTextLabel.text = self.config[@"colorRegion"] ?: @"Full";
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
            break;
        }
        case VCNCameraSectionFaceDetection: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Face Blur";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = [self.config[@"faceBlurEnabled"] boolValue];
                sw.tag = 300;
                [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
            } else {
                cell.textLabel.text = @"Blur Radius";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f",
                                             [self.config[@"blurRadius"] floatValue] ?: 20.0f];
            }
            break;
        }
    }

    return cell;
}

- (void)switchToggled:(UISwitch *)sw {
    switch (sw.tag) {
        case 100: self.config[@"enabled"] = @(sw.on); break;
        case 200: self.config[@"colorSyncEnabled"] = @(sw.on); break;
        case 300: self.config[@"faceBlurEnabled"] = @(sw.on); break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == VCNCameraSectionSource && indexPath.row == 1) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Source Type"
                                                                      message:nil
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSString *type in @[@"image", @"video", @"stream"]) {
            [alert addAction:[UIAlertAction actionWithTitle:type style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.config[@"sourceType"] = type;
                [self.tableView reloadData];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }

    if (indexPath.section == VCNCameraSectionColorSync && indexPath.row == 4) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Color Region"
                                                                      message:nil
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSString *region in @[@"Full", @"Forehead", @"Chin", @"Sides"]) {
            [alert addAction:[UIAlertAction actionWithTitle:region style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.config[@"colorRegion"] = region;
                [self.tableView reloadData];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end
