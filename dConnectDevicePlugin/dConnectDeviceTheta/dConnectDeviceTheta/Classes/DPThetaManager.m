//
//  DPThetaManager.m
//  dConnectDeviceTheta
//
//  Copyright (c) 2015 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPThetaManager.h"
#import "DPThetaDevicePlugin.h"
#import "PtpConnection.h"
#import "PtpLogging.h"

static NSString * const DPThetaRegexDecimalPoint = @"^[-+]?([0-9]*)?(\\.)?([0-9]*)?$";
static NSString * const DPThetaRegexDigit = @"^([0-9]*)?$";
static NSString * const DPThetaRegexCSV = @"^([^,]*,)+";

@interface DPThetaManager()<PtpIpEventListener>
{
    PtpConnection* _ptpConnection;
    NSMutableArray* _objects;
    PtpIpStorageInfo* _storageInfo;
    NSString* _deviceInfo;
    NSUInteger _batteryLevel;
    NSUInteger _cameraStatus;
    DPThetaBlock _imageCallback;
    NSMutableDictionary* _onPhotoEventList;
    NSMutableDictionary* _onStatusEventList;
    CGSize _imageSize;
}
@end

@implementation DPThetaManager

/*!
 セマフォのタイムアウト時間[秒]
 */
static int const _timeout = 500;

// share instance
+ (instancetype)sharedManager
{
    static id sharedInstance;
    static dispatch_once_t onceSpheroToken;
    dispatch_once(&onceSpheroToken, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

// init
- (instancetype)init
{
    self = [super init];
    if (self) {
        _objects = [NSMutableArray array];
        _imageCallback = nil;
        _cameraStatus = 0;
        _deviceInfo = nil;
        _batteryLevel = 0;
        _onPhotoEventList = [NSMutableDictionary new];
        _onStatusEventList = [NSMutableDictionary new];

        // Ready to PTP/IP.
        _ptpConnection = [[PtpConnection alloc] init];
        [_ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
        [_ptpConnection setEventListener:self];
        

    }
    return self;
}


#pragma mark - PtpIpEventListener delegates.

-(void)ptpip_eventReceived:(int)code :(uint32_t)param1 :(uint32_t)param2 :(uint32_t)param3
{
    // PTP/IP-Event callback.
    if (code == PTPIP_OBJECT_ADDED) {
        [_ptpConnection operateSession:^(PtpIpSession *session) {
            PtpIpObjectInfo *objectInfo = [self loadObject:param1 session:session];
            if (objectInfo.object_format == PTPIP_FORMAT_JPEG) {
                NSString *filePath = [self saveImageFileWithPtpIpObjectInfo:objectInfo
                                                                    session:session];
                if (_imageCallback) {
                    _imageCallback(filePath, objectInfo.filename);
                    _imageCallback = nil;
                }
                //OnPhotoのコールバック
                for (id key in [_onPhotoEventList keyEnumerator]) {
                    DPThetaBlock callback = _onPhotoEventList[key];
                    if (callback) {
                        callback(filePath, objectInfo.filename);
                    }
                }
            } else {
                //OnStatusChangeのコールバック
                for (id key in [_onStatusEventList keyEnumerator]) {
                    DPThetaOnStatusChangeCallback callback = _onStatusEventList[key];
                    if (callback) {
                        callback(objectInfo, @"stop", nil);
                    }
                }
            }
            
        }];
        
    } else {
        for (id key in [_onStatusEventList keyEnumerator]) {
            DPThetaOnStatusChangeCallback callback = _onStatusEventList[key];
            if (callback) {
                callback(nil, @"recording", nil);
            }
        }
    }
}

-(void)ptpip_socketError:(int)err
{
    // socket error callback.
    // This method is running at PtpConnection#gcd thread.
    
    // If libptpip closed the socket, `closed` is non-zero.
    BOOL closed = PTP_CONNECTION_CLOSED(err);
    int error = err;
    // PTPIP_PROTOCOL_*** or POSIX error number (errno()).
    error = PTP_ORIGINAL_PTPIPERROR(err);
    
    NSArray* errTexts = @[@"Socket closed",              // PTPIP_PROTOCOL_SOCKET_CLOSED
                          @"Brocken packet",             // PTPIP_PROTOCOL_BROCKEN_PACKET
                          @"Rejected",                   // PTPIP_PROTOCOL_REJECTED
                          @"Invalid session id",         // PTPIP_PROTOCOL_INVALID_SESSION_ID
                          @"Invalid transaction id.",    // PTPIP_PROTOCOL_INVALID_TRANSACTION_ID
                          @"Unrecognided command",       // PTPIP_PROTOCOL_UNRECOGNIZED_COMMAND
                          @"Invalid receive state",      // PTPIP_PROTOCOL_INVALID_RECEIVE_STATE
                          @"Invalid data length",        // PTPIP_PROTOCOL_INVALID_DATA_LENGTH
                          @"Watchdog expired",           // PTPIP_PROTOCOL_WATCHDOG_EXPIRED
                          ];
    NSString* desc = @(strerror(error));
    if ((PTPIP_PROTOCOL_SOCKET_CLOSED<=error) && (err<=PTPIP_PROTOCOL_WATCHDOG_EXPIRED)) {
        desc = errTexts[error - PTPIP_PROTOCOL_SOCKET_CLOSED];
    }
    
    if (closed) {
        [_objects removeAllObjects];
    }
    for (id key in [_onStatusEventList keyEnumerator]) {
        DPThetaOnStatusChangeCallback callback = _onStatusEventList[key];
        if (callback) {
            callback(nil, @"error", desc);
        }
    }
    if (_imageCallback) {
        _imageCallback(nil, nil);
        _imageCallback = nil;
    }

}


// 接続
- (BOOL)connect
{
    if ([_ptpConnection connected]) {
        return YES;
    }
    __block BOOL result = NO;
    // Setup `target IP`(camera IP).
    // Product default is "192.168.1.1".
    [_ptpConnection setTargetIp:@"192.168.1.1"];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 100);

    [_ptpConnection connect:^(BOOL connected) {
        result = connected;
        dispatch_semaphore_signal(semaphore);

    }];
    dispatch_semaphore_wait(semaphore, timeout);
    return result;

}

// 接続断
- (void)disconnect
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);

    [_ptpConnection close:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, timeout);
}

// 初期値の更新
- (void)enumObjects
{
    [_objects removeAllObjects];
    
    [_ptpConnection getDeviceInfo:^(const PtpIpDeviceInfo* info) {
        // "GetDeviceInfo" completion callback.
        _deviceInfo = info.serial_number;
    }];
    
    [_ptpConnection operateSession:^(PtpIpSession *session) {
        [session setDateTime:[NSDate dateWithTimeIntervalSinceNow:0]];
        _storageInfo = [session getStorageInfo];
        
        _batteryLevel = [session getBatteryLevel];
        
        NSArray* objectHandles = [session getObjectHandles];
        
        for (NSNumber* it in objectHandles) {
            uint32_t objectHandle = (uint32_t)it.integerValue;
            PtpIpObjectInfo *obj = [self loadObject:objectHandle session:session];
            if (obj) {
                [_objects addObject:obj];
            }
        }
    }];
}

- (PtpIpObjectInfo*)loadObject:(uint32_t)objectHandle session:(PtpIpSession*)session
{
    PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
    if (!objectInfo) {
        return nil;
    }
    
    return objectInfo;
}



// Thetaと接続されているかどうか
- (BOOL)isConnected {
    return [_ptpConnection connected];
}


// take a photo in the Theta
- (BOOL)takePictureWithCompletion:(void(^)(NSString *uri, NSString* path))completion
                          fileMgr:(DConnectFileManager*)fileMgr
{
    self.fileMgr = fileMgr;
    __block BOOL result = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);

    [_ptpConnection operateSession:^(PtpIpSession *session)
     {
         // Single shot mode or Interval shooting mode.
         if ([session getStillCaptureMode] == 1
             || [session getStillCaptureMode] == 3) {
             result = YES;
             _imageCallback = completion;
             [session setAudioVolume: 1];
             [session initiateCapture];
         } else {
             result = NO;
         }
         dispatch_semaphore_signal(semaphore);
     }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return result;
}

// 動画を撮影する
- (BOOL)recordingMovie {
    __block BOOL result = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);
    
    [_ptpConnection operateSession:^(PtpIpSession *session)
     {
         // Single shot mode or Interval shooting mode.
         if ([session getStillCaptureMode] == 0) {
             result = YES;
             [session setAudioVolume: 1];
             [session initiateOpenCapture];
         } else {
             result = NO;
         }
         dispatch_semaphore_signal(semaphore);
     }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return result;
}

// 動画を撮影を停止する
- (BOOL)stopMovie {
    __block BOOL result = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);
    
    [_ptpConnection operateSession:^(PtpIpSession *session)
     {
         // Single shot mode or Interval shooting mode.
         if ([session getStillCaptureMode] == 0) {
             result = [session terminateOpenCapture: 0xFFFFFFFF];
         } else {
             result = NO;
         }
         dispatch_semaphore_signal(semaphore);
     }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return result;
}

// BatteryのLevelを返す
- (NSUInteger)getBatteryLevel {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);

    [_ptpConnection operateSession:^(PtpIpSession *session) {
        _batteryLevel = [session getBatteryLevel];
        dispatch_semaphore_signal(semaphore);

    }];
    dispatch_semaphore_wait(semaphore, timeout);

    return _batteryLevel;
}

//シリアルNoを返す
- (NSString*)getSerialNo {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);

    [_ptpConnection getDeviceInfo:^(const PtpIpDeviceInfo* info) {
        _deviceInfo = info.serial_number;
        dispatch_semaphore_signal(semaphore);

    }];
    dispatch_semaphore_wait(semaphore, timeout);

    return _deviceInfo;
}

//カメラのステータスを返す
- (NSUInteger)getCameraStatus {
    __block NSUInteger status = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);
    
    [_ptpConnection operateSession:^(PtpIpSession *session)
     {
         // Single shot mode or Interval shooting mode.
         status = [session getCaptureStatus];
         dispatch_semaphore_signal(semaphore);
     }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return status;
    
}


#pragma mark- Set Event

- (void)addOnPhotoEventCallbackWithID:(NSString*)serviceId
                              fileMgr:(DConnectFileManager*)fileMgr
                             callback:(void (^)(NSString *path))callback
{
    self.fileMgr = fileMgr;
    _onPhotoEventList[serviceId] = callback;
}

- (void)addOnStatusEventCallbackWithID:(NSString*)serviceId
                              callback:(void (^)(PtpIpObjectInfo *object, NSString *status, NSString *message))callback
{
    _onStatusEventList[serviceId] = callback;
}

- (void)removeOnPhotoEventCallbackWithID:(NSString*)serviceId
{
    [_onPhotoEventList removeObjectForKey:serviceId];
}

- (void)removeOnStatusEventCallbackWithID:(NSString*)serviceId
{
    [_onStatusEventList removeObjectForKey:serviceId];
}


- (NSString*)saveImageFileWithPtpIpObjectInfo:(PtpIpObjectInfo *)ptpIp
                                      session:(PtpIpSession *)session
{
    NSString *path = ptpIp.filename;
    if (!self.fileMgr) {
        return nil;
    }

    NSFileManager *sysFileMgr = [NSFileManager defaultManager];
    
    NSString *dstPath = [self pathByAppendingPathComponent:path];
    if ([sysFileMgr fileExistsAtPath:dstPath]) {
        return nil;
    }
    NSData *data = [self getDataWithPtpObject:ptpIp
                    session:session];
    NSString *resultPath = [self.fileMgr createFileForPath:dstPath contents:data];
    
    return resultPath;
}



//バイナリーデータを取得する
-(NSData*)getDataWithPtpObject:(PtpIpObjectInfo *)ptpInfo
                    session:(PtpIpSession *)session
{
    NSMutableData* imageData = [NSMutableData data];
    uint32_t objectHandle = (uint32_t)ptpInfo.object_handle;
    NSInteger imageWidth = 2048;
    NSInteger imageHeight = 1024;
    if (((_imageSize.width != imageWidth)
         && (_imageSize.width != imageHeight))
        && ((_imageSize.width > 0)
            && (_imageSize.width > 0))) {
        imageWidth = _imageSize.width;
        imageHeight = _imageSize.height;
    }
    [session getResizedImageObject:objectHandle
                                       width:imageWidth
                                      height:imageHeight
                                 onStartData:^(NSUInteger totalLength) {
                                 } onChunkReceived:^BOOL(NSData *data) {
                                     // Callback for each chunks.
                                     [imageData appendData:data];
                                     return YES;
                                 }];
    return (NSData*) imageData;

}


// ファイルを削除する
- (BOOL)removeFileWithName:(NSString*)fileName
                   fileMgr:(DConnectFileManager*)fileMgr

{
    self.fileMgr = fileMgr;
    __block BOOL isSuccess = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);

    [_ptpConnection operateSession:^(PtpIpSession *session) {
        NSArray* objectHandles = [session getObjectHandles];
        
        for (NSNumber* it in objectHandles) {
            uint32_t objectHandle = (uint32_t)it.integerValue;
            PtpIpObjectInfo *obj = [self loadObject:objectHandle session:session];
            if ([fileName isEqualToString:obj.filename]) {
                [session deleteObject: objectHandle];
                dispatch_semaphore_signal(semaphore);
                isSuccess = YES;
                return;
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, timeout);

    return isSuccess;
}


- (NSString*)receiveImageFileWithFileName:(NSString *)fileName
                                  fileMgr:(DConnectFileManager*)fileMgr
{
    self.fileMgr = fileMgr;
    __block PtpIpObjectInfo *ptpInfo;
    __block NSString *path = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);
    
    [_ptpConnection operateSession:^(PtpIpSession *session) {
        NSArray* objectHandles = [session getObjectHandles];
        
        for (NSNumber* it in objectHandles) {
            uint32_t objectHandle = (uint32_t)it.integerValue;
            PtpIpObjectInfo *obj = [self loadObject:objectHandle session:session];
            if ([fileName isEqualToString:obj.filename]) {
                ptpInfo = obj;
                path = [self saveImageFileWithPtpIpObjectInfo:ptpInfo
                                  session:session];

                dispatch_semaphore_signal(semaphore);
                return;
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return path;
}



// ファイルを取得する
- (NSMutableArray*)getAllFiles
{
    __block NSMutableArray *images = [NSMutableArray array];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * _timeout);
    
    [_ptpConnection operateSession:^(PtpIpSession *session) {
        NSArray* objectHandles = [session getObjectHandles];
        
        for (NSNumber* it in objectHandles) {
            uint32_t objectHandle = (uint32_t)it.integerValue;
            PtpIpObjectInfo *obj = [self loadObject:objectHandle session:session];
            if (obj.object_format == PTPIP_FORMAT_JPEG) {
                [images addObject:obj];
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, timeout);
    
    return images;
}



// イメージのサイズを指定する
- (void)setImageSize:(CGSize)imageSize
{
    _imageSize = imageSize;
}

// アプリがバックグラウンドに入った
- (void)applicationDidEnterBackground
{
    if (_ptpConnection) {
        [self disconnect];
    }
}

// アプリがフォアグラウンドに入った
- (void)applicationWillEnterForeground
{
    if (_ptpConnection) {
        [self connect];
    }
}

- (NSString *) pathByAppendingPathComponent:(NSString *)pathComponent
{
    return [self.fileMgr.URL URLByAppendingPathComponent:pathComponent].standardizedURL.path;
}


- (NSString *) percentEncodeString:(NSString *)string withEncoding:(NSStringEncoding)encoding
{
    NSCharacterSet *allowedCharSet
    = [[NSCharacterSet characterSetWithCharactersInString:@";/?:@&=$+{}<>., "] invertedSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharSet];
}


/*
 数値判定。
 */
+ (BOOL)existNumberWithString:(NSString *)numberString Regex:(NSString*)regex {
    NSRange match = [numberString rangeOfString:regex options:NSRegularExpressionSearch];
    //数値の場合
    return match.location != NSNotFound;
}

// 整数かどうかを判定する。 true:存在する
+ (BOOL)existDigitWithString:(NSString*)digit {
    return [self existNumberWithString:digit Regex:DPThetaRegexDigit];
}

// 少数かどうかを判定する。
+ (BOOL)existDecimalWithString:(NSString*)decimal {
    return [self existNumberWithString:decimal Regex:DPThetaRegexDecimalPoint];
}

@end