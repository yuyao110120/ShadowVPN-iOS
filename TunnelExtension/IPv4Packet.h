//
//  IPv4PacketParse.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPv4Packet : NSObject

- (instancetype)initWithPacketData:(NSData *)data;

@property (nonatomic, readonly) u_int8_t protocol;
@property (nonatomic, readonly) u_int32_t destinationIP;

@property (nonatomic, readonly) NSUInteger headerLength;
@property (nonatomic, readonly) NSUInteger payloadLength;

- (NSData *)payloadData;

- (id)payloadPacket;

@end
