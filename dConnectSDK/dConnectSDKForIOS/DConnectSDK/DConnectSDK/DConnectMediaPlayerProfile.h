//
//  DConnectMediaStreamsPlayProfile.h
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

/*! 
 @file
 @brief Media Player プロファイルを実装するための機能を提供する。
 @author NTT DOCOMO
 */
#import <DConnectSDK/DConnectProfile.h>


/*!
 @brief プロファイル名。
 */
extern NSString *const DConnectMediaPlayerProfileName;

/*!
 @brief アトリビュート: media。
 */
extern NSString *const DConnectMediaPlayerProfileAttrMedia;

/*!
 @brief アトリビュート: media_list。
 */
extern NSString *const DConnectMediaPlayerProfileAttrMediaList;

/*!
 @brief アトリビュート: volume。
 */
extern NSString *const DConnectMediaPlayerProfileAttrVolume;

/*!
 @brief アトリビュート: play_status。
 */
extern NSString *const DConnectMediaPlayerProfileAttrPlayStatus;

/*!
 @brief アトリビュート: play。
 */
extern NSString *const DConnectMediaPlayerProfileAttrPlay;

/*!
 @brief アトリビュート: stop。
 */
extern NSString *const DConnectMediaPlayerProfileAttrStop;

/*!
 @brief アトリビュート: pause。
 */
extern NSString *const DConnectMediaPlayerProfileAttrPause;

/*!
 @brief アトリビュート: resume。
 */
extern NSString *const DConnectMediaPlayerProfileAttrResume;

/*!
 @brief アトリビュート: seek。
 */
extern NSString *const DConnectMediaPlayerProfileAttrSeek;

/*!
 @brief アトリビュート: seek。
 */
extern NSString *const DConnectMediaPlayerProfileAttrMute;

/*!
 @brief アトリビュート: onstatuschange。
 */
extern NSString *const DConnectMediaPlayerProfileAttrOnStatusChange;

/*!
 @brief パラメータ: mediaId。
 */
extern NSString *const DConnectMediaPlayerProfileParamMediaId;

/*!
 @brief パラメータ: media。
 */
extern NSString *const DConnectMediaPlayerProfileParamMedia;

/*!
 @brief パラメータ: mediaPlayer。
 */
extern NSString *const DConnectMediaPlayerProfileParamMediaPlayer;

/*!
 @brief パラメータ: mimeType。
 */
extern NSString *const DConnectMediaPlayerProfileParamMIMEType;

/*!
 @brief パラメータ: title。
 */
extern NSString *const DConnectMediaPlayerProfileParamTitle;

/*!
 @brief パラメータ: type。
 */
extern NSString *const DConnectMediaPlayerProfileParamType;

/*!
 @brief パラメータ: language。
 */
extern NSString *const DConnectMediaPlayerProfileParamLanguage;

/*!
 @brief パラメータ: description。
 */
extern NSString *const DConnectMediaPlayerProfileParamDescription;

/*!
 @brief パラメータ: imageUri。
 */
extern NSString *const DConnectMediaPlayerProfileParamImageURI;

/*!
 @brief パラメータ: duration。
 */
extern NSString *const DConnectMediaPlayerProfileParamDuration;

/*!
 @brief パラメータ: creators。
 */
extern NSString *const DConnectMediaPlayerProfileParamCreators;

/*!
 @brief パラメータ: creator。
 */
extern NSString *const DConnectMediaPlayerProfileParamCreator;

/*!
 @brief パラメータ: role。
 */
extern NSString *const DConnectMediaPlayerProfileParamRole;

/*!
 @brief パラメータ: keywords。
 */
extern NSString *const DConnectMediaPlayerProfileParamKeywords;

/*!
 @brief パラメータ: genres。
 */
extern NSString *const DConnectMediaPlayerProfileParamGenres;

/*!
 @brief パラメータ: query。
 */
extern NSString *const DConnectMediaPlayerProfileParamQuery;

/*!
 @brief パラメータ: order。
 */
extern NSString *const DConnectMediaPlayerProfileParamOrder;

/*!
 @brief パラメータ: offset。
 */
extern NSString *const DConnectMediaPlayerProfileParamOffset;

/*!
 @brief パラメータ: limit。
 */
extern NSString *const DConnectMediaPlayerProfileParamLimit;

/*!
 @brief パラメータ: count。
 */
extern NSString *const DConnectMediaPlayerProfileParamCount;

/*!
 @brief パラメータ: status。
 */
extern NSString *const DConnectMediaPlayerProfileParamStatus;

/*!
 @brief パラメータ: pos。
 */
extern NSString *const DConnectMediaPlayerProfileParamPos;

/*!
 @brief パラメータ: volume。
 */
extern NSString *const DConnectMediaPlayerProfileParamVolume;

/*!
 @brief パラメータ: mute。
 */
extern NSString *const DConnectMediaPlayerProfileParamMute;


#pragma mark - constants

/*!
 @brief 状態: 再生。
 */
extern NSString *const DConnectMediaPlayerProfileStatusPlay;

/*!
 @brief 状態: 停止。
 */
extern NSString *const DConnectMediaPlayerProfileStatusStop;

/*!
 @brief 状態: 一時停止。
 */
extern NSString *const DConnectMediaPlayerProfileStatusPause;

/*!
 @brief 状態: 再開。
 */
extern NSString *const DConnectMediaPlayerProfileStatusResume;

/*!
 @brief 状態: ミュート。
 */
extern NSString *const DConnectMediaPlayerProfileStatusMute;

/*!
 @brief 状態: ミュート解除。
 */
extern NSString *const DConnectMediaPlayerProfileStatusUnmute;

/*!
 @brief 状態: 再生コンテンツ変更。
 */
extern NSString *const DConnectMediaPlayerProfileStatusMedia;

/*!
 @brief 状態: 音量変更。
 */
extern NSString *const DConnectMediaPlayerProfileStatusVolume;

/*!
 @brief 状態: 再生完了。
 */
extern NSString *const DConnectMediaPlayerProfileStatusComplete;

/*!
 @brief 並び順: 昇順。
 */
extern NSString *const DConnectMediaPlayerProfileOrderASC;

/*!
 @brief 並び順: 降順。
 */
extern NSString *const DConnectMediaPlayerProfileOrderDESC;

/*!
 @class DConnectMediaPlayerProfile
 @brief Media Player プロファイル。
 
 Media Player Profileの各APIへのリクエストを受信する。
 受信したリクエストは各API毎にデリゲートに通知される。
 
 @deprecated
 本クラスで定義していた定数はSwagger形式の定義ファイルで管理することになったので、このクラスは使用しないこととする。
 プロファイルを実装する際は本クラスではなく、@link DConnectProfile @endlink クラスを継承すること。
 */
@interface DConnectMediaPlayerProfile : DConnectProfile

#pragma mark - Setter

/*!
 @brief メッセージに検索件数を設定する。
 @param[in] count 検索件数
 @param[in,out] message 検索件数を格納するメッセージ
 */
+ (void) setCount:(int)count target:(DConnectMessage *)message;

/*!
 @brief メッセージにメディアIDを設定する。
 @param[in] mediaId メディアID
 @param[in,out] message メディアIDを格納するメッセージ
 */
+ (void) setMediaId:(NSString *)mediaId target:(DConnectMessage *)message;

/*!
 @brief メッセージにメディアを設定する。
 @param[in] media メディア
 @param[in,out] message メディアを格納するメッセージ
 */
+ (void) setMedia:(DConnectArray *)media target:(DConnectMessage *)message;

/*!
 @brief メッセージにメディアプレーヤーを設定する。
 @param[in] mediaPlayer メディアプレーヤー
 @param[in,out] message メディアプレーヤーを格納するメッセージ
 */
+ (void) setMediaPlayer:(DConnectMessage *)mediaPlayer target:(DConnectMessage *)message;

/*!
 @brief メッセージにミュートを設定する。
 @param[in] mute YESならミュート、NOならアンミュート
 @param[in,out] message ミューと情報を格納するメッセージ
 */
+ (void) setMute:(BOOL)mute target:(DConnectMessage *)message;

/*!
 @brief メッセージに再生状態を設定する。
 @param[in] status 再生状態
 @param[in,out] message 再生状態を格納するメッセージ
 */
+ (void) setStatus:(NSString *)status target:(DConnectMessage *)message;

/*!
 @brief メッセージに再生位置を設定する。
 @param[in] pos 再生位置
 @param[in,out] message 再生位置を格納するメッセージ
 */
+ (void) setPos:(int)pos target:(DConnectMessage *)message;

/*!
 @brief メッセージにマイムタイプを設定する。
 @param[in] mimeType マイムタイプ
 @param[in,out] message マイムタイプを格納するメッセージ
 */
+ (void) setMIMEType:(NSString *)mimeType target:(DConnectMessage *)message;

/*!
 @brief メッセージにタイトルを設定する。
 @param[in] title タイトル
 @param[in,out] message タイトルを格納するメッセージ
 */
+ (void) setTitle:(NSString *)title target:(DConnectMessage *)message;

/*!
 @brief メッセージにタイプ名を設定する。
 @param[in] type タイプ名
 @param[in,out] message タイプ名を格納するメッセージ
 */
+ (void) setType:(NSString *)type target:(DConnectMessage *)message;

/*!
 @brief メッセージに言語を設定する。
 @param[in] language 言語
 @param[in,out] message 言語を格納するメッセージ
 */
+ (void) setLanguage:(NSString *)language target:(DConnectMessage *)message;

/*!
 @brief メッセージに画像のURIを設定する。
 @param[in] imageUri 画像のURI
 @param[in,out] message 画像のURIを格納するメッセージ
 */
+ (void) setImageUri:(NSString *)imageUri target:(DConnectMessage *)message;

/*!
 @brief メッセージに説明文を設定する。
 @param[in] description 説明文
 @param[in,out] message 説明文を格納するメッセージ
 */
+ (void) setDescription:(NSString *)description target:(DConnectMessage *)message;

/*!
 @brief メッセージにメディアの再生時間を設定する。
 @param[in] duration メディアの再生時間
 @param[in,out] message メディアの再生時間を格納するメッセージ
 */
+ (void) setDuration:(int)duration target:(DConnectMessage *)message;

/*!
 @brief メッセージに制作者情報一覧を設定する。
 @param[in] creators 制作者情報一覧
 @param[in,out] message 制作者情報一覧を格納するメッセージ
 */
+ (void) setCreators:(DConnectArray *)creators target:(DConnectMessage *)message;

/*!
 @brief メッセージに制作者名を設定する。
 @param[in] creator 制作者名
 @param[in,out] message 制作者名を格納するメッセージ
 */
+ (void) setCreator:(NSString *)creator target:(DConnectMessage *)message;

/*!
 @brief メッセージに役割名を設定する。
 @param[in] role 役割名
 @param[in,out] message 役割名を格納するメッセージ
 */
+ (void) setRole:(NSString *)role target:(DConnectMessage *)message;

/*!
 @brief メッセージにキーワード一覧を設定する。
 @param[in] keywords キーワード一覧
 @param[in,out] message キーワード一覧を格納するメッセージ
 */
+ (void) setKeywords:(DConnectArray *)keywords target:(DConnectMessage *)message;

/*!
 @brief メッセージにジャンル一覧を設定する。
 @param[in] genres ジャンル一覧
 @param[in,out] message ジャンル一覧を格納するメッセージ
 */
+ (void) setGenres:(DConnectArray *)genres target:(DConnectMessage *)message;

/*!
 @brief メッセージに音量を設定する。
 @param[in] volume 音量
 @param[in,out] message 音量を格納するメッセージ
 */
+ (void) setVolume:(double)volume target:(DConnectMessage *)message;


#pragma mark - Getter

/*!
 @brief リクエストデータからメディアIDを取得する。
 @param[in] request リクエストパラメータ
 @return メディアID。無い場合はnilを返す。
 */
+ (NSString *) mediaIdFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから再生位置を取得する。
 @param[in] request リクエストパラメータ
 @return 再生位置。無い場合はnilを返す。
 */
+ (NSNumber *) posFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから状態を取得する。
 @param[in] request リクエストパラメータ
 @return 状態。無い場合はnilを返す。
 */
+ (NSString *) statusFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから音量を取得する。
 @param[in] request リクエストパラメータ
 @return 音量。無い場合はnilを返す。
 */
+ (NSNumber *) volumeFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから検索文字列を取得する。
 @param[in] request リクエストパラメータ
 @return 検索文字列。無い場合はnilを返す。
 */
+ (NSString *) queryFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータからマイムタイプを取得する。
 @param[in] request リクエストパラメータ
 @return マイムタイプ。無い場合はnilを返す。
 */
+ (NSString *) mimeTypeFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから並び順を取得する。
 @param[in] request リクエストパラメータ
 @return 並び順。無い場合はnilを返す。
 */
+ (NSString *) orderFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータから再生位置を取得する。
 @param[in] request リクエストパラメータ
 @return 再生位置。無い場合はnilを返す。
 */
+ (NSNumber *) offsetFromRequest:(DConnectMessage *)request;

/*!
 @brief リクエストデータからリミットを取得する。
 @param[in] request リクエストパラメータ
 @return リミット。無い場合はnilを返す。
 */
+ (NSNumber *) limitFromRequest:(DConnectMessage *)request;

@end
