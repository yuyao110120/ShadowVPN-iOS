//
//  DNSClient.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "DNSClient.h"

@implementation DNSClient {
    NWUDPSession *_UDPSession;
    
    NSMutableArray *_queries;
}

- (instancetype)initWithDNSServerAddress:(NSString *)address tunnelProvider:(NEPacketTunnelProvider *)tunnelProvider {
    self = [self init];
    if (self) {
        _queries = [NSMutableArray arrayWithCapacity:100];
        KDClassLog(@"Creating DNS Client...");
        NWHostEndpoint *endpoint = [NWHostEndpoint endpointWithHostname:address
                                                                   port:@"53"];
        
        _UDPSession = [tunnelProvider createUDPSessionToEndpoint:endpoint fromEndpoint:nil];
        
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
    }
    return self;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *,id> *)change
                       context:(nullable void *)context {
    if (object == _UDPSession && [keyPath isEqualToString:@"state"]) {
        KDClassLog(@"UDP Session state changed: %d", (int)_UDPSession.state);
        [self UDPSessionStateChanged];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)queryWithPayload:(NSData *)payload {
    @synchronized(_queries) {
        [_queries addObject:payload];
    }
}

- (void)UDPSessionStateChanged {
    if (_UDPSession.state == NWUDPSessionStateReady) {
        [self processQuery];
    } else if (_UDPSession.state == NWUDPSessionStateFailed || _UDPSession.state == NWUDPSessionStateCancelled)  {
    }
}

- (void)processQuery {
    NSData *data;
    @synchronized(_queries) {
        if (_queries.count == 0) return;
        data = _queries.firstObject;
        [_queries removeObjectAtIndex:0];
    }
    
    [_UDPSession writeDatagram:data completionHandler:^(NSError * _Nullable error) {
        if (error){
            KDClassLog(@"Write UDP error: %@", error);
            @synchronized(_queries) {
                [_queries insertObject:data atIndex:0];
            }
#warning TODO
        }
    }];
}

- (void)processUDPIncomingDatagrams:(NSArray *)datagrams {
}

- (void)dealloc {
    [_UDPSession removeObserver:self forKeyPath:@"state"];
}

@end
