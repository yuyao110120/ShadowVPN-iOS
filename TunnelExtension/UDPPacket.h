//
//  UDPPacket.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UDPPacket : NSObject

- (instancetype)initWithPacketData:(NSData *)data;

@property (nonatomic, readonly) u_int16_t sourcePort;
@property (nonatomic, readonly) u_int16_t destinationPort;

- (NSData *)payloadData;

@end
