//
//  ViewController.m
//  Tunnel
//
//  Created by blankwonder on 7/16/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "ViewController.h"

@import NetworkExtension;

@interface ViewController () {
    NETunnelProviderManager *_manager;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * managers, NSError * error) {
        NSLog(@"Error: %@", error);
        NSLog(@"%@", managers);
        
        if (managers.count > 0) {
            _manager = managers[0];
        } else {
            _manager = [[NETunnelProviderManager alloc] init];
        }
    }];
}

- (void)setup {
    NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
    protocol.serverAddress = @"203.66.65.7:1123";
    protocol.username = @"BLANKWONDER";
    _manager.protocolConfiguration = protocol;
    _manager.enabled = YES;
    _manager.onDemandEnabled = NO;
    
    [_manager saveToPreferencesWithCompletionHandler:^(NSError * __nullable error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)start {
    NSError *error = nil;
    if (![_manager.connection startVPNTunnelWithOptions:nil andReturnError:&error]) {
        NSLog(@"Start error: %@", error);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
