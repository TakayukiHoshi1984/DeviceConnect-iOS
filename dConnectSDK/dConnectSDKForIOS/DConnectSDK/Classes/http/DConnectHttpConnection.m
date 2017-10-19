//
//  DConnectHttpConnection.m
//  DConnectSDK
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectHttpConnection.h"
#import "DConnectWebSocket.h"
#import "DConnectIdentityStore.h"

@implementation DConnectHttpConnection

#pragma mark - Override Method

- (WebSocket *)webSocketForURI:(NSString *)path
{
    DConnectWebSocket *websocket = [[DConnectWebSocket alloc] initWithRequest:request socket:asyncSocket];
    websocket.delegate = config.server;
    websocket.connectTime = [NSDate date].timeIntervalSince1970;
    return websocket;
}

- (BOOL)isSecureServer
{
    // TODO: 設定画面でYES/NOを切り替えられるようにする
    return YES;
}

/**
 * This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
 **/
- (NSArray *)sslIdentityAndCertificates
{
    NSArray *array = [[DConnectIdentityStore shared] identity];
    NSLog(@"sslIdentityAndCertificates: %d", array.count);
    return array;
}

@end
