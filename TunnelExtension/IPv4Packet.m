//
//  IPv4PacketParse.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "IPv4Packet.h"
#import "UDPPacket.h"
#import "KDLogger.h"

@implementation IPv4Packet {
    NSData *_rawData;
}

- (instancetype)initWithPacketData:(NSData *)data {
    self = [self init];
    if (self) {
        if (data.length < 20) return nil;
        _rawData = data;
        
        const char *bytes = data.bytes;
        
        _protocol = *((u_int8_t *)(bytes + 9));
        _destinationIP = *((u_int32_t *)(bytes + 16));
        
        _headerLength = ((*(u_int8_t *)bytes) & 0x0F) * 4;
    }
    return self;
}

- (NSData *)payloadData {
    return [_rawData subdataWithRange:NSMakeRange(_headerLength, _rawData.length - _headerLength)];
}

- (id)payloadPacket {
    if (_protocol == 0x11) {
        return [[UDPPacket alloc] initWithPacketData:[self payloadData]];
    } else {
        return nil;
    }
}

@end
