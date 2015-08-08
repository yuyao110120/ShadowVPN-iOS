//
//  DNSPacket.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DNSPacket : NSObject

- (instancetype)initWithPacketData:(NSData *)data;

@property (nonatomic, readonly) NSArray *queryDomains;

@end
