//
//  ShadowVPNCrypto.m
//  ShadowVPN-iOS
//
//  Created by Blankwonder on 8/6/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "ShadowVPNCrypto.h"
#include "sodium.h"
#include <string.h>
#include "crypto_secretbox_salsa208poly1305.h"
#import "KDLogger.h"

#define SHADOWVPN_ZERO_BYTES 32
#define SHADOWVPN_OVERHEAD_LEN 24
#define SHADOWVPN_PACKET_OFFSET 8

#define BUFFER_SIZE 2000

@implementation ShadowVPNCrypto

static unsigned char key[32];
+ (void)setPassword:(NSString *)password {
    const char *c = password.UTF8String;
    
    sodium_init();
    randombytes_set_implementation(&randombytes_salsa20_implementation);
    randombytes_stir();
    crypto_generichash(key, sizeof key, (const unsigned char *)c, strlen(c), NULL, 0);
}

+ (NSData *)encryptData:(NSData *)data {
    unsigned char *inBuffer = malloc(BUFFER_SIZE);
    unsigned char *outBuffer = malloc(BUFFER_SIZE);
    memset(inBuffer, 0, BUFFER_SIZE);
    memset(outBuffer, 0, BUFFER_SIZE);

    [data getBytes:inBuffer + SHADOWVPN_ZERO_BYTES length:BUFFER_SIZE - SHADOWVPN_ZERO_BYTES];
    
    unsigned char nonce[8];
    randombytes_buf(nonce, 8);
    int r = crypto_secretbox_salsa208poly1305(outBuffer, inBuffer, data.length + SHADOWVPN_ZERO_BYTES, nonce, key);
    if (r != 0) return nil;
    memcpy(outBuffer + 8, nonce, 8);
    
    NSData *resultData = [NSData dataWithBytes:outBuffer + SHADOWVPN_PACKET_OFFSET length:SHADOWVPN_OVERHEAD_LEN + data.length];
    
    free(inBuffer);
    free(outBuffer);
    
    return resultData;
}

+ (NSData *)decryptData:(NSData *)data {
    unsigned char *inBuffer = malloc(BUFFER_SIZE);
    unsigned char *outBuffer = malloc(BUFFER_SIZE);
    memset(inBuffer, 0, BUFFER_SIZE);
    memset(outBuffer, 0, BUFFER_SIZE);

    [data getBytes:inBuffer + SHADOWVPN_PACKET_OFFSET length:BUFFER_SIZE - SHADOWVPN_PACKET_OFFSET];
    
    unsigned char nonce[8];
    memcpy(nonce, inBuffer + 8, 8);
    int r = crypto_secretbox_salsa208poly1305_open(outBuffer, inBuffer, data.length + SHADOWVPN_PACKET_OFFSET, nonce, key);
    if (r != 0) {
        NSLog(@"Decrypt failed with code: %d", r);
        return nil;
    }
    
    NSData *resultData = [NSData dataWithBytes:outBuffer + SHADOWVPN_ZERO_BYTES length:data.length - SHADOWVPN_OVERHEAD_LEN];
    
    free(inBuffer);
    free(outBuffer);
    
    return resultData;
}

@end
