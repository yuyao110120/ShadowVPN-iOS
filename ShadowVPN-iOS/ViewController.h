//
//  ViewController.h
//  Tunnel
//
//  Created by blankwonder on 7/16/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KDEasyTouchButton.h"

@interface ViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    IBOutlet UITableView *_tableView;
    IBOutlet UITableViewCell *_connectCell;
    IBOutlet KDEasyTouchButton *_connectButton;
}

- (IBAction)connect;

@end

