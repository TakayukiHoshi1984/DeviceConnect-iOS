//
//  DeviceIconViewCell.h
//  dConnectBrowserForIOS9
//
//  Created by Tetsuya Hirano on 2016/07/01.
//  Copyright © 2016年 GClue,Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DeviceIconViewModel.h"

@interface DeviceIconViewCell : UICollectionViewCell
typedef void (^DidDeviceIconSelected)(DConnectMessage*);

@property (weak, nonatomic) IBOutlet UIImageView *iconImage;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;
@property (strong, nonatomic) DeviceIconViewModel *viewModel;
@property (copy, nonatomic) DidDeviceIconSelected didIconSelected;

- (void)setDevice:(DConnectMessage*)message;
- (void)setEnabled:(BOOL)isEnabled;
@end
