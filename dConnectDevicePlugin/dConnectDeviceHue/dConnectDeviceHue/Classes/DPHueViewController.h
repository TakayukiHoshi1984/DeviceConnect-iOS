//
//  DPHueViewController.h
//  dConnectDeviceHue
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//
/*! @file
 @brief Hue デバイスプラグインの設定画面を表示するためのViewController。
 @author NTT DOCOMO
 @date 作成日(2014.7.15)
 */
#import <UIKit/UIKit.h>
#import "DPHueItemBridge.h"

/*!
 @class DPHueViewController
 @brief Hue デバイスプラグインの設定画面を表示するためのViewController。
 
 UIPageViewControllerのDelegateを持つ。
 */
@interface DPHueViewController : UIViewController <UIPageViewControllerDelegate>

/*!
 @brief 各ページをコントロールするためのクラス。
 */
@property (strong, nonatomic) UIPageViewController *pageViewController;

/*!
 @brief 閉じるボタン。
 */
@property (strong, nonatomic) IBOutlet UIBarButtonItem *closeBtn;

/*!
 @brief 設定画面を閉じるボタンのアクション。
 @param[in] sender UIオブジェクト。
 @return UIアクション。
 */
- (IBAction)closeBtnDidPushed:(id)sender;

/*!
 @brief 指定した画面を表示。
 @param[in] jumpIndex 設定画面のページ。
 @param[in] bridge 現在接続を行なっているブリッジ情報
 */
- (void)showPage:(NSUInteger)jumpIndex bridge:(DPHueItemBridge*)bridge;

@end
