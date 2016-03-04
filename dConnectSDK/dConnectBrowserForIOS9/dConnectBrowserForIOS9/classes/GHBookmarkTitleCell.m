//
//  GHBookmarkTitleCell.m
//  dConnectBrowserForIOS9
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "GHBookmarkTitleCell.h"

@implementation GHBookmarkTitleCell

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)setItem:(GHPageModel*)page
{
    self.titleField.text = page.title;
    self.urlField.text = page.url;
}
@end
