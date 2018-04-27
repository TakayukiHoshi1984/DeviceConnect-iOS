//
//  DPHueSystemProfile.m
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHueSystemProfile.h"
#import <DConnectSDK/DConnectServiceListViewController.h>
#import "DPHueManager.h"
#import "DPHueService.h"
#define DCBundle() \
[NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"DConnectSDK_resources" ofType:@"bundle"]]
@implementation DPHueSystemProfile
- (id)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        
        __weak DPHueSystemProfile *weakSelf = self;
        
        // API登録(dataSourceのsettingPageForRequestを実行する処理を登録)
        NSString *putSettingPageForRequestApiPath = [self apiPath: DConnectSystemProfileInterfaceDevice
                                                    attributeName: DConnectSystemProfileAttrWakeUp];
        [self addPutPath: putSettingPageForRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         
                         BOOL send = [weakSelf didReceivePutWakeupRequest:request response:response];
                         return send;
                     }];
    }
    return self;
}

#pragma mark - DConnectSystemProfileDatasource

- (UIViewController *) profile:(DConnectSystemProfile *)sender
         settingPageForRequest:(DConnectRequestMessage *)request
{
    UIStoryboard *storyBoard;
    storyBoard = [UIStoryboard storyboardWithName:@"DConnectSDK-iPhone"
                                           bundle:DCBundle()];
    UINavigationController *top = [storyBoard instantiateViewControllerWithIdentifier:@"ServiceList"];
    DConnectServiceListViewController *serviceListViewController = (DConnectServiceListViewController *) top.viewControllers[0];
    serviceListViewController.delegate = self;
    return top;
}
#pragma mark - DConnectSystemProfileDelegate
- (DConnectServiceProvider *)serviceProvider {
    return ((DConnectDevicePlugin *)self.plugin).serviceProvider;
}

- (UIViewController *)settingViewController {
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"dConnectDeviceHue_resources" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    
    UIStoryboard *storyBoard;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        storyBoard = [UIStoryboard storyboardWithName:@"HueSetting_iPhone" bundle:bundle];
    } else{
        storyBoard = [UIStoryboard storyboardWithName:@"HueSetting_iPad" bundle:bundle];
    }
    return [storyBoard instantiateInitialViewController];
}

- (void)didRemovedService:(DConnectService *)service
{
    NSArray *arr = [service.serviceId componentsSeparatedByString:@"_"];
    if (arr.count == 1) {
        NSArray<PHSDevice*>* devices = [[DPHueManager sharedManager] getLightStatusForIpAddress:service.serviceId];
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                            for (PHSDevice *device in devices) {
                                NSString *lightServiceId = [NSString stringWithFormat:@"%@_%@", service.serviceId, device.identifier];
                                DConnectService *removed = [[self serviceProvider] service:lightServiceId];
                                if (removed) {
                                    [[self serviceProvider] removeService:removed];
                                }
                            }
                       });
        // ブリッジが削除された後も、ブリッジだけはDConnectServiceとして登録しておくようにする
        [[DPHueManager sharedManager] startBridgeDiscoveryWithCompletion:^(NSDictionary<NSString *,PHSBridgeDiscoveryResult *> *results) {
            for (id key in [results keyEnumerator]) {
                DConnectService *service = [self.serviceProvider service: key];
                PHSBridgeDiscoveryResult *result = results[key];
                if (!service) {
                    service = [[DPHueService alloc] initWithBridgeIpAddress:result.ipAddress uniqueId:result.uniqueId plugin:self.plugin];
                    [self.serviceProvider addService: service];
                }
                [service setOnline:NO];
            }
        }];

    }
}

@end
