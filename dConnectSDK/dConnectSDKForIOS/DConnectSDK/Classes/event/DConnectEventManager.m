//
//  DConnectEventManager.m
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectEventManager.h"

#pragma mark - DConnectEventManager
@interface DConnectEventManager()

/** キャッシュコントローラー. */
@property (nonatomic, strong) id<DConnectEventCacheController> controller;

- (DConnectEvent *) createEventForRequest:(DConnectRequestMessage *)request;
- (void) checkControllerState;

@end

@implementation DConnectEventManager

#pragma mark Static Methods

+ (DConnectEventManager *) sharedManagerForClass:(Class)clazz {

    if (clazz == nil) {
        return nil;
    }
    
    DConnectEventManager *manager = nil;
    NSString *className = NSStringFromClass(clazz);
    manager = [DConnectEventManager sharedManagerForKey:className];
    return manager;
}

+ (DConnectEventManager *) sharedManagerForKey:(NSString *)key {
    
    static NSMutableDictionary *managers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        managers = [NSMutableDictionary dictionary];
    });
    
    DConnectEventManager *manager = nil;
    @synchronized (managers) {
        manager = [managers objectForKey:key];
        
        if (manager == nil) {
            manager = [DConnectEventManager new];
            [managers setObject:manager forKey:key];
        }
    }
    return manager;
}

#pragma mark Instance Methods

- (void) setController:(id<DConnectEventCacheController>)controller {
    _controller = controller;
}

- (DConnectEventError) addEventForRequest:(DConnectRequestMessage *)request {
    
    [self checkControllerState];
    
    DConnectEvent *event = [self createEventForRequest:request];
    if (!event) {
        return DConnectEventErrorFailed;
    }
    
    return [_controller addEvent:event];
}

- (DConnectEventError) removeEventForRequest:(DConnectRequestMessage *)request {
    
    [self checkControllerState];
    
    DConnectEvent *event = [self createEventForRequest:request];
    if (!event) {
        return DConnectEventErrorFailed;
    }
    
    return [_controller removeEvent:event];
}

- (BOOL) removeEventsForOrigin:(NSString *)origin {
    [self checkControllerState];
    return [_controller removeEventsForOrigin:origin];
}

- (BOOL) removeAll {
    [self checkControllerState];
    return [_controller removeAll];
}

- (NSArray *) eventListForProfile:(NSString *)profile attribute:(NSString *)attribute {
    return [self eventListForProfile:profile interface:nil attribute:attribute];
}

- (NSArray *) eventListForProfile:(NSString *)profile interface:(NSString *)interface attribute:(NSString *)attribute {
    return [self eventListForServiceId:nil profile:profile interface:interface attribute:attribute];
}

- (NSArray *) eventListForServiceId:(NSString *)serviceId profile:(NSString *)profile attribute:(NSString *)attribute {
    return [self eventListForServiceId:serviceId profile:profile interface:nil attribute:attribute];
}

- (NSArray *) eventListForServiceId:(NSString *)serviceId profile:(NSString *)profile
                         interface:(NSString *)interface attribute:(NSString *)attribute
{
    [self checkControllerState];
    return [_controller eventsForServiceId:serviceId profile:profile interface:interface attribute:attribute];
}

- (void) flush {
    [self checkControllerState];
    [_controller flush];
}

#pragma mark Static Methods

+ (DConnectMessage *) createEventMessageWithEvent:(DConnectEvent *)event {
    
    DConnectMessage *message = [DConnectMessage message];
    [message setString:event.profile forKey:DConnectMessageProfile];
    if (event.interface) {
        [message setString:event.interface forKey:DConnectMessageInterface];
    }
    [message setString:event.attribute forKey:DConnectMessageAttribute];
    [message setString:event.accessToken forKey:DConnectMessageAccessToken];
    [message setString:event.origin forKey:DConnectMessageOrigin];
    if (event.serviceId) {
        [message setString:event.serviceId forKey:DConnectMessageServiceId];
    }
    return message;
}

#pragma mark Private Methods

- (DConnectEvent *) createEventForRequest:(DConnectRequestMessage *)request {
    
    if (!request) {
        return nil;
    }
    
    DConnectEvent *event = [DConnectEvent new];
    event.serviceId = request.serviceId;
    event.profile = request.profile;
    event.interface = request.interface;
    event.attribute = request.attribute;
    event.origin = request.origin;
    event.accessToken = request.accessToken;
    
    return event;
}

- (void) checkControllerState {
    
    if (!_controller) {
        [NSException raise:@"DConnectNoCacheControllerException"
                    format:@"CacheController is not set."];
    }
    
}

@end
