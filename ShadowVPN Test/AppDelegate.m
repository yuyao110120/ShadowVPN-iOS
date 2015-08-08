//
//  AppDelegate.m
//  ShadowVPN Test
//
//  Created by Blankwonder on 8/7/15.
//  Copyright © 2015 Yach. All rights reserved.
//

#import "AppDelegate.h"
#import "crypto.h"
#import "ShadowVPNCrypto.h"
#import "KDLogger.h"
#import "crypto_secretbox_salsa208poly1305.h"
#include "sodium.h"
#include <string.h>
#include "crypto_secretbox_salsa208poly1305.h"


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"u3eR490+2cVOoVMddmj82Y5Yc1MI0HzcGcWHSDaLXXEGMa/K/pOKdgrPEEM26pBNAKCL6C2zpnCWUCqsj4Or3QGnpDHs04C7pk0pS2nK8whrYL13UCBye6th9DZ+wbB+8lFWZYmaDebJECqOhYL2LBFeN7D2CvEbuF1B7dpTbwUKS8Ey0SVw8U5SHuNmauggdx0+RgVIXHoCqxw+l+f9k45Vr/U5FwoNQuGVq5ryMCF71Fg0cytWudC1GEgN5uo3IjRrXnzJvvD0vUp0dl/P8NuotPHB6R0v4XOiiNufVsHaAIlVwP7lJUBusEYJk2JvGRn4E8AjoUHkJlS+MNZX9wBgWw8lysqkpku7aHXVRUfpatNvBydvpdryT4bNq21ADxS3YCr8Awa5qdlm3s2i9chmqyPvbHmk1cyL+kZhtr1bwt69vzLXmdSPdc4ME38bThnKf9Wq6zHr2XVu/elDaUf/LDr7g0qvbwhQIRpKRyt8+Ao4gy4ObAhRE4kNz0geHw3Oatl3+vJklOEewoG5mqPDPLTHGoFwVXDelH6ncQQJA+mxP8DZnHbBUAmy/IPlfRzw69DZn+/YszXhDXkCd7/yxSlN90Z1Sne14/mFJ3oRmu1kzo3LzwyA8qx04C4nNDgYh9SJhLnSXWOMbNqFV336ZAMEMfuHzyJRvGf1raHOXP+Ha64r2rFpytdjIAG0z/Jakaq16J1osXrQDTyFcKE5oGiHKIlSQgowvwe/oZbAtfQf/XQMecwvwEsalOgRg9yXAPd+ps59QaqRoE/qgVx0sGZjGKUS0tE9LV3RNPhl34ZMOU9gfpc1LLqCr1YecFdsOVDB2qUdUNF8I4OhPAPvXczwaEBOYInkFLkm5AwcIWi9uzrjD/WTxCsXPqLyFvk5/ex2pqLGBZE8IxU3rOnNn92N30U/A3eOw16+4JLkDGBVJ3hKl6+YLn5mETsFHN6l8fupULNxiwXY6ymEEqJnte2OC01/ovSmS7hmGpx4sfLxnvzuwOK5cZSiKhV9MHeoouYE7e0WQwGFpoFD3aChveYYVw01XZScc2Tj4uhmpZF71dcxoxZk4JQXxtngr8ZfpDGdyzqgSDAo/uNLkSyuKq9L5dKE5WpLgAETjFiy04dZk1j4h1OkxJ614pn/JG2A2Oc1v67voPOidUH6bqjlPBNVy8dhD+dn3c3EgGqHi5YyvKagtNRJm8gQc/v4IvdiUc+hCqdN7jowIVNF+5uLonsBSX4WamqV8Ekdagc0wzHkXvpS6YY346nNkWsoOh4XdkM3hnSn6OzhD1Lm8DGswnmxxjg9wsieynhux3oFlxORCy9UNdSQmQWeQfeKkDvPFJxIvtrsmIkP" options:0];
    
    const size_t bufferSize = 4000;
    
    unsigned char *inBuffer = malloc(bufferSize);
    memset(inBuffer, 0, bufferSize);
    unsigned char *outBuffer = malloc(bufferSize);
    memset(outBuffer, 0, bufferSize);
    
    [data getBytes:inBuffer + SHADOWVPN_PACKET_OFFSET length:bufferSize - SHADOWVPN_PACKET_OFFSET];
    
    
    int r;
    {
        static unsigned char key[32];
        
        sodium_init();
        randombytes_set_implementation(&randombytes_salsa20_implementation);
        randombytes_stir();
        
        crypto_generichash(key, sizeof key, (unsigned char *)"BLANKWONDER",
                                      11, NULL, 0);
        
        unsigned char *m = outBuffer;
        unsigned char *c = inBuffer;
        unsigned long long clen = data.length - 24;
        
        
        unsigned char nonce[8];
        memcpy(nonce, c + 8, 8);
        r = crypto_secretbox_salsa208poly1305_open(m, c, clen + 32, nonce, key);
    }
    
    NSData *dd1;
    if (r != 0) {
        KDClassLog(@"failure");
    } else {
        dd1 = [NSData dataWithBytes:outBuffer + SHADOWVPN_ZERO_BYTES length:data.length - SHADOWVPN_OVERHEAD_LEN];
        KDClassLog(@"success");
    }
    
    [ShadowVPNCrypto setPassword:@"BLANKWONDER"];
    
    NSData *dd2 = [ShadowVPNCrypto decryptData:data];
    if (dd2)  {
        KDClassLog(@"success");
    } else {
        KDClassLog(@"failure");
    }
    
    KDClassLog(@"%d", [dd1 isEqualToData:dd2]);

    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
