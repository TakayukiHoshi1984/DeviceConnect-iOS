//
//  SonyCameraDevicePlugin.m
//  dConnectDeviceSonyCamera
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "SonyCameraDevicePlugin.h"
#import "SonyCameraViewController.h"
#import "SonyCameraService.h"
#import "SonyCameraManager.h"
#import "SonyCameraSystemProfile.h"
#import "SonyCameraMediaStreamRecordingProfile.h"
#import <SystemConfiguration/CaptiveNetwork.h>

/*!
 @brief Sony Remote Camera用デバイスプラグイン。
 */
@interface SonyCameraDevicePlugin() <SonyCameraManagerDelegate>

/*!
 @brief 1970/1/1からの時間を取得する。
 @return 時間
 */
- (UInt64) getEpochMilliSeconds;

/*!
 @brief 現在接続されているWifiのSSIDからSony Cameraかチェックする.
 @retval YES Sony Cameraの場合
 @retval NO Sony Camera以外
 */
- (BOOL) checkSSID;

@end


#pragma mark - SonyCameraDevicePlugin

@implementation SonyCameraDevicePlugin

- (instancetype) init {
    self = [super initWithObject: self];
    if (self) {
        Class key = [self class];
        [[DConnectEventManager sharedManagerForClass:key] setController:[DConnectMemoryCacheController new]];

        self.pluginName = @"Sony Camera (Device Connect Device Plug-in)";

        self.sonyCameraManager = [[SonyCameraManager alloc] initWithPlugin:self];
        self.sonyCameraManager.delegate = self;
        
        [self.sonyCameraManager setPlugin:self];
        [self addProfile:[SonyCameraSystemProfile new]];
        
        if ([self checkSSID]) {
            [self.sonyCameraManager connectSonyCamera];
        }
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            UIApplication *application = [UIApplication sharedApplication];
            [notificationCenter addObserver:weakSelf
                                   selector:@selector(applicationWillEnterForeground)
                                       name:UIApplicationWillEnterForegroundNotification
                                     object:application];
        });
    }
    return self;
}

- (BOOL) isConnectedSonyCamera {
    return [self checkSSID];
}

#pragma mark - Private Methods

- (UInt64) getEpochMilliSeconds
{
    return (UInt64)floor((CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) * 1000.0);
}

- (BOOL) checkSSID {
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (!interfaces) return NO;
    if (CFArrayGetCount(interfaces)==0) return NO;
    CFDictionaryRef dicRef = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(interfaces, 0));
    if (dicRef) {
        NSString *ssid = CFDictionaryGetValue(dicRef, kCNNetworkInfoKeySSID);
        if ([ssid hasPrefix:@"DIRECT-"]) {
            NSArray *array = @[@"HDR-AS100", @"ILCE-6000", @"DSC-HC60V", @"DSC-HX400",
                               @"ILCE-5000", @"DSC-QX10", @"DSC-QX100", @"HDR-AS15",
                               @"HDR-AS30", @"HDR-MV1", @"NEX-5R", @"NEX-5T", @"NEX-6",
                               @"ILCE-7R/B", @"ILCE-7/B"];
            for (NSString *name in array) {
                NSRange searchResult = [ssid rangeOfString:name];
                if (searchResult.location != NSNotFound) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

#pragma mark - SonyCameraManagerDelegate Methods

- (void) didDiscoverDeviceList:(BOOL)discovery {
    [self.delegate didReceiveDeviceList:discovery];
}

- (void) didTakePicture:(NSString *)postImageUrl {
    SonyCameraManager *manager = self.sonyCameraManager;
    
    NSString *ssid = [manager getCurrentWifiName];
    
    // イベント作成
    DConnectMessage *photo = [DConnectMessage message];
    [DConnectMediaStreamRecordingProfile setUri:postImageUrl target:photo];
    [DConnectMediaStreamRecordingProfile setPath:[postImageUrl lastPathComponent] target:photo];
    [DConnectMediaStreamRecordingProfile setMIMEType:@"image/png" target:photo];
    
    // イベントの取得
    DConnectEventManager *mgr = [DConnectEventManager sharedManagerForClass:[self class]];
    NSArray *evts = [mgr eventListForServiceId:ssid
                                       profile:DConnectMediaStreamRecordingProfileName
                                     attribute:DConnectMediaStreamRecordingProfileAttrOnPhoto];
    // イベント送信
    for (DConnectEvent *evt in evts) {
        DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
        [eventMsg setMessage:photo forKey:DConnectMediaStreamRecordingProfileParamPhoto];
        [manager.plugin sendEvent:eventMsg];
    }
}

- (void) didAddedService:(SonyCameraService *)service {
    [self.serviceProvider addService:service];
}

#pragma mark - DConnectDevicePlugin Methods

- (void) applicationWillEnterForeground
{
    if ([self checkSSID]) {
        [self.sonyCameraManager connectSonyCamera];
    } else {
        [self.sonyCameraManager disconnectSonyCamera];
    }
}

- (NSString*)iconFilePath:(BOOL)isOnline
{
    NSBundle *bundle = DPSonyCameraBundle();
    NSString* filename = isOnline ? @"dconnect_icon" : @"dconnect_icon_off";
    return [bundle pathForResource:filename ofType:@"png"];
}

@end
