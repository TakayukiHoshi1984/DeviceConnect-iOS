//
//  DPSpheroSystemProfile.m
//  dConnectDeviceSphero
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPSpheroSystemProfile.h"
#import "DPSpheroManager.h"
#import "DPSpheroDevicePlugin.h"

@implementation DPSpheroSystemProfile

// 初期化
- (id)init
{
    self = [super init];
    if (self) {
        self.dataSource = self;
        self.delegate = self;
    }
    return self;
}

// デバイスプラグインのバージョン
- (NSString *) versionOfSystemProfile:(DConnectSystemProfile *)profile
{
    return @"1.0.0";
}

// デバイスプラグインの設定画面用のUIViewControllerを要求する
- (UIViewController *) profile:(DConnectSystemProfile *)sender
         settingPageForRequest:(DConnectRequestMessage *)request
{
    
    // 設定画面用のViewControllerをStoryboardから生成する
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"dConnectDeviceSphero_resources" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    
    UIStoryboard *storyBoard;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        storyBoard = [UIStoryboard storyboardWithName:@"SpheroDevicePlugin_iPhone" bundle:bundle];
    } else{
        storyBoard = [UIStoryboard storyboardWithName:@"SpheroDevicePlugin_iPad" bundle:bundle];
    }
    return [storyBoard instantiateInitialViewController];
}

// イベント一括解除リクエストを受け取った
- (BOOL)                  profile:(DConnectSystemProfile *)profile
    didReceiveDeleteEventsRequest:(DConnectRequestMessage *)request
                         response:(DConnectResponseMessage *)response
                       sessionKey:(NSString *)sessionKey
{
    DConnectEventManager *eventMgr = [DConnectEventManager sharedManagerForClass:[DPSpheroDevicePlugin class]];
    if ([eventMgr removeEventsForSessionKey:sessionKey]) {
        [response setResult:DConnectMessageResultTypeOk];
    } else {
        [response setErrorToUnknownWithMessage:
         @"Failed to remove events associated with the specified session key."];
    }
    return YES;
}

@end
