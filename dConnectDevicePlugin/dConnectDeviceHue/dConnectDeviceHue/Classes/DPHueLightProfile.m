//
//  DPHueLightProfile.m
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHueLightProfile.h"

@implementation DPHueLightProfile
- (id)init
{
    self = [super init];
    if (self) {
        
        __weak DPHueLightProfile *weakSelf = self;
        
        // API登録(didReceiveGetLightRequest相当)
        NSString *getLightRequestApiPath = [self apiPath: nil
                                           attributeName: nil];
        [self addGetPath: getLightRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         NSString *serviceId = [request serviceId];
                         if (!serviceId) {
                             [response setErrorToEmptyServiceId];
                             return YES;
                         }
                         NSArray *arr = [serviceId componentsSeparatedByString:@"_"];
                         NSString *lightId = nil;
                         if (arr.count == 2) {
                             serviceId = arr[0];
                             lightId = arr[1];
                         }
                         NSArray<PHSDevice*> *lightList = [[DPHueManager sharedManager] getLightStatusForIpAddress:serviceId];
                         DConnectArray *lights = [DConnectArray array];
                         if (!lightId) {
                             for (PHSDevice *light in lightList) {
                                 PHSLightPoint* lightPoint = (PHSLightPoint*)light;
                                 
                                 //ライトの状態をメッセージにセットする（LightID,名前,点灯状態）
                                 DConnectMessage *led = [DConnectMessage new];
                                 [DConnectLightProfile setLightId:lightPoint.identifier target:led];
                                 [DConnectLightProfile setLightName:lightPoint.name target:led];
                                 [DConnectLightProfile setLightOn:[lightPoint.lightState.on boolValue] target:led];
                                 [DConnectLightProfile setLightConfig:@"" target:led];
                                 
                                 [lights addMessage:led];
                             }
                         } else {
                             for (PHSDevice *light in lightList) {
                                 PHSLightPoint* lightPoint = (PHSLightPoint*)light;
                                 if ([lightPoint.identifier isEqualToString:lightId]) {
                                     //ライトの状態をメッセージにセットする（LightID,名前,点灯状態）
                                     DConnectMessage *led = [DConnectMessage new];
                                     [DConnectLightProfile setLightId:lightPoint.identifier target:led];
                                     [DConnectLightProfile setLightName:lightPoint.name target:led];
                                     [DConnectLightProfile setLightOn:[lightPoint.lightState.on boolValue] target:led];
                                     [DConnectLightProfile setLightConfig:@"" target:led];
                                     
                                     [lights addMessage:led];
                                     break;
                                 }
                                 
                             }
                         }
                         [response setResult:DConnectMessageResultTypeOk];
                         [DConnectLightProfile setLights:lights target:response];
                         return YES;
                     }];
        
        // API登録(didReceivePostLightRequest相当)
        NSString *postLightRequestApiPath = [self apiPath: nil attributeName: nil];
        [self addPostPath: postLightRequestApiPath
                      api:^(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                          NSString *serviceId = [request serviceId];
                          NSString *lightId = [DConnectLightProfile lightIdFromRequest: request];
                          NSNumber *brightness = [DConnectLightProfile brightnessFromRequest: request];
                          NSString *color = [DConnectLightProfile colorFromRequest: request];
                          NSArray *flashing = [DConnectLightProfile parsePattern: [DConnectLightProfile flashingFromRequest: request] isId:NO];
                          
                          if (!flashing) {
                              [response setErrorToInvalidRequestParameterWithMessage:
                               @"Parameter 'flashing' invalid."];
                              return YES;
                          }

                          if (![weakSelf checkFlash:response flashing:flashing]) {
                              return YES;
                          }
                          
                          if (!serviceId) {
                              [response setErrorToEmptyServiceId];
                              return YES;
                          }
                          NSArray *arr = [serviceId componentsSeparatedByString:@"_"];
                          if (arr.count == 2) {
                              serviceId = arr[0];
                              lightId = arr[1];
                          }
                          // lightIdが省略された場合はデフォルトを使用
                          if (!lightId) {
                              lightId = [self getDefaultLightIdForIpAddress:serviceId];
                          }
                          
                          // brightフォーマットチェック
                          if ([weakSelf checkBrightness:[request stringForKey:DConnectLightProfileParamBrightness]]) {
                              [weakSelf setErrRespose:response];
                              return YES;
                          }

                          return [weakSelf turnOnOffHueLightWithResponse:response
                                                               ipAddress:serviceId
                                                                 lightId:lightId
                                                                    isOn:YES
                                                              brightness:brightness
                                                                flashing:flashing
                                                                   color:color];
                      }];
        
        // API登録(didReceivePutLightRequest相当)
        NSString *putLightRequestApiPath = [self apiPath: nil attributeName: nil];
        [self addPutPath: putLightRequestApiPath
                     api:^(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         
                         NSString *serviceId = [request serviceId];
                         NSString *lightId = [DConnectLightProfile lightIdFromRequest: request];
                         NSNumber *brightness = [DConnectLightProfile brightnessFromRequest: request];
                         NSString *name = [request stringForKey:DConnectLightProfileParamName];
                         NSString *color = [request stringForKey:DConnectLightProfileParamColor];
                         NSArray *flashing = [DConnectLightProfile parsePattern: [DConnectLightProfile flashingFromRequest: request] isId:NO];
                         if (!flashing) {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"Parameter 'flashing' invalid."];
                             return YES;
                         }
                         if (![weakSelf checkFlash:response flashing:flashing]) {
                             return YES;
                         }
                         
                         if (!serviceId) {
                             [response setErrorToEmptyServiceId];
                             return YES;
                         }
                         NSArray *arr = [serviceId componentsSeparatedByString:@"_"];
                         if (arr.count == 2) {
                             serviceId = arr[0];
                             lightId = arr[1];
                         }
                         // lightIdが省略された場合はデフォルトを使用
                         if (!lightId) {
                             lightId = [self getDefaultLightIdForIpAddress:serviceId];
                         }
                         
                         // nameが指定されてない場合はエラーで返す
                         if (![[DPHueManager sharedManager] checkParamRequiredStringItemWithParam:name errorState:STATE_ERROR_NO_NAME]) {
                             [weakSelf setErrRespose:response];
                             return YES;
                         }
                         
                         // brightフォーマットチェック
                         if ([weakSelf checkBrightness:[request stringForKey:DConnectLightProfileParamBrightness]]) {
                             [weakSelf setErrRespose:response];
                             return YES;
                         }

                         if (![[DPHueManager sharedManager] checkParamForIpAddress:serviceId lightId:lightId]) {
                             [weakSelf setErrRespose:response];
                             return YES;
                         }

                         return [[DPHueManager sharedManager] changeLightNameWithIpAddress:serviceId
                                                                                   lightId:lightId
                                                                                      name:name
                                                                                     color:color
                                                                                brightness:brightness
                                                                                  flashing:flashing
                                                                                completion:^{
                                                                                    [[DPHueManager sharedManager] updateManageServicesForIpAddress:serviceId online:YES];
                                                                                  [weakSelf setErrRespose:response];
                                                                                  [[DConnectManager sharedManager] sendResponse:response];
                                                                              }];
                     }];
        
        // API登録(didReceiveDeleteLightRequest相当)
        NSString *deleteLightRequestApiPath = [self apiPath: nil
                                              attributeName: nil];
        [self addDeletePath: deleteLightRequestApiPath
                        api:^(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                            NSString *serviceId = [request serviceId];
                            NSString *lightId = [DConnectLightProfile lightIdFromRequest: request];
                            
                            if (!serviceId) {
                                [response setErrorToEmptyServiceId];
                                return YES;
                            }
                            NSArray *arr = [serviceId componentsSeparatedByString:@"_"];
                            if (arr.count == 2) {
                                serviceId = arr[0];
                                lightId = arr[1];
                            }
                            // lightIdが省略された場合はデフォルトを使用
                            if (!lightId) {
                                lightId = [self getDefaultLightIdForIpAddress:serviceId];
                            }

                            return [weakSelf turnOnOffHueLightWithResponse:response
                                                                 ipAddress:serviceId
                                                                   lightId:lightId
                                                                      isOn:NO
                                                                brightness:[NSNumber numberWithDouble:0]
                                                                  flashing:nil
                                                                     color:nil];
                        }];
    }
    return self;
    
}


#pragma mark - private method

//デフォルトのlightIdを取得
- (NSString *) getDefaultLightIdForIpAddress:(NSString*)ipAddress {
    NSArray<PHSDevice*>* devices = [[DPHueManager sharedManager] getLightStatusForIpAddress:ipAddress];
    return devices[0].identifier;
}

// brightnessのフォーマットチェック
- (BOOL) checkBrightness:(NSString *)brightnessString {
    return (brightnessString && ![[DPHueManager sharedManager] isDigitWithString:brightnessString]);
}

//ライトのON/OFF
- (BOOL)turnOnOffHueLightWithResponse:(DConnectResponseMessage*)response
                            ipAddress:(NSString*)ipAddress
                              lightId:(NSString*)lightId
                                isOn:(BOOL)isOn
                          brightness:(NSNumber *)brightness
                             flashing:(NSArray*)flashing
                               color:(NSString*)color
{
    if (![[DPHueManager sharedManager] checkParamForIpAddress:ipAddress lightId:lightId]) {
        [self setErrRespose:response];
        return YES;
    }

    PHSLightState *lightState = [[DPHueManager sharedManager] getLightStateIsOn:isOn brightness:brightness color:color];
    if (lightState == nil) {
        [self setErrRespose:response];
        return YES;
    }
    
    return [[DPHueManager sharedManager] changeLightStatusWithIpAddress:ipAddress
                                                                lightId:lightId
                                                           lightState:lightState
                                                             flashing:flashing
                                                           completion:^ {
                                                               [self setErrRespose:response];
                                                               [[DConnectManager sharedManager] sendResponse:response];
                                                           }];
}



//エラーの振り分け
- (void) setErrRespose:(DConnectResponseMessage *)response {
    
    switch ([DPHueManager sharedManager].bridgeConnectState) {
        case STATE_INIT:
            [response setErrorToNotFoundServiceWithMessage:@"Not the response from the hue"];
            break;
        case STATE_NON_CONNECT:
            [response setErrorToNotFoundServiceWithMessage:@"Bridge not found"];
            break;
        case STATE_NOT_AUTHENTICATED:
            [response setErrorToNotFoundServiceWithMessage:
                @"It is not application registration, please register from the app settings screen"];
            break;
        case STATE_ERROR_NO_NAME:
            [response setErrorToInvalidRequestParameterWithMessage:@"Name after the change has not been specified"];
            break;
        case STATE_ERROR_NO_LIGHTID:
             [response setErrorToInvalidRequestParameterWithMessage:@"lightIds must be specified"];
            break;
        case STATE_ERROR_INVALID_LIGHTID:
            [response setErrorToInvalidRequestParameterWithMessage:@"lightIds is invalid"];
            break;
        case STATE_ERROR_INVALID_BRIGHTNESS:
            [response setErrorToInvalidRequestParameterWithMessage:@"brightness is invalid"];
            break;
        case STATE_ERROR_LIMIT_GROUP:
            [response setErrorToNotSupportProfileWithMessage:
                @"Hue has reached the upper limit to which the group can create"];
            break;
        case STATE_ERROR_CREATE_FAIL_GROUP:
            [response setErrorToUnknownWithMessage:@"Failed to create a group"];
            break;
        case STATE_ERROR_DELETE_FAIL_GROUP:
            [response setErrorToUnknownWithMessage:@"Failed to delete the group"];
            break;
        case STATE_ERROR_NOT_FOUND_LIGHT:
            [response setErrorToInvalidRequestParameterWithMessage:@"light not found"];
            break;
        case STATE_ERROR_NO_GROUPID:
            [response setErrorToInvalidRequestParameterWithMessage:@"groupId must be specified"];
            break;
        case STATE_ERROR_NOT_FOUND_GROUP:
            [response setErrorToInvalidRequestParameterWithMessage:@"group not found"];
            break;
        case STATE_ERROR_INVALID_COLOR:
            [response setErrorToInvalidRequestParameterWithMessage:@"color is invalid"];
            break;
        case STATE_ERROR_UPDATE_FAIL_LIGHT_STATE:
             [response setErrorToUnknownWithMessage:@"Failed to update the state of the light"];
            break;
        case STATE_ERROR_CHANGE_FAIL_LIGHT_NAME:
            [response setErrorToUnknownWithMessage:@"Failed to change the name of the light"];
            break;
        case STATE_ERROR_UPDATE_FAIL_GROUP_STATE:
            [response setErrorToUnknownWithMessage:@"Failed to update the state of the light group"];
            break;
        case STATE_ERROR_CHANGE_FAIL_GROUP_NAME:
            [response setErrorToUnknownWithMessage:@"Failed to change the name of the light group"];
            break;
        case STATE_CONNECT:
            [response setResult:DConnectMessageResultTypeOk];
            break;
        default:
            [response setErrorToUnknown];
            break;
    }
}

@end
