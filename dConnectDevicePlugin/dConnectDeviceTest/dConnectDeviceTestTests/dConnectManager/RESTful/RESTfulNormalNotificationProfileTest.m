//
//  RESTfulNormalNotificationProfileTest.m
//  dConnectDeviceTest
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "RESTfulTestCase.h"

@interface RESTfulNormalNotificationProfileTest : RESTfulTestCase

@end

/*!
 * @class RESTfulNormalNotificationProfileTest
 * @brief Notificationプロファイルの正常系テスト.
 *
 * @author NTT DOCOMO, INC.
 */
@implementation RESTfulNormalNotificationProfileTest

/*!
 * @brief 通知を送信するテストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: POST
 * Path: /notification/notify?serviceId=xxxx&type=0&body=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * ・notificationidに1が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationNotifyPost
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/notify?serviceId=%@&type=0",
                   self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"POST"];
    
    CHECK_RESPONSE(@"{\"notificationId\":\"1\",\"result\":0}", request);
}

/*!
 * @brief 通知の消去要求を送信するテストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: DELETE
 * Path: /notification/notify?serviceId=xxxx&notificationId=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationNotifyDelete
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/notify?serviceId=%@&notificationId=1",
                   self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"DELETE"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
}

/*!
 * @brief 通知クリックイベントのコールバック登録テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: PUT
 * Path: /notification/onclick?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * ・コールバック登録後にイベントを受信できること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnClickPut
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onclick?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"PUT"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    CHECK_EVENT(@"{\"notificationId\":\"1\"}");
}

/*!
 * @brief 通知クリックイベントのコールバック解除テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: DELETE
 * Path: /notification/onshow?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnClickDelete
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onclick?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"DELETE"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    
}

/*!
 * @brief 通知表示イベントのコールバック登録テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: PUT
 * Path: /notification/onshow?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * ・コールバック登録後にイベントを受信できること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnShowPut
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onshow?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"PUT"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    CHECK_EVENT(@"{\"notificationId\":\"1\"}");
}

/*!
 * @brief 通知表示イベントのコールバック解除テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: DELETE
 * Path: /notification/onshow?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnShowDelete
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onshow?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"DELETE"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    
}

/*!
 * @brief 通知消去イベントのコールバック登録テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: PUT
 * Path: /notification/onclose?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * ・コールバック登録後にイベントを受信できること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnClosePut
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onclose?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"PUT"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    CHECK_EVENT(@"{\"notificationId\":\"1\"}");
}

/*!
 * @brief 通知消去イベントのコールバック解除テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: DELETE
 * Path: /notification/onclose?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnCloseDelete
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onclose?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"DELETE"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    
}

/*!
 * @brief 通知操作エラー発生イベントのコールバック登録テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: PUT
 * Path: /notification/onerror?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * ・コールバック登録後にイベントを受信できること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnErrorPut
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onerror?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"PUT"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    CHECK_EVENT(@"{\"notificationId\":\"1\"}");
}

/*!
 * @brief 通知操作エラー発生イベントのコールバック解除テストを行う.
 *
 * <pre>
 * 【HTTP通信】
 * Method: DELETE
 * Path: /notification/onerror?serviceId=xxxx&accessToken=xxxx
 * </pre>
 *
 * <pre>
 * 【期待する動作】
 * ・resultに0が返ってくること。
 * </pre>
 */
- (void) testHttpNormalNotificationOnErrorDelete
{
    NSURL *uri = [NSURL URLWithString:
                  [NSString stringWithFormat:@"http://localhost:4035/gotapi/notification/onerror?accessToken=%@&serviceId=%@",
                   self.clientId, self.serviceId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uri];
    [request setHTTPMethod:@"DELETE"];
    
    CHECK_RESPONSE(@"{\"result\":0}", request);
    
}

@end
