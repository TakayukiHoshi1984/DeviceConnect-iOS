//
//  GHPageModel.m
//  dConnectBrowserForIOS9
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "GHPageModel.h"

@implementation GHPageModel

- (void)dealloc
{
    self.title      = nil;
    self.url        = nil;
    self.category   = nil;
    self.type       = nil;
    self.priority   = nil;
    self.identifier = nil;
    self.children   = nil;
}

@end
