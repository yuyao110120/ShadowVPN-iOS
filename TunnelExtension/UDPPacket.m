//
//  UDPPacket.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "UDPPacket.h"

@implementation UDPPacket{
    NSData *_rawData;
}

- (instancetype)initWithPacketData:(NSData *)data {
    self = [self init];
    if (self) {
        _rawData = data;
        const u_int16_t *bytes = data.bytes;
        
        _sourcePort = ntohs(*bytes);
        _destinationPort = ntohs(*(bytes + 1));
    }
    return self;
}

- (NSData *)payloadData {
    return [_rawData subdataWithRange:NSMakeRange(8, _rawData.length - 8)];
}

@end
