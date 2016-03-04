//
//  GHDirectory.h
//  dConnectBrowserForIOS9
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import "GHData.h"

@interface GHDirectory : NSObject

+ (GHPageModel*)checkDirectory:(Page*)page;
+ (GHPageModel*)copyPageModel:(Page*)page;
@end
