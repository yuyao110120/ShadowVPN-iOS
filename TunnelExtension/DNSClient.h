//
//  DNSClient.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DNSClient : NSObject

- (instancetype)initWithDNSServerAddress:(NSString *)address tunnelProvider:(NEPacketTunnelProvider *)tunnelProvider;

- (void)queryWithPayload:(NSData *)payload;

@end
