//
//  PacketTunnelProvider.m
//  Tunnel
//
//  Created by blankwonder on 7/16/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "PacketTunnelProvider.h"

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>

#include <sys/select.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/ip.h>
#include <sys/uio.h>

#import "crypto.h"

#define SHADOWVPN_ZERO_BYTES 32
#define SHADOWVPN_OVERHEAD_LEN 24
#define SHADOWVPN_PACKET_OFFSET 8
#define SHADOWVPN_MTU 1440

@implementation PacketTunnelProvider {
    NWUDPSession *_UDPSession;
    
    void (^_startCompletionHandler)(NSError * __nullable error);
}

- (void)startTunnelWithOptions:(nullable NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * __nullable error))completionHandler {
    const char *password = self.protocolConfiguration.username.UTF8String;
    
    crypto_init();
    crypto_set_password(password, strlen(password));
    
    NSArray *host = [self.protocolConfiguration.serverAddress componentsSeparatedByString:@":"];
    
    NWHostEndpoint *endpoint = [NWHostEndpoint endpointWithHostname:host[0] port:host[1]];
    
    _UDPSession = [self createUDPSessionToEndpoint:endpoint fromEndpoint:nil];
    
    [_UDPSession addObserver:self
                  forKeyPath:@"state"
                     options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial
                     context:NULL];
    
    [_UDPSession setReadHandler:^(NSArray<NSData *> *datagrams, NSError *error) {
        NSLog(@"Received UDP packet");
        if (error) {
            NSLog(@"Error when UDP session read: %@", error);
        } else {
            [self processUDPIncomingDatagrams:datagrams];
        }
    } maxDatagrams:NSUIntegerMax];
    
    _startCompletionHandler = completionHandler;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *,id> *)change
                       context:(nullable void *)context {
    if (object == _UDPSession) {
        NSLog(@"KVO %@: %@", keyPath, change[NSKeyValueChangeNewKey]);
        
        if ([keyPath isEqualToString:@"state"] && _UDPSession.state == NWUDPSessionStateReady) {
            
            NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"203.66.65.7"];
            
            settings.IPv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.7.0.2"]
                                                                  subnetMasks:@[@"255.255.255.0"]];
            
            settings.IPv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
            settings.DNSSettings = [[NEDNSSettings alloc] initWithServers:@[@"8.8.8.8"]];
            
            settings.MTU = @(SHADOWVPN_MTU);
            
            [self setTunnelNetworkSettings:settings completionHandler:^(NSError * __nullable error) {
                NSLog(@"Error when setTunnelNetworkSettings: %@", error);
                
                _startCompletionHandler(nil);
                _startCompletionHandler = nil;
                
                [self readTun];
            }];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)readTun {
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * __nonnull packets, NSArray<NSNumber *> * __nonnull protocols) {
        
        [packets enumerateObjectsUsingBlock:^(NSData * data, NSUInteger idx, BOOL * stop) {
            int p = [protocols[idx] intValue];
            if (p != AF_INET) return;
            const char *bytes = data.bytes;
            char type = *(bytes + 9);
            
            NSLog(@"Tun incoming data: %x", type);
            
            NSData *encryptedData = [self encryptOutgoingPacket:data];
            NSLog(@"Encrypt %lu --> %lu", (unsigned long)data.length, (unsigned long)encryptedData.length);
            
            [_UDPSession writeDatagram:encryptedData completionHandler:^(NSError * __nullable error) {
                if (error) NSLog(@"Write UDP error: %@", error);
            }];
        }];
    
        [self readTun];
    }];
}

- (void)processUDPIncomingDatagrams:(NSArray *)datagrams {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:datagrams.count];
    NSMutableArray *protocols = [NSMutableArray arrayWithCapacity:datagrams.count];
    
    for (NSData *data in datagrams) {
        NSData *decryptedData = [self decryptIncomingPacket:data];
        [result addObject:decryptedData];
        
        NSLog(@"Decrypt %lu --> %lu", (unsigned long)data.length, (unsigned long)decryptedData.length);
        
        [protocols addObject:@(AF_INET)];
    }
    
    [self.packetFlow writePackets:result withProtocols:protocols];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    NSLog(@"NEProviderStopReason: %ld", (long)reason);
    completionHandler();
}

- (void)cancelTunnelWithError:(nullable NSError *)error {
    NSLog(@"cancelTunnelWithError: %@", error);
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(nullable void (^)(NSData * __nullable responseData))completionHandler {
    NSLog(@"handleAppMessage: %@", messageData);
}

static unsigned char *inBuffer;
static unsigned char *outBuffer;

static void initBuffer() {
    if (!inBuffer) {
        inBuffer = malloc(4000);
        outBuffer = malloc(4000);
    }
}

- (NSData *)encryptOutgoingPacket:(NSData *)data {
    initBuffer();
    memcpy(inBuffer + SHADOWVPN_ZERO_BYTES, data.bytes, data.length);

    int result = crypto_encrypt(outBuffer, inBuffer, data.length);
    if (result != 0) return nil;
    
    NSData *resultData = [NSData dataWithBytes:outBuffer + SHADOWVPN_PACKET_OFFSET length:SHADOWVPN_OVERHEAD_LEN + data.length];
    
    return resultData;
}

- (NSData *)decryptIncomingPacket:(NSData *)data {
    initBuffer();
    memcpy(inBuffer + SHADOWVPN_PACKET_OFFSET, data.bytes, data.length);
    
    crypto_decrypt(outBuffer, inBuffer, data.length - SHADOWVPN_OVERHEAD_LEN);
    
    NSData *resultData =  [NSData dataWithBytes:outBuffer + SHADOWVPN_ZERO_BYTES length:data.length - SHADOWVPN_OVERHEAD_LEN];
    
    return resultData;
}



@end
