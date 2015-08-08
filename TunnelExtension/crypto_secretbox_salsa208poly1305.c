/**
 crypto_secretbox_salsa208poly1305.c
 
 Copyright (C) 2015 clowwindy
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */

#include "sodium.h"
#include <string.h>

int crypto_secretbox_salsa208poly1305(
                                      unsigned char *c,
                                      const unsigned char *m,unsigned long long mlen,
                                      const unsigned char *n,
                                      const unsigned char *k
                                      ) {
    if (mlen < 32) return -1;
    crypto_stream_salsa208_xor(c, m, mlen, n, k);
    crypto_onetimeauth_poly1305(c + 16,c + 32,mlen - 32,c);
    memset(c, 0, 16);
    return 0;
}

int crypto_secretbox_salsa208poly1305_open(
                                           unsigned char *m,
                                           const unsigned char *c,unsigned long long clen,
                                           const unsigned char *n,
                                           const unsigned char *k
                                           ) {
    unsigned char subkey[32];
    if (clen < 32) return -1;
    crypto_stream_salsa208(subkey,32,n,k);
    if (crypto_onetimeauth_poly1305_verify(c + 16,c + 32,clen - 32,subkey) != 0) return -2;
    crypto_stream_salsa208_xor(m,c,clen,n,k);
    memset(m, 0, 32);
    return 0;
}
