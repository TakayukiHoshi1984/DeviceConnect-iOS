//
//  SonyCameraSimpleHttpServer.m
//  dConnectDeviceSonyCamera
//
//  Copyright (c) 2017 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "SonyCameraSimpleHttpServer.h"
#import "GCDAsyncSocket.h"


#define HTTP_TIMEOUT 3.0


@implementation SonyCameraConnection

@end


@interface SonyCameraSimpleHttpServer () <GCDAsyncSocketDelegate>

@end


@implementation SonyCameraSimpleHttpServer {
    GCDAsyncSocket *_listenSocket;
    NSMutableArray *_connections;
    NSString *_boundary;
    NSString *_path;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.listenPort = 8080;

        _listenSocket = nil;
        _connections = [NSMutableArray array];
        _boundary = @"0123456789ABCDEF";
        _path = [[NSUUID UUID] UUIDString];
    }
    return self;
}


#pragma mark - GCDAsyncSocketDelegate Methods

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"Accept:%p", sock);
    
    SonyCameraConnection *connection = [SonyCameraConnection new];
    connection.fromSocket = newSocket;
    connection.ready = NO;
    
    @synchronized(self) {
        [_connections addObject:connection];
    }

    [newSocket readDataWithTimeout:HTTP_TIMEOUT tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"Disconnect:%p %@", sock, err);
    
    @synchronized(self) {
        SonyCameraConnection *c = [self foundConnection:sock];
        if (c) {
            [_connections removeObject:c];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"ReadData:%p", sock);
 
    NSString *headerData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([self parseHttpHeader:headerData]) {
        [self writeHeadersToSocket:sock];
    } else {
        [sock disconnect];
    }
}

#pragma mark - Private Methods

- (BOOL) parseHttpHeader:(NSString *)header
{
    NSString *method;
    NSString *path;
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSArray* lines = [header componentsSeparatedByString:@"\r\n"];
    int lineIndex = 0;
    
    if (lines.count == 0) {
        return NO;
    }
    
    NSArray *keyValue = [lines[0] componentsSeparatedByString:@" "];
    if (keyValue && keyValue.count >= 2) {
        method = [keyValue[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        path = [keyValue[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    
    if (!method || !path) {
        return NO;
    }

    if (![[method lowercaseString] isEqualToString:@"get"]) {
        return NO;
    }
    
    if (![[path substringFromIndex:1] isEqualToString:_path]) {
        return NO;
    }
    
    // 各ヘッダーを格納
    for (; lineIndex < lines.count; lineIndex++) {
        NSString *line = lines[lineIndex];
        NSArray *keyValue = [line componentsSeparatedByString:@":"];
        if (keyValue && keyValue.count == 2) {
            NSString *key =[keyValue[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *value = [keyValue[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            headers[key] = value;
        }
    }
    
    return YES;
}

- (void) writeHeadersToSocket:(GCDAsyncSocket *)socket
{
    NSString *str = @"HTTP/1.0 200 OK\r\n"
                    "Server: SonyCameraSimpleHttpServer\r\n"
                    "Connection: close\r\n"
                    "Max-Age: 0\r\n"
                    "Expires: 0\r\n"
                    "Cache-Control: no-store, no-cache, must-revalidate, pre-check=0, post-check=0, max-age=0\r\n"
                    "Pragma: no-cache\r\n"
                    "Content-Type: multipart/x-mixed-replace; "
                    "boundary=%@\r\n"
                    "\r\n"
                    "--%@\r\n";
    
    NSString *string = [NSString stringWithFormat:str, _boundary, _boundary];
    NSData *headerData = [string dataUsingEncoding:NSUTF8StringEncoding];
    [socket writeData:headerData withTimeout:HTTP_TIMEOUT tag:0];
    
    SonyCameraConnection *conn = [self foundConnection:socket];
    if (conn) {
        conn.ready = YES;
    }
}

- (void) sendImageData:(NSData *)imageData toSocket:(GCDAsyncSocket *)socket
{
    NSString *str = @"--%@\r\n"
                    "Content-Type: %@\r\n"
                    "Content-Length: %d\r\n"
                    "\r\n";
    NSString *string = [NSString stringWithFormat:str, _boundary, @"image/jpg", imageData.length];
    NSData *headerData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSData *endData = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    [socket writeData:headerData withTimeout:HTTP_TIMEOUT tag:0];
    [socket writeData:imageData withTimeout:HTTP_TIMEOUT tag:0];
    [socket writeData:endData withTimeout:HTTP_TIMEOUT tag:0];
}

- (SonyCameraConnection *) foundConnection:(GCDAsyncSocket *)socket
{
    __block SonyCameraConnection *result = nil;
    
    [_connections enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SonyCameraConnection *connection, NSUInteger idx, BOOL *stop) {
        if ([connection.fromSocket.description isEqualToString:socket.description]) {
            result = connection;
            *stop = YES;
        }
    }];
    
    return result;
}


#pragma mark - Public Methods

- (void) start
{
    NSError *error = nil;
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [_listenSocket acceptOnPort:self.listenPort error:&error];
}

- (void) stop
{
    [_listenSocket setDelegate:nil delegateQueue:NULL];
    [_listenSocket disconnect];
    _listenSocket = nil;
}

- (NSString *) getUrl
{
    NSString *str = @"http://localhost:%d/%@";
    return  [NSString stringWithFormat:str, self.listenPort, _path];
}

- (void) offerData:(NSData *)data
{
    __block typeof(self) weakSelf = self;

    [_connections enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SonyCameraConnection *connection, NSUInteger idx, BOOL *stop) {
        if (connection.ready) {
            [weakSelf sendImageData:data toSocket:connection.fromSocket];
        }
    }];
}

@end
