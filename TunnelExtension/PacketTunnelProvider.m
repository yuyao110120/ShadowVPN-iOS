//
//  PacketTunnelProvider.m
//  Tunnel
//
//  Created by blankwonder on 7/16/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "PacketTunnelProvider.h"
#import "ShadowVPNCrypto.h"
#import "IPv4Packet.h"
#import "UDPPacket.h"
#import "DNSPacket.h"
#import "SettingsModel.h"

static NSString * const kShadowVPNTunnelProviderErrorDomain = @"kShadowVPNTunnelProviderErrorDomain";

@implementation PacketTunnelProvider {
    NWUDPSession *_UDPSession;
    NSUserDefaults *_sharedDefaults;
    
    NSString *_hostIPAddress;
    NSMutableArray *_outgoingBuffer;
    
    dispatch_queue_t _dispatchQueue;
    SettingsModel *_settings;
}

- (void)startTunnelWithOptions:(nullable NSDictionary<NSString *,NSObject *> *)options
             completionHandler:(void (^)(NSError * __nullable error))completionHandler {
    NSString *groupContainerPath = [[NSFileManager defaultManager]
                                    containerURLForSecurityApplicationGroupIdentifier:
                                    kAppGroupIdentifier].path;
    KDLoggerSetLogFilePath([groupContainerPath stringByAppendingPathComponent:@"log.txt"]);
    KDLoggerInstallUncaughtExceptionHandler();
    
    KDClassLog(@"Starting tunnel...");
    _outgoingBuffer = [NSMutableArray arrayWithCapacity:100];
    _dispatchQueue = dispatch_queue_create("manager", NULL);
    
    dispatch_async(_dispatchQueue, ^{
        [self addObserver:self
                      forKeyPath:@"defaultPath"
                         options:0
                         context:NULL];
        
        _settings = [SettingsModel settingsFromAppGroupContainer];
        KDClassLog(@"Settings: %@", _settings.dictionaryValue);

        [ShadowVPNCrypto setPassword:_settings.password];
        
        NSArray *result = [[self class] dnsResolveWithHost:_settings.hostname];
        if (result.count == 0) {
            NSError *error = [NSError errorWithDomain:kShadowVPNTunnelProviderErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"DNS failed!"}];
            completionHandler(error);
            return;
        }
        _hostIPAddress = result.firstObject;
        KDClassLog(@"Server DNS Result: %@", _hostIPAddress);
        
        NEPacketTunnelNetworkSettings *settings = [self prepareTunnelNetworkSettings];
        
        KDUtilDefineWeakSelfRef
        [self setTunnelNetworkSettings:settings completionHandler:^(NSError * __nullable error) {
            if (error)  {
                KDLog(NSStringFromClass([weakSelf class]), @"Error occurred while setTunnelNetworkSettings: %@", error);
                completionHandler(error);
            } else {
                completionHandler(nil);
                [weakSelf setupUDPSession];
                [weakSelf readTun];
            }
        }];
    });
}

- (NEPacketTunnelNetworkSettings *)prepareTunnelNetworkSettings {
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:_hostIPAddress];
    settings.IPv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[_settings.clientIP]
                                                          subnetMasks:@[_settings.subnetMasks]];
    
    RoutingMode routingMode = _settings.routingMode;
    if (routingMode == RoutingModeChnroute) {
        [self setupChnroute:settings.IPv4Settings];
    } else if (routingMode == RoutingModeBestroutetb) {
        [self setupBestroutetb:settings.IPv4Settings];
    } else {
        settings.IPv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    }
    
    settings.DNSSettings = [[NEDNSSettings alloc] initWithServers:@[_settings.DNS]];
    settings.MTU = @(_settings.MTU);

    return settings;
}

- (void)setupUDPSession {
    dispatch_async(_dispatchQueue, ^{
        if (_UDPSession) return;
        KDClassLog(@"Creating UDP Session...");
        NWHostEndpoint *endpoint = [NWHostEndpoint endpointWithHostname:_hostIPAddress
                                                                   port:[NSString stringWithFormat:@"%u", _settings.port]];
        
        _UDPSession = [self createUDPSessionToEndpoint:endpoint fromEndpoint:nil];
        
        [_UDPSession addObserver:self
                      forKeyPath:@"state"
                         options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial
                         context:NULL];
        
        KDUtilDefineWeakSelfRef
        [_UDPSession setReadHandler:^(NSArray<NSData *> *datagrams, NSError *error) {
            if (error) {
                KDLog(NSStringFromClass([weakSelf class]), @"Error when UDP session read: %@", error);
            } else {
                [weakSelf processUDPIncomingDatagrams:datagrams];
            }
        } maxDatagrams:NSUIntegerMax];
    });
}

- (void)releaseUDPSession {
    KDClassLog(@"releaseUDPSession");
    dispatch_async(_dispatchQueue, ^{
        [_UDPSession removeObserver:self forKeyPath:@"state"];
        _UDPSession = nil;
    });
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *,id> *)change
                       context:(nullable void *)context {
    if (object == _UDPSession && [keyPath isEqualToString:@"state"]) {
        KDClassLog(@"UDP Session state changed: %d", (int)_UDPSession.state);
        if (_UDPSession.state == NWUDPSessionStateReady) {
            [self processOutgoingBuffer];
        } else if (_UDPSession.state == NWUDPSessionStateFailed || _UDPSession.state == NWUDPSessionStateCancelled)  {
            [self releaseUDPSession];
        }
    } else if (object == self && [keyPath isEqualToString:@"defaultPath"]) {
        KDClassLog(@"KVO defaultPath: %@", self.defaultPath);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)processOutgoingBuffer {
    dispatch_async(_dispatchQueue, ^{
        if (!_UDPSession) {
            [self setupUDPSession];
            return;
        }
        if (_UDPSession.state != NWUDPSessionStateReady) {
            return;
        }
        
        NSArray *datas;
        @synchronized(_outgoingBuffer) {
            if (_outgoingBuffer.count == 0) return;
            datas = [_outgoingBuffer copy];
            [_outgoingBuffer removeAllObjects];
        }
        
        [_UDPSession writeMultipleDatagrams:datas completionHandler:^(NSError * _Nullable error) {
            if (error){
                KDClassLog(@"Write UDP error: %@", error);
                @synchronized(_outgoingBuffer) {
                    [_outgoingBuffer addObjectsFromArray:datas];
                }
                [self releaseUDPSession];
                [self setupUDPSession];
            }
        }];
    });
}

- (void)readTun {
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * __nonnull packets, NSArray<NSNumber *> * __nonnull protocols) {
        
        NSMutableArray *datas = [NSMutableArray arrayWithCapacity:packets.count];
        [packets enumerateObjectsUsingBlock:^(NSData * data, NSUInteger idx, BOOL * stop) {
            if ([protocols[idx] intValue] != AF_INET) return;
            
            IPv4Packet *packet = [[IPv4Packet alloc] initWithPacketData:data];
            
            UDPPacket *udp = packet.payloadPacket;
            if (udp && udp.destinationPort == 53) {
                DNSPacket *dns = [[DNSPacket alloc] initWithPacketData:udp.payloadData];
                
                KDClassLog(@"DNS Query: %@", dns.queryDomains);
            }
            
//            struct in_addr ip_addr;
//            ip_addr.s_addr = packet.destinationIP;
//            KDClassLog(@"Protocol: %X --> %s", packet.protocol, inet_ntoa(ip_addr));
            
            NSData *encryptedData = [ShadowVPNCrypto encryptData:data];
            if (!encryptedData) {
                KDClassLog(@"Encrypt failed: %@", data);
                return;
            }
            
            [datas addObject:encryptedData];

        }];
        [self readTun];
        
        dispatch_async(_dispatchQueue, ^{
            [_outgoingBuffer addObjectsFromArray:datas];
            [self processOutgoingBuffer];
        });
    }];
}

- (void)processUDPIncomingDatagrams:(NSArray *)datagrams {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:datagrams.count];
    NSMutableArray *protocols = [NSMutableArray arrayWithCapacity:datagrams.count];
    
    for (NSData *data in datagrams) {
        NSData *decryptedData = [ShadowVPNCrypto decryptData:data];
        if (!decryptedData) {
            KDClassLog(@"Decrypt failed! Data length: %lu", (unsigned long)data.length);
            KDClassLog(@"%@", [data base64EncodedStringWithOptions:0]);
            return;
        }
        
        [result addObject:decryptedData];
        [protocols addObject:@(AF_INET)];
    }
    
    [self.packetFlow writePackets:result withProtocols:protocols];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    KDClassLog(@"NEProviderStopReason: %ld", (long)reason);
    completionHandler();
}

- (void)cancelTunnelWithError:(nullable NSError *)error {
    KDClassLog(@"cancelTunnelWithError: %@", error);
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(nullable void (^)(NSData * __nullable responseData))completionHandler {
    KDClassLog(@"handleAppMessage: %@", messageData);
    completionHandler(nil);
}

+ (NSArray *)dnsResolveWithHost:(NSString *)host {
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)host);
    Boolean result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL);
    if (result) {
        CFArrayRef addresses = CFHostGetAddressing(hostRef, &result);
        
        NSMutableArray *resultArray = [[NSMutableArray alloc] init];
        for(int i = 0; i < CFArrayGetCount(addresses); i++){
            CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addresses, i);
            struct sockaddr_in *remoteAddr = (struct sockaddr_in*)CFDataGetBytePtr(saData);
            
            if (remoteAddr != NULL){
                NSString *str =[NSString stringWithCString:inet_ntoa(remoteAddr->sin_addr) encoding:NSASCIIStringEncoding];
                [resultArray addObject:str];
            }
        }
        CFRelease(hostRef);
        return resultArray;
    } else {
        CFRelease(hostRef);
        return nil;
    }
}

- (void)setupChnroute:(NEIPv4Settings *)settings {
    NSString *data = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"chnroutes" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableArray *routes = [NSMutableArray array];
    [data enumerateLinesUsingBlock:^(NSString * line, BOOL * stop) {
        NSArray *comps = [line componentsSeparatedByString:@" "];
        NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:comps[0] subnetMask:comps[1]];
        [routes addObject:route];
    }];
    
    KDClassLog(@"chnroute: %lu", (unsigned long)routes.count);
    
    settings.excludedRoutes = routes;
    settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
}

- (void)setupBestroutetb:(NEIPv4Settings *)settings {
    NSString *data = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"bestroutetb" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableArray *excludedRoutes = [NSMutableArray array];
    NSMutableArray *includedRoutes = [NSMutableArray array];

    [data enumerateLinesUsingBlock:^(NSString * line, BOOL * stop) {
        NSArray *comps = [line componentsSeparatedByString:@" "];
        NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:comps[0] subnetMask:comps[1]];
        
        if ([comps[2] isEqual:@"vpn_gateway"]) {
            [includedRoutes addObject:route];
        } else {
            [excludedRoutes addObject:route];
        }
    }];
    
    [includedRoutes addObject:[NEIPv4Route defaultRoute]];
    
    KDClassLog(@"bestroutetb: includedRoutes %lu, excludedRoutes %lu", (unsigned long)includedRoutes.count, (unsigned long)excludedRoutes.count);
    
    settings.excludedRoutes = excludedRoutes;
    settings.includedRoutes = includedRoutes;
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    KDClassLog(@"sleepWithCompletionHandler");
    completionHandler();
}

- (void)wake {
    KDClassLog(@"wake");
}

@end
