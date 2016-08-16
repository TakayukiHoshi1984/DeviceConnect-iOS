//
//  DPChromecastSystemProfile.m
//  dConnectDeviceChromeCast
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPChromecastSystemProfile.h"
#import "DPChromecastDevicePlugin.h"

@implementation DPChromecastSystemProfile

- (id)init
{
    self = [super init];
    if (self) {
        self.dataSource = self;
        self.delegate = self;
        __weak DPChromecastSystemProfile *weakSelf = self;
        
        // API登録(dataSourceのsettingPageForRequestを実行する処理を登録)
        NSString *putSettingPageForRequestApiPath = [self apiPath: DConnectSystemProfileInterfaceDevice
                                                    attributeName: DConnectSystemProfileAttrWakeUp];
        [self addPutPath: putSettingPageForRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         
                         BOOL send = [weakSelf didReceivePutWakeupRequest:request response:response];
                         return send;
                     }];
        
        // API登録(didReceiveDeleteEventsRequest相当)
        NSString *deleteEventsRequestApiPath = [self apiPath: nil
                                               attributeName: DConnectSystemProfileAttrEvents];
        [self addDeletePath: deleteEventsRequestApiPath
                        api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                            
                            NSString *sessionKey = [request sessionKey];
                            
                            DConnectEventManager *eventMgr = [DConnectEventManager sharedManagerForClass:[DPChromecastDevicePlugin class]];
                            if ([eventMgr removeEventsForSessionKey:sessionKey]) {
                                [response setResult:DConnectMessageResultTypeOk];
                            } else {
                                [response setErrorToUnknownWithMessage:
                                 @"Failed to remove events associated with the specified session key."];
                            }
                            
                            return YES;
                        }];
    }
    return self;
}

// デバイスプラグインのバージョン
-(NSString *) versionOfSystemProfile:(DConnectSystemProfile *)profile
{
    return @"2.0.0";
}

// デバイスプラグインの設定画面用のUIViewControllerを要求する
-(UIViewController *) profile:(DConnectSystemProfile *)sender
        settingPageForRequest:(DConnectRequestMessage *)request
{
    // 設定画面用のViewControllerをStoryboardから生成する
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"dConnectDeviceChromecast_resources" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    
    UIStoryboard *storyBoard;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        storyBoard = [UIStoryboard storyboardWithName:@"Chromecast_iPhone" bundle:bundle];
    } else {
        storyBoard = [UIStoryboard storyboardWithName:@"Chromecast_iPad" bundle:bundle];
    }
    return [storyBoard instantiateInitialViewController];
}


@end
