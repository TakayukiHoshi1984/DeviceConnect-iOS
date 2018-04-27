//
//  DPHueConst.h
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPHueManager.h"
#import "DPHueService.h"
#import "DPHueLightService.h"
#import "DPHueReachability.h"
#import "DPHueDeviceRepeatExecutor.h"

@interface DPHueManager()

@property (nonatomic, strong) NSMutableDictionary<NSString *, PHSBridge *> *bridges;
@property (nonatomic, strong) PHSBridgeDiscovery *bridgeDiscovery;
@property (nonatomic) NSString *currentIpAddress;
@property (nonatomic, weak) id<DPHueBridgeControllerDelegate> delegate;
@property (nonatomic) DPHueDeviceRepeatExecutor *flashingExecutor;
@end


@implementation DPHueManager

static NSString *const DPHueApName = @"DConnectDeviceHueiOS";
// 共有インスタンス
+ (instancetype)sharedManager
{
    static id sharedInstance;
    static dispatch_once_t onceHueToken;
    dispatch_once(&onceHueToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

// 初期化
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initHue];
    }
    return self;
}

//HueSDKの初期化
-(void)initHue
{
    [self configureSDK];
    self.bridges = [NSMutableDictionary dictionary];
    self.delegate = nil;
    self.currentIpAddress = nil;
    self.currentEvent = PHSBridgeConnectionEventNone;
}



- (void)configureSDK {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // Replace device id
    [PHSPersistence setStorageLocation:documentsDirectory andDeviceId:DPHueApName];
    
    [PHSLog setConsoleLogLevel:PHSLogLevelOff];
}


// ServiceProviderを登録 
- (void)setServiceProvider: (DConnectServiceProvider *) serviceProvider {
    self.mServiceProvider = serviceProvider;
}

#pragma mark - Discovery Bridges

- (void)startBridgeDiscoveryWithCompletion:(DPHueBridgeDiscoveryBlock)completionHandler
{
    [self stopBridgeDiscovery];
    self.bridgeDiscovery = [PHSBridgeDiscovery new];
    PHSBridgeDiscoveryOption options = PHSDiscoveryOptionUPNP | PHSDiscoveryOptionNUPNP | PHSDiscoveryOptionIPScan ;
    [self.bridgeDiscovery search:options withCompletionHandler:^(NSDictionary<NSString *,PHSBridgeDiscoveryResult *> *results, PHSReturnCode returnCode) {
       
        if (completionHandler) {
            completionHandler(results);
        }
    }];
}

- (void)stopBridgeDiscovery
{
    if (self.bridgeDiscovery) {
        [self.bridgeDiscovery stop];
        self.bridgeDiscovery = nil;
    }
}

#pragma mark - Bridge authentication

- (void)connectForIPAddress:(NSString*)ipAddress uniqueId:(NSString*)uniqueId delegate:(id<DPHueBridgeControllerDelegate>)delegate
{
    [self stopBridgeDiscovery];
    [self disconnectForIPAddress:ipAddress];
    self.delegate = delegate;
    PHSBridge *bridge = [self buildBridgeForIpAddress:ipAddress uniqueId:uniqueId];
    self.bridges[ipAddress] = bridge;
    self.currentIpAddress = ipAddress;
    
    [self updateManageServicesForIpAddress:ipAddress online:NO];
    [self.bridges[ipAddress] connect];
    
}

- (void)disconnectForIPAddress:(NSString*)ipAddress
{
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        return;
    }
    self.currentIpAddress = nil;
    [self.bridges removeObjectForKey:ipAddress];
    [bridge disconnect];
}
- (void)disconnectAllBridge
{
    for (NSString *key in self.bridges.allKeys) {
        PHSBridge *bridge = self.bridges[key];
        [self.bridges removeObjectForKey:key];
        [bridge disconnect];
    }
    self.currentIpAddress = nil;
}
// private
- (PHSBridge *)buildBridgeForIpAddress:(NSString *)ipAddress uniqueId:(NSString*)uniqueId {
    return [PHSBridge bridgeWithBlock:^(PHSBridgeBuilder* builder) {
        builder.connectionTypes = PHSBridgeConnectionTypeLocal;
        builder.ipAddress = ipAddress;
        builder.bridgeID  = uniqueId;
        
        builder.bridgeConnectionObserver = self;
        
        [builder addStateUpdateObserver:self];
    } withAppName:DPHueApName withDeviceName:DPHueApName];

}

#pragma mark - PHSBridgeConnectionObserver

- (void)bridgeConnection:(PHSBridgeConnection *)bridgeConnection handleEvent:(PHSBridgeConnectionEvent)connectionEvent {
    if (!self.delegate) {
        return;
    }
    switch (connectionEvent) {
        default:
            break;
        case PHSBridgeConnectionEventConnectionRestored:
            [self.delegate didConnectedWithIpAddress:self.currentIpAddress];
            [self updateManageServicesForIpAddress:self.currentIpAddress online:YES];
            break;
        case PHSBridgeConnectionEventCouldNotConnect:
        case PHSBridgeConnectionEventConnectionLost:
        case PHSBridgeConnectionEventDisconnected:
            [self.delegate didDisconnectedWithIpAddress:self.currentIpAddress];
            [self updateManageServicesForIpAddress:self.currentIpAddress online:NO];
            break;
            
        case PHSBridgeConnectionEventNotAuthenticated:
        case PHSBridgeConnectionEventLinkButtonNotPressed:
            [self.delegate didPushlinkBridgeWithIpAddress:self.currentIpAddress];
            [self updateManageServicesForIpAddress:self.currentIpAddress online:NO];
            break;
        case PHSBridgeConnectionEventAuthenticated:
            break;
    }
    self.currentEvent = connectionEvent;
    
}
- (void)bridgeConnection:(PHSBridgeConnection *)bridgeConnection handleErrors:(NSArray<PHSError *> *)connectionErrors {

    [self updateManageServicesForIpAddress:self.currentIpAddress online:NO];
    if (!self.delegate) {
        return;
    }
    [self.delegate didErrorWithIpAddress:self.currentIpAddress errors:connectionErrors];
}

#pragma mark - PHSBridgeStateUpdateObserver

- (void)bridge:(PHSBridge *)bridge handleEvent:(PHSBridgeStateUpdatedEvent)updateEvent {
    if (updateEvent == PHSBridgeStateUpdatedEventInitialized) {
        [self updateManageServicesForIpAddress:self.currentIpAddress online:YES];
        [self startHeartbeatForBridge:bridge];
        if (!self.delegate) {
            return;
        }
        [self.delegate didConnectedWithIpAddress:self.currentIpAddress];
    }
}
- (void)startHeartbeatForBridge:(PHSBridge *)bridge {
    PHSBridgeConnection* connection = bridge.bridgeConnections.firstObject;
    [connection.heartbeatManager startHeartbeatWithType:PHSBridgeStateCacheTypeFullConfig interval:10];
}

#pragma mark - Search Light
-(void)searchLightForIpAddress:(NSString*)ipAddress delegate:(id<PHSFindNewDevicesCallback>)delegate {
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        return;
    }
    [bridge findNewDevicesWithAllowedConnections:PHSBridgeConnectionTypeLocal callback:delegate];
}


-(void)registerLightsForSerialNo:(NSArray*)serialNos
                       ipAddress:(NSString*)ipAddress
                        delegate:(id<PHSFindNewDevicesCallback>)delegate
{
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        return;
    }
    [bridge findNewDevices:serialNos allowedConnectionTypes:PHSBridgeConnectionTypeLocal callback:delegate];
}

-(NSArray<PHSDevice*>*)getLightStatusForIpAddress:(NSString*)ipAddress
{
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        return [NSArray<PHSDevice*> array];
    }
    return [bridge.bridgeState getDevicesOfType:PHSDomainTypeLight];
}





#pragma mark - private method

//completionHandlerの共通処理
- (void) setCompletionWithResponseCompletion:(void(^)(void))completion
                        errors:(NSArray*)errors
                  errorState:(BridgeConnectState)errorState
{
    if (errors != nil && errors.count > 0) {
        _bridgeConnectState = errorState;
    } else {
        _bridgeConnectState = STATE_CONNECT;
    }
    if (completion) {
        completion();
    }
}


//パラメータチェック LightId
- (BOOL)checkParamForIpAddress:(NSString*)ipAddress lightId:(NSString*)lightId
{
    //LightIdが指定されてない場合はエラーで返す
    if (!lightId) {
        _bridgeConnectState = STATE_ERROR_NO_LIGHTID;
        return NO;
    }
    
    //キャッシュにあるライトの一覧からライトを取り出す
    NSArray<PHSDevice*>* caches = [[DPHueManager sharedManager] getLightStatusForIpAddress:ipAddress];
    for (PHSDevice *light in caches) {
        if ([lightId isEqualToString:light.identifier]) {
            return YES;
        }
    }
    _bridgeConnectState = STATE_ERROR_NOT_FOUND_LIGHT;
    return NO;
}


//パラメータチェック 必須文字チェック
- (BOOL)checkParamRequiredStringItemWithParam:(NSString*)param
                        errorState:(BridgeConnectState)errorState
{
    
    //valueが指定されてない場合はエラーで返す
    if (param == nil) {
        _bridgeConnectState = errorState;
        return NO;
    }
    if (param.length == 0) {
        _bridgeConnectState = errorState;
        return NO;
    }
    
    return YES;
}


- (void)checkColor:(double)dBlightness blueValue:(unsigned int)blueValue greenValue:(unsigned int)greenValue redValue:(unsigned int)redValue color:(NSString *)color myBlightnessPointer:(int *)myBlightnessPointer uicolorPointer:(NSString **)uicolorPointer
{
    NSScanner *scan;
    NSString *blueString;
    NSString *greenString;
    NSString *redString;
    if (color) {
        if (color.length != 6) {
            _bridgeConnectState = STATE_ERROR_INVALID_COLOR;
            return;
        }
        
        redString = [color substringWithRange:NSMakeRange(0, 2)];
        greenString = [color substringWithRange:NSMakeRange(2, 2)];
        blueString = [color substringWithRange:NSMakeRange(4, 2)];
        scan = [NSScanner scannerWithString:redString];
        if (![scan scanHexInt:&redValue]) {
            _bridgeConnectState = STATE_ERROR_INVALID_COLOR;
            return;
        }
        scan = [NSScanner scannerWithString:greenString];
        if (![scan scanHexInt:&greenValue]) {
            _bridgeConnectState = STATE_ERROR_INVALID_COLOR;
            return;
        }
        scan = [NSScanner scannerWithString:blueString];
        if (![scan scanHexInt:&blueValue]) {
            _bridgeConnectState = STATE_ERROR_INVALID_COLOR;
            return;
        }
        
        redValue = (unsigned int)round(redValue * dBlightness);
        greenValue = (unsigned int)round(greenValue * dBlightness);
        blueValue = (unsigned int)round(blueValue * dBlightness);
    }else{
        redValue = (unsigned int)round(255 * dBlightness);
        greenValue = (unsigned int)round(255 * dBlightness);
        blueValue = (unsigned int)round(255 * dBlightness);
    }
    
    *myBlightnessPointer = MAX(redValue, greenValue);
    *myBlightnessPointer = MAX(*myBlightnessPointer, blueValue);
    *uicolorPointer = [NSString stringWithFormat:@"%02X%02X%02X",redValue, greenValue, blueValue];
}

//エラーの場合、エラー情報をresponseに設定しnilをreturn
- (PHSLightState*) getLightStateIsOn:(BOOL)isOn
                          brightness:(NSNumber *)brightness
                               color:(NSString *)color
{
    PHSLightState* lightState = [PHSLightState new];

    [lightState setOn:[NSNumber numberWithBool:isOn]];

    if (isOn) {
        double dBlightness = 0;

        if (!brightness ||
            [brightness doubleValue] == DBL_MIN ||
            ([brightness doubleValue] != DBL_MIN && [brightness doubleValue] > 1.0) ||
            ([brightness doubleValue] != DBL_MIN && [brightness doubleValue] < 0.0) ) {
            dBlightness = 1.0;
        } else {
            dBlightness = [brightness doubleValue];
        }
        unsigned int redValue = 0, greenValue = 0, blueValue = 0;

        int myBlightness;
        NSString *uicolor;
        [self checkColor:dBlightness blueValue:blueValue greenValue:greenValue redValue:redValue color:color myBlightnessPointer:&myBlightness uicolorPointer:&uicolor];

        PHSColor *xyPoint = [self convRgbToXy:uicolor];
        if (xyPoint.xy.x != FLT_MIN && xyPoint.xy.y != FLT_MIN) {
            [lightState setXYWithColor:xyPoint];
        } else {
            _bridgeConnectState = STATE_ERROR_INVALID_COLOR;
            return nil;
        }

        if (myBlightness < 1) {
            myBlightness = 1;
        }
        if (myBlightness > 254) {
            myBlightness = 254;
        }
        
        [lightState setBrightness:[NSNumber numberWithInt:(int)myBlightness]];
    }

    return lightState;
}




/*!
 Lightのステータスチェンジ
 */
- (BOOL) changeLightStatusWithIpAddress:(NSString*)ipAddress
                                lightId:(NSString *)lightId
                             lightState:(PHSLightState*)lightState
                               flashing:(NSArray*)flashing
                             completion:(void(^)(void))completion
{
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        [self setCompletionWithResponseCompletion:completion
                                           errors:[NSArray array]
                                       errorState:STATE_ERROR_UPDATE_FAIL_LIGHT_STATE];
        return NO;
    }
    PHSDevice* device = [bridge.bridgeState getDeviceOfType:PHSDomainTypeLight withIdentifier:lightId];
    __weak typeof(self) _self = self;

    //メインスレッドで動作させる
    dispatch_sync(dispatch_get_main_queue(), ^{
        PHSLightPoint* lightPoint = (PHSLightPoint*)device;
        if (flashing && flashing.count > 0) {
            PHSLightState* offState = [_self getLightStateIsOn:NO brightness:0 color:nil];
            [_self setCompletionWithResponseCompletion:completion
                                               errors:nil
                                           errorState:STATE_ERROR_UPDATE_FAIL_LIGHT_STATE];

            _self.flashingExecutor = [[DPHueDeviceRepeatExecutor alloc] initWithPattern:flashing on:^{
                [lightPoint updateState:lightState allowedConnectionTypes:PHSBridgeConnectionTypeLocal
                      completionHandler:^(NSArray<PHSClipResponse *> *responses, NSArray<PHSError *> *errors, PHSReturnCode returnCode) {
                      }];
            } off:^{
                [lightPoint updateState:offState allowedConnectionTypes:PHSBridgeConnectionTypeLocal
                      completionHandler:^(NSArray<PHSClipResponse *> *responses, NSArray<PHSError *> *errors, PHSReturnCode returnCode) {
                      }];
            }];

        } else {
            [lightPoint updateState:lightState allowedConnectionTypes:PHSBridgeConnectionTypeLocal
                  completionHandler:^(NSArray<PHSClipResponse *> *responses, NSArray<PHSError *> *errors, PHSReturnCode returnCode) {
                      [self setCompletionWithResponseCompletion:completion
                                                         errors:errors
                                                     errorState:STATE_ERROR_UPDATE_FAIL_LIGHT_STATE];
            }];
        }
    });
    
    return NO;
}

/*
 Lightの名前チェンジ
 */
-(BOOL)changeLightNameWithIpAddress:(NSString*)ipAddress
                            lightId:(NSString *)lightId
                             name:(NSString *)name
                            color:(NSString *)color
                       brightness:(NSNumber *)brightness
                         flashing:(NSArray*)flashing
                       completion:(void(^)(void))completion
{
    unsigned int redValue = 0, greenValue = 0, blueValue = 0;

    // 省略時はMax値(1.0)を設定する
    double brightness_ = 1;
    if (brightness) {
        brightness_ = [brightness doubleValue];
    }
    
    int myBlightness;
    NSString *uicolor;
    [self checkColor:brightness_ blueValue:blueValue greenValue:greenValue
            redValue:redValue color:color myBlightnessPointer:&myBlightness uicolorPointer:&uicolor];

    if (!uicolor) {
        [self setCompletionWithResponseCompletion:completion
                                           errors:[NSArray array]
                                       errorState:STATE_ERROR_INVALID_COLOR];
        return NO;
    }
    
    PHSBridge *bridge = self.bridges[ipAddress];
    if (!bridge) {
        [self setCompletionWithResponseCompletion:completion
                                           errors:[NSArray array]
                                       errorState:STATE_ERROR_UPDATE_FAIL_LIGHT_STATE];
        return NO;
    }

    //　メインスレッドで動作させる
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 500);
    PHSLightState* onState = [self getLightStateIsOn:YES brightness:brightness color:color];
    [self changeLightStatusWithIpAddress:ipAddress
                                 lightId:lightId
                            lightState:onState
                              flashing:flashing
                            completion:^ {
                                dispatch_semaphore_signal(semaphore);
                            }];
    dispatch_semaphore_wait(semaphore, timeout);
    PHSDevice* device = [bridge.bridgeState getDeviceOfType:PHSDomainTypeLight withIdentifier:lightId];
    PHSDeviceConfiguration *conf = device.deviceConfiguration;
    [conf setName:name];
    [device updateConfiguration:conf allowedConnectionTypes:PHSBridgeConnectionTypeLocal completionHandler:^(NSArray<PHSClipResponse *> *responses, NSArray<PHSError *> *errors, PHSReturnCode returnCode) {
        [self setCompletionWithResponseCompletion:completion
                                           errors:errors
                                       errorState:STATE_ERROR_CHANGE_FAIL_LIGHT_NAME];

    }];
    return NO;
}




/*
 数値判定。
 */
- (BOOL)isDigitWithString:(NSString *)numberString {
    NSRange match = [numberString rangeOfString:@"^[-+]?([0-9]*)?(\\.)?([0-9]*)?$" options:NSRegularExpressionSearch];
    //数値の場合
    if(match.location != NSNotFound) {
        return YES;
    }
    _bridgeConnectState = STATE_ERROR_INVALID_BRIGHTNESS;
    return NO;
}


#pragma mark - private method

/*
 Hue方式の色を取得する。
 エラーの場合は、xとyにFLT_MINを返す。
 */
- (PHSColor *) convRgbToXy:(NSString *)color
{
    
    NSString *redString = [color substringWithRange:NSMakeRange(0, 2)];
    NSString *greenString = [color substringWithRange:NSMakeRange(2, 2)];
    NSString *blueString = [color substringWithRange:NSMakeRange(4, 2)];
    
    NSScanner *scan = [NSScanner scannerWithString:redString];
    
    unsigned int redValue, greenValue, blueValue;
    
    if (![scan scanHexInt:&redValue]) {
        return [PHSColor new];
    }
    scan = [NSScanner scannerWithString:greenString];
    if (![scan scanHexInt:&greenValue]) {
        return [PHSColor new];
    }
    scan = [NSScanner scannerWithString:blueString];
    if (![scan scanHexInt:&blueValue]) {
        return [PHSColor new];
    }
    float fRR = (float)(redValue/255.0);
    float fGG = (float)(greenValue/255.0);
    float fBB = (float)(blueValue/255.0);    
    PHSColor *phsColor = [PHSColor createWithRed:(int)fRR green:(int)fGG blue:(int)fBB];
    return phsColor;
}

- (void)updateManageServicesForIpAddress:(NSString*)ipAddress  online:(BOOL)online {
    @synchronized(self) {
        
        // ServiceProvider未登録なら処理しない
        if (!self.mServiceProvider) {
            return;
        }
        PHSBridge *bridge = self.bridges[ipAddress];
        if (!bridge) {
            return;
        }

        // オフラインにする場合は、全サービスをオフラインにする(Wifi Offにされたことを想定)
        if (!online) {
            for (DConnectService *service in [self.mServiceProvider services]) {
                [service setOnline: online];
            }
            return;
        }
        // ServiceProviderに未登録のデバイスが見つかったら追加登録する。登録済ならそのサービスをオンラインにする
        for (id key in [self.bridges keyEnumerator]) {
            DConnectService *service = [self.mServiceProvider service: key];
            PHSBridge *bridge = self.bridges[key];
            NSString *ipAddress = bridge.bridgeConfiguration.networkConfiguration.ipAddress;
            NSString *uniqueId = bridge.bridgeConfiguration.networkConfiguration.macAddress;
            if (!service) {
                service = [[DPHueService alloc] initWithBridgeIpAddress:ipAddress uniqueId:uniqueId plugin:[self plugin]];
                [self.mServiceProvider addService: service];
            }
            [service setOnline:online];
            NSArray<PHSDevice*> *lightList = [self getLightStatusForIpAddress:key];
            for (PHSDevice *light in lightList) {
                NSString *serviceId = [NSString stringWithFormat:@"%@_%@", key,light.identifier];
                DConnectService *service = [self.mServiceProvider service: serviceId];
                if (service) {
                    [service setOnline: online];
                } else {
                    service = [[DPHueLightService alloc] initWithIpAddress:key lightId:light.identifier lightName:light.name plugin:[self plugin]];
                    [self.mServiceProvider addService: service];
                    [service setOnline:online];
                }
            }
        }
    }
}

@end
