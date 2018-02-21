//
//  DConnectIdentityStore.m
//  DConnectSDK
//
//  Created by Masaru Takano on 2017/10/19.
//  Copyright © 2017年 NTT DOCOMO, INC. All rights reserved.
//

#import "DConnectIdentityStore.h"

#import <openssl/ssl.h>
#import <openssl/evp.h>
#import <openssl/rsa.h>
#import <openssl/x509v3.h>
#import <openssl/asn1.h>
#import <openssl/pem.h>
#import <openssl/pkcs12.h>

@implementation DConnectIdentityStore {
    NSMutableArray *_certificates;
}

+ (DConnectIdentityStore *) shared {
    static DConnectIdentityStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [DConnectIdentityStore new];
    });
    return instance;
}

- (id) init {
    self = [super init];
    if (self) {
        _certificates = [NSMutableArray array];
        
        NSString *dirPath = NSTemporaryDirectory();
        NSString *p12Path = [dirPath stringByAppendingPathComponent:@"certificate.p12"];
        if ([self generatePKCS12:p12Path]) {
            SecIdentityRef identity = [self importPKCS12:p12Path];
            NSLog(@"SecIdentityRef: %@", identity);
            [_certificates addObject:(__bridge id) identity];
        } else {
            NSLog(@"Failed to generate p12 file.");
        }
    }
    return self;
}

- (NSArray *) identity
{
    return _certificates;
}

- (void) findIdentity
{
    NSDictionary *query = @{
                            (__bridge id)kSecClass: (__bridge id) kSecClassIdentity
                            };
    CFTypeRef resultRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultRef);
    NSLog(@"findIdentity: status = %d", status);
    if (status == errSecSuccess) {
        NSDictionary *result = (__bridge_transfer NSDictionary *)resultRef;
        NSLog(@"findIdentity: count = %d", [result count]);
    }
}

- (int) generatePKCS12:(NSString *)outPath
{
    EVP_PKEY * pkey;
    pkey = EVP_PKEY_new();
    
    RSA * rsa;
    rsa = RSA_generate_key(
                           2048,   /* number of bits for the key - 2048 is a sensible value */
                           RSA_F4, /* exponent - RSA_F4 is defined as 0x10001L */
                           NULL,   /* callback - can be NULL if we aren't displaying progress */
                           NULL    /* callback argument - not needed in this case */
                           );
    
    EVP_PKEY_assign_RSA(pkey, rsa);
    
    X509 * x509;
    x509 = X509_new();
    
    ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);
    
    //X509_set_version(x509, 2); // 2 -> x509v3
    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 315360000L); // 10 years
    
    X509_set_pubkey(x509, pkey);
    X509_NAME *name;
    name = X509_get_subject_name(x509);
    X509_NAME_add_entry_by_txt(name, "C",  MBSTRING_ASC,
                               (unsigned char *)"JP", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "ST",  MBSTRING_ASC,
                               (unsigned char *)"N/A", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "L",  MBSTRING_ASC,
                               (unsigned char *)"N/A", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "O",  MBSTRING_ASC,
                               (unsigned char *)"N/A", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,
                               (unsigned char *)"localhost", -1, -1, 0);
    X509_set_issuer_name(x509, name);
    X509_sign(x509, pkey, EVP_sha1());
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if (![fileMgr createFileAtPath:outPath contents:[NSData data] attributes:nil]) {
        NSLog(@"Failed to create file: %@", outPath);
        return 0;
    }
    SSLeay_add_all_algorithms();
    PKCS12 *p12 = PKCS12_create("0000",
                                "Device Connect System for iOS",
                                pkey,
                                x509,
                                NULL,
                                0,0,0,0,0);
    if (!p12) {
        NSLog(@"Failed to create p12.");
        return 0;
    }
    
    FILE *fp = fopen([outPath cStringUsingEncoding:NSASCIIStringEncoding], "w");
    int success = i2d_PKCS12_fp(fp, p12);
    if (success) {
        NSLog(@"Created p12: %@", outPath);
    } else {
        NSLog(@"Failed to create p12.");
    }
    fclose(fp);
    PKCS12_free(p12);
    return success;
}

- (SecIdentityRef) importPKCS12:(NSString *)inPath
{
    NSURL *path = [NSURL fileURLWithPath:inPath];
    NSLog(@"Certificate Path: %@", path);
    NSData *data = [NSData dataWithContentsOfURL:path];
    
    NSString* password = @"0000";
    NSDictionary* options = @{
                              (id)kSecImportExportPassphrase : password
                              };
    
    CFArrayRef rawItems = NULL;
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)data,
                                      (__bridge CFDictionaryRef)options,
                                      &rawItems);
    NSArray* items = (NSArray*)CFBridgingRelease(rawItems); // Transfer to ARC
    
    NSDictionary* firstItem = nil;
    if ((status == errSecSuccess) && ([items count] > 0)) {
        firstItem = items[0];
        SecIdentityRef identity = (SecIdentityRef) CFBridgingRetain(firstItem[(id)kSecImportItemIdentity]);
        return identity;
    }
    return nil;
}

@end
