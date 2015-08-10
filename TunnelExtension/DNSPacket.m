//
//  DNSPacket.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "DNSPacket.h"

@implementation DNSPacket

- (instancetype)initWithPacketData:(NSData *)data {
    self = [self init];
    if (self) {
        if (data.length < 12) return nil;
        const u_int16_t *bytes = data.bytes;
        
        _identifier = *((u_int16_t *)data.bytes);

        u_int16_t count = ntohs(*(bytes + 2));
        
        NSMutableArray *domains = [NSMutableArray arrayWithCapacity:count];
        
        const char *ptr = (const char *)(bytes + 6);
        const char *endPtr = data.bytes + data.length;

        for (int i = 0; i < count; i++) {
            char domain[256];
            
            int domainLength = 0;
            while (*ptr != 0) {
                u_int8_t len = *ptr;
                ptr++;
                if (ptr + len >= endPtr) return nil;
                stpncpy(domain + domainLength, ptr, len);
                ptr += len;
                domainLength += len;
                domain[domainLength] = '.';
                domainLength++;
            }
            
            ptr += 3;
            if (ptr >= endPtr) return nil;
            
            domain[domainLength - 1] = '\0';
            [domains addObject:@(domain)];
        }
        
        _queryDomains = domains;
        _rawData = data;
    }
    return self;
}

@end
