//
//  DPHueService.m
//  dConnectDeviceHue
//
//  Copyright (c) 2016 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHueService.h"
#import "DPHueLightProfile.h"

@implementation DPHueService

- (instancetype) initWithBridgeIpAddress: (NSString *) ipAddress
                                uniqueId: (NSString *) uniqueId
                                  plugin: (id) plugin {
    self = [super initWithServiceId:ipAddress plugin: plugin];
    if (self) {
        NSString *name = [NSString stringWithFormat:@"Hue %@", uniqueId];
        [self setName: name];
        [self setNetworkType: DConnectServiceDiscoveryProfileNetworkTypeWiFi];
        [self setOnline: YES];
        
        // プロファイルを追加
        [self addProfile:[DPHueLightProfile new]];
    }
    return self;
}
#pragma mark - DConnectServiceInformationProfileDataSource Implement.

- (DConnectServiceInformationProfileConnectState)profile:(DConnectServiceInformationProfile *)profile
                                   wifiStateForServiceId:(NSString *)serviceId {
    
    DConnectServiceInformationProfileConnectState wifiState;
    if (self.online) {
        wifiState = DConnectServiceInformationProfileConnectStateOn;
    } else {
        wifiState = DConnectServiceInformationProfileConnectStateOff;
    }
    return wifiState;
}

@end
