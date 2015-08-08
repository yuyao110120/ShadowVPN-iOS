//
//  ShadowVPNCrypto.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/6/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ShadowVPNCrypto : NSObject

+ (void)setPassword:(NSString *)password;

+ (NSData *)encryptData:(NSData *)data;
+ (NSData *)decryptData:(NSData *)data;

@end
