//
//  DConnectService.h
//  DConnectSDK
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import <DConnectSDK/DConnectServiceProvider.h>
#import <DConnectSDK/DConnectProfileProvider.h>

@interface DConnectService : NSObject<DConnectProfileProvider>

- (instancetype) initWithServiceId: (NSString *)serviceId;

- (NSString *) serviceId;

- (void) setName: (NSString *)name;

- (NSString *) name;

- (void) setNetworkType: (NSString *) type;

- (NSString *) networkType;

- (void) setOnline: (BOOL) isOnline;

- (BOOL) isOnline;

- (NSString *) config;

- (void) setConfig: (NSString *) config;

- (BOOL) onRequest: request response: response;

@end