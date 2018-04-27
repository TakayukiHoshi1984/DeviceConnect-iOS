//
//  DPHueConst.h
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

/*! @file
 @brief Hueの機能を管理する。
 @author NTT DOCOMO
 @date 作成日(2014.7.15)
 */
#import <Foundation/Foundation.h>
#import <DConnectSDK/DConnectSDK.h>
#import <DConnectSDK/DConnectServiceProvider.h>
#import <HueSDK/HueSDK.h>


@protocol DPHueBridgeControllerDelegate

@required
- (void)didPushlinkBridgeWithIpAddress:(NSString*)ipAddress;
- (void)didConnectedWithIpAddress:(NSString*)ipAddress;
- (void)didDisconnectedWithIpAddress:(NSString*)ipAddress;
- (void)didErrorWithIpAddress:(NSString*)ipAddress errors:(NSArray<PHSError *> *)errors;
@end
/*!
 @class DPHueManager
 @brief Hueのマネージャクラス。
 
 Hueの機能を管理する。
 */
@interface DPHueManager : NSObject <PHSBridgeConnectionObserver, PHSBridgeStateUpdateObserver>

/*!
 @brief Hueデバイスプラグインのレスポンスステータス。
 */
typedef enum BridgeConnectState : NSInteger {
    STATE_INIT,
    STATE_CONNECT,
    STATE_NON_CONNECT,
    STATE_NOT_AUTHENTICATED,
    STATE_ERROR_NO_NAME,
    STATE_ERROR_NO_LIGHTID,
    STATE_ERROR_INVALID_LIGHTID,
    STATE_ERROR_LIMIT_GROUP,
    STATE_ERROR_CREATE_FAIL_GROUP,
    STATE_ERROR_DELETE_FAIL_GROUP,
    STATE_ERROR_NOT_FOUND_LIGHT,
    STATE_ERROR_NO_GROUPID,
    STATE_ERROR_NOT_FOUND_GROUP,
    STATE_ERROR_INVALID_COLOR,
    STATE_ERROR_UPDATE_FAIL_LIGHT_STATE,
    STATE_ERROR_CHANGE_FAIL_LIGHT_NAME,
    STATE_ERROR_UPDATE_FAIL_GROUP_STATE,
    STATE_ERROR_CHANGE_FAIL_GROUP_NAME,
    STATE_ERROR_INVALID_BRIGHTNESS
} BridgeConnectState;

/*!
 @brief ServiceProvider.
 */
@property (nonatomic) DConnectServiceProvider *mServiceProvider;

/*!
 @brief Hue Bridge リスト。
 */
@property (nonatomic) NSDictionary *hueBridgeList;
/*!
 @brief Hue Brdige のステータス。
 */
@property (nonatomic) BridgeConnectState bridgeConnectState;

/*!
 @brief デバイスプラグイン。
 */
@property(nonatomic, weak) id plugin;
@property (nonatomic) PHSBridgeConnectionEvent currentEvent;


/*!
 @brief Lightのステートを返すブロック。
 */
typedef void (^DPHueLightStatusBlock)(BridgeConnectState state);

/*!
 @brief 発見したブリッジのリストを返す.
 */
typedef void (^DPHueBridgeDiscoveryBlock)(NSDictionary<NSString *,PHSBridgeDiscoveryResult *> *results);

/*!
 @brief DPHueManagerの共有インスタンスを返す。
 @return DPHueManagerの共有インスタンス。
 */
+(instancetype)sharedManager;

/*!
 @brief ブリッジの初期化
 */
-(void)initHue;

/*!
 @brief ServiceProviderを登録
 */
- (void)setServiceProvider: (DConnectServiceProvider *) serviceProvider;

/*!
 @brief ブリッジの検索。
 @param[out] completionHandler ブリッジの検索結果を通知するブロック。
 */


#pragma mark - 新規追加
- (void)startBridgeDiscoveryWithCompletion:(DPHueBridgeDiscoveryBlock)completionHandler;

- (void)stopBridgeDiscovery;

- (void)connectForIPAddress:(NSString*)ipAddress uniqueId:(NSString*)uniqueId delegate:(id<DPHueBridgeControllerDelegate>)delegate;

- (void)disconnectForIPAddress:(NSString*)ipAddress;

-(void)searchLightForIpAddress:(NSString*)ipAddress delegate:(id<PHSFindNewDevicesCallback>)delegate;

-(void)registerLightsForSerialNo:(NSArray*)serialNos
                       ipAddress:(NSString*)ipAddress
                        delegate:(id<PHSFindNewDevicesCallback>)delegate;
-(NSArray<PHSDevice*>*)getLightStatusForIpAddress:(NSString*)ipAddress;
- (void)disconnectAllBridge;

/*!
 @brief ライトIDのチェック。
 @param[in] lightId ライトのID
 */
- (BOOL)checkParamForIpAddress:(NSString*)ipAddress lightId:(NSString*)lightId;

/*!
 @brief 設定するライトのステータスをPHLightStateのインスタンスに設定。
 @param[in] isOn true(On)/false(Off)
 @param[in] brightness ライトの明るさ
 @param[in] color ライトの色
 @retval PHLightState
 */
- (PHSLightState*) getLightStateIsOn:(BOOL)isOn
                          brightness:(NSNumber *)brightness
                               color:(NSString *)color;


/*!
 @brief パラメータのチェックを行う。
 @param[in] param リクエストパラメータ
 @param[in] errorState エラーステータス
 @retval YES レスポンスパラメータを返却する。
 @retval NO レスポンスパラメータを返却しないので、@link DConnectManager::sendResponse: @endlinkで返却すること。
 */
-(BOOL)checkParamRequiredStringItemWithParam:(NSString*)param
                                   errorState:(BridgeConnectState)errorState;
/*!
 @brief ライトのステータスを変更する。
 @param[in] lightId ライトのID
 @param[in] lightState 変更するステータス
 @param[in] flashing フラッシュパターン
 @param[in, out] completion レスポンスを返す
 @retval YES レスポンスパラメータを返却する。
 @retval NO レスポンスパラメータを返却しないので、@link DConnectManager::sendResponse: @endlinkで返却すること。
 */
-(BOOL)changeLightStatusWithIpAddress:(NSString*)ipAddress
                              lightId:(NSString *)lightId
                         lightState:(PHSLightState*)lightState
                           flashing:(NSArray*)flashing
                         completion:(void(^)(void))completion;


/*!
 @brief ライト名の変更。
 @param[in] lightId ライトのID
 @param[in] name 変更後のライトの名前
 @param[in] color 変更するライトの色
 @param[in] brightness 変更するライトの明るさ
 @param[in] flashing フラッシュパターン
 @param[in, out] completion レスポンスを返す
 @retval YES レスポンスパラメータを返却する。
 @retval NO レスポンスパラメータを返却しないので、@link DConnectManager::sendResponse: @endlinkで返却すること。
 */
-(BOOL)changeLightNameWithIpAddress:(NSString*)ipAddress
                                lightId:(NSString *)lightId
                             name:(NSString *)name
                            color:(NSString *)color
                       brightness:(NSNumber *)brightness
                         flashing:(NSArray*)flashing
                       completion:(void(^)(void))completion;

/*!
 @brief 文字列の実数判定。
 @param[in] numberString 数値判定する文字列
 @retval YES 実数である
 @retval NO 実数ではない
 */
- (BOOL)isDigitWithString:(NSString *)numberString;

/*!
 @brief Hueプラグインが管理するサービスのオンライン・オフラインを切り替える。
 @param[in] onlineForSet YES:オンラインに切り替える NO:オフラインに切り替える
 */
- (void)updateManageServicesForIpAddress:(NSString*)ipAddress  online:(BOOL)online;
@end
