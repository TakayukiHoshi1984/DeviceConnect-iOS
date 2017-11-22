//
//  SonyCameraRemoteApiUtil.m
//  dConnectDeviceSonyCamera
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "SonyCameraRemoteApiUtil.h"
#import "SampleRemoteApi.h"
#import "RemoteApiList.h"
#import "DeviceList.h"
#import "SampleLiveviewManager.h"

/** @define 各操作のタイムアウト時間を定義する. */
#define TIMEOUT (30)

NSString *const SonyCameraStatusMovieRecording = @"MovieRecording";
NSString *const SonyCameraStatusIdle = @"IDLE";
NSString *const SonyCameraShootModeMovie = @"movie";
NSString *const SonyCameraShootModePicture = @"still";

@interface SonyCameraRemoteApiUtil ()

/*!
 @breif 一時的にレスポンスを格納するDictionary。
 */
@property (strong, nonatomic) NSMutableDictionary *responseDic;

/*!
 @brief APIリスト。
 */
@property (strong, nonatomic) NSArray *apiList;

/*!
 @brief プレビュー用マネジャー。
 */
@property (strong, nonatomic) SampleLiveviewManager *liveviewMgr;

@end


@implementation SonyCameraRemoteApiUtil

- (id) init
{
    self = [super init];
    if (self) {
        self.responseDic = [NSMutableDictionary dictionary];
        self.liveviewMgr = [[SampleLiveviewManager alloc] init];
        self.apiList = nil;
        self.cameraStatus = nil;
        self.shootMode = nil;
        self.zoomPosition = -1;
        
        // SonyCameraの監視を開始する.
        SampleCameraEventObserver *observer = [SampleCameraEventObserver getInstance];
        [observer startWithDelegate:self];
    }
    return self;
}

#pragma mark - Public Methods -

- (void) destroy
{
    [[SampleCameraEventObserver getInstance] stop];
}

- (void) actGetApiList
{
    [SampleRemoteApi getAvailableApiList:self isSync:NO];
    
    // APIリストが返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_getAvailableApiList] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    NSDictionary *dict = [self.responseDic objectForKey:API_getAvailableApiList];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_getAvailableApiList];
        
        NSString *errorMessage = @"";
        NSInteger errorCode = -1;
        NSArray *resultArray = dict[@"result"];
        NSArray *errorArray = dict[@"error"];
        if (errorArray && errorArray.count > 0) {
            errorCode = (NSInteger) errorArray[0];
            errorMessage = errorArray[1];
        }

        // サポートしているAPI
        if (resultArray.count > 0 && errorCode < 0) {
            self.apiList = resultArray[0];
        }
    }
}

- (BOOL) isApiAvailable:(NSString *)apiName
{
    return (self.apiList && self.apiList.count > 0 && [self.apiList containsObject:apiName]);
}

- (BOOL) isStartedLiveView
{
    return [self.liveviewMgr isStarted];
}

- (BOOL) actStartLiveView:(id<SampleLiveviewDelegate>)delegate
{
    [SampleRemoteApi startLiveview:self];
    
    // 撮影モード切り替えの結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_startLiveview] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    NSDictionary *dict = [self.responseDic objectForKey:API_startLiveview];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_startLiveview];
        
        NSString *errorMessage = @"";
        NSInteger errorCode = -1;
        NSArray *resultArray = dict[@"result"];
        NSArray *errorArray = dict[@"error"];
        if (errorArray && errorArray.count > 0) {
            errorCode = (NSInteger) errorArray[0];
            errorMessage = errorArray[1];
        }

        if (resultArray.count > 0 && errorCode < 0) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSString* liveviewUrl = resultArray[0];
                [self.liveviewMgr start:liveviewUrl delegate:delegate];
            });
        }
        return YES;
    }
    return NO;
}

- (BOOL) actStopLiveView
{
    [self.liveviewMgr stop];
    return YES;
}

- (BOOL) actSetShootMode:(NSString *)mode
{
    [SampleRemoteApi setShootMode:self shootMode:mode];
    
    // 撮影モード切り替えの結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_setShootMode] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // 撮影モード切り替えの結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_setShootMode];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_setShootMode];
        
        NSString *errorMessage = @"";
        NSInteger errorCode = -1;
        NSArray *resultArray = dict[@"result"];
        NSArray *errorArray = dict[@"error"];
        if (errorArray && errorArray.count > 0) {
            errorCode = (NSInteger) errorArray[0];
            errorMessage = errorArray[1];
        }
        return (resultArray.count > 0 && errorCode == 0);
    }
    return NO;
}

- (NSDictionary *) actTakePicture
{
    [SampleRemoteApi actTakePicture:self];
    
    // 写真撮影の結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_actTakePicture] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // 撮影結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_actTakePicture];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_actTakePicture];
        return dict;
    }
    return nil;
}

- (NSDictionary *) startMovieRec
{
    [SampleRemoteApi startMovieRec:self];
    
    // 写真撮影の結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_startRecMode] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // 撮影結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_startRecMode];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_startRecMode];
        return dict;
    }
    return nil;
}



- (NSDictionary *) stopMovieRec
{
    [SampleRemoteApi startMovieRec:self];
    
    // 写真撮影の結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_stopRecMode] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // 撮影結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_stopRecMode];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_stopRecMode];
        return dict;
    }
    return nil;
}


- (NSDictionary *) actZoom:(NSString *)direction movement:(NSString *)movement
{
    [SampleRemoteApi actZoom:self direction:direction movement:movement];
    
    // ズームの結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_actZoom] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // ズーム結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_actZoom];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_actZoom];
        return dict;
    }
    return nil;
}

- (NSDictionary *) getStillSize
{
    [SampleRemoteApi getStillSize:self];
    
    // ズームの結果が返ってくるまでwait
	int time = 0;
	while ([self.responseDic valueForKey:API_getStillSize] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // ズーム結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_getStillSize];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_getStillSize];
        return dict;
    }
    return nil;
}

- (BOOL) setDate:(NSString *)date {
    [SampleRemoteApi setCurrentTime:self dateTime:date timeZoneOffsetMinute:0 dstOffsetMinute:0];
    
    int time = 0;
	while ([self.responseDic valueForKey:API_setCurrentTime] == nil && time < TIMEOUT) {
		sleep(1);
		time++;
	}
    
    // 時間設定の結果を取得
    NSDictionary *dict = [self.responseDic objectForKey:API_setCurrentTime];
    if (time <= TIMEOUT) {
        [self.responseDic removeObjectForKey:API_setCurrentTime];
        
        NSString *errorMessage = @"";
        NSInteger errorCode = -1;
        NSArray *resultArray = dict[@"result"];
        NSArray *errorArray = dict[@"error"];
        if (errorArray && errorArray.count > 0) {
            errorCode = (NSInteger) errorArray[0];
            errorMessage = errorArray[1];
        }
        return (resultArray.count > 0 && errorCode == 0);
    }
    return NO;
}


#pragma mark - HttpAsynchronousRequestParserDelegate Methods -

- (void) parseMessage:(NSData *)response apiName:(NSString *)apiName {
	NSError *error;
	NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:response
														 options:NSJSONReadingMutableContainers
														   error:&error];
	NSArray *resultArray = [NSArray new];
	NSString* errorMessage = @"";
	NSInteger errorCode = -1;
    NSInteger apiId = -1;
	if (error) {
        return;
	} else {
        apiId = (NSInteger) dict[@"id"];
		resultArray = dict[@"result"];
		NSArray *errorArray = dict[@"error"];
		if (errorArray && errorArray.count > 0) {
			errorCode = (NSInteger) errorArray[0];
			errorMessage = errorArray[1];
		}
	}
    // レスポンス格納用のdictionaryにデータをつめる
	if([apiName isEqualToString:API_getAvailableApiList]) {
        [self.responseDic setObject:dict forKey:API_getAvailableApiList];
	} else if([apiName isEqualToString:API_setShootMode]) {
        [self.responseDic setObject:dict forKey:API_setShootMode];
	} else if([apiName isEqualToString:API_startLiveview]) {
        [self.responseDic setObject:dict forKey:API_startLiveview];
	} else if([apiName isEqualToString:API_actTakePicture]) {
        [self.responseDic setObject:dict forKey:API_actTakePicture];
	} else if([apiName isEqualToString:API_startMovieRec]) {
        [self.responseDic setObject:dict forKey:API_startRecMode];
	} else if([apiName isEqualToString:API_stopMovieRec]) {
        [self.responseDic setObject:dict forKey:API_stopRecMode];
	} else if([apiName isEqualToString:API_actZoom]) {
        [self.responseDic setObject:dict forKey:API_actZoom];
    } else if([apiName isEqualToString:API_getStillSize]) {
        [self.responseDic setObject:dict forKey:API_getStillSize];
    } else if ([apiName isEqualToString:API_setCurrentTime]) {
        [self.responseDic setObject:dict forKey:API_setCurrentTime];
    }
}


#pragma mark - SampleEventObserverDelegate Methods -

- (void) didAvailableApiListChanged:(NSArray*) API_CAMERA_list {
    self.apiList = API_CAMERA_list;
}

- (void) didCameraStatusChanged:(NSString*) status {
    self.cameraStatus = status;
}

- (void) didLiveviewStatusChanged:(BOOL) status {
    
}

- (void) didShootModeChanged:(NSString*) shootMode {
    self.shootMode = shootMode;
}

- (void) didZoomPositionChanged:(int) zoomPosition {
    self.zoomPosition = zoomPosition / (double) 100;
}

- (void) didStorageInformationChanged:(NSString *)storagId {
    if (self.delegate) {
        [self.delegate didReceivedImage:storagId];
    }
}

@end
