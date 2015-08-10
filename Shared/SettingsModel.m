//
//  SettingModel.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "SettingsModel.h"
#import "KDLogger.h"
#import "KDUtilities.h"
#import <arpa/inet.h>

NSString * const SettingsModelErrorDomain = @"SettingsModelErrorDomain";

#define kConfigurationKey @"Configuration"

BOOL IsStringValidIPAddress(NSString *IPAddress) {
    if (!KDUtilIsStringValid(IPAddress)) return NO;
    struct in_addr pin;
    int success = inet_aton([IPAddress UTF8String], &pin);
    if (success == 1) return TRUE;
    return NO;
}

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

- (BOOL)validateValue:(inout id __nullable * __nonnull)ioValue forKey:(NSString *)inKey error:(out NSError **)outError {    
    void (^setError)() = ^{
        *outError = [NSError errorWithDomain:SettingsModelErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid value for key: %@", inKey]}];
    };

    
    if ([@[@"clientIP", @"subnetMasks", @"DNS"] containsObject:inKey]) {
        id str = *ioValue;
        if (IsStringValidIPAddress(str)) {
            return YES;
        } else {
            setError();
            return NO;
        }
    } else if ([inKey isEqualToString:@"hostname"] || [inKey isEqualToString:@"password"]) {
        id str = *ioValue;
        if (KDUtilIsStringValid(str)) {
            return YES;
        } else {
            setError();
            return NO;
        }
    } else if ([inKey isEqualToString:@"port"] || [inKey isEqualToString:@"MTU"]) {
        NSNumber *val = *ioValue;
        if (val.intValue > 0) {
            return YES;
        } else {
            setError();
            return NO;
        }
    } else if ([inKey isEqualToString:@"chinaDNS"]) {
        NSString *str = *ioValue;
        if (str.length == 0) return YES;
        if (IsStringValidIPAddress(str)) {
            return YES;
        } else {
            setError();
            return NO;
        }
    } else {
        return YES;
    }
}

@end
