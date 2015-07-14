//
//  DConnectManager.m
//  dConnectManager
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectManager+Private.h"
#import "DConnectDevicePlugin+Private.h"
#import "DConnectURLProtocol.h"
#import "DConnectManagerAuthorizationProfile.h"
#import "DConnectManagerDeliveryProfile.h"
#import "DConnectManagerServiceDiscoveryProfile.h"
#import "DConnectManagerSystemProfile.h"
#import "DConnectFilesProfile.h"
#import "DConnectManagerAuthorizationProfile.h"
#import "DConnectAvailabilityProfile.h"
#import "DConnectWebSocket.h"
#import "DConnectMessage+Private.h"
#import "DConnectSettings.h"
#import "DConnectEventManager.h"
#import "DConnectDBCacheController.h"
#import "DConnectConst.h"
#import "DConnectWhitelist.h"
#import "DConnectOriginParser.h"
#import "LocalOAuth2Main.h"

NSString *const DConnectApplicationDidEnterBackground = @"DConnectApplicationDidEnterBackground";
NSString *const DConnectApplicationWillEnterForeground = @"DConnectApplicationWillEnterForeground";
NSString *const DConnectStoryboardName = @"DConnectSDK";

NSString *const DConnectProfileNameNetworkServiceDiscovery = @"networkServiceDiscovery";
NSString *const DConnectAttributeNameGetNetworkServices = @"getNetworkServices";
NSString *const DConnectAttributeNameCreateClient = @"createClient";
NSString *const DConnectAttributeNameRequestAccessToken = @"requestAccessToken";

/*!
 @brief レスポンス用のコールバックを管理するデータクラス.
 */
@interface DConnectResponseCallbackInfo : NSObject

@property (nonatomic, strong) DConnectResponseBlocks callback;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

- (id) initWithCallback:(DConnectResponseBlocks) callback semaphore:(dispatch_semaphore_t) semaphore;
@end

@implementation DConnectResponseCallbackInfo

- (id) initWithCallback:(DConnectResponseBlocks)callback semaphore:(dispatch_semaphore_t)semaphore {
    
    self = [super init];
    if (self) {
        _callback = callback;
        _semaphore = semaphore;
    }
    
    return self;
}

@end



@interface DConnectManager ()
{
    dispatch_queue_t _requestQueue;
}

/*! @brief Websocketを管理するクラス.
 */
@property (nonatomic) DConnectWebSocket *mWebsocket;

/**
 * プロファイルを格納するマップ.
 */
@property (nonatomic) NSMutableDictionary *mProfileMap;

/**
 * リクエスト配送用のプロファイル.
 */
@property (nonatomic) DConnectManagerDeliveryProfile *mDeliveryProfile;

/*!
 @brief DConnectManager起動フラグ。
 */
@property (nonatomic) BOOL mStartFlag;

/**
 * レスポンスとブロックを管理するマップ.
 */
@property (nonatomic, strong) NSMutableDictionary *mResponseBlockMap;

/**
 * 受け取ったリクエストの処理を行う.
 * @param[in] request リクエスト
 * @param[in,out] response レスポンス
 */
- (void) didReceiveRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response
                  callback:(DConnectResponseBlocks) callback;

/*!
 @brief 受け取ったリクエストを処理する。
 
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @param[in] callback コールバック
 */
- (void) executeRequest:(DConnectRequestMessage *)request
               response:(DConnectResponseMessage *)response
               callback:(DConnectResponseBlocks)callback;

/**
 * タイムアウトのレスポンスを返す.
 *
 * @param[in] key レスポンスのコード
 */
- (void) sendTimeoutResponseForKey:(NSString *)key;

- (BOOL) allowsOriginOfRequest:(DConnectRequestMessage *)requestMessage;

@end


@implementation DConnectManager

+ (DConnectManager *) sharedManager {
    static DConnectManager *sharedDConnectManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDConnectManager = [DConnectManager new];
    });
    return sharedDConnectManager;
}

- (void) start {
    // 開始フラグをチェック
    if (self.mStartFlag) {
        return;
    }
    self.mStartFlag = YES;
    _requestQueue = dispatch_queue_create("org.deviceconnect.manager.queue.request", DISPATCH_QUEUE_SERIAL);
    
    // デバイスプラグインの検索
    [self.mDeviceManager searchDevicePlugin];
    
    // サーバの設定
    [DConnectURLProtocol setHost:self.settings.host];
    [DConnectURLProtocol setPort:self.settings.port];
    
    // NSURLProtocolへ登録
    [NSURLProtocol registerClass:[DConnectURLProtocol class]];
}

- (void) startWebsocket {
    if (self.mWebsocket) {
        [self.mWebsocket stop];
    }
    self.mWebsocket = [[DConnectWebSocket alloc] initWithHost:self.settings.host
                                                         port:self.settings.port];
    [self.mWebsocket start];
}

- (BOOL) isStarted {
    return self.mStartFlag;
}

- (void) sendRequest:(DConnectRequestMessage *)request
              isHttp:(BOOL)isHttp
            callback:(DConnectResponseBlocks)callback
{
    if (request) {
        __weak DConnectManager *_self = self;
        // iOS Message APIリクエストの実行をUIスレッドで行うと、
        // タイムアウト用のスレッド制御処理の影響でデバイスプラグインで
        // UIスレッドが使用できなくなるため、常に非同期で行う。
        dispatch_async(
                dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // DConnectManagerではsessionKeyにプラグインIDを
            // 付与するなどリクエストデータを書き換える処理が
            // 発生するため、呼び出し元でデータの齟齬が
            // 無いようにリクエストデータをコピーする。
            // Webからのリクエストの場合は呼び出しもとで
            // 当メソッドの呼び出し後にリクエストデータを参照することが
            // ないためネイティブからの呼び出し時のみコピーを行う。
            DConnectRequestMessage *tmpReq = isHttp ? request : [request copy];
            DConnectResponseMessage *response = [DConnectResponseMessage message];
            
            [_self didReceiveRequest:tmpReq response:response callback:callback];
        });
    } else {
        @throw @"request must not be nil.";
    }

}

- (void) sendRequest:(DConnectRequestMessage *) request callback:(DConnectResponseBlocks)callback {
    [self sendRequest:request isHttp:NO callback:callback];
}

- (void)makeEventMessage:(DConnectMessage *)event
                     key:(NSString *)key
             hasDelegate:(BOOL)hasDelegate
                  plugin:(DConnectDevicePlugin *)plugin
{
    NSString *profile = [event stringForKey:DConnectMessageProfile];
    NSString *attribute = [event stringForKey:DConnectMessageAttribute];
    if ([profile isEqualToString:DConnectServiceDiscoveryProfileName] &&
        [attribute isEqualToString:DConnectServiceDiscoveryProfileAttrOnServiceChange]) {
        
        // サービスIDを付加する
        DConnectMessage *service = [event messageForKey:DConnectServiceDiscoveryProfileParamNetworkService];
        NSString *serviceId = [service stringForKey:DConnectServiceDiscoveryProfileParamId];
        NSString *did = [_mDeviceManager serviceIdByAppedingPluginIdWithDevicePlugin:plugin
                                                                           serviceId:serviceId];
        [service setString:did forKey:DConnectServiceDiscoveryProfileParamId];
        DConnectEventManager *mgr = [DConnectEventManager sharedManagerForClass:[DConnectManager class]];
        NSArray *evts = [mgr eventListForProfile:profile attribute:attribute];
        
        for (DConnectEvent *evt in evts) {
            [event setString:evt.sessionKey forKey:DConnectMessageSessionKey];
            
            if (hasDelegate) {
                [self.delegate manager:self didReceiveDConnectMessage:event];
            } else {
                NSString *json = [event convertToJSONString];
                [self.mWebsocket sendEvent:json forSessionKey:evt.sessionKey];
            }
        }
    } else {
        
        // serviceIdにプラグインIDを付加
        NSString *serviceId = [event stringForKey:DConnectMessageServiceId];
        if (serviceId) {
            NSString *did = [_mDeviceManager serviceIdByAppedingPluginIdWithDevicePlugin:plugin
                                                                               serviceId:serviceId];
            [event setString:did forKey:DConnectMessageServiceId];
        }
        
        if (hasDelegate) {
            [self.delegate manager:self didReceiveDConnectMessage:event];
        } else {
            NSString *json = [event convertToJSONString];
            [self.mWebsocket sendEvent:json forSessionKey:key];
        }
    }
}

- (BOOL) sendEvent:(DConnectMessage *)event {
    NSString *sessionKey = [event stringForKey:DConnectMessageSessionKey];
    if (sessionKey) {
        NSArray *names = [sessionKey componentsSeparatedByString:@"."];
        NSString *pluginId = names[names.count - 1];
        NSRange range = [sessionKey rangeOfString:pluginId];
        NSString *key;
        if (range.location != NSNotFound) {
            if (range.location == 0) {
                key = sessionKey;
            } else {
                key = [sessionKey substringToIndex:range.location - 1];
            }
        } else {
            key = sessionKey;
        }
        [event setString:key forKey:DConnectMessageSessionKey];

        DConnectDevicePlugin *plugin = [_mDeviceManager devicePluginForPluginId:pluginId];
        
        BOOL hasDelegate = NO;
        if ([self.delegate respondsToSelector:@selector(manager:didReceiveDConnectMessage:)]) {
            hasDelegate = YES;
        } else {
            // イベントのJSONにあるURIをFilesプロファイルに変換
            [DConnectURLProtocol convertUri:event];
        }
        [self makeEventMessage:event key:key hasDelegate:hasDelegate plugin:plugin];
    }
    return NO;
}

- (void) sendResponse:(DConnectResponseMessage *)response {
    [response setString:self.productName forKey:DConnectMessageProduct];
    [response setString:self.versionName forKey:DConnectMessageVersion];
    
    DConnectResponseCallbackInfo *info = nil;
    @synchronized (_mResponseBlockMap) {
        info = [_mResponseBlockMap objectForKey:response.code];
        if (info) {
            [_mResponseBlockMap removeObjectForKey:response.code];
        }
    }
    
    if (info) {
        
        if (info.callback) {
            info.callback(response);
        }
        
        if (info.semaphore) {
            dispatch_semaphore_signal(info.semaphore);
        }
    }
}

#pragma mark - Private Methods -

- (id) init {
    self = [super init];
    if (self) {
        self.mStartFlag = NO;
        
        // DConnect設定を初期化
        _settings = [DConnectSettings new];
        self.productName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDisplayName"];
        self.versionName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
        
        // イベント管理クラス
        Class key = [self class];
        [[DConnectEventManager sharedManagerForClass:key]
                                setController:
                                    [DConnectDBCacheController
                                            controllerWithClass:key]];

        self.mDeviceManager = [DConnectDevicePluginManager new];
        self.mProfileMap = [NSMutableDictionary dictionary];
        self.mResponseBlockMap = [NSMutableDictionary dictionary];
        
        // プロファイルの追加
        [self addProfile:[DConnectManagerServiceDiscoveryProfile new]];
        [self addProfile:[DConnectManagerSystemProfile new]];
        [self addProfile:[DConnectFilesProfile new]];
        [self addProfile:[[DConnectManagerAuthorizationProfile alloc] initWithObject:self]];
        [self addProfile:[DConnectAvailabilityProfile new]];
        
        // デバイスプラグイン配送用プロファイル
        self.mDeliveryProfile = [DConnectManagerDeliveryProfile new];
        self.mDeliveryProfile.provider = self;
    }
    return self;
}

- (void) executeRequest:(DConnectRequestMessage *)request
               response:(DConnectResponseMessage *)response
               callback:(DConnectResponseBlocks)callback {
    [request setString:self.productName forKey:DConnectMessageProduct];
    [request setString:self.versionName forKey:DConnectMessageVersion];
    
    DConnectProfile *profile = [self profileWithName:[request profile]];
    
    // 各プロファイルでリクエストを処理する。
    // dConnectManagerに指定のプロファイルがあれば、dConnectManagerに送る。
    BOOL processed = NO;
    if (profile) {
        processed = [profile didReceiveRequest:request response:response];
    }
    
    // 未だresponseが処理済みでなければ、
    // 送られてきたリクエストをデバイスプラグインに送る。
    if (!processed) {
        processed = [self.mDeliveryProfile didReceiveRequest:request response:response];
    }
    
    
    // TODO: ここの処理を修正する
    // 本当はtrueで行うのではないと思う。
    if (processed) {
        [self sendResponse:response];
    }
}

- (void) didReceiveRequest:(DConnectRequestMessage *) request
                  response:(DConnectResponseMessage *) response
                  callback:(DConnectResponseBlocks) callback
{
    __weak DConnectManager *_self = self;
    
    // 常に待つので0を指定しておく
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * HTTP_REQUEST_TIMEOUT);
    
    // 非同期で呼び出せるよう、レスポンスに対するコールバックを保持しておく。
    [self addCallback:callback semaphore:semaphore forKey:response.code];
    
    dispatch_async(_requestQueue, ^{
        // 指定されたプロファイルを取得する
        NSString *profileName = [request profile];
        
        if (![_self allowsOriginOfRequest:request]) {
            [response setErrorToInvalidOrigin];
            DConnectProfile *profile = [_self profileWithName:profileName];
            if (profile && [profile isKindOfClass:[DConnectManagerAuthorizationProfile class]]) {
                DConnectManagerAuthorizationProfile *authProfile =
                (DConnectManagerAuthorizationProfile *) profile;
                [authProfile didReceiveInvalidOriginRequest:request response:response];
            }
            [_self sendResponse:response];
            return;
        }
        
        if (!profileName) {
            [response setErrorToNotSupportProfile];
            [_self sendResponse:response];
            return;
        }
        
        if (self.settings.useLocalOAuth) {
            @try {
                // Local OAuthチェック
                NSArray *scopes = DConnectIgnoreProfiles();
                NSString *accessToken = [request accessToken];
                LocalOAuth2Main *oauth = [LocalOAuth2Main sharedOAuthForClass:[DConnectManager class]];
                LocalOAuthCheckAccessTokenResult *result = [oauth checkAccessTokenWithScope:profileName
                                                                              specialScopes:scopes
                                                                                accessToken:accessToken];
                if ([result checkResult]) {
                    
                    [_self executeRequest:request response:response callback:callback];
                } else {
                    // Local OAuth認証失敗
                    if (accessToken == nil) {
                        [response setErrorToEmptyAccessToken];
                    } else if (![result isExistAccessToken]) {
                        [response setErrorToNotFoundClientId];
                    } else if (![result isExistClientId]) {
                        [response setErrorToNotFoundClientId];
                    } else if (![result isExistScope]) {
                        [response setErrorToScope];
                    } else if (![result isExistNotExpired]) {
                        [response setErrorToExpiredAccessToken];
                    } else {
                        [response setErrorToAuthorization];
                    }
                    [_self sendResponse:response];
                }
            } @catch (NSString *exception) {
                [response setErrorToInvalidRequestParameterWithMessage:exception];
                [_self sendResponse:response];
            }
        } else {
            [_self executeRequest:request
                         response:response
                         callback:callback];
        }
    });
    
    // 非同期で各プロファイルの処理を出来るようにするため、
    // sendResponseされるまで待つ。
    // タイムアウトの場合はタイムアウトエラーをレスポンスとして返す。
    long result = dispatch_semaphore_wait(semaphore, timeout);
    if (result != 0) {
        [self sendTimeoutResponseForKey:response.code];
    }
}

- (void) addCallback:(DConnectResponseBlocks)callback forKey:(NSString *)key {
    [self addCallback:callback semaphore:nil forKey:key];
}

- (void) addCallback:(DConnectResponseBlocks)callback semaphore:(dispatch_semaphore_t)semaphore
              forKey:(NSString *)key
{
    @synchronized (_mResponseBlockMap) {
        DConnectResponseCallbackInfo *info = [[DConnectResponseCallbackInfo alloc] initWithCallback:callback
                                                                                          semaphore:semaphore];
        _mResponseBlockMap[key] = info;
    }
}

- (void) removeCallbackForKey:(NSString *)key {
    @synchronized (_mResponseBlockMap) {
        [_mResponseBlockMap removeObjectForKey:key];
    }
}

#pragma mark - DConnectProfileProvider Methods -

- (void) addProfile:(DConnectProfile *) profile {
    NSString *name = [profile profileName];
    if (name) {
        [self.mProfileMap setObject:profile forKey:name];
        profile.provider = self;
    }
}

- (void) removeProfile:(DConnectProfile *)profile {
    NSString *name = [profile profileName];
    if (name) {
        [self.mProfileMap removeObjectForKey:name];
    }
}

- (DConnectProfile *) profileWithName:(NSString *)name {
    if (name) {
        return [_mProfileMap objectForKey:name];
    }
    return nil;
}

- (NSArray *) profiles {
    NSMutableArray *list = [NSMutableArray array];
    for (id key in [self.mProfileMap allKeys]) {
        [list addObject:[self.mProfileMap objectForKey:key]];
    }
    return list;
}

- (void) sendTimeoutResponseForKey:(NSString *)key { 
    DConnectResponseCallbackInfo *info = nil;
    @synchronized (_mResponseBlockMap) {
        info = [_mResponseBlockMap objectForKey:key];
        if (info) {
            [_mResponseBlockMap removeObjectForKey:key];
        }
    }
    if (info) {
        DConnectResponseMessage *timeoutResponse = [DConnectResponseMessage message];
        [timeoutResponse setErrorToTimeout];
        if (info.callback) {
            info.callback(timeoutResponse);   
        }
    }
}

- (BOOL) allowsOriginOfRequest:(DConnectRequestMessage *)requestMessage{
    NSString *originExp = [requestMessage origin];
    if (!originExp) {
        return NO;
    }
    if (![self.settings useOriginBlocking]) {
        return YES;
    }
    NSArray *ignores = DConnectIgnoreOrigins();
    if ([ignores containsObject:originExp]) {
        return YES;
    }
    id<DConnectOrigin> origin = [DConnectOriginParser parse:originExp];
    return [[DConnectWhitelist sharedWhitelist] allows:origin];
}

@end
