//
//  LocalBundleServer.m
//  dConnectBrowserForIOS9
//
//  Copyright (c) 2018 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "LocalBundleServer.h"
#import <DConnectSDK/RoutingHTTPServer.h>
#import <DConnectSDK/RoutingConnection.h>
#import <DConnectSDK/RouteRequest.h>
#import <DConnectSDK/RouteResponse.h>
#import <DConnectSDK/DConnectSDK.h>

@interface FileServerConnection : RoutingConnection
@end
@implementation FileServerConnection
- (BOOL)isSecureServer
{
    return [DConnectManager sharedManager].settings.useSSL;
}
- (NSArray *)sslIdentityAndCertificates
{
    return [[DConnectIdentityStore shared] identity];
}
@end

@interface LocalBundleServer()
{
    RoutingHTTPServer *fileServer;
}
@end

@implementation LocalBundleServer

+ (LocalBundleServer *) sharedServer {
    static LocalBundleServer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [LocalBundleServer new];
    });
    return shared;
}

- (id) init {
    self = [super init];
    if (self) {
        fileServer = [RoutingHTTPServer new];
        [fileServer setConnectionClass:[FileServerConnection class]];
        [fileServer setPort:10080];
        [fileServer setDefaultHeader:@"Connection" value:@"close"];
        [fileServer setDefaultHeader:@"Cache-Control" value:@"private, max-age=0, no-cache"];
        [fileServer setDefaultHeader:@"Server" value:@"DeviceConnect/1.0"];
        [fileServer setDefaultHeader:@"Access-Control-Allow-Origin" value:@"*"];
        [fileServer get:@"/*" withBlock:^(RouteRequest *request, RouteResponse *response) {
            NSString *rootPath = [NSBundle mainBundle].bundlePath;
            NSString *requestPath = [NSString stringWithFormat:@"file://%@%@", rootPath, request.url.path];
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:requestPath]];
            if (!data) {
                [response setStatusCode:404];
                return;
            }
            [self setHeaderInResponse:response withRequest:request];
            [response setStatusCode:200];
            [response respondWithData:data];
        }];
    }
    return self;
}

- (NSString *) url
{
    BOOL isSSL = [DConnectManager sharedManager].settings.useSSL;
    NSString *scheme = isSSL ? @"https" : @"http";
    return [NSString stringWithFormat:@"%@://localhost:%d", scheme, [fileServer listeningPort]];
}

- (void) start
{
    NSError *error;
    [fileServer start:&error];
    if (!error) {
        NSLog(@"Started file server: localhost:%d", fileServer.port);
    } else {
        NSLog(@"Failed to start file server: error = %@", error);
    }
}

- (void) stop
{
    [fileServer stop];
}

- (void) restart
{
    [self stop];
    [self start];
}

- (void) setHeaderInResponse:(RouteResponse *)response withRequest:(RouteRequest *)request
{
    NSString *requestHeaders = [request header:@"Access-Control-Request-Headers"];
    NSMutableString *allowHeaders = @"XMLHttpRequest, x-gotapi-origin".mutableCopy;
    if (requestHeaders) {
        [allowHeaders appendString:[NSString stringWithFormat:@", %@", requestHeaders]];
    }
    
    [response setHeader:@"Date" value:[[NSDate date] descriptionWithLocale:nil]];
    [response setHeader:@"Access-Control-Allow-Headers" value:allowHeaders];
}

@end
