//
//  DConnectURLProtocol.m
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectURLProtocol.h"

#import "DConnectManager+Private.h"
#import "DConnectMessage+Private.h"
#import "DConnectFilesProfile.h"
#import "DConnectMultipartParser.h"
#import "DConnectFileManager.h"
#import "NSURLRequest+BodyAndBodyStreamInOne.h"
#import "DConnectURIBuilder.h"

/// 内部用タイプを定義する。
#define EXTRA_INNER_TYPE @"_type"

/// HTTPからの通信タイプを定義する。
#define EXTRA_TYPE_HTTP @"http"

/*!
 @define プロファイルがない場合のException名。
 */
#define HAVE_NO_API_EXCEPTION @"no-api-exception"

/*!
 @define プロファイルがない場合のException名。
 */
#define HAVE_NO_PROFILE_EXCEPTION @"no-profile-exception"

/*!
 @define 実装されていないActionの場合のException名。
 */
#define NOT_SUPPORT_ACTION_EXCEPTION @"no-action-exception"

/*!
 @define JSONのマイムタイプ。
 */
#define MIME_TYPE_JSON @"application/json; charset=UTF-8"

typedef NS_ENUM(NSInteger, DConnectOriginHeaderError) {
    NONE,
    EMPTY,
    NOT_UNIQUE,
};

@implementation ResponseContext

@end



@interface DConnectURLProtocol ()

/*!
 HTTPレスポンス用のヘッダーを生成する。
 @param request HTTPリクエスト
 @param mimeType レスポンスのMIMEタイプ
 @param data レスポンスで返却するデータ
 @return ヘッダー
 */
+ (NSDictionary *)generateHeadersWithRequest:(NSURLRequest *)request
                                    mimeType:(NSString *)mimeType
                                        data:(NSData *)data;

+ (NSString *) percentEncodeString:(NSString *)string withEncoding:(NSStringEncoding)encoding;
+ (NSString *) stringByURLDecodingWithString:(NSString *)string;

/*!
 HTTPメソッド名からDevice Connect で定義されたメソッド名を取得する。
 @param httpMethod HTTPメソッド名
 @return d-Connectメソッド名
 */
int getDConnectMethod(NSString *httpMethod);

@end

@implementation DConnectURLProtocol

// Device Connect ServerのURLのホスト部分の実態
static NSString* host = @"localhost";

// Device Connect ServerのURLのポート部分の実態
static int port = 4035;

static NSString *scheme = @"http";

#pragma mark - NSURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest*)request
{
    DCLogD(@"URL: %@", request.URL.absoluteString);
    DCLogD(@"Method: %@", request.HTTPMethod);
    if ([request.URL.host isEqualToString:host] && ([request.URL.port intValue] == port)) {
        return YES;
    }
    return NO;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request
{
    return request;
}

- (void)startLoading
{
    DCLogD(@"URL: %@", self.request.URL);
    
    [NSFileHandle fileHandleForReadingFromURL:nil error:nil];
    
    __weak DConnectURLProtocol *weakSelf = self;
    [DConnectURLProtocol responseContextWithHTTPRequest:self.request
                                               callback:
     ^(ResponseContext* responseCtx) {
         
#ifdef DEBUG_LEVEL
#if DEBUG_LEVEL > 3
         if (responseCtx.data) {
             DCLogD(@"data: %@", [[NSString alloc] initWithData:responseCtx.data encoding:NSUTF8StringEncoding]);
         }
#endif
#endif
         if (responseCtx.response) {
             // レスポンスあり；成功。
             
             // レスポンスを返す。
             [[weakSelf client] URLProtocol:weakSelf
                         didReceiveResponse:responseCtx.response
                         cacheStoragePolicy:NSURLCacheStorageNotAllowed];
             // レスポンスのデータを返す。
             [[weakSelf client] URLProtocol:weakSelf didLoadData:responseCtx.data];
         } else {
             // レスポンス無し；失敗
             
             // エラーを設定する
             [[weakSelf client] URLProtocol:weakSelf didFailWithError:
              [NSError errorWithDomain:NSCocoaErrorDomain code:NSURLErrorUnknown userInfo:nil]];
         }
         // データのローディング終了を告げる。
         [[weakSelf client] URLProtocolDidFinishLoading:weakSelf];
     }];
}

- (void)stopLoading
{
    // 何もしない
}

#pragma mark - Public

+ (NSString *) host {
    return host;
}

+ (int) port {
    return port;
}

+ (NSString *) scheme {
    return scheme;
}

+ (void) setHost:(NSString *)hostName {
    host = hostName;
}

+ (void) setPort:(int)portNumber {
    port = portNumber;
}

+ (void) setScheme:(NSString *)schemeName {
    scheme = schemeName;
}

+ (DConnectRequestMessage *) requestMessageWithHTTPReqeust:(NSURLRequest *)request
{
    NSURL *url = [request URL];
    DConnectRequestMessage *requestMessage = [DConnectRequestMessage message];
    
    // HTTPリクエストのURLのパスセグメントを取得
    NSMutableCharacterSet *whiteAndSlash = [NSMutableCharacterSet whitespaceCharacterSet];
    [whiteAndSlash formUnionWithCharacterSet:
     [NSMutableCharacterSet characterSetWithCharactersInString:@"/"]];
    NSString *trimmedPath = [url.path stringByTrimmingCharactersInSet:whiteAndSlash];
    NSArray *pathComponentArr = [trimmedPath componentsSeparatedByString:@"/"];
    
    // パラメータ「key=val」をパースし、パラメータ用NSDicitonaryに格納する。
    [NSURLRequest addURLParametersFromString:url.query
                            toRequestMessage:requestMessage
                             percentDecoding:YES];
    
    // URLのパスセグメントの数から、
    // プロファイル・属性・インターフェースが何なのかを判定する。
    NSString *api, *profile, *attr, *interface;
    api = profile = attr = interface = nil;
    
    if ([pathComponentArr count] == 1 &&
        [pathComponentArr[0] length] != 0)
    {
        api = pathComponentArr[0];
    } else if ([pathComponentArr count] == 2 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
    } else if ([pathComponentArr count] == 3 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0 &&
               [pathComponentArr[2] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
        attr = pathComponentArr[2];
    } else if ([pathComponentArr count] == 4 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0 &&
               [pathComponentArr[2] length] != 0 &&
               [pathComponentArr[3] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
        interface = pathComponentArr[2];
        attr = pathComponentArr[3];
    }
    
    if (api == nil || ![api isEqualToString:DConnectMessageDefaultAPI]) {
        [NSException raise:HAVE_NO_API_EXCEPTION
                    format:@"No valid api was detected in URL."];
    }
    
    if (profile == nil) {
        [NSException raise:HAVE_NO_PROFILE_EXCEPTION
                    format:@"No valid profile was detected in URL."];
    }
    
    // リクエストメッセージにHTTPリクエストの
    // メソッドに対応するアクション名を格納する
    int methodId = getDConnectMethod([request HTTPMethod]);
    if (methodId == -1) {
        [NSException raise:NOT_SUPPORT_ACTION_EXCEPTION
                    format:@"Unknown method"];
    }
    [requestMessage setAction:methodId];
    
    // リクエストメッセージにプロファイル・
    // インターフェース・属性・パラメータ各種を突っ込む。
    requestMessage.api = api;
    requestMessage.profile = profile;
    
    if (interface) {
        requestMessage.interface = interface;
    }
    
    if (attr) {
        requestMessage.attribute = attr;
    }
    
    // HTTPリクエストヘッダの解析
    [request addParametersFromHTTPHeaderToRequestMessage:requestMessage];
    
    // パラメータがHTTPボディに記述されているなら、
    // 解析しリクエストメッセージに追加する。
    [request addParametersFromHTTPBodyToRequestMessage:requestMessage];
    
    return requestMessage;
}

+ (void) responseContextWithHTTPRequest:(NSURLRequest *)request
                               callback:(void(^)(ResponseContext* responseCtx))callback
{
    if ([[request HTTPMethod] isEqualToString:@"OPTIONS"]) {
        // CORSのプリフライトリクエストである「OPTIONS」へのリクエストを返す。
        
        ResponseContext *responseCtx = [ResponseContext new];
        
        NSMutableDictionary *headerDict =
        [DConnectURLProtocol generateHeadersWithRequest:request
                                               mimeType:@"text/plain"
                                                   data:nil].mutableCopy;
        [headerDict setValue:@"POST, GET, PUT, DELETE" forKey:@"Access-Control-Allow-Methods"];
        
        responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                           statusCode:200
                                                          HTTPVersion:@"HTTP/1.1"
                                                         headerFields:headerDict];
        responseCtx.data = nil;
        
        callback(responseCtx);
    } else {
        @try {
            // HTTPリクエストを解析して、DeviceConnectのリクエストに変換
            DConnectRequestMessage *requestMessage = [DConnectURLProtocol requestMessageWithHTTPReqeust:request];
            
            [requestMessage setString:EXTRA_TYPE_HTTP forKey:EXTRA_INNER_TYPE];
            [[DConnectManager sharedManager] sendRequest:requestMessage
                                                  isHttp:YES
                                                callback:^(DConnectResponseMessage *responseMessage) {
                // HTTPレスポンスを作成
                [DConnectURLProtocol responseContextWithResponseMessage:responseMessage
                                                   precedingHTTPRequest:request
                                                precedingRequestMessage:requestMessage
                                                               callback:callback];
            }];
        }
        @catch (NSException *exception) {
            DCLogE(@"Exception:\n%@", [exception reason]);
            
            ResponseContext *responseCtx = [ResponseContext new];
            NSDictionary *headerDict = [DConnectURLProtocol generateHeadersWithRequest:request
                                                                              mimeType:MIME_TYPE_JSON
                                                                                  data:responseCtx.data];
            // 各exceptionに合わせてエラーメッセージを設定
            NSString *name = [exception name];
            DConnectResponseMessage * response = [DConnectResponseMessage new];
            [response setResult:DConnectMessageResultTypeError];
            [response setVersion:[DConnectManager sharedManager].versionName];
            [response setProduct:[DConnectManager sharedManager].productName];
            if ([name isEqualToString:HAVE_NO_API_EXCEPTION]) {
                responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                                   statusCode:404
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:headerDict];
                const char *rawData = [[exception reason] UTF8String];
                responseCtx.data = [NSData dataWithBytes:rawData length:strlen(rawData)];
            } else if ([name isEqualToString:HAVE_NO_PROFILE_EXCEPTION]) {
                responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                                   statusCode:200
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:headerDict];
                [response setErrorToNotSupportProfile];
                const char *rawData = [[response convertToJSONString] UTF8String];
                responseCtx.data = [NSData dataWithBytes:rawData length:strlen(rawData)];
            } else if ([name isEqualToString:NOT_SUPPORT_ACTION_EXCEPTION]) {
                responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                                   statusCode:501
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:headerDict];
                responseCtx.data = nil;
            } else {
                responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                                   statusCode:200
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:headerDict];
                [response setErrorToUnknown];
                const char *rawData = [[response convertToJSONString] UTF8String];
                responseCtx.data = [NSData dataWithBytes:rawData length:strlen(rawData)];
            }
            callback(responseCtx);
        }
    }
}

+ (void) responseContextWithResponseMessage:(DConnectResponseMessage *)responseMessage
                       precedingHTTPRequest:(NSURLRequest *)request
                    precedingRequestMessage:(DConnectRequestMessage *)requestMessage
                                   callback:(void(^)(ResponseContext* responseCtx))callback
{
    NSString *mimeType;
    ResponseContext *responseCtx = [ResponseContext new];
    BOOL processed = NO;
    NSInteger statusCode = 200;
    
    if ([requestMessage.profile isEqualToString:DConnectFilesProfileName]) {
        // 特殊処理：DConnectResponseMessageからHTTPレスポンス
        // /ファイルデータ（任意MIMEタイプ）を生成する
        // HTTPレスポンスのボディ（任意コンテンツ）を用意

        if ([responseMessage result] == DConnectMessageResultTypeOk) {
            responseCtx.data = [responseMessage dataForKey:DConnectFilesProfileParamData];
            mimeType = [responseMessage stringForKey:DConnectFilesProfileParamMimeType];
            processed = YES;
            
        } else if ([responseMessage result] ==  DConnectMessageResultTypeError) {
            // エラーのJSONを返す；HTTPステータスコードを404（Not Found）に変えておく。
            statusCode = 404;
        }
    }
    if (!processed) {
        // URIを変換
        [self convertUri:responseMessage];
        
        // JSONに変換
        NSString *json = [responseMessage convertToJSONString];
        if (!json) {
            // レスポンスメッセージからのJSON生成失敗；エラー用データを用意する。
            // 原因不明エラーで、メッセージにJSON生成失敗の旨を記す。
            NSString *dataStr =
            [NSString stringWithFormat:
                    @"{\"%@\":%lu,\"%@\":%lu,\"%@\":\"Failed to generate a JSON body.\"}",
             DConnectMessageResult, (unsigned long)DConnectMessageResultTypeError,
             DConnectMessageErrorCode, (unsigned long)DConnectMessageErrorCodeUnknown,
             DConnectMessageErrorMessage];
            const char *rawData = dataStr.UTF8String;
            responseCtx.data = [NSData dataWithBytes:rawData length:strlen(rawData)];
        } else {
            responseCtx.data = [json dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        mimeType = MIME_TYPE_JSON;
    }
    
    NSDictionary *headerDict = [DConnectURLProtocol generateHeadersWithRequest:request
                                                                      mimeType:mimeType
                                                                          data:responseCtx.data];
    responseCtx.response = [[NSHTTPURLResponse alloc] initWithURL:[request URL]
                                                       statusCode:statusCode
                                                      HTTPVersion:@"HTTP/1.1"
                                                     headerFields:headerDict];
    
    callback(responseCtx);
}

+ (void) convertUri:(DConnectMessage *) response
{
    NSArray *keys = [response allKeys];
    for (NSString *key in keys) {
        NSObject *obj = [response objectForKey:key];
        if ([key isEqualToString:@"uri"]) {
            NSString *uri = (NSString *)obj;
            
            // http, httpsで指定されているURLは直接アクセスできるのでFilesAPIを利用しない
            NSString *pattern = @"^https?://.+";
            NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                options:0 error:nil];
            NSTextCheckingResult *result = [expression firstMatchInString:uri
                                                                  options:0
                                                                    range:NSMakeRange(0, uri.length)];
            
            if (!result || result.numberOfRanges < 1) {
                // http, https以外の場合はuriパラメータ値を
                // DeviceConnectManager Files API向けURLに置き換える。
                DConnectURIBuilder *builder = [DConnectURIBuilder new];
                [builder setProfile:DConnectFilesProfileName];
                [builder addParameter:uri forName:DConnectFilesProfileParamUri];
                [response setString:[[builder build] absoluteString] forKey:@"uri"];
            }
        } else if ([obj isKindOfClass:[DConnectMessage class]]) {
            [self convertUri:(DConnectMessage *)obj];
        } else if ([obj isKindOfClass:[DConnectArray class]]) {
            DConnectArray *arr = (DConnectArray *) obj;
            for (int i = 0; i < arr.count; i++) {
                NSObject *message = [arr objectAtIndex:i];
                if ([message isKindOfClass:[DConnectMessage class]]) {
                    [self convertUri:(DConnectMessage *) message];
                }
            }
        }
    }
}

#pragma mark - Private

+ (NSDictionary *)generateHeadersWithRequest:(NSURLRequest *)request
                                    mimeType:(NSString *)mimeType
                                        data:(NSData *)data
{
    NSMutableString *allowHeaders = @"XMLHttpRequest".mutableCopy;
    NSString *requestHeaders = [request valueForHTTPHeaderField:@"Access-Control-Request-Headers"];
    if (requestHeaders) {
        [allowHeaders appendString:[NSString stringWithFormat:@", %@", requestHeaders]];
    }
    
    return @{@"Content-Type" : mimeType,
             @"Content-Length" : data ?
             [NSString stringWithFormat:@"%lu", (unsigned long)[data length]] : @"0",
             @"Date": [[NSDate date] descriptionWithLocale:nil],
             @"Access-Control-Allow-Origin" : @"*",
             @"Access-Control-Allow-Headers" : allowHeaders,
             @"Connection": @"close",
             @"Server" : @"dConnectServer",
             @"Last-Modified" : @"Fri, 26 May 2014 00:00:00 +0900",
             @"Cache-Control" : @"private, max-age=0, no-cache"
             };
}

+ (NSString *) percentEncodeString:(NSString *)string withEncoding:(NSStringEncoding)encoding
{
    NSCharacterSet *allowedCharSet
            = [[NSCharacterSet characterSetWithCharactersInString:@"%;/?:@&=$+{}<>., "]
                    invertedSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharSet];
}

+ (NSString *) stringByURLDecodingWithString:(NSString *)string {
    NSString *url = [string stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    url = [url stringByRemovingPercentEncoding];
    
    return url;
}

int getDConnectMethod(NSString *httpMethod) {
    if ([httpMethod isEqualToString:@"GET"]) {
        return DConnectMessageActionTypeGet;
    } else if ([httpMethod isEqualToString:@"POST"]) {
        return DConnectMessageActionTypePost;
    } else if ([httpMethod isEqualToString:@"PUT"]) {
        return DConnectMessageActionTypePut;
    } else if ([httpMethod isEqualToString:@"DELETE"]) {
        return DConnectMessageActionTypeDelete;
    }
    return -1;
}

@end

@implementation NSURLRequest (DConnect)

- (void)addParametersFromHTTPHeaderToRequestMessage:(DConnectRequestMessage *)requestMessage
{
    // オリジンの解析
    NSString *webOrigin = [self valueForHTTPHeaderField:@"origin"];
    NSString *nativeOrigin = [self valueForHTTPHeaderField:DConnectMessageHeaderGotAPIOrigin];
    if (nativeOrigin) {
        [requestMessage setString:nativeOrigin forKey:DConnectMessageOrigin];
    } else if (webOrigin) {
        [requestMessage setString:webOrigin forKey:DConnectMessageOrigin];
    } else {
        DCLogW(@"origin of request is not specified.");
    }
}

- (void)addParametersFromMultipartToRequestMessage:(DConnectMessage *)requestMessage
{
    UserData *userData = [UserData userDataWithRequest:requestMessage];
    DConnectMultipartParser *multiParser =
    [DConnectMultipartParser multipartParserWithURL:self
                                   userData:userData];
    
    [multiParser parse];
}

- (void)addParametersFromHTTPBodyToRequestMessage:(DConnectRequestMessage *)requestMessage
{
    NSString *contentType = [self valueForHTTPHeaderField:@"content-type"];
    if (contentType && [contentType rangeOfString:@"multipart/form-data"
                           options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        [self addParametersFromMultipartToRequestMessage:requestMessage];
    } else if (self.body && self.body.length > 0) {
        BOOL doDecode = [contentType isEqualToString:@"application/x-www-form-urlencoded"];
        [NSURLRequest addURLParametersFromString:[[NSString alloc]
                                                  initWithData:[self body]
                                                      encoding:NSUTF8StringEncoding]
                                toRequestMessage:requestMessage
                                 percentDecoding:doDecode];
    }
}

/// パラメータ「key=val」or「key」をパースし、パラメータ用NSDicitonaryに格納する。
+ (void)addURLParametersFromString:(NSString *)urlParameterStr
                  toRequestMessage:(DConnectRequestMessage *)requestMessage
                   percentDecoding:(BOOL)doDecode
{
    if (!urlParameterStr) {
        return;
    }
    NSArray *paramArr = [urlParameterStr componentsSeparatedByString:@"&"];
    [paramArr enumerateObjectsWithOptions:NSEnumerationConcurrent
                               usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
     {
         NSArray *keyValArr = [(NSString *)obj componentsSeparatedByString:@"="];
         NSString *key;
         NSString *val;
         
#ifdef DEBUG_LEVEL
#if DEBUG_LEVEL > 3
         // valが無くkeyのみのパラメータ
         if ([keyValArr count] == 1) {
             key = doDecode ?
                    [DConnectURLProtocol stringByURLDecodingWithString:(NSString *)keyValArr[0]]
                        : keyValArr[0];
             DCLogD(@"Key-only URL query parameter \"%@\" will be ignored.", key);
         }
#endif
#endif
         // key&valのパラメータ
         if ([keyValArr count] == 2) {
             
             if (doDecode) {
                 key = [DConnectURLProtocol stringByURLDecodingWithString:(NSString *)keyValArr[0]];
                 val = [DConnectURLProtocol stringByURLDecodingWithString:(NSString *)keyValArr[1]];
             } else {
                 key = keyValArr[0];
                 val = keyValArr[1];
             }
             
             if (key && val) {
                 @synchronized (requestMessage) {
                     [requestMessage setString:val forKey:key];
                 }
             }
         }
     }];
}

@end
