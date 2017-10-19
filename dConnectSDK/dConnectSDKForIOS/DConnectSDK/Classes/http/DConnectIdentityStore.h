//
//  DConnectIdentityStore.h
//  DConnectSDK
//
//  Created by Masaru Takano on 2017/10/19.
//  Copyright © 2017年 NTT DOCOMO, INC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DConnectIdentityStore : NSObject

+ (DConnectIdentityStore *) shared;

- (NSArray *) identity;

@end
