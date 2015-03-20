//
//  GCIPUtil.m
//  dConnectServer
//
//  Created by Takashi Tsuchiya on 2014/07/18.
//  Copyright (c) 2014年 GClue, Inc. All rights reserved.
//

#import "GCIPUtil.h"
#import <ifaddrs.h>
#import <arpa/inet.h>


@implementation GCIPUtil

+ (NSString *)myIPAddress
{
	NSString *address = nil;
	struct ifaddrs *interfaces = NULL;
	struct ifaddrs *temp_addr = NULL;
	int success = 0;
	success = getifaddrs(&interfaces);
	if (success == 0) {
		temp_addr = interfaces;
		while(temp_addr != NULL) {
			if(temp_addr->ifa_addr->sa_family == AF_INET) {
				if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
				}
			}
			temp_addr = temp_addr->ifa_next;
		}
	}
	freeifaddrs(interfaces);
	return address;
}

@end