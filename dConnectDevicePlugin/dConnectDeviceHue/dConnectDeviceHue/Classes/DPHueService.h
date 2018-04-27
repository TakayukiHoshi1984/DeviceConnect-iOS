//
//  DPHueService.h
//  dConnectDeviceHue
//
//  Copyright (c) 2016 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <DConnectSDK/DConnectService.h>
#import <DConnectSDK/DConnectFileManager.h>
#import <DConnectSDK/DConnectServiceInformationProfile.h>

@interface DPHueService : DConnectService<DConnectServiceInformationProfileDataSource>

- (instancetype) initWithBridgeIpAddress: (NSString *) ipAddress
                                uniqueId: (NSString *) uniqueId
                                  plugin: (id) plugin;
@end
