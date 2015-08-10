//
//  SettingModel.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constant.h"
#import <Mantle/Mantle.h>

extern NSString * const SettingsModelErrorDomain;

typedef NS_ENUM(int, RoutingMode) {
    RoutingModeAll = 0,
    RoutingModeChnroute = 1,
    RoutingModeBestroutetb =2
};

@interface SettingsModel : MTLModel

@property (nonatomic, copy) NSString *hostname;
@property (nonatomic) int port;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *clientIP;
@property (nonatomic, copy) NSString *subnetMasks;
@property (nonatomic, copy) NSString *DNS;
@property (nonatomic, copy) NSString *chinaDNS;
@property (nonatomic) int MTU;
@property (nonatomic) RoutingMode routingMode;

+ (instancetype)settingsFromAppGroupContainer;
+ (void)saveSettingsToAppGroupContainer:(SettingsModel *)model;

@end
