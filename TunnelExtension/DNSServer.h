//
//  DNSServer.h
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/10/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DNSServer : NSObject

- (void)setupOutgoingConnectionWithTunnelProvider:(NEPacketTunnelProvider *)provider
                                         chinaDNS:(NSString *)chinaDNS
                                        globalDNS:(NSString *)globalDNS;

- (void)startServer;
- (void)stopServer;

@end
