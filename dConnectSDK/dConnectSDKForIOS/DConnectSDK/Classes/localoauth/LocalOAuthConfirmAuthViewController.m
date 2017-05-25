//
//  LocalOAuthConfirmAuthViewController.m
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "LocalOAuthConfirmAuthViewController.h"
#import "LocalOAuthConfirmAuthParams.h"
#import "LocalOAuthTypedefs.h"
#import "LocalOAuth2Settings.h"

#define SCREEN_BOUNDS   ([UIScreen mainScreen].bounds)

static const int LocalOAuthConfirmAuthViewControllerCellLabelTag = 1;

@interface LocalOAuthConfirmAuthViewController () {

    /** パラメータ */
    LocalOAuthConfirmAuthParams * _confirmAuthParams;
    
    /** 自動テストモードフラグ */
    BOOL _autoTestMode;
    
    /** 承認・拒否コールバック */
    LocalOAuthApprovalCallback _approvalCallback;


    /** 表示用スコープ(ローカライズ文字列) */
    NSArray *_displayScopes;

}

/*!
    秒単位の時間を{日、時間、分、秒}の表記の文字列に変換する.

    @param[in] sec 秒単位の時間
    @return secが0秒以上なら{日、時間、分、秒}
            の表記に変換した時間 / secがマイナス値なら""
 */
- (NSString *) toTimespanString: (long long) sec;

/*!
    自動テストモードのときに承認処理を行うタイマー処理.
    @param[in] timer タイマーオブジェクト
 */
-(void)autoTestProc:(NSTimer*)timer;

@end

@implementation LocalOAuthConfirmAuthViewController

- (void)setParameter: (NSObject *)confirmAuthParams
       displayScopes: (NSArray *)displayScopes
     setAutoTestMode: (BOOL)autoTestMode
    approvalCallback: (LocalOAuthApprovalCallback)approvalCallback {

    /* パラメータを保存する */
    _confirmAuthParams = (LocalOAuthConfirmAuthParams *)confirmAuthParams;
    _displayScopes = displayScopes;
    _autoTestMode = autoTestMode;
    _approvalCallback = approvalCallback;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [UINavigationBar appearance].barTintColor = [UIColor whiteColor];
    [UINavigationBar appearance].tintColor = [UIColor colorWithRed:0.000 green:0.549 blue:0.890 alpha:1.000];
    /* 言語環境(書式)の設定に合わせたフォーマットで日付文字列を取得 */
    NSDate *expirePeriod = [NSDate dateWithTimeIntervalSinceNow:
                            LocalOAuth2Settings_DEFAULT_TOKEN_EXPIRE_PERIOD];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterNoStyle;
    NSString *formattedDateString = [dateFormatter stringFromDate: expirePeriod];
    
    NSBundle *bundle = DCBundle();
    NSString *strExpirePeriod = [NSString
                                    stringWithFormat:DCLocalizedString(bundle,
                                                @"token_default_expiration_date"),
                                                    formattedDateString];
    
    [_labelApplicationName setText: [_confirmAuthParams applicationName]];
    [_labelExpirePeriod setText:strExpirePeriod];

    _tableScopeView.delegate = self;
    _tableScopeView.dataSource = self;
    _tableScopeView.allowsSelection = NO;
    
    /* 自動テストモードの場合は、タイマーを開始する */
    if (_autoTestMode) {
        [NSTimer
         scheduledTimerWithTimeInterval:3.0f    /* 3秒後 */
         target:self
         selector:@selector(autoTestProc:)
         userInfo:nil
         repeats:NO        /* 繰り返しフラグ */
         ];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationController.view.layer.cornerRadius = 10;
        self.navigationController.view.superview.backgroundColor = [UIColor clearColor];
        self.view.superview.layer.cornerRadius = 10;
        self.view.superview.backgroundColor = [UIColor clearColor];
    }
}

/**
 * 承認ボタン押下
 */
- (IBAction)touchUpApprovalButton:(id)sender {
    
    /* 承認された */
    _approvalCallback(true);
}

/**
 * テーブルの行数
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [_displayScopes count] ;
}

/**
 * 行に表示するデータ
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"cell";
    
    NSString *displayScope = _displayScopes[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    UILabel *label = (UILabel *)[cell viewWithTag:LocalOAuthConfirmAuthViewControllerCellLabelTag];
    label.text = displayScope;

    return cell;
}

- (NSString *) toTimespanString: (long long) sec {
    long long secOfDay = sec / DAY;
    sec -= secOfDay * DAY;
    long long secOfHour = sec / HOUR;
    sec -= secOfHour * HOUR;
    long long minute = sec / MINUTE;
    sec -= minute * MINUTE;
    
    NSNumber *numOfDay = [NSNumber numberWithLongLong:secOfDay];
    NSNumber *numOfHour = [NSNumber numberWithLongLong:secOfHour];
    NSNumber *numOfMinute = [NSNumber numberWithLongLong:minute];
    NSNumber *numOfSec = [NSNumber numberWithLongLong:sec];
    
    NSMutableString *expiredTime = [NSMutableString string];
    if (secOfDay > 0) {
        [expiredTime appendString: [numOfDay stringValue]];
        [expiredTime appendString: @"日"];
    }
    if (secOfHour > 0) {
        [expiredTime appendString: [numOfHour stringValue]];
        [expiredTime appendString: @"時間"];
    }
    if (minute > 0) {
        [expiredTime appendString: [numOfMinute stringValue]];
        [expiredTime appendString: @"分"];
    }
    if (sec > 0 || (expiredTime == nil && sec == 0)) {
        [expiredTime appendString: [numOfSec stringValue]];
        [expiredTime appendString: @"秒"];
    }
    return expiredTime;
}

-(void)autoTestProc:(NSTimer*)timer{
    
    /* 承認された */
    _approvalCallback(YES);
}

- (IBAction)cancelDidClicked:(id)sender {
    _approvalCallback(NO);
    if ([self isBeingDismissed]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
