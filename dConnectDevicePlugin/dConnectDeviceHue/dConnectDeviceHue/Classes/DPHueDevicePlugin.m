//
//  dConnectDeviceHue.m
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHueDevicePlugin.h"
#import "DPHueSystemProfile.h"
#import "DPHueManager.h"
#import "DPHueConst.h"
#import "DPHueService.h"

NSString *const DPHueBundleName = @"dConnectDeviceHue_resources";


@interface DPHueDevicePlugin()<DPHueBridgeControllerDelegate, PHSFindNewDevicesCallback>
@end
@implementation DPHueDevicePlugin

- (id) init {
    
    self = [super initWithObject: self];
    
    if (self) {
        
        [[DPHueManager sharedManager] setServiceProvider: self.serviceProvider];
        [[DPHueManager sharedManager] setPlugin: self];
        
        self.pluginName = @"hue (Device Connect Device Plug-in)";
        
        [self addProfile:[DPHueSystemProfile new]];
        
        __weak typeof(self) _self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            UIApplication *application = [UIApplication sharedApplication];

            [notificationCenter addObserver:_self selector:@selector(enterForeground)
                       name:UIApplicationWillEnterForegroundNotification
                     object:application];
            [notificationCenter addObserver:_self selector:@selector(enterForeground)
                                       name:UIApplicationDidBecomeActiveNotification
                                     object:application];

            [notificationCenter addObserver:_self selector:@selector(enterBackground)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:application];
        });
    }
    
    return self;
}

- (void) dealloc {
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    UIApplication *application = [UIApplication sharedApplication];
    
    [notificationCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:application];
    [notificationCenter removeObserver:self name:UIApplicationDidBecomeActiveNotification object:application];
    [notificationCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:application];
}
/*!
 @brief バックグラウンドに回ったときの処理
 */
- (void) enterBackground {
//    [[DPHueManager sharedManager] saveBridgeList];
}
/*!
 @brief フォアグラウンドに戻ったときの処理。
        すでにHueブリッジと認証されている場合、プロセスキル後にForegroundになった場合自動で再接続を行う。
 */
- (void) enterForeground {
    __weak typeof(self) _self = self;
    [[DPHueManager sharedManager] startBridgeDiscoveryWithCompletion:^(NSDictionary<NSString *,PHSBridgeDiscoveryResult *> *results) {
        for (id key in [results keyEnumerator]) {
            DConnectService *service = [self.serviceProvider service: key];
            PHSBridgeDiscoveryResult *result = results[key];
            if (!service) {
                service = [[DPHueService alloc] initWithBridgeIpAddress:result.ipAddress uniqueId:result.uniqueId plugin:_self];
                [self.serviceProvider addService: service];
            }

            [[DPHueManager sharedManager] connectForIPAddress:result.ipAddress uniqueId:result.uniqueId delegate:_self];
        }
    }];
}

- (void)didPushlinkBridgeWithIpAddress:(NSString*)ipAddress {
    [[DPHueManager sharedManager] disconnectForIPAddress:ipAddress];
}
- (void)didConnectedWithIpAddress:(NSString*)ipAddress {
    DPHueManager *manager = [DPHueManager sharedManager];
    NSArray<PHSDevice*>* devices = [manager getLightStatusForIpAddress:ipAddress];
    if (devices.count == 0) {
        [manager searchLightForIpAddress:ipAddress delegate:nil];
    }
}
- (void)didDisconnectedWithIpAddress:(NSString*)ipAddress {
}
- (void)didErrorWithIpAddress:(NSString*)ipAddress errors:(NSArray<PHSError *> *)errors {
}

- (void)bridge:(PHSBridge*)bridge didFindDevices:(NSArray<PHSDevice *> *)devices errors:(NSArray<PHSError *> *)errors {
}

- (void)bridge:(PHSBridge*)bridge didFinishSearch:(NSArray<PHSError *> *)errors {
    NSString *ipAddress = bridge.bridgeConfiguration.networkConfiguration.ipAddress;
    [[DPHueManager sharedManager] updateManageServicesForIpAddress:ipAddress online:YES];
}

- (NSString*)iconFilePath:(BOOL)isOnline
{
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"dConnectDeviceHue_resources" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString* filename = isOnline ? @"dconnect_icon" : @"dconnect_icon_off";
    return [bundle pathForResource:filename ofType:@"png"];
}



#pragma mark - DevicePlugin's bundle
- (NSBundle*)pluginBundle
{
    return [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"dConnectDeviceHue_resources" ofType:@"bundle"]];
}
@end
