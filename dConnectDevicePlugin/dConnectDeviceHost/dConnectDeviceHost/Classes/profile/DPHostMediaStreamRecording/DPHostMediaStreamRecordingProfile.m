//
//  DPHostMediaStreamRecordingProfile.m
//  dConnectDeviceHost
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <DConnectSDK/DConnectFileManager.h>
#import <ImageIO/ImageIO.h>
#import "DPHostDevicePlugin.h"
#import "DPHostService.h"
#import "DPHostMediaStreamRecordingProfile.h"
#import "DPHostRecorderContext.h"
#import "DPHostUtils.h"

NSUInteger MediaIdLength = 3;

static NSString *KeyPathAdjustingFocus = @"adjustingFocus";
static NSString *KeyPathAdjustingExposure = @"adjustingExposure";
static NSString *KeyPathAdjustingWhiteBalance = @"adjustingWhitBalance";

typedef NS_ENUM(NSUInteger, OptionIndex) {
    OptionIndexImageWidth,  ///< imageWidth: 画像の横幅
    OptionIndexImageHeight, ///< imageHeight: 画像の縦幅
    OptionIndexMimeType,    ///< mimeType: MIMEタイプ
};

@interface DPHostMediaStreamRecordingProfile ()

@property NSDictionary *cameraInfoDict;
/*!
 デフォルトの静止画レコーダーのID
 iOSデバイスによっては背面カメラが無かったりと差異があるので、
 ランタイム時にデフォルトのレコーダーを決定する処理を行う。
 */
@property (nonatomic) NSNumber *defaultPhotoRecorderId;
/*!
 デフォルトの動画レコーダーのID
 iOSデバイスによっては背面カメラが無かったりと差異があるので、
 ランタイム時にデフォルトのレコーダーを決定する処理を行う。
 */
@property (nonatomic) NSNumber *defaultVideoRecorderId;
/*!
 デフォルトの音声レコーダーのID
 */
@property (nonatomic) NSNumber *defaultAudioRecorderId;
/*!
 カレントのレコーダーのID
 */
@property (nonatomic) NSNumber *currentRecorderId;


/// レコーダーで使用できる静止画入力データ
@property (nonatomic) NSMutableArray *photoDataSourceArr;
/// レコーダーで使用できる動画入力データ
@property (nonatomic) NSMutableArray *audioDataSourceArr;
/// レコーダーで使用できる音声入力データ
@property (nonatomic) NSMutableArray *videoDataSourceArr;

/// 使用できるレコーダー
@property (nonatomic) NSMutableArray *recorderArr;

@property ALAssetsLibrary *library;


/*!
 @brief iOSデバイスの向き
 画面が天井や地面を向いた際は、無視して以前の向き情報を保持する。
 UIDeviceOrientationPortraitUpsideDown: 
 この場合、iOSデバイスを正面に見据えて、デバイスを反時計回りに180°回転し、
 Homeボタンが上方向にある状態。
 UIDeviceOrientationLandscapeLeft: 
 この場合、iOSデバイスを正面に見据えて、デバイスを反時計回りに90°回転し、
 Homeボタンが右方向にある状態。
 */
@property (nonatomic) UIDeviceOrientation referenceOrientation;

/// 前回プレビューを送った時間。
@property (nonatomic) CMTime lastPreviewTimestamp;
/// Data Available Event APIでプレビュー画像URIの配送を行うかどうか。
@property (nonatomic) BOOL sendPreview;
/// Data Available Event APIでプレビュー画像URIの配送を行うインターバル（秒）。
@property (nonatomic) CMTime secPerFrame;

/// ポーズ前最後のサンプルのタイムスタンプ
@property CMTime lastSampleTimestamp;
/// ポーズの累計期間
@property CMTime totalPauseDuration;
/// ポーズの累計期間を再計算する必要が有るかどうか
@property BOOL needRecalculationOfTotalPauseDuration;
/**
 @brief 現在のプレビュー画像の連番。
 Data Available Event APIで送るプレビュー画像は0-99までの連番を組み込んだ固定名を与えるの
 で、現在0-99までのどの連番を使ったかを管理する。
 */
@property int curPreviewImageEnumerator;

/*!
 オーディオAssetWriterInputを準備し、指定されたアセットライターに追加する。
 @param assetWriter オーディオAssetWriterInputを追加したいアセットライター
 @param currentFormatDescription メディア情報を保持したオブジェクト
 @retval YES <code>assetWriter</code>へのオーディオAssetWriterInput追加に成功。
 @retval NO <code>assetWriter</code>へのオーディオAssetWriterInput追加に失敗。
 */
- (BOOL) setupAssetWriterAudioInputForRecorderContext:(DPHostRecorderContext *)recorderCtx
                                          description:(CMFormatDescriptionRef)currentFormatDescription;
/*!
 ビデオAssetWriterInputを準備し、指定されたアセットライターに追加する。
 @param assetWriter ビデオAssetWriterInputを追加したい
 @param currentFormatDescription メディア情報を保持したオブジェクト
 @retval YES <code>assetWriter</code>へのビデオAssetWriterInput追加に成功。
 @retval NO <code>assetWriter</code>へのビデオAssetWriterInput追加に失敗。
 */
- (BOOL) setupAssetWriterVideoInputForRecorderContext:(DPHostRecorderContext *)recorderCtx
                                          description:(CMFormatDescriptionRef)currentFormatDescription;

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(UIDeviceOrientation)orientation
                                                  position:(AVCaptureDevicePosition)position;

- (CGAffineTransform)transformVideoOrientation:(AVCaptureVideoOrientation)orientation
                                      position:(AVCaptureDevicePosition)position;

- (void) sendOnPhotoEventWithPath:(NSString *)path mimeType:(NSString*)mimeType;
- (void) sendOnRecordingChangeEventWithStatus:(NSString *)status
                                         path:(NSString *)path
                                     mimeType:(NSString *)mimeType
                                 errorMessage:(NSString *)errorMsg;
- (void) sendOnDataAvailableEventWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/*!
 サンプルデータを書き込む。
 @param sampleBuffer オーディオもしくはビデオのサンプルデータ
 @param recorderCtx AssetWriterInputを保持するレコーダー管理オブジェクト
 @param isAudio <code>YES</code>ならばオーディオAssetWriterInputに、
        <code>NO</code>ならばビデオAssetWriterInputに
        <code>sampleBuffer</code>を追加
 @retval YES <code>sampleBuffer</code>のAssetWriterInputへの書き込みに成功。
 @retval NO <code>sampleBuffer</code>のAssetWriterInputへの書き込みに失敗。
 */
- (BOOL) appendSampleBuffer:(CMSampleBufferRef)sampleBuffer
            recorderContext:(DPHostRecorderContext *)recorderCtx isAudio:(BOOL)isAudio;

- (CMSampleBufferRef) sampleBufferByAdjustingTimestamp:(CMSampleBufferRef)sample by:(CMTime)offset;

@end

@implementation DPHostMediaStreamRecordingProfile

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
        self.eventMgr = [DConnectEventManager sharedManagerForClass:[DPHostDevicePlugin class]];
        __weak DPHostMediaStreamRecordingProfile *weakSelf = self;
        
        self.recorderArr = [NSMutableArray array];
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange)
                                   name:UIDeviceOrientationDidChangeNotification object:nil];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        self.curPreviewImageEnumerator = 0;
        self.currentRecorderId = nil;
        self.secPerFrame = CMTimeMake(2, 1000);
        self.lastPreviewTimestamp = kCMTimeInvalid;
        self.lastSampleTimestamp = kCMTimeInvalid;
        self.totalPauseDuration = kCMTimeInvalid;
        self.needRecalculationOfTotalPauseDuration = NO;
        DPHostRecorderDataSource *recCtx;
        self.library = [ALAssetsLibrary new];
        AVCaptureSession *session;
        self.photoDataSourceArr = [NSMutableArray array];
        self.audioDataSourceArr = [NSMutableArray array];
        self.videoDataSourceArr = [NSMutableArray array];
        NSString *defaultVideoDevUId = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].uniqueID;
        NSArray *audioDevArr = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        NSArray *videoDevArr = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        for (AVCaptureDevice *audioDev in audioDevArr) {
            // 出力：音声
            session = [AVCaptureSession new];
            recCtx = [DPHostRecorderDataSource recorderDataSourceForAudioWithAudioDevice:audioDev];
            
            if (recCtx) {
                recCtx.position = audioDev.position;
                [self.audioDataSourceArr addObject:recCtx];
            }
        }
        for (AVCaptureDevice *videoDev in videoDevArr) {
            session = [AVCaptureSession new];
            recCtx = [DPHostRecorderDataSource recorderDataSourceForPhotoWithVideoDevice:videoDev];
            
            if (recCtx) {
                recCtx.position = videoDev.position;
                [self.photoDataSourceArr addObject:recCtx];
            }
            session = [AVCaptureSession new];
            recCtx = [DPHostRecorderDataSource recorderDataSourceForVideoWithVideoDevice:videoDev];
            
            if (recCtx) {
                recCtx.position = videoDev.position;
                NSMutableArray *dimensionArr =
                @[
                  AVCaptureSessionPreset352x288,
                  AVCaptureSessionPreset640x480,
                  AVCaptureSessionPreset1280x720,
                  AVCaptureSessionPreset1920x1080
                  ].mutableCopy;
                for (size_t i = 0; i < dimensionArr.count; ++i) {
                    if (![session canSetSessionPreset:dimensionArr[i]]) {
                        [dimensionArr removeObjectAtIndex:i];
                    }
                }
                NSDictionary *(^getDimension)(NSString *) = ^ NSDictionary *(NSString *preset) {
                    if ([preset isEqualToString:AVCaptureSessionPreset352x288]) {
                        return @{@"h":@352 ,@"w":@288};
                    } else if ([preset isEqualToString:AVCaptureSessionPreset640x480]) {
                        return @{@"h":@640 ,@"w":@480};
                    } else if ([preset isEqualToString:AVCaptureSessionPreset1280x720]) {
                        return @{@"h":@1280 ,@"w":@720};
                    } else if ([preset isEqualToString:AVCaptureSessionPreset1920x1080]) {
                        return @{@"h":@1920 ,@"w":@1080};
                    }
                    return nil;
                };
                NSDictionary *minDim = getDimension([dimensionArr firstObject]);
                NSDictionary *maxDim = getDimension([dimensionArr lastObject]);
                recCtx.imageHeight = recCtx.minImageHeight = minDim[@"h"];
                recCtx.imageWidth = recCtx.minImageWidth = minDim[@"w"];
                recCtx.maxImageHeight = maxDim[@"h"];
                recCtx.maxImageWidth = maxDim[@"w"];
                
                [self.videoDataSourceArr addObject:recCtx];
            }
        }
        unsigned long videoNormalCount = 0;
        unsigned long videoBackCount = 0;
        unsigned long videoFrontCount = 0;
        for (DPHostRecorderDataSource *dataSrc in self.photoDataSourceArr) {
            if ([dataSrc.uniqueId isEqualToString:defaultVideoDevUId]) {
                self.defaultPhotoRecorderId = [NSNumber numberWithUnsignedInteger:self.recorderArr.count];
            }
            
            DPHostRecorderContext *recorder = [[DPHostRecorderContext alloc] initWithProfile:self];
            recorder.type = RecorderTypePhoto;
            recorder.mimeType = [DConnectFileManager searchMimeTypeForExtension:@"jpg"];
            recorder.state = RecorderStateInactive;
            
            [recorder setRecorderDataSource:dataSrc delegate:self];
            
            NSMutableString *name = @"photo_".mutableCopy;
            switch (dataSrc.position) {
                case AVCaptureDevicePositionBack:
                    [name appendString:@"back_"];
                    [name appendString:[NSString stringWithFormat:@"%lu", videoBackCount]];
                    ++videoBackCount;
                    break;
                case AVCaptureDevicePositionFront:
                    [name appendString:@"front_"];
                    [name appendString:[NSString stringWithFormat:@"%lu", videoFrontCount]];
                    ++videoFrontCount;
                    break;
                case AVCaptureDevicePositionUnspecified:
                default:
                    [name appendString:[NSString stringWithFormat:@"%lu", videoNormalCount]];
                    ++videoNormalCount;
                    break;
            }
            recorder.name = [NSString stringWithString:name];
            
            [self.recorderArr addObject:recorder];
        }
        
        unsigned long audioVideoNormalCount = 0;
        unsigned long audioVideoBackCount = 0;
        unsigned long audioVideoFrontCount = 0;
        for (DPHostRecorderDataSource *videoDataSrc in self.videoDataSourceArr) {
            // 動画（ビデオのみ）
            if (self.audioDataSourceArr.count == 0 && [videoDataSrc.uniqueId isEqualToString:defaultVideoDevUId]) {
                self.defaultVideoRecorderId = [NSNumber numberWithUnsignedInteger:self.recorderArr.count];
            }
            DPHostRecorderContext *recorder;
            NSMutableString *name;
            
            for (DPHostRecorderDataSource *audioDataSrc in self.audioDataSourceArr) {
                // 動画（動画・音声）
                if ([videoDataSrc.uniqueId isEqualToString:defaultVideoDevUId]) {
                    self.defaultVideoRecorderId = [NSNumber numberWithUnsignedInteger:self.recorderArr.count];
                }
                
                recorder = [[DPHostRecorderContext alloc] initWithProfile:self];
                recorder.type = RecorderTypeMovie;
                recorder.mimeType = [DConnectFileManager searchMimeTypeForExtension:@"mp4"];
                recorder.state = RecorderStateInactive;
                
                [recorder setRecorderDataSource:audioDataSrc delegate:self];
                [recorder setRecorderDataSource:videoDataSrc delegate:self];
                
                name = @"movie_audio_video_".mutableCopy;
                switch (videoDataSrc.position) {
                    case AVCaptureDevicePositionBack:
                        [name appendString:@"back_"];
                        [name appendString:[NSString stringWithFormat:@"%lu", audioVideoBackCount]];
                        ++audioVideoBackCount;
                        break;
                    case AVCaptureDevicePositionFront:
                        [name appendString:@"front_"];
                        [name appendString:[NSString stringWithFormat:@"%lu", audioVideoFrontCount]];
                        ++audioVideoFrontCount;
                        break;
                    case AVCaptureDevicePositionUnspecified:
                    default:
                        [name appendString:[NSString stringWithFormat:@"%lu", audioVideoNormalCount]];
                        ++audioVideoNormalCount;
                        break;
                }
                recorder.name = [NSString stringWithString:name];
                
                [self.recorderArr addObject:recorder];
            }
        }
        
        unsigned long audioCount = 0;
        for (DPHostRecorderDataSource *audioDataSrc in self.audioDataSourceArr) {
            DPHostRecorderContext *recorder;
            NSMutableString *name;
            
            // 動画（音声のみ）
            recorder = [[DPHostRecorderContext alloc] initWithProfile:self];
            recorder.type = RecorderTypeMovie;
            recorder.mimeType = [DConnectFileManager searchMimeTypeForExtension:@"mp4"];
            recorder.state = RecorderStateInactive;
            
            [recorder setRecorderDataSource:audioDataSrc delegate:self];
            
            name = @"movie_audio_".mutableCopy;
            [name appendString:[NSString stringWithFormat:@"%lu", audioCount]];
            ++audioCount;
            recorder.name = [NSString stringWithString:name];
            
            [self.recorderArr addObject:recorder];
        }
        self.defaultAudioRecorderId = [NSNumber numberWithUnsignedInteger:self.recorderArr.count - 1];
        
        // API登録(didReceiveGetMediaRecorderRequest相当)
        NSString *getPlayStatusRequestApiPath = [self apiPath: nil
                                                attributeName: DConnectMediaStreamRecordingProfileAttrMediaRecorder];
        [self addGetPath: getPlayStatusRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         DConnectArray *recorders = [DConnectArray array];
                         for (size_t i = 0; i < _recorderArr.count; ++i) {
                             DPHostRecorderContext *recorderItr = [weakSelf recorderArr][i];
                             
                             
                             [recorderItr performReading:
                              ^{
                                  DConnectMessage *recorder = [DConnectMessage message];
                                  
                                  [DConnectMediaStreamRecordingProfile setRecorderId:[NSString stringWithFormat:@"%lu", i] target:recorder];
                                  [DConnectMediaStreamRecordingProfile setRecorderName:recorderItr.name target:recorder];
                                  
                                  NSString *state;
                                  switch (recorderItr.state) {
                                      case RecorderStateInactive:
                                          state = DConnectMediaStreamRecordingProfileRecorderStateInactive;
                                          break;
                                      case RecorderStatePaused:
                                          state = DConnectMediaStreamRecordingProfileRecorderStatePaused;
                                          break;
                                      case RecorderStateRecording:
                                          state = DConnectMediaStreamRecordingProfileRecorderStateRecording;
                                          break;
                                  }
                                  [DConnectMediaStreamRecordingProfile setRecorderState:state target:recorder];
                                  
                                  if (recorderItr.videoDevice) {
                                      if (recorderItr.videoDevice.imageWidth) {
                                          [DConnectMediaStreamRecordingProfile setRecorderImageWidth:
                                           [recorderItr.videoDevice.imageWidth intValue] target:recorder];
                                      }
                                      if (recorderItr.videoDevice.imageHeight) {
                                          [DConnectMediaStreamRecordingProfile setRecorderImageHeight:
                                           [recorderItr.videoDevice.imageHeight intValue] target:recorder];
                                      }
                                  }
                                  [DConnectMediaStreamRecordingProfile setRecorderMIMEType:recorderItr.mimeType target:recorder];
                                  [DConnectMediaStreamRecordingProfile setRecorderConfig:@"[]" target:recorder];
                                  
                                  [recorders addMessage:recorder];
                              }];
                         }
                         [DConnectMediaStreamRecordingProfile setRecorders:recorders target:response];
                         [response setResult:DConnectMessageResultTypeOk];
                         
                         return YES;
                     }];
         
        // API登録(didReceivePostTakePhotoRequest相当)
        NSString *postTakePhotoRequestApiPath = [self apiPath: nil
                                                attributeName: DConnectMediaStreamRecordingProfileAttrTakePhoto];
        [self addPostPath: postTakePhotoRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         
                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];

                         unsigned long long idx;
                         if (target || (target && target.length > 0)) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf defaultPhotoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [_defaultPhotoRecorderId unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         unsigned long long count = (unsigned)[weakSelf recorderArr].count;
                         
                         if (!_recorderArr || count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = _recorderArr[(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         
                         for (DPHostRecorderContext *recorderItr in [weakSelf recorderArr]) {
                             if (recorderItr == recorder) {
                                 continue;
                             }
                             if ((recorderItr.state == RecorderStateRecording)
                                 && recorder.videoDevice && recorderItr.videoDevice &&
                                 [recorder.videoDevice.uniqueId isEqualToString:recorderItr.videoDevice.uniqueId]) {
                                 // ビデオ入力デバイスが既に他のコンテキストで使われている。
                                 [response setErrorToUnknownWithMessage:
                                  [NSString stringWithFormat:@"Video device is currently used by %@.",
                                   recorderItr.name]];
                                 return YES;
                             }
                         }
                         
                         __block BOOL isSync = YES;
                         if (recorder.videoConnection.supportsVideoOrientation) {
                             recorder.videoConnection.videoOrientation = videoOrientationFromDeviceOrientation([UIDevice currentDevice].orientation);
                         }
                         [recorder performWriting:
                          ^{
                              if (recorder.type != RecorderTypePhoto) {
                                  [response setErrorToInvalidRequestParameterWithMessage:
                                   @"target is not a video device; it is not capable of taking a photo."];
                                  isSync = YES;
                                  return;
                              }
                              
                              if (![recorder.session isRunning]) {
                                  [recorder.session startRunning];
                              }
                              
                              // 写真を撮影する。
                              __block AVCaptureDevice *captureDevice = [AVCaptureDevice deviceWithUniqueID:recorder.videoDevice.uniqueId];
                              NSError *error;
                              [captureDevice lockForConfiguration:&error];
                              
                              if (error) {
                                  NSLog(@"Failed to acquire a configuration lock for %@.", captureDevice.uniqueID);
                              } else {
                                  
                                  if (captureDevice.focusMode != AVCaptureFocusModeContinuousAutoFocus &&
                                      [captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                                      captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
                                  } else if (captureDevice.focusMode != AVCaptureFocusModeAutoFocus &&
                                             [captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                                      captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
                                  } else if (captureDevice.focusMode != AVCaptureFocusModeLocked &&
                                             [captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
                                      captureDevice.focusMode = AVCaptureFocusModeLocked;
                                  }
                                  if (captureDevice.exposureMode != AVCaptureExposureModeContinuousAutoExposure &&
                                      [captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                                      captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
                                  } else if (captureDevice.exposureMode != AVCaptureExposureModeAutoExpose &&
                                             [captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
                                      captureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
                                  } else if (captureDevice.exposureMode != AVCaptureExposureModeLocked &&
                                             [captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
                                      captureDevice.exposureMode = AVCaptureExposureModeLocked;
                                  }
                                  if (captureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance &&
                                      [captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
                                      captureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
                                  } else if (captureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeAutoWhiteBalance &&
                                             [captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
                                      captureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
                                  } else if (captureDevice.whiteBalanceMode != AVCaptureWhiteBalanceModeLocked &&
                                             [captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
                                      captureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeLocked;
                                  }
                                  if (captureDevice.automaticallyEnablesLowLightBoostWhenAvailable != NO &&
                                      captureDevice.lowLightBoostSupported) {
                                      captureDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
                                  }
                                  [captureDevice unlockForConfiguration];
                                  
                                  [NSThread sleepForTimeInterval:0.5];
                              }
                              
                              AVCaptureStillImageOutput *stillImageOutput = (AVCaptureStillImageOutput *)recorder.videoConnection.output;
                              [stillImageOutput captureStillImageAsynchronouslyFromConnection:recorder.videoConnection
                                                                            completionHandler:
                               ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                   if (!imageDataSampleBuffer || error) {
                                       [response setErrorToUnknownWithMessage:@"Failed to take a photo."];
                                       [[DConnectManager sharedManager] sendResponse:response];
                                       return;
                                   }
                                   NSData *jpegData;
                                   @try {
                                       jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
 
                                   }
                                   @catch (NSException *exception) {
                                       NSString *message;
                                       if ([[exception name] isEqualToString:NSInvalidArgumentException]) {
                                           message = @"Non-JPEG data was given.";
                                       } else {
                                           message = [NSString stringWithFormat:@"%@ encountered.", [exception name]];
                                       }
                                       [response setErrorToUnknownWithMessage:message];
                                       [[DConnectManager sharedManager] sendResponse:response];
                                       return;
                                   }
                                   
                                   // EXIF情報を水平に統一する。ブラウザによってはEXIF情報により画像の向きが変わるため。
                                   CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpegData, NULL);
                                   NSDictionary *metadata = (__bridge NSDictionary*) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
                                   NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithDictionary:metadata];
                                   NSMutableDictionary *tiff = meta[(NSString*) kCGImagePropertyTIFFDictionary];
                                   tiff[(NSString*) kCGImagePropertyTIFFOrientation] = @(kCGImagePropertyOrientationUp);
                                   meta[(NSString*) kCGImagePropertyTIFFDictionary] = tiff;
                                   meta[(NSString*) kCGImagePropertyOrientation] = @(kCGImagePropertyOrientationUp);
                                   UIImage *jpeg = [[UIImage alloc] initWithData:jpegData];
                                   UIImage *fixJpeg = [weakSelf fixOrientationWithImage:jpeg position:recorder.videoDevice.position];
                                   [[weakSelf library] writeImageToSavedPhotosAlbum:fixJpeg.CGImage metadata:meta completionBlock:
                                    ^(NSURL *assetURL, NSError *error) {
                                        if (!assetURL || error) {
                                            [response setErrorToUnknownWithMessage:@"Failed to save a photo to camera roll."];
                                            [[DConnectManager sharedManager] sendResponse:response];
                                            return;
                                        }
                                        [DConnectMediaStreamRecordingProfile setUri:[assetURL absoluteString] target:response];
                                        [response setResult:DConnectMessageResultTypeOk];
                                        
                                        if ([recorder.session isRunning]) {
                                            [recorder.session stopRunning];
                                        }
                                        
                                        [[DConnectManager sharedManager] sendResponse:response];
                                        
                                        NSString *mimeType = [DConnectFileManager searchMimeTypeForExtension:assetURL.path.pathExtension];
                                        [weakSelf sendOnPhotoEventWithPath:[assetURL absoluteString] mimeType:mimeType];
                                        
                                        return;
                                    }];
                               }];
                              
                              // 非同期の「- captureStillImageAsynchronouslyFromConnection:completionHandler:」の処理内
                              // でHTTPレスポンスを返却させる。
                              isSync = NO;
                              return;
                          }];
                         
                         return isSync;
                     }];
        
        // API登録(didReceivePostRecordRequest相当)
        NSString *postRecordRequestApiPath = [self apiPath: nil
                                             attributeName: DConnectMediaStreamRecordingProfileAttrRecord];
        [self addPostPath: postRecordRequestApiPath
                      api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                          
                          NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];
                          NSNumber *timeslice = [DConnectMediaStreamRecordingProfile timesliceFromRequest:request];

                          NSString *timesliceString = [request stringForKey:DConnectMediaStreamRecordingProfileParamTimeSlice];
                          if (![DPHostUtils existDigitWithString:timesliceString]
                              || (timeslice && timeslice < 0) || (timesliceString && timesliceString.length <= 0)) {
                              [response setErrorToInvalidRequestParameterWithMessage:
                               @"timeslice is not supported; please omit this parameter."];
                              return YES;
                          }
                          
                          unsigned long long idx;
                          if (target) {
                              if ([target isEqualToString:@"video"]) {
                                  idx = [_defaultVideoRecorderId unsignedLongLongValue];
                              } else if ([target isEqualToString:@"audio"]) {
                                  idx = [_defaultAudioRecorderId unsignedLongLongValue];
                              } else {
                                  BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                  if (!success) {
                                      [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                      return YES;
                                  }
                                  
                              }
                          } else if ([weakSelf defaultVideoRecorderId]) {
                              // target省略時はデフォルトのレコーダーを指定する。
                              idx = [_defaultVideoRecorderId unsignedLongLongValue];
                          } else if ([weakSelf currentRecorderId]) {
                              idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                          } else {
                              [response setErrorToInvalidRequestParameterWithMessage:
                               @"target was not specified, and no default target was set; please specify an existing target."];
                              return YES;
                          }
                          if (!_recorderArr || _recorderArr.count < idx) {
                              [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                              return YES;
                          }
                          _currentRecorderId = [NSNumber numberWithUnsignedLongLong:idx];
                          DPHostRecorderContext *recorder;
                          @try {
                              recorder = _recorderArr[(NSUInteger)idx];
                          }
                          @catch (NSException *exception) {
                              NSString *message;
                              if ([[exception name] isEqualToString:NSRangeException]) {
                                  message = @"target is not found in the recorder ID list.";
                              } else {
                                  message = @"Exception encountered while trying to access the recorder ID list.";
                              }
                              [response setErrorToInvalidRequestParameterWithMessage:message];
                              return YES;
                          }
                          
                          if (recorder.state == RecorderStateRecording) {
                              [response setErrorToIllegalDeviceStateWithMessage:@"target is already recording."];
                              return YES;
                          }
                          
                          // 入力デバイスが既に他のレコーダーで使われていないかをチェックする
                          for (DPHostRecorderContext *recorderItr in [weakSelf recorderArr]) {
                              if (recorderItr == recorder) {
                                  continue;
                              }
                              if (recorderItr.state == RecorderStateRecording) {
                                  if (recorder.audioDevice && recorderItr.audioDevice &&
                                      [recorder.audioDevice.uniqueId isEqualToString:recorderItr.audioDevice.uniqueId]) {
                                      // 音声入力デバイスが既に他のコンテキストで使われている。
                                      [response setErrorToUnknownWithMessage:
                                       [NSString stringWithFormat:@"Audio device is currently used by %@.",
                                        recorderItr.name]];
                                      return YES;
                                  }
                                  if (recorder.videoDevice && recorderItr.videoDevice &&
                                      [recorder.videoDevice.uniqueId isEqualToString:recorderItr.videoDevice.uniqueId]) {
                                      // ビデオ入力デバイスが既に他のコンテキストで使われている。
                                      [response setErrorToUnknownWithMessage:
                                       [NSString stringWithFormat:@"Video device is currently used by %@.",
                                        recorderItr.name]];
                                      return YES;
                                  }
                              }
                          }
                          
                          __block BOOL isSync = YES;
                          [recorder performWriting:
                           ^{
                               if (recorder.type != RecorderTypeMovie) {
                                   [response setErrorToInvalidRequestParameterWithMessage:
                                    @"target is not an audiovisual device; it is not capable of taking a movie."];
                                   return;
                               }
                               
                               recorder.videoOrientation = [recorder.videoConnection videoOrientation];
                               
                               AVCaptureDevice *captureDevice = [AVCaptureDevice deviceWithUniqueID:recorder.videoDevice.uniqueId];
                               NSError *error;
                               [captureDevice lockForConfiguration:&error];
                               if (error) {
                                   NSLog(@"Failed to acquire a configuration lock for %@.", captureDevice.uniqueID);
                               } else {
                                   
                                   // 画面中央に露光やフォーカスが調整される様にする。
                                   CGPoint pointOfInterest = CGPointMake(.5, .5);
                                   if ([captureDevice isFocusPointOfInterestSupported] &&
                                       [captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                                       captureDevice.focusPointOfInterest = pointOfInterest;
                                       captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
                                   }
                                   if ([captureDevice isExposurePointOfInterestSupported] &&
                                       [captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                                       captureDevice.exposurePointOfInterest = pointOfInterest;
                                       captureDevice.exposureMode =
                                       AVCaptureExposureModeContinuousAutoExposure;
                                   }
                                   [captureDevice unlockForConfiguration];
                                   
                                   // 露光の為に少し待つ
                                   [NSThread sleepForTimeInterval:0.5];
                               }
                               
                               [recorder setupAssetWriterWithResponse:response];
                               recorder.state = RecorderStateRecording;
                               
                               // ポーズ関連の変数を初期化
                               _lastPreviewTimestamp = kCMTimeInvalid;
                               _totalPauseDuration = kCMTimeInvalid;
                               _needRecalculationOfTotalPauseDuration = NO;
                               
                               if (![recorder.session isRunning]) {
                                   [recorder.session startRunning];
                               }
                               isSync = NO;
                           }];
                          
                          return isSync;
                      }];
        
        // API登録(didReceivePutPauseRequest相当)
        NSString *putPauseRequestApiPath = [self apiPath: nil
                                           attributeName: DConnectMediaStreamRecordingProfileAttrPause];
        [self addPutPath: putPauseRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         
                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];

                         unsigned long long idx;
                         if (target) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 idx = [_currentRecorderId unsignedLongLongValue];
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf currentRecorderId]) {
                             idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                         } else if ([weakSelf defaultVideoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [[weakSelf defaultVideoRecorderId] unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         if (![weakSelf recorderArr] || [weakSelf recorderArr].count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                             return YES;
                         }
                         
                         [weakSelf setCurrentRecorderId: [NSNumber numberWithUnsignedLongLong:idx]];
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = [weakSelf recorderArr][(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         
                         if (recorder.state == RecorderStatePaused) {
                             [response setErrorToIllegalDeviceStateWithMessage:@"target is already pausing."];
                             return YES;
                         }
                         
                         if (recorder.state == RecorderStateRecording) {
                             if ([recorder.session isRunning]) {
                                 [recorder.session stopRunning];
                                 if ([recorder.session isRunning]) {
                                     [response setErrorToUnknownWithMessage:
                                      @"Failed to pause the specified recorder; failed to stop capture session."];
                                     return YES;
                                 }
                             }
                             
                             recorder.state = RecorderStatePaused;
                             
                             [weakSelf sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStatePause
                                                                   path:nil mimeType:nil errorMessage:nil];
                             
                             [weakSelf setNeedRecalculationOfTotalPauseDuration: YES];
                             
                             [response setResult:DConnectMessageResultTypeOk];
                         } else {
                             [response setErrorToIllegalDeviceStateWithMessage:
                              @"The specified recorder is not recording; no need for pause."];
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutResumeRequest相当)
        NSString *putResumeRequestApiPath = [self apiPath: nil
                                            attributeName: DConnectMediaStreamRecordingProfileAttrResume];
        [self addPutPath: putResumeRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];
                         
                         unsigned long long idx;
                         if (target) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 idx = [_currentRecorderId unsignedLongLongValue];
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf currentRecorderId]) {
                             idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                             
                         } else if ([weakSelf defaultVideoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [[weakSelf defaultVideoRecorderId] unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         if (![weakSelf recorderArr] || [weakSelf recorderArr].count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                             return YES;
                         }
                         [weakSelf setCurrentRecorderId: [NSNumber numberWithUnsignedLongLong:idx]];
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = [weakSelf recorderArr][(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         if (recorder.state == RecorderStateRecording) {
                             [response setErrorToIllegalDeviceStateWithMessage:@"target is not pausing."];
                             return YES;
                         }
                         if (recorder.state == RecorderStatePaused) {
                             if (![recorder.session isRunning]) {
                                 [recorder.session startRunning];
                                 if (![recorder.session isRunning]) {
                                     [response setErrorToUnknownWithMessage:
                                      @"Failed to resume the specified recorder; failed to start capture session."];
                                     return YES;
                                 }
                             }
                             recorder.state = RecorderStateRecording;
                             
                             [weakSelf sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStateResume
                                                                   path:nil mimeType:nil errorMessage:nil];
                             [response setResult:DConnectMessageResultTypeOk];
                         } else {
                             [response setErrorToIllegalDeviceStateWithMessage:
                              @"The specified recorder is not recording; no need for pause."];
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutStopRequest相当)
        NSString *putStopRequestApiPath = [self apiPath: nil
                                          attributeName: DConnectMediaStreamRecordingProfileAttrStop];
        [self addPutPath: putStopRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];
                         
                         unsigned long long idx;
                         if (target) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 idx = [_currentRecorderId unsignedLongLongValue];
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf currentRecorderId]) {
                             idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                         } else if ([weakSelf defaultVideoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [_defaultVideoRecorderId unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         if (!_recorderArr || _recorderArr.count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                             return YES;
                         }
                         
                         _currentRecorderId = [NSNumber numberWithUnsignedLongLong:idx];
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = _recorderArr[(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         if (recorder.state == RecorderStateInactive) {
                             [response setErrorToIllegalDeviceStateWithMessage:@"target is not recording."];
                             return YES;
                         }
                         
                         [recorder performWriting:
                          ^{
                              // レコーディングサンプルの配信を停止する。
                              [recorder.session stopRunning];
                              
                              if (recorder.audioWriterInput) {
                                  if (recorder.writer.status != AVAssetWriterStatusUnknown) {
                                      [recorder.audioWriterInput markAsFinished];
                                  }
                              }
                              if (recorder.videoWriterInput) {
                                  if (recorder.writer.status != AVAssetWriterStatusUnknown) {
                                      [recorder.videoWriterInput markAsFinished];
                                  }
                              }
                              
                              recorder.state = RecorderStateInactive;
                              recorder.audioReady = recorder.videoReady = NO;
                          }];
                         
                         if (!recorder.writer) {
                             [response setErrorToIllegalDeviceStateWithMessage:@"Writer is non exist."];
                             return YES;
                         }
                         if (recorder.writer.status == AVAssetWriterStatusUnknown) {
                             [response setErrorToIllegalDeviceStateWithMessage:@"Unknown Failed to finishing an aseet writer"];
                             return YES;
                         }
                         
                         [recorder.writer finishWritingWithCompletionHandler:
                          ^{
                              
                              if (recorder.writer.status == AVAssetWriterStatusFailed) {
                                  [response setErrorToUnknownWithMessage:@"Failed to finishing an aseet writer"];
                                  [[DConnectManager sharedManager] sendResponse:response];
                                  return;
                              }
                              NSURL *fileUrl = recorder.writer.outputURL;
                              
                              // 動画をカメラロールに追加。
                              [[weakSelf library] writeVideoAtPathToSavedPhotosAlbum:fileUrl
                                                           completionBlock:
                               ^(NSURL *assetURL, NSError *error) {
                                   if (error) {
                                       [response setErrorToUnknownWithMessage:@"Failed to save a movie to camera roll (1)."];
                                       [[DConnectManager sharedManager] sendResponse:response];
                                       return;
                                   } else if (!assetURL) {
                                       [response setErrorToUnknownWithMessage:@"Failed to save a movie to camera roll (2)."];
                                       [[DConnectManager sharedManager] sendResponse:response];
                                       return;
                                   }
                                   NSFileManager *fileMgr = [NSFileManager defaultManager];
                                   if ([fileMgr fileExistsAtPath:[fileUrl path]]
                                       && ![fileMgr removeItemAtURL:fileUrl error:nil]) {
                                       NSLog(@"Failed to remove a movie file.");
                                   }
                                   
                                   [DConnectMediaStreamRecordingProfile setUri:[assetURL absoluteString] target:response];
                                   [response setResult:DConnectMessageResultTypeOk];
                                   
                                   [weakSelf sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStateStop
                                                                         path:[assetURL absoluteString] mimeType:recorder.mimeType
                                                                 errorMessage:nil];
                                   [[DConnectManager sharedManager] sendResponse:response];
                                   _currentRecorderId = nil;
                                   recorder.writer = nil;
                                   recorder.audioWriterInput = recorder.videoWriterInput = nil;
                                   
                               }];
                          }];
                         
                         // 「- finishWritingWithCompletionHandler:」の中でHTTPレスポンスを返却させる
                         return NO;
                     }];
        
        // API登録(didReceivePutMuteTrackRequest相当)
        NSString *putMuteTrackRequestApiPath = [self apiPath: nil
                                               attributeName: DConnectMediaStreamRecordingProfileAttrMuteTrack];
        [self addPutPath: putMuteTrackRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];
                         
                         unsigned long long idx;
                         if (target) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 idx = [_currentRecorderId unsignedLongLongValue];
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf currentRecorderId]) {
                             idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                             
                         } else if ([weakSelf defaultVideoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [_defaultVideoRecorderId unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         if (!_recorderArr || _recorderArr.count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                             return YES;
                         }
                         
                         _currentRecorderId = [NSNumber numberWithUnsignedLongLong:idx];
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = _recorderArr[(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         
                         if (!recorder.audioDevice) {
                             [response setErrorToUnknownWithMessage:
                              @"The specified target does not capture audio and can not be muted."];
                             return YES;
                         }
                         
                         if (!recorder.isMuted) {
                             recorder.isMuted = YES;
                             
                             [weakSelf sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStateMutetrack
                                                                   path:nil mimeType:nil errorMessage:nil];
                             
                             [response setResult:DConnectMessageResultTypeOk];
                         } else {
                             [response setErrorToIllegalDeviceStateWithMessage:@"The specified recorder is already muted."];
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutUnmuteTrackRequest相当)
        NSString *putUnmuteTrackRequestApiPath = [self apiPath: nil
                                                 attributeName: DConnectMediaStreamRecordingProfileAttrUnmuteTrack];
        [self addPutPath: putUnmuteTrackRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                         NSString *target = [DConnectMediaStreamRecordingProfile targetFromRequest:request];
                         
                         unsigned long long idx;
                         if (target) {
                             if ([target isEqualToString:@"video"]) {
                                 idx = [_defaultVideoRecorderId unsignedLongLongValue];
                             } else if ([target isEqualToString:@"audio"]) {
                                 idx = [_defaultAudioRecorderId unsignedLongLongValue];
                             } else {
                                 idx = [_currentRecorderId unsignedLongLongValue];
                                 BOOL success = [[NSScanner scannerWithString:target] scanUnsignedLongLong:&idx];
                                 if (!success) {
                                     [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                                     return YES;
                                 }
                             }
                         } else if ([weakSelf currentRecorderId]) {
                             idx = [[weakSelf currentRecorderId] unsignedLongLongValue];
                             
                         } else if ([weakSelf defaultVideoRecorderId]) {
                             // target省略時はデフォルトのレコーダーを指定する。
                             idx = [[weakSelf defaultVideoRecorderId] unsignedLongLongValue];
                         } else {
                             [response setErrorToInvalidRequestParameterWithMessage:
                              @"target was not specified, and no default target was set; please specify an existing target."];
                             return YES;
                         }
                         if (!_recorderArr || _recorderArr.count < idx) {
                             [response setErrorToInvalidRequestParameterWithMessage:@"target is invalid."];
                             return YES;
                         }
                         _currentRecorderId = [NSNumber numberWithUnsignedLongLong:idx];
                         DPHostRecorderContext *recorder;
                         @try {
                             recorder = _recorderArr[(NSUInteger)idx];
                         }
                         @catch (NSException *exception) {
                             NSString *message;
                             if ([[exception name] isEqualToString:NSRangeException]) {
                                 message = @"target is not found in the recorder ID list.";
                             } else {
                                 message = @"Exception encountered while trying to access the recorder ID list.";
                             }
                             [response setErrorToInvalidRequestParameterWithMessage:message];
                             return YES;
                         }
                         
                         if (!recorder.audioDevice) {
                             [response setErrorToUnknownWithMessage:
                              @"The specified target does not capture audio and can not be unmuted."];
                             return YES;
                         }
                         
                         if (recorder.isMuted) {
                             recorder.isMuted = NO;
                             
                             [weakSelf sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStateUnmutetrack
                                                                   path:nil mimeType:nil errorMessage:nil];
                             
                             [response setResult:DConnectMessageResultTypeOk];
                         } else {
                             [response setErrorToIllegalDeviceStateWithMessage:@"The specified recorder is not muted."];
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutOnPhotoRequest相当)
        NSString *putOnPhotoRequestApiPath = [self apiPath: nil
                                             attributeName: DConnectMediaStreamRecordingProfileAttrOnPhoto];
        [self addPutPath: putOnPhotoRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         switch ([[weakSelf eventMgr] addEventForRequest:request]) {
                             case DConnectEventErrorNone:             // エラー無し.
                                 [response setResult:DConnectMessageResultTypeOk];
                                 break;
                             case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                 [response setErrorToInvalidRequestParameter];
                                 break;
                             case DConnectEventErrorNotFound:         // マッチするイベント無し.
                             case DConnectEventErrorFailed:           // 処理失敗.
                                 [response setErrorToUnknown];
                                 break;
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutOnRecordingChangeRequest相当)
        NSString *putOnRecordingChangeRequestApiPath = [self apiPath: nil
                                                       attributeName: DConnectMediaStreamRecordingProfileAttrOnRecordingChange];
        [self addPutPath: putOnRecordingChangeRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                         switch ([[weakSelf eventMgr] addEventForRequest:request]) {
                             case DConnectEventErrorNone:             // エラー無し.
                                 [response setResult:DConnectMessageResultTypeOk];
                                 break;
                             case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                 [response setErrorToInvalidRequestParameter];
                                 break;
                             case DConnectEventErrorNotFound:         // マッチするイベント無し.
                             case DConnectEventErrorFailed:           // 処理失敗.
                                 [response setErrorToUnknown];
                                 break;
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceivePutOnDataAvailableRequest相当)
        NSString *putOnDataAvailableRequestApiPath = [self apiPath: nil
                                                     attributeName: DConnectMediaStreamRecordingProfileAttrOnDataAvailable];
        [self addPutPath: putOnDataAvailableRequestApiPath
                     api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                         NSString *serviceId = [request serviceId];

                         NSArray *evts = [[weakSelf eventMgr] eventListForServiceId:serviceId
                                                                  profile:DConnectMediaStreamRecordingProfileName
                                                                attribute:DConnectMediaStreamRecordingProfileAttrOnDataAvailable];
                         if (evts.count == 0) {
                             [weakSelf profile:weakSelf didReceivePostRecordRequest:nil response:[response copy]
                                 serviceId:serviceId target:nil timeslice:nil];
                             
                             // プレビュー画像URIの配送処理が開始されていないのなら、開始する。
                             _sendPreview = YES;
                         }
                         
                         switch ([[weakSelf eventMgr] addEventForRequest:request]) {
                             case DConnectEventErrorNone:             // エラー無し.
                                 [response setResult:DConnectMessageResultTypeOk];
                                 break;
                             case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                 [response setErrorToInvalidRequestParameter];
                                 break;
                             case DConnectEventErrorNotFound:         // マッチするイベント無し.
                             case DConnectEventErrorFailed:           // 処理失敗.
                                 [response setErrorToUnknown];
                                 break;
                         }
                         
                         return YES;
                     }];
        
        // API登録(didReceiveDeleteOnPhotoRequest相当)
        NSString *deleteOnPhotoRequestApiPath = [self apiPath: nil
                                                attributeName: DConnectMediaStreamRecordingProfileAttrOnPhoto];
        [self addDeletePath: deleteOnPhotoRequestApiPath
                        api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                            switch ([[weakSelf eventMgr] removeEventForRequest:request]) {
                                case DConnectEventErrorNone:             // エラー無し.
                                    [response setResult:DConnectMessageResultTypeOk];
                                    break;
                                case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                    [response setErrorToInvalidRequestParameter];
                                    break;
                                case DConnectEventErrorNotFound:         // マッチするイベント無し.
                                case DConnectEventErrorFailed:           // 処理失敗.
                                    [response setErrorToUnknown];
                                    break;
                            }
                            
                            return YES;
                        }];

        // API登録(didReceiveDeleteOnRecordingChangeRequest相当)
        NSString *deleteOnRecordingChangeRequestApiPath = [self apiPath: nil
                                                          attributeName: DConnectMediaStreamRecordingProfileAttrOnRecordingChange];
        [self addDeletePath: deleteOnRecordingChangeRequestApiPath
                        api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {
                            switch ([[weakSelf eventMgr] removeEventForRequest:request]) {
                                case DConnectEventErrorNone:             // エラー無し.
                                    [response setResult:DConnectMessageResultTypeOk];
                                    break;
                                case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                    [response setErrorToInvalidRequestParameter];
                                    break;
                                case DConnectEventErrorNotFound:         // マッチするイベント無し.
                                case DConnectEventErrorFailed:           // 処理失敗.
                                    [response setErrorToUnknown];
                                    break;
                            }
                            
                            return YES;
                        }];
        
        // API登録(didReceiveDeleteOnDataAvailableRequest相当)
        NSString *deleteOnDataAvailableRequestApiPath = [self apiPath: nil
                                                        attributeName: DConnectMediaStreamRecordingProfileAttrOnDataAvailable];
        [self addDeletePath: deleteOnDataAvailableRequestApiPath
                        api:^BOOL(DConnectRequestMessage *request, DConnectResponseMessage *response) {

                            NSString *serviceId = [request serviceId];
                            
                            switch ([[weakSelf eventMgr] removeEventForRequest:request]) {
                                case DConnectEventErrorNone:             // エラー無し.
                                    [response setResult:DConnectMessageResultTypeOk];
                                    break;
                                case DConnectEventErrorInvalidParameter: // 不正なパラメータ.
                                    [response setErrorToInvalidRequestParameter];
                                    break;
                                case DConnectEventErrorNotFound:         // マッチするイベント無し.
                                case DConnectEventErrorFailed:           // 処理失敗.
                                    [response setErrorToUnknown];
                                    break;
                            }
                            
                            NSArray *evts = [[weakSelf eventMgr] eventListForServiceId:serviceId
                                                                     profile:DConnectMediaStreamRecordingProfileName
                                                                   attribute:DConnectMediaStreamRecordingProfileAttrOnDataAvailable];
                            if (evts.count == 0) {
                                [weakSelf profile:weakSelf didReceivePutStopRequest:nil response:[response copy]
                                    serviceId:serviceId target:nil];
                                
                                // イベント受領先が存在しないなら、プレビュー画像URIの配送処理を停止する。
                                _sendPreview = NO;
                                // 次回プレビュー開始時に影響を与えない為に、初期値（無効値）を設定する。
                                _lastPreviewTimestamp = kCMTimeInvalid;
                            }
                            
                            return YES;
                        }];
        
    }
    return self;
}

- (void)dealloc
{
    // iOSデバイスの向き変更の監視をやめる
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (BOOL) setupAssetWriterAudioInputForRecorderContext:(DPHostRecorderContext *)recorderCtx
                                          description:(CMFormatDescriptionRef)currentFormatDescription
{
    if (!recorderCtx.writer) {
        NSLog(@"assetWriter must be specified.");
        return NO;
    }

    const AudioStreamBasicDescription *currentASBD
            = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout
            = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
    NSData *currentChannelLayoutData = nil;
    
    if ( currentChannelLayout && aclSize > 0 )
        currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
    else
        currentChannelLayoutData = [NSData data];
    
    NSDictionary *audioCompressionSettings =
    @{
      AVFormatIDKey : @(kAudioFormatMPEG4AAC),
      AVSampleRateKey : @(currentASBD->mSampleRate),
      AVEncoderBitRatePerChannelKey : @64000,
      AVNumberOfChannelsKey : @(currentASBD->mChannelsPerFrame),
      AVChannelLayoutKey : currentChannelLayoutData
      };
    if ([recorderCtx.writer canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
        AVAssetWriterInput *assetWriterAudioIn = recorderCtx.audioWriterInput
        = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        assetWriterAudioIn.expectsMediaDataInRealTime = YES;
        
        if ([recorderCtx.writer canAddInput:assetWriterAudioIn]) {
            [recorderCtx.writer addInput:assetWriterAudioIn];
            recorderCtx.audioReady = YES;
        }
        else {
            NSLog(@"Could not add asset writer audio input.");
            return NO;
        }
    }
    else {
        NSLog(@"Could not apply audio output settings.");
        return NO;
    }
    
    return YES;
}

- (BOOL) setupAssetWriterVideoInputForRecorderContext:(DPHostRecorderContext *)recorderCtx
                                          description:(CMFormatDescriptionRef)currentFormatDescription
{
    if (!recorderCtx.writer) {
        NSLog(@"assetWriter must be specified.");
        return NO;
    }
    float bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    int numPixels = dimensions.width * dimensions.height;
    int bitsPerSecond;
    
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
    if ( numPixels < (640 * 480) )
        bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    else
        bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    
    bitsPerSecond = numPixels * bitsPerPixel;
    
    NSDictionary *videoCompressionSettings =
    @{
      AVVideoCodecKey : AVVideoCodecH264,
      AVVideoWidthKey : @(dimensions.width),
      AVVideoHeightKey : @(dimensions.height),
      AVVideoCompressionPropertiesKey : @{
              AVVideoAverageBitRateKey : @(bitsPerSecond),
              AVVideoMaxKeyFrameIntervalKey : @30,
              },
      };
    if ([recorderCtx.writer canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
        AVAssetWriterInput *assetWriterVideoIn = recorderCtx.videoWriterInput
        = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        assetWriterVideoIn.expectsMediaDataInRealTime = YES;
        
        assetWriterVideoIn.transform =
        [self transformVideoOrientation:recorderCtx.videoOrientation position:recorderCtx.videoDevice.position];
        if ([recorderCtx.writer canAddInput:assetWriterVideoIn]) {
            [recorderCtx.writer addInput:assetWriterVideoIn];
            recorderCtx.videoReady = YES;
        }
        else {
            NSLog(@"Couldn't add asset writer video input.");
            return NO;
        }
    }
    else {
        NSLog(@"Couldn't apply video output settings.");
        return NO;
    }
    
    return YES;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(UIDeviceOrientation)orientation
                                                  position:(AVCaptureDevicePosition)position
{
    CGFloat angle = 0.0;
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            angle = 0.0;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIDeviceOrientationLandscapeLeft:
            angle = position == AVCaptureDevicePositionBack ? -M_PI_2 : M_PI_2;
            break;
        case UIDeviceOrientationLandscapeRight:
            angle = position == AVCaptureDevicePositionBack ? M_PI_2 : -M_PI_2;
            break;
        default:
            break;
    }
    
    return angle;
}

- (CGAffineTransform)transformVideoOrientation:(AVCaptureVideoOrientation)orientation
                                      position:(AVCaptureDevicePosition)position
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    // iOSデバイスの向きが、ポートレート状態から角度的に何度の差があるか算出。
    CGFloat orientationAngleOffset =
    [self angleOffsetFromPortraitOrientationToOrientation:_referenceOrientation
                                                 position:position];
    CGFloat videoOrientationAngleOffset =
    [self angleOffsetFromPortraitOrientationToOrientation:(UIDeviceOrientation)orientation
                                                 position:position];
    
    // Find the difference in angle between the passed in orientation and the current video orientation
    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    transform = CGAffineTransformMakeRotation(angleOffset);
    
    return transform;
}

- (void) sendOnPhotoEventWithPath:(NSString *)path mimeType:(NSString*)mimeType
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ;
    });
    
    // イベントの取得
    NSArray *evts = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                            profile:DConnectMediaStreamRecordingProfileName
                                          attribute:DConnectMediaStreamRecordingProfileAttrOnPhoto];
    // イベント送信
    for (DConnectEvent *evt in evts) {
        DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
        DConnectMessage *photo = [DConnectMessage message];
        
        DConnectManager *mgr = [DConnectManager sharedManager];
        NSString *uri = [NSString stringWithFormat:@"http://%@:%d/files?uri=%@",
                         mgr.settings.host, mgr.settings.port,
                         [DPHostUtils percentEncodeString:path withEncoding:NSUTF8StringEncoding]];
        [DConnectMediaStreamRecordingProfile setPath:uri target:photo];
        
        [DConnectMediaStreamRecordingProfile setMIMEType:mimeType target:photo];
        [DConnectMediaStreamRecordingProfile setPhoto:photo target:eventMsg];
        
        [SELF_PLUGIN sendEvent:eventMsg];
    }
}

- (void) sendOnRecordingChangeEventWithStatus:(NSString *)status
                                         path:(NSString *)path
                                     mimeType:(NSString *)mimeType
                                 errorMessage:(NSString *)errorMsg
{
    // イベントの取得
    NSArray *evts = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                            profile:DConnectMediaStreamRecordingProfileName
                                           attribute:DConnectMediaStreamRecordingProfileAttrOnRecordingChange];

    // イベント送信
    for (DConnectEvent *evt in evts) {
        DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
        DConnectMessage *media = [DConnectMessage message];
        [DConnectMediaStreamRecordingProfile setStatus:status target:media];
        if (path) {
            [DConnectMediaStreamRecordingProfile setPath:path target:media];
        }
        if (mimeType) {
            [DConnectMediaStreamRecordingProfile setMIMEType:mimeType target:media];
        }
        if (errorMsg) {
            [DConnectMediaStreamRecordingProfile setErrorMessage:errorMsg target:media];
        }
        [DConnectMediaStreamRecordingProfile setMedia:media target:eventMsg];
        
        [SELF_PLUGIN sendEvent:eventMsg];
    }
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little
                                                 | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

- (void) sendOnDataAvailableEventWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    NSURL *fileURL;
    NSArray *evts;
    @autoreleasepool {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!imageBuffer) {
            return;
        }
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        if (!ciImage) {
            return;
        }
        
        // イベントの取得
        evts = [_eventMgr eventListForServiceId:DPHostDevicePluginServiceId
                                       profile:DConnectMediaStreamRecordingProfileName
                                     attribute:DConnectMediaStreamRecordingProfileAttrOnDataAvailable];
        
        // プレビュー画像の書き出し。
        if (evts.count > 0) {
            UIImage *image = [UIImage imageWithCIImage:ciImage];
            CGSize size = image.size;
            double scale = 160000.0 / (size.width * size.height);
            size = CGSizeMake((int)(size.width * scale), (int)(size.height * scale));
            UIGraphicsBeginImageContext(size);
            [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSData *jpegData = UIImageJPEGRepresentation(image, 1.0);
            
            NSString *fileName = [NSString stringWithFormat:@"preview_%02d", _curPreviewImageEnumerator];
            fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
            if (!fileURL || ![jpegData writeToURL:fileURL atomically:NO]) {
                return;
            }
        } else {
            return;
        }
    }
    _curPreviewImageEnumerator = (_curPreviewImageEnumerator + 1) % 100;
    
    DConnectURIBuilder *builder = [DConnectURIBuilder new];
    builder.profile = @"files";
    [builder addParameter:[NSString stringWithFormat:@"%@",
                           [DPHostUtils percentEncodeString:[fileURL path]
                                               withEncoding:NSUTF8StringEncoding]]
                  forName:@"uri"];
    NSString *uri = builder.build.absoluteString;
    // イベント送信
    for (DConnectEvent *evt in evts) {
        DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
        DConnectMessage *media = [DConnectMessage message];
        
        [DConnectMediaStreamRecordingProfile setUri:uri target:media];
        [DConnectMediaStreamRecordingProfile setMIMEType:@"image/jpeg" target:media];
        [DConnectMediaStreamRecordingProfile setMedia:media target:eventMsg];
        
        [SELF_PLUGIN sendEvent:eventMsg];
    }
}

AVCaptureVideoOrientation videoOrientationFromDeviceOrientation(UIDeviceOrientation deviceOrientation)
{
    AVCaptureVideoOrientation orientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationFaceUp:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationFaceDown:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    return orientation;
}
- (UIImage *)fixOrientationWithImage:(UIImage *)image position:(AVCaptureDevicePosition) position{
    
    if (image.imageOrientation == UIImageOrientationUp && position != AVCaptureDevicePositionFront) return image;

    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (image.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, image.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (position) {
        case AVCaptureDevicePositionFront:
            switch (image.imageOrientation) {
                    
                case UIImageOrientationLeft:
                case UIImageOrientationLeftMirrored:
                case UIImageOrientationRight:
                case UIImageOrientationRightMirrored:
                    transform = CGAffineTransformTranslate(transform, 0, image.size.width);
                    transform = CGAffineTransformScale(transform, 1, -1);
                    break;
                case UIImageOrientationDown:
                case UIImageOrientationDownMirrored:
                case UIImageOrientationUp:
                case UIImageOrientationUpMirrored:
                default:
                    transform = CGAffineTransformTranslate(transform, image.size.width, 0);
                    transform = CGAffineTransformScale(transform, -1, 1);
                    break;
            }

            break;
        case AVCaptureDevicePositionUnspecified:
        case AVCaptureDevicePositionBack:
        default:
            break;
    }

    CGContextRef ctx = CGBitmapContextCreate(NULL, image.size.width, image.size.height,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:

            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.height,image.size.width), image.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.width,image.size.height), image.CGImage);
            break;
    }
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}
#pragma mark - AVCapture{Audio,Video}DataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CMSampleBufferRef buffer = sampleBuffer;
    // オーディオ・ビデオのどちらからデータが来たかのフラグ
    BOOL isAudio;
    if ([captureOutput isKindOfClass:[AVCaptureAudioDataOutput class]]) {
        isAudio = YES;
    } else if ([captureOutput isKindOfClass:[AVCaptureVideoDataOutput class]]) {
        isAudio = NO;
    } else {
        NSLog(@"Capture output \"%s\" is not supported.", object_getClassName([captureOutput class]));
        return;
    }
    
    CMTime originalSampleBufferTimestamp = CMSampleBufferGetPresentationTimeStamp(buffer);
    if (!CMTIME_IS_NUMERIC(originalSampleBufferTimestamp)) {
        NSLog(@"Invalid %@ timestamp; could not append the sample.", isAudio ? @"audio" : @"video");
        return;
    }
    
    BOOL updateLastSampleTimestamp = YES;
    BOOL adjustTimestamp = YES;
    BOOL initMuteSample = YES;
    BOOL requireRelease = NO;
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(buffer);
    for (DPHostRecorderContext *recorder in _recorderArr) {
        if (recorder.state != RecorderStateRecording) {
            continue;
        }
        
        if (isAudio) {
            // オーディオ
            if (recorder.audioConnection != connection) {
                continue;
            }
            if (!recorder.audioReady &&
                ![self setupAssetWriterAudioInputForRecorderContext:recorder
                                                        description:formatDescription])
            {
                // キャプチャーセッションを停止する。
                [recorder.session stopRunning];
                [recorder.response setErrorToUnknownWithMessage:
                 [NSString stringWithFormat:
                    @"Failed to add an audio input to an asset writer for recorder \"%@\".",
                        recorder.name]];
                [recorder sendResponse];
                recorder.state = RecorderStateInactive;
                recorder.audioReady = recorder.videoReady = NO;
                recorder.writer = nil;
                recorder.audioWriterInput = recorder.videoWriterInput = nil;
                
                continue;
            }
        } else {
            // ビデオ
            if (recorder.videoConnection != connection) {
                continue;
            }
            if (!recorder.videoReady &&
                ![self setupAssetWriterVideoInputForRecorderContext:recorder
                                                        description:formatDescription])
            {
                
                // キャプチャーセッションを停止する。
                [recorder.session stopRunning];

                [recorder.response setErrorToUnknownWithMessage:
                 [NSString stringWithFormat:
                    @"Failed to add an video input to an asset writer for recorder \"%@\".",
                        recorder.name]];
                [recorder sendResponse];
                
                // TODO: レコーダーの初期化コードを関数化
                recorder.state = RecorderStateInactive;
                recorder.audioReady = recorder.videoReady = NO;
                recorder.writer = nil;
                recorder.audioWriterInput = recorder.videoWriterInput = nil;
                
                continue;
            }
        }
        
        if ((!recorder.audioDevice || recorder.audioReady) &&
            (!recorder.videoDevice || recorder.videoReady)) {
            if (_needRecalculationOfTotalPauseDuration) {
                if (!isAudio) {
                    return;
                }
                
                if (CMTIME_IS_NUMERIC(_lastSampleTimestamp)) {
                    CMTime sampleBufferTimestamp = originalSampleBufferTimestamp;
                    if (CMTIME_IS_NUMERIC(_totalPauseDuration)) {
                        sampleBufferTimestamp = CMTimeSubtract(sampleBufferTimestamp, _totalPauseDuration);
                    }
                    CMTime pauseDuration = CMTimeSubtract(sampleBufferTimestamp, _lastSampleTimestamp);
                    
                    if (CMTIME_IS_NUMERIC(_totalPauseDuration) && _totalPauseDuration.value != 0) {
                        _totalPauseDuration = CMTimeAdd(_totalPauseDuration, pauseDuration);
                    } else {
                        _totalPauseDuration = pauseDuration;
                    }
                }
                _lastSampleTimestamp.flags = 0;
                _needRecalculationOfTotalPauseDuration = NO;
            }
            
            if (adjustTimestamp) {
                CFRetain(buffer);
                
                // ポーズの累計期間に応じたサンプルのタイミング修正を行う。
                if (CMTIME_IS_NUMERIC(_totalPauseDuration) && _totalPauseDuration.value != 0) {
                    // タイムスタンプのタイムスタンプをポーズの累計期間に応じて調整する
                    CMSampleBufferRef tmp = [self sampleBufferByAdjustingTimestamp:sampleBuffer by:_totalPauseDuration];
                    CFRelease(sampleBuffer);
                    buffer = tmp;
                }
                adjustTimestamp = NO;
                requireRelease = YES;
            }
            
            if (isAudio && recorder.isMuted && initMuteSample) {
                CMBlockBufferRef buf = CMSampleBufferGetDataBuffer(buffer);
                size_t length;
                size_t totalLength;
                char* data;
                if (CMBlockBufferGetDataPointer(buf, 0, &length, &totalLength, &data) != noErr) {
                    NSLog(@"Failed to set audio amplitude to 0 for muting.");
                } else {
                    for (size_t i = 0; i < length; ++i) {
                        data[i] = 0;
                    }
                }
                initMuteSample = NO;
            }
            
            if (!isAudio && _sendPreview &&
                // デフォルトカメラの時だけ
                recorder == _recorderArr[[_defaultVideoRecorderId intValue]]) {
                if (CMTIME_IS_INVALID(_lastPreviewTimestamp)) {
                    // まだプレビューの配送を行っていないのであれば、プレビューを配信する。
                    [self sendOnDataAvailableEventWithSampleBuffer:sampleBuffer];
                } else if (CMTIME_IS_NUMERIC(_lastPreviewTimestamp)) {
                    CMTime elapsedTime =
                    CMTimeSubtract(_lastPreviewTimestamp, originalSampleBufferTimestamp);
                    if (CMTIME_COMPARE_INLINE(elapsedTime, >=, _secPerFrame)) {
                        // 規定時間が経過したのであれば、プレビューを配信する。
                        [self sendOnDataAvailableEventWithSampleBuffer:sampleBuffer];
                    }
                } else {
                    _lastPreviewTimestamp = originalSampleBufferTimestamp;
                }
            }
            
            if (isAudio && updateLastSampleTimestamp) {
                // サンプルのタイムスタンプを保持しておく
                CMTime sampleBufferTimestamp = CMSampleBufferGetPresentationTimeStamp(buffer);
                CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
                if (duration.value > 0) {
                    _lastSampleTimestamp = CMTimeAdd(sampleBufferTimestamp, duration);
                } else {
                    // 「サンプルの開始時間（タイムスタンプ）」と「サンプルの終了時間」が同義。
                    _lastSampleTimestamp = sampleBufferTimestamp;
                }
                updateLastSampleTimestamp = NO;
            }
            
            [self appendSampleBuffer:sampleBuffer recorderContext:recorder isAudio:isAudio];
        }
    }
    if (requireRelease) {
        CFRelease(buffer);
    }
}

- (BOOL) appendSampleBuffer:(CMSampleBufferRef)sampleBuffer
            recorderContext:(DPHostRecorderContext *)recorderCtx
                    isAudio:(BOOL)isAudio
{
    @synchronized(recorderCtx) {
        if (!recorderCtx.writer) {
            return NO;
        }
        
        if (CMSampleBufferDataIsReady(sampleBuffer)) {
            if (recorderCtx.writer.status == AVAssetWriterStatusUnknown) {
                if ([recorderCtx.writer startWriting]) {
                    [recorderCtx.writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                    
                    // ライターの書き出し成功を確認、Record APIのHTTPレスポンスでOKを返却する。
                    [recorderCtx.response setResult:DConnectMessageResultTypeOk];
                    [recorderCtx sendResponse];
                    
                    [self sendOnRecordingChangeEventWithStatus:DConnectMediaStreamRecordingProfileRecordingStateRecording
                                                          path:nil mimeType:nil errorMessage:nil];
                }
                else {
                    // ライターの書き出し失敗
                    
                    // キャプチャーセッションを停止する。
                    [recorderCtx.session stopRunning];
                    
                    // Record APIのHTTPレスポンスでエラーを返却する。
                    [recorderCtx.response setErrorToUnknownWithMessage:
                            [NSString stringWithFormat:@"Failed to start a session for an asset writer: %@",
                                recorderCtx.writer.error.localizedDescription]];
                    [recorderCtx sendResponse];
                    
                    // TODO: レコーダーの初期化コードを関数化
                    recorderCtx.state = RecorderStateInactive;
                    recorderCtx.audioReady = recorderCtx.videoReady = NO;
                    recorderCtx.writer = nil;
                    recorderCtx.audioWriterInput = recorderCtx.videoWriterInput = nil;
                    
                    return NO;
                }
            }
            
            if (recorderCtx.writer.status == AVAssetWriterStatusFailed) {
                recorderCtx.state = RecorderStateInactive;
                recorderCtx.audioReady = recorderCtx.videoReady = NO;
                recorderCtx.writer = nil;
                recorderCtx.audioWriterInput = recorderCtx.videoWriterInput = nil;
                
                // TODO: エラーイベントを配送する
                
                return NO;
            }
            
            if (recorderCtx.writer.status == AVAssetWriterStatusWriting) {
                AVAssetWriterInput *writerInput =
                isAudio ? recorderCtx.audioWriterInput : recorderCtx.videoWriterInput;
                if (writerInput || sampleBuffer) {
                    if (!writerInput.readyForMoreMediaData) {
                        return NO;
                    }
                    if ([writerInput appendSampleBuffer:sampleBuffer]) {
                        return YES;
                    } else if (recorderCtx.writer.status == AVAssetWriterStatusFailed) {
                        return NO;
                    }
                }
            }
            
            // TODO: エラーイベントを配送する
            NSLog(@"Failed to append a sample data.");
            return NO;
        }
        
        // TODO: エラーイベントを配送する
        NSLog(@"Sample data is not ready.");
        return NO;
    }
}

- (CMSampleBufferRef) sampleBufferByAdjustingTimestamp:(CMSampleBufferRef)sample by:(CMTime)offset
{
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; ++i)
    {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

#pragma mark - UIDeviceOrientationDidChangeNotification
- (void)deviceOrientationDidChange
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    // 縦か横の時だけ更新する。
    if ( UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation) ) {
        _referenceOrientation = orientation;
    }
}

@end
