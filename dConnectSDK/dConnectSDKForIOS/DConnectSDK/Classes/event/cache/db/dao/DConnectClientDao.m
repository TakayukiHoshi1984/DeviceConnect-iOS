//
//  DConnectClientDao.m
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectClientDao.h"
#import "DConnectEventDao.h"
#import "DConnectAttributeDao.h"
#import "DConnectDeviceDao.h"
#import "DConnectEventDeviceDao.h"
#import "DConnectEventSessionDao.h"
#import "DConnectInterfaceDao.h"
#import "DConnectProfileDao.h"

NSString *const DConnectClientDaoTableName = @"Client";
NSString *const DConnectClientDaoClmAccessToken = @"access_token";
NSString *const DConnectClientDaoClmOrigin = @"origin";

@implementation DConnectClient
@end

@implementation DConnectClientDao

+ (void) createWithDatabase:(DConnectSQLiteDatabase *)database {
    
    NSString *sql = DCEForm(@"CREATE TABLE %@"
                            "(%@ INTEGER PRIMARY KEY AUTOINCREMENT,"
                            "%@ TEXT NOT NULL, %@ TEXT,"
                            "%@ INTEGER NOT NULL,"
                            "%@ INTEGER NOT NULL, UNIQUE(%@));",
                            DConnectClientDaoTableName,
                            DConnectEventDaoClmId,
                            DConnectClientDaoClmOrigin,
                            DConnectClientDaoClmAccessToken,
                            DConnectEventDaoClmCreateDate,
                            DConnectEventDaoClmUpdateDate,
                            DConnectClientDaoClmOrigin);
    
    if (![database execSQL:sql]){
        @throw @"error";
    };
}

+ (long long) insertWithEvent:(DConnectEvent *)event toDatabase:(DConnectSQLiteDatabase *)database {
    
    long long result = -1;
    
    do {
        
        DConnectSQLiteCursor *cursor
        = [database selectFromTable:DConnectClientDaoTableName
                            columns:@[DConnectEventDaoClmId]
                              where:DCEForm(@"%@=?", DConnectClientDaoClmOrigin)
                         bindParams:@[event.origin]];
        
        if (!cursor) {
            break;
        }
        
        NSObject *accessToken = (event.accessToken == nil) ? [NSNull null] : event.accessToken;
        NSNumber *current = [NSNumber numberWithLongLong:getCurrentTimeInMillis()];
        if (cursor.count == 0) {
            
            result = [database insertIntoTable:DConnectClientDaoTableName
                                       columns:@[DConnectClientDaoClmOrigin, DConnectClientDaoClmAccessToken,
                                                 DConnectEventDaoClmCreateDate, DConnectEventDaoClmUpdateDate]
                                        params:@[event.origin, accessToken, current, current]];
            
        } else if ([cursor moveToFirst]) {
            result = [cursor longLongValueAtIndex:0];
            int count = [database updateTable:DConnectClientDaoTableName
                                      columns:@[DConnectClientDaoClmAccessToken, DConnectEventDaoClmUpdateDate]
                                        where:DCEForm(@"%@=?", DConnectEventDaoClmId)
                                   bindParams:@[accessToken, current, [NSNumber numberWithLongLong:result]]];
            if (count != 1) {
                result = -1;
            }
        }
        
        [cursor close];
    } while (false);
    
    return result;
}

+ (NSArray *) clientsForOrigin:(NSString *)origin
                        onDatabase:(DConnectSQLiteDatabase *)database {
    
    NSMutableArray *clients = nil;
    DConnectSQLiteCursor *cursor
    = [database selectFromTable:DConnectClientDaoTableName
                        columns:@[DConnectEventDaoClmId,
                                  DConnectClientDaoClmOrigin,
                                  DConnectClientDaoClmAccessToken]
                          where:DCEForm(@"%@=?", DConnectClientDaoClmOrigin)
                     bindParams:@[origin]];
    
    if (!cursor) {
        return clients;
    }
    
    
    if ([cursor moveToFirst]) {
        clients = [NSMutableArray array];
        do {
            DConnectClient *client = [DConnectClient new];
            client.rowId = [cursor intValueAtIndex:0];
            client.origin = [cursor stringValueAtIndex:1];
            client.accessToken = [cursor stringValueAtIndex:2];
            [clients addObject:client];
        } while ([cursor moveToNext]);
    }
    
    [cursor close];
    
    return clients;
}

+ (DConnectClient *) clientWithId:(long long)rowId onDatabase:(DConnectSQLiteDatabase *)database {
    
    DConnectClient *client = nil;
    DConnectSQLiteCursor *cursor
    = [database selectFromTable:DConnectClientDaoTableName
                        columns:@[DConnectClientDaoClmOrigin, DConnectClientDaoClmAccessToken]
                          where:DCEForm(@"%@=?", DConnectEventDaoClmId)
                     bindParams:@[[NSNumber numberWithLongLong:rowId]]];
    
    if (!cursor) {
        return client;
    }
    
    
    if ([cursor moveToFirst]) {
        client = [DConnectClient new];
        client.rowId = rowId;
        client.origin = [cursor stringValueAtIndex:0];
        client.accessToken = [cursor stringValueAtIndex:1];
    }
    
    [cursor close];
    
    return client;
}

+ (NSArray *) clientsForAPIWithServiceId:(DConnectEvent *)event
                             onDatabase:(DConnectSQLiteDatabase *)database
{
    
    NSMutableArray *clients = nil;
    NSString *sql
    = DCEForm(@"SELECT c.%@, c.%@, c.%@, es.%@, es.%@ "
              "FROM %@ AS p INNER JOIN %@ AS i ON p.%@ = i.%@ "
              "INNER JOIN %@ AS a ON i.%@ = a.%@ INNER JOIN "
              "%@ AS ed ON a.%@ = ed.%@ INNER JOIN %@ AS d ON "
              "ed.%@ = d.%@ INNER JOIN %@ AS es ON es.%@ = ed.%@ "
              "INNER JOIN %@ AS c ON es.%@ = c.%@ WHERE p.%@ = ? "
              "AND i.%@ = ? AND a.%@ = ? AND d.%@ = ?;",
              DConnectEventDaoClmId,
              DConnectClientDaoClmOrigin,
              DConnectClientDaoClmAccessToken,
              DConnectEventDaoClmCreateDate,
              DConnectEventDaoClmUpdateDate,
              DConnectProfileDaoTableName,
              DConnectInterfaceDaoTableName,
              DConnectEventDaoClmId,
              DConnectInterfaceDaoClmPId,
              DConnectAttributeDaoTableName,
              DConnectEventDaoClmId,
              DConnectAttributeDaoClmIId,
              DConnectEventDeviceDaoTableName,
              DConnectEventDaoClmId,
              DConnectEventDeviceDaoClmAId,
              DConnectDeviceDaoTableName,
              DConnectEventDeviceDaoClmDId,
              DConnectEventDaoClmId,
              DConnectEventSessionDaoTableName,
              DConnectEventSessionDaoClmEDId,
              DConnectEventDaoClmId,
              DConnectClientDaoTableName,
              DConnectEventSessionDaoClmCId,
              DConnectEventDaoClmId,
              DConnectProfileDaoClmName,
              DConnectInterfaceDaoClmName,
              DConnectAttributeDaoClmName,
              DConnectDeviceDaoClmServiceId);
    
    NSString *interface = (event.interface) ? event.interface : DConnectInterfaceDaoEmptyName;
    NSString *serviceId = (event.serviceId) ? event.serviceId : DConnectDeviceDaoEmptyServiceId;
    
    DConnectSQLiteCursor *cursor = [database queryWithSQL:sql
                                               bindParams:@[event.profile, interface,
                                                            event.attribute, serviceId]];
    
    if (!cursor) {
        return clients;
    }
    
    if ([cursor moveToFirst]) {
        clients = [NSMutableArray array];
        do {
            DConnectClient *client = [DConnectClient new];
            client.rowId = [cursor longLongValueAtIndex:0];
            client.origin = [cursor stringValueAtIndex:1];
            client.accessToken = [cursor stringValueAtIndex:2];
            client.esCreateDate = [NSDate dateWithTimeIntervalSince1970:[cursor longLongValueAtIndex:3]];
            client.esUpdateDate = [NSDate dateWithTimeIntervalSince1970:[cursor longLongValueAtIndex:4]];
            [clients addObject:client];
            
        } while ([cursor moveToNext]);
    }
    
    [cursor close];
    
    return clients;
}

@end
