//
//  ViewController.m
//  Tunnel
//
//  Created by blankwonder on 7/16/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "ViewController.h"
#import "Constant.h"
#import "KDSelectionViewController.h"
#import "KDUtilities.h"
#import "LoggerViewController.h"
#import "SettingsModel.h"
#import "KDLogger.h"

#define kRoutingModeTitles @[@"All", @"chnroute", @"bestroutetb"]

@import NetworkExtension;

@interface ViewController () <UITextFieldDelegate>{
    NETunnelProviderManager *_manager;
    NSArray *_cells, *_textFields;
    NSArray *_textFieldCells;
    
    UITableViewCell *_routingCell;
    
    BOOL _editing;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _connectButton.adjustAllRectWhenHighlighted = YES;
    self.title = @"ShadowVPN";
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [button addTarget:self action:@selector(showLogViewController) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    
    NSMutableArray *textFields = [NSMutableArray array];
    UITableViewCell *(^newCell)(NSString *title) = ^UITableViewCell *(NSString *title) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = title;
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(140, 0, [UIScreen mainScreen].bounds.size.width - 140, 44)];
        [cell.contentView addSubview:textField];
        [textFields addObject:textField];
        
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        
        textField.delegate = self;
        
        return cell;
    };
    
    SettingsModel *settings = [SettingsModel settingsFromAppGroupContainer];
    
    _routingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _routingCell.textLabel.text = @"Routing";
    _routingCell.detailTextLabel.text = kRoutingModeTitles[settings.routingMode];
    
    _textFieldCells = @[@[newCell(@"Host"), newCell(@"Port"), newCell(@"Password")],
                        @[newCell(@"Client IP"), newCell(@"Subnet Masks"), newCell(@"DNS"), newCell(@"MTU")],
                        @[_routingCell]];
    _textFields = textFields;
    
    [textFields[0] setPlaceholder:@"Domain or IP Address"];
    [textFields[1] setPlaceholder:@"Port"];
    [textFields[2] setPlaceholder:@"Password"];
    [textFields[3] setPlaceholder:@"Default: 10.7.0.2"];
    [textFields[4] setPlaceholder:@"Default: 255.255.255.0"];
    [textFields[5] setPlaceholder:@"DNS Server Address"];
    [textFields[6] setPlaceholder:@"Default: 1400"];
    
    [textFields[1] setKeyboardType:UIKeyboardTypeNumberPad];
    [textFields[3] setKeyboardType:UIKeyboardTypeDecimalPad];
    [textFields[4] setKeyboardType:UIKeyboardTypeDecimalPad];
    [textFields[5] setKeyboardType:UIKeyboardTypeDecimalPad];
    [textFields[6] setKeyboardType:UIKeyboardTypeNumberPad];
    
    if (settings) {
        [textFields[0] setText:settings.hostname];
        [textFields[1] setText:[NSString stringWithFormat:@"%u", settings.port]];
        [textFields[2] setText:settings.password];
        [textFields[3] setText:settings.clientIP];
        [textFields[4] setText:settings.subnetMasks];
        [textFields[5] setText:settings.DNS];
        [textFields[6] setText:[NSString stringWithFormat:@"%u", settings.MTU]];
    }
    
    self.editing = ![self isTextFieldsAllCompleted];
    
    if ([textFields[3] text].length == 0) {
        [textFields[3] setText:@"10.7.0.2"];
    }
    if ([textFields[4] text].length == 0) {
        [textFields[4] setText:@"255.255.255.0"];
    }
    if ([textFields[5] text].length == 0) {
        [textFields[5] setText:@"8.8.8.8"];
    }
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * managers, NSError * error) {
        if (managers.count > 0) {
            _manager = managers[0];
        } else {
            _manager = [[NETunnelProviderManager alloc] init];
        }
        
        [self applicationDidBecomeActive];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldTextDidChange)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(VPNManagerStatusChanged)
                                                 name:NEVPNStatusDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

KDUtilRemoveNotificationCenterObserverDealloc

- (BOOL)isTextFieldsAllCompleted {
    for (UITextField *textFiled in _textFields) {
        if (textFiled.text.length == 0) {
            return NO;
        }
    }
    return YES;
}

- (void)setEditing:(BOOL)editing {
    _editing = editing;
    
    for (UITextField *textFiled in _textFields) {
        textFiled.enabled = _editing;
    }

    if (editing) {
        _cells = _textFieldCells;
        _routingCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editingDone)];
        [self textFieldTextDidChange];
    } else {
        NSMutableArray *cells = [NSMutableArray arrayWithArray:_textFieldCells];
        [cells addObject:@[_connectCell]];
        _cells = cells;
        _routingCell.accessoryType = UITableViewCellAccessoryNone;

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(startEditing)];
    }
    
    [_tableView reloadData];
}

- (void)textFieldTextDidChange {
    self.navigationItem.rightBarButtonItem.enabled = [self isTextFieldsAllCompleted];
}

- (void)startEditing {
    [self setEditing:YES];
    [_textFields.firstObject becomeFirstResponder];
}

- (void)editingDone {
    BOOL completed = [self isTextFieldsAllCompleted];

    if (completed) {
        [self setEditing:NO];
        
        SettingsModel *settings = [SettingsModel settingsFromAppGroupContainer];
        
        settings.hostname = [_textFields[0] text];
        settings.port =  [[_textFields[1] text] intValue];
        settings.password = [_textFields[2] text];
        settings.clientIP = [_textFields[3] text];
        settings.subnetMasks = [_textFields[4] text];
        settings.DNS = [_textFields[5] text];
        settings.MTU = [[_textFields[6] text] intValue];
        settings.routingMode = (int)[kRoutingModeTitles indexOfObject:_routingCell.detailTextLabel.text];
    
        [SettingsModel saveSettingsToAppGroupContainer:settings];
        
        KDClassLog(@"New settings saved: %@", settings.dictionaryValue);
    }
}

- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView {
    return _cells.count;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_cells[section] count];
}

- (UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return _cells[indexPath.section][indexPath.row];
}

- (void)VPNManagerStatusChanged {
    NSLog(@"VPNManagerStatusChanged: %ld", (long)_manager.connection.status);
    switch (_manager.connection.status) {
        case NEVPNStatusInvalid:
            break;
        case NEVPNStatusDisconnected:
            _connectButton.enabled = YES;
            [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
            break;
        case NEVPNStatusDisconnecting:
            _connectButton.enabled = NO;
            break;
        case NEVPNStatusConnecting:
            _connectButton.enabled = NO;
            break;
        case NEVPNStatusReasserting:
            _connectButton.enabled = NO;
            break;
        case NEVPNStatusConnected:
            _connectButton.enabled = YES;
            [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
            break;
    }
    
}

- (void)connect {
    if (_manager.connection.status == NEVPNStatusDisconnected ||_manager.connection.status == NEVPNStatusInvalid) {
        NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
        protocol.serverAddress = [_textFields[0] text];
        _manager.protocolConfiguration = protocol;
        _manager.enabled = YES;
        _manager.onDemandEnabled = NO;
        
        [_manager saveToPreferencesWithCompletionHandler:^(NSError * __nullable error) {
            if (error) {
                NSLog(@"Error when saveToPreferencesWithCompletionHandler: %@", error);
                return;
            }
            NSError *startError = nil;
            if (![_manager.connection startVPNTunnelWithOptions:nil andReturnError:&startError]) {
                NSLog(@"Start error: %@", startError);
            }
        }];
    } else {
        [_manager.connection stopVPNTunnel];
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell == _connectCell) return YES;
    if (cell == _routingCell && _editing) return YES;
    return NO;
}

- (void)tableView:(nonnull UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell == _connectCell) {
        [self connect];
    } else if (cell == _routingCell && _editing) {
        KDSelectionViewController *vc = [[KDSelectionViewController alloc] initWithOptions:kRoutingModeTitles];
        vc.title = @"Routing";
        [vc setCompletionHandler:^(NSString *title, NSInteger idx) {
            _routingCell.detailTextLabel.text = title;
            [self.navigationController popViewControllerAnimated:YES];
        }];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)keyboardWillShow:(NSNotification *)aNotification {
    [self moveTextViewForKeyboard:aNotification up:YES];
}

- (void)keyboardWillHide:(NSNotification *)aNotification {
    [self moveTextViewForKeyboard:aNotification up:NO];
}

- (void) moveTextViewForKeyboard:(NSNotification*)aNotification up: (BOOL) up {
    NSDictionary* userInfo = [aNotification userInfo];
    
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardEndFrame;
    
    [userInfo[UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [userInfo[UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [userInfo[UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    
    UIEdgeInsets insets = _tableView.contentInset;
    if (up) {
        insets.bottom = keyboardEndFrame.size.height;
    } else {
        insets.bottom = 0;
    }
    _tableView.contentInset = insets;
    
    [self.view layoutIfNeeded];
    
    [UIView commitAnimations];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)applicationDidBecomeActive {
    [_manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        [self VPNManagerStatusChanged];
    }];
}

- (void)showLogViewController {
    LoggerViewController *vc = [[LoggerViewController alloc] init];
    UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nvc animated:YES completion:^{}];
}

@end
