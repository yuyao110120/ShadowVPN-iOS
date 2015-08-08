//
//  SettingModel.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "SettingsModel.h"
#import "KDLogger.h"

#define kConfigurationKey @"Configuration"

#define kConfigurationAllKeyArray @[kConfigurationKeyHostname, kConfigurationKeyPort, kConfigurationKeyPassword, kConfigurationKeyClientIP, kConfigurationKeySubnetMasks, kConfigurationKeyDNS, kConfigurationKeyMTU, kConfigurationKeyRoutingMode]


@implementation SettingsModel

+ (instancetype)settingsFromAppGroupContainer {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupIdentifier];
    
    NSDictionary *config = [sharedDefaults objectForKey:kConfigurationKey];
    if (!config) return nil;
    
    NSError *error;
    SettingsModel *model = [SettingsModel modelWithDictionary:config error:&error];
    if (error) {
        KDClassLog(@"Configuration parse error: %@, %@", error, config);
    }
    
    return model;
}

+ (void)saveSettingsToAppGroupContainer:(SettingsModel *)model {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupIdentifier];
    [sharedDefaults setObject:model.dictionaryValue forKey:kConfigurationKey];
    [sharedDefaults synchronize];
}


@end
