//
//  SonyCameraManager.h
//  dConnectDeviceSonyCamera
//
//  Copyright (c) 2016 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "SampleLiveviewManager.h"
#import "SonyCameraRemoteApiUtil.h"
#import "SonyCameraDevicePlugin.h"

/*!
 @brief IDのプレフィックス。
 */
NSString *const SonyServiceId = @"sony_camera_";

/*!
 @brief デバイス名。
 */
NSString *const SonyDeviceName = @"Sony Camera";

/*!
 @brief ファイルのプレフィックス。
 */
NSString *const SonyFilePrefix = @"sony";

/*!
 @define サービスID.
 */
#define SERVICE_ID @"0"



@interface SonyCameraManager : NSObject/*<SonyCameraRemoteApiUtilDelegate>*/

/*!
 @brief Service生成時に登録するプロファイル(DConnectProfile *)の配列
 */
@property (nonatomic, weak) SonyCameraDevicePlugin *plugin;

/*!
 @brief SonyRemoteApi操作用.
 */
@property (nonatomic, strong) SonyCameraRemoteApiUtil *remoteApi;

/*!
 @brief ファイル管理クラス。
 */
@property (nonatomic, strong) DConnectFileManager *mFileManager;

/*!
 @brief タイムスライス。
 */
@property (nonatomic) UInt64 timeslice;

/*!
 @brief タイムスライス開始時刻。
 */
@property (nonatomic) UInt64 previewStart;

/*!
 @brief プレビューカウント。
 */
@property (nonatomic) int mPreviewCount;

/*!
 @brief サーチフラグ.
 */
@property (nonatomic) BOOL searchFlag;

/*!
 @brief liveViewDelegate.
 */
@property (nonatomic, weak) id<SampleLiveviewDelegate> liveViewDelegate;

/*!
 @brief remoteApiUtilDelegate.
 */
@property (nonatomic, weak) id<SonyCameraRemoteApiUtilDelegate> remoteApiUtilDelegate;


/*!
 @brief SonyCameraManagerの共有インスタンスを返す。
 @return SonyCameraManagerの共有インスタンス。
 */
+ (instancetype)sharedManager;

- (instancetype)initWithPlugin: (SonyCameraDevicePlugin *) plugin
              liveViewDelegate: (id<SampleLiveviewDelegate>) liveViewDelegate
         remoteApiUtilDelegate: (id<SonyCameraRemoteApiUtilDelegate>) remoteApiUtilDelegate;

/*!
 @brief 指定されたURLからデータをダウンロードする。
 
 Sony Cameraのデバイスに対してHTTP通信でデータをダウンロードする。
 @param[in] requestURL データが置いてあるURL
 @return データ
 */
- (NSData *) download:(NSString *)requestURL;

/*!
 @brief ファイルを保存する。
 
 ファイル名は、「sony_201408_011500.png」のようにsonyのプレフィックスに時刻が入る。
 
 @param[in] data 保存するデータ
 
 @retval 保存したファイルへのURL
 @retval nil 保存に失敗した場合
 */
- (NSString *) saveFile:(NSData *)data;


/*!
 @brief 選択されたサービスIDに対応するカメラを選択する.
 @param serviceId サービスID
 @param response レスポンス
 @retval YES 選択できた場合
 @retval NO 選択できなかった場合
 */
- (BOOL) selectServiceId:(NSString *)serviceId response:(DConnectResponseMessage *)response;


/*!
 @brief プレビューイベントを持っているかをチェックする.
 @retval YES 持っている
 @retval NO 持っていない
 */
- (BOOL) hasDataAvaiableEvent;


@end

