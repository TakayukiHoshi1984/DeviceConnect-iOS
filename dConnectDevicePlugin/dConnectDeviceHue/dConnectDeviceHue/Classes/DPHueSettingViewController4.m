//
//  DPHueSettingViewController4.m
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//
#import "DPHueSettingViewController4.h"
#define PutPresentedViewController(top) \
top = [UIApplication sharedApplication].keyWindow.rootViewController; \
while (top.presentedViewController) { \
top = top.presentedViewController; \
}
// Storyboard で設定したidentifier
static NSString *DPHueCellIdentifier = @"cellLight";

@interface DPHueSettingViewController4 ()<PHSFindNewDevicesCallback>

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *lightSearchingIndicator;
@property (weak, nonatomic) IBOutlet UIView *indicator;

@property (weak, nonatomic) IBOutlet UITableView *foundLightListView;
@property (strong, nonatomic) NSString *serial;
@property (nonatomic, strong) NSArray<PHSDevice *> *foundDevices;
@property (weak, nonatomic) UIAlertAction *okAction;

- (IBAction)searchAutomatic:(id)sender;
- (IBAction)searchManual:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *autoSearchBtn;
@property (weak, nonatomic) IBOutlet UIButton *manualSearchBtn;


@end

@implementation DPHueSettingViewController4

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    self.foundDevices = [NSMutableArray array];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _foundLightListView.delegate = self;
    _foundLightListView.dataSource = self;
    [_foundLightListView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cellLight"];
    [_foundLightListView reloadData];
    if ([_foundLightListView respondsToSelector:@selector(setSeparatorInset:)]) {
        [_foundLightListView setSeparatorInset:UIEdgeInsetsZero];
    }
    void (^roundCorner)(UIView*) = ^void(UIView *v) {
        CALayer *layer = v.layer;
        layer.masksToBounds = YES;
        layer.cornerRadius = 4.;
    };
    roundCorner(_indicator);
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [manager getLightStatusForIpAddress:self.bridge.ipAddress].count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; // 選択状態の解除
}

// セルの生成と設定
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:DPHueCellIdentifier
                                    forIndexPath:indexPath];
    cell.exclusiveTouch = YES;
    cell.accessoryView.exclusiveTouch = YES;
    NSString * path = [_bundle pathForResource:@"hue_small_icon" ofType:@"png"];
    cell.imageView.image = [UIImage imageWithContentsOfFile:path];
    NSArray<PHSDevice*>* lights = [manager getLightStatusForIpAddress:self.bridge.ipAddress];
    int i = 0;
    
    for (PHSDevice *light in lights) {
        if (indexPath.row == i) {
            cell.textLabel.text = light.name;
            break;
        }
        i++;
    }
    return cell;
}

-(void)startIndicator
{
    _lightSearchingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [_lightSearchingIndicator.layer setValue:[NSNumber numberWithFloat:1.39f] forKeyPath:@"transform.scale"];

    [_lightSearchingIndicator startAnimating];
    _lightSearchingIndicator.hidden = NO;
    _autoSearchBtn.enabled = NO;
    _manualSearchBtn.enabled = NO;
    [super setCloseBtn:NO];
}

-(void)stopIndicator
{
    [_lightSearchingIndicator stopAnimating];
    _lightSearchingIndicator.hidden = YES;
    _autoSearchBtn.enabled = YES;
    _manualSearchBtn.enabled = YES;
    _indicator.hidden = YES;
    [super setCloseBtn:YES];
}


- (IBAction)searchAutomatic:(id)sender {
    _indicator.hidden = NO;
    [self startIndicator];
    [manager searchLightForIpAddress:self.bridge.ipAddress delegate:self];
}

- (IBAction)searchManual:(id)sender {
    UIAlertController *serialAlert = [UIAlertController alertControllerWithTitle:DPHueLocalizedString(_bundle, @"HueSerialNoTitle")
                                                                         message:DPHueLocalizedString(_bundle, @"HueSerialNoDesc")
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:nil];
    [serialAlert addAction:cancelAction];
    __weak typeof(self) _self = self;
    _okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        _self.indicator.hidden = NO;
        [_self startIndicator];
        NSArray *serials = @[_self.serial];
        [[DPHueManager sharedManager] registerLightsForSerialNo:serials ipAddress:_self.bridge.ipAddress delegate:_self];
    }];
    _okAction.enabled = NO;
    [serialAlert addAction:_okAction];

    [serialAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        textField.placeholder = DPHueLocalizedString(_bundle, @"HueSerialNoHint");
        textField.delegate = _self;
        textField.keyboardType = UIKeyboardTypeAlphabet;
    }];
    [self presentViewController:serialAlert animated:YES completion:nil];
}

- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSMutableString *text = [textField.text mutableCopy];
    [text replaceCharactersInRange:range withString:string];
    if ([text length] >= 6) {
        _okAction.enabled = YES;
        _serial = text;
    }
    return ([text length] <= 6);
}



- (void)bridge:(PHSBridge*)bridge didFindDevices:(NSArray<PHSDevice *> *)devices errors:(NSArray<PHSError *> *)errors {
    if (errors) {
        [self stopIndicator];
         [self showAleart:errors[0].description];
        return;
    }
    for (PHSDevice *header in devices) {
        BOOL duplicated = NO;
        for (PHSDevice *cache in self.foundDevices) {
            if ([cache.identifier isEqualToString:header.identifier]) {
                duplicated = YES;
                break;
            }
        }
        if (!duplicated) {
            [self.foundDevices arrayByAddingObject:header];
        }
    }
}

- (void)bridge:(PHSBridge*)bridges didFinishSearch:(NSArray<PHSError *> *)errors {
    __weak typeof(self) _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [_self.foundLightListView reloadData];
        [_self stopIndicator];
        if (self.foundDevices.count > 0) {
            NSString *successMessage = [DPHueLocalizedString(_bundle, @"HueSearchLight")
                                        stringByAppendingFormat:DPHueLocalizedString(_bundle, @"HueSearchHitLight"),
                                        _self.foundDevices.count];
            [_self showAleart:successMessage];
        } else {
            [_self showAleart:DPHueLocalizedString(_bundle, @"HueSearchLightOld")];
        }
    });
}
@end
