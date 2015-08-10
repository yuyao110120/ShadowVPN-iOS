//
//  DNSServer.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/10/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "DNSServer.h"
#import "GCDAsyncUdpSocket.h"
#import "DNSPacket.h"


@interface DNSServerQuery : NSObject
@property (nonatomic) NSArray *domains;
@property (nonatomic) NSData *clientAddress;
@property (nonatomic) DNSPacket *packet;
@end

@interface DNSServer () <GCDAsyncUdpSocketDelegate> {
    dispatch_queue_t _dispatchQueue;
    
    BOOL _outgoingSessionReady;
    
    GCDAsyncUdpSocket *_socket;
    
    NWUDPSession *_whitelistSession;
    NWUDPSession *_blacklistSession;
    
    NSMutableArray *_queries;
    NSMutableDictionary *_waittingQueriesMap;

    u_int16_t _queryIDCounter;
    
    NSMutableSet *_whitelistSuffixSet;
}

@end

@implementation DNSServer

- (instancetype)init {
    self = [super init];
    if (self) {
        _queryIDCounter = 0;
        _queries = [NSMutableArray arrayWithCapacity:10];
        _waittingQueriesMap = [NSMutableDictionary dictionaryWithCapacity:10];
        _dispatchQueue = dispatch_queue_create("DNSServer", NULL);
        _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_dispatchQueue];
        
        NSString *whitelistSuffixStr = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"china_domains" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
        
        _whitelistSuffixSet = [NSMutableSet set];
        
        [whitelistSuffixStr enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            [_whitelistSuffixSet addObject:line];
        }];
        
    }
    return self;
}

- (void)startServer {
    NSError *error = nil;
    if (![_socket bindToPort:53 error:&error]) {
        KDClassLog(@"Error occurred when start DNS server (binding): %@", error);
    } else {
        if (![_socket beginReceiving:&error]) {
            KDClassLog(@"Error occurred when start DNS server (receiving): %@", error);
        }
    }
}

- (void)stopServer {
    [_socket synchronouslySetDelegate:nil];
    [_socket close];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    DNSPacket *dns = [[DNSPacket alloc] initWithPacketData:data];
    if (!dns) return;
    
    DNSServerQuery *query = [[DNSServerQuery alloc] init];
    query.domains = dns.queryDomains;
    query.clientAddress = address;
    query.packet = dns;
    
    [_queries addObject:query];
    
    [self processQuery];
}

- (void)processQuery {
    if (!_outgoingSessionReady) return;
    if (_queries.count == 0) return;
    
    DNSServerQuery *query = _queries.firstObject;
    [_queries removeObjectAtIndex:0];
    
    NSMutableData *data = [query.packet.rawData mutableCopy];
    
    if (_queryIDCounter == UINT16_MAX) _queryIDCounter = 0;
    
    u_int16_t queryID = _queryIDCounter++;
    
    [data replaceBytesInRange:NSMakeRange(0, 2) withBytes:&queryID];
    

    NWUDPSession *session;
    
    if ([self isDomain:query.packet.queryDomains.firstObject containedInSet:_whitelistSuffixSet]) {
        session = _whitelistSession;
    } else {
        session = _blacklistSession;
    }
    
//    KDClassLog(@"Processing DNS query: %@, forwarding to %@", query.packet.queryDomains.firstObject, session.endpoint);

    [session writeDatagram:data completionHandler:^(NSError * _Nullable error) {
        if (error) {
            KDClassLog(@"Error occurred when write to session(%@): %@", session.endpoint, error);
            [_queries addObject:query];
        } else {
            _waittingQueriesMap[@(queryID)] = query;
        }
    }];
}

- (void)setupOutgoingConnectionWithTunnelProvider:(NEPacketTunnelProvider *)provider
                                         chinaDNS:(NSString *)chinaDNS
                                        globalDNS:(NSString *)globalDNS {
    _whitelistSession = [provider createUDPSessionToEndpoint:[NWHostEndpoint endpointWithHostname:chinaDNS port:@"53"]
                                                fromEndpoint:nil];
    _blacklistSession = [provider createUDPSessionThroughTunnelToEndpoint:[NWHostEndpoint endpointWithHostname:globalDNS port:@"53"]
                                                             fromEndpoint:nil];
    
    KDUtilDefineWeakSelfRef
    [_whitelistSession setReadHandler:^(NSArray<NSData *> * _Nullable datagrams, NSError * _Nullable error) {
        if (error) {
            KDLog(NSStringFromClass([weakSelf class]), @"Error when whitelist UDP session read: %@", error);
        } else {
            [weakSelf processResponse:datagrams];
        }
    } maxDatagrams:NSUIntegerMax];
    [_blacklistSession setReadHandler:^(NSArray<NSData *> * _Nullable datagrams, NSError * _Nullable error) {
        if (error) {
            KDLog(NSStringFromClass([weakSelf class]), @"Error when blacklist UDP session read: %@", error);
        } else {
            [weakSelf processResponse:datagrams];
        }
    } maxDatagrams:NSUIntegerMax];
    
    [_whitelistSession addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    [_blacklistSession addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
}

- (void)processResponse:(NSArray *)datagrams {
    dispatch_async(_dispatchQueue, ^{
        for (NSData *data in datagrams) {
            u_int16_t queryID = *((u_int16_t *)data.bytes);
            
            DNSServerQuery *query = _waittingQueriesMap[@(queryID)];
            if (!query) {
                KDClassLog(@"Local query not found!");
            } else {
                NSMutableData *mdata = [data mutableCopy];
                u_int16_t identifier = query.packet.identifier;
                [mdata replaceBytesInRange:NSMakeRange(0, 2) withBytes:&identifier];
                
                [_socket sendData:mdata toAddress:query.clientAddress withTimeout:10 tag:0];
            }
        }
    });
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *,id> *)change
                       context:(nullable void *)context {
    if ([keyPath isEqualToString:@"state"]) {
        NWUDPSession *session = object;
        KDClassLog(@"UDP Session(%@) state changed: %d", session.endpoint, session.state);
        _outgoingSessionReady = _whitelistSession.state == NWUDPSessionStateReady && _blacklistSession.state == NWUDPSessionStateReady;
        if (_outgoingSessionReady && _dispatchQueue) {
            dispatch_async(_dispatchQueue, ^{
                [self processQuery];
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)isDomain:(NSString *)domain containedInSet:(NSSet *)domainSet {
    NSString *ptr = domain;
    do {
        if ([domainSet containsObject:ptr]) {
            return YES;
        }
        
        NSRange range = [ptr rangeOfString:@"."];
        if (range.location == NSNotFound) {
            return NO;
        }
        
        ptr = [ptr substringFromIndex:range.location + 1];
    } while(ptr);
    return NO;
}

@end

@implementation DNSServerQuery

@end