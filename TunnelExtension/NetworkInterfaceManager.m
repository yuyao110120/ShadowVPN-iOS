//
//  KDNetworkInterfaceManager.m
//  Netpas
//
//  Created by Blankwonder on 4/23/15.
//  Copyright (c) 2015 Blankwonder. All rights reserved.
//

#import "NetworkInterfaceManager.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

NSString * const NetworkInterfaceManagerInterfaceDidChange = @"NetworkInterfaceManagerInterfaceDidChange";

@implementation NetworkInterfaceManager {
}

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    __strong static id sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {}
    return self;
}

- (void)updateInterfaceInfo {
    BOOL previousWWAN = _WWANValid;
    BOOL previousWiFi = _WiFiValid;

    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        for( struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            BOOL up = NO;
            
            if (addr->sin_family == AF_INET) {
                if ((interface->ifa_flags & IFF_UP) != 0) {
                    char addrBuf[INET_ADDRSTRLEN];
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        up = [self isValidIPAddress:[NSString stringWithUTF8String:addrBuf]];
                    }
                }
            }
            
            if (strcmp(interface->ifa_name, "en0") == 0) {
                _WiFiValid = up;
            } else if (strcmp(interface->ifa_name, "pdp_ip0") == 0) {
                _WWANValid = up;
            }
        }
        
        freeifaddrs(interfaces);
    }
    
    if (_monitoring && (_WiFiValid != previousWiFi || _WWANValid != previousWWAN)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkInterfaceManagerInterfaceDidChange object:self];
        _monitoring = NO;
    }
}

- (BOOL)isValidIPAddress:(NSString *)IPAddress {
    if (IPAddress.length == 0) return NO;
    if ([IPAddress isEqual:@"0.0.0.0"]) return NO;
    if ([IPAddress hasPrefix:@"169.254"]) return NO;
    
    return YES;
}

- (void)monitorInterfaceChange {
    _monitoring = YES;
}

@end