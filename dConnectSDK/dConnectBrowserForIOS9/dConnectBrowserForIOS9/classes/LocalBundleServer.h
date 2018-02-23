//
//  LocalBundleServer.h
//  dConnectBrowserForIOS9
//
//  Copyright (c) 2018 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

@interface LocalBundleServer : NSObject

@property (atomic, readonly) NSString *url;

+ (instancetype) sharedServer;
- (void) start;
- (void) stop;
- (void) restart;

@end
