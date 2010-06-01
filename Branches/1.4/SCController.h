//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


@interface SCController : NSObject
{
}

+ (SCController *)sharedController;
+ (id)allocWithZone:(NSZone *)zone;
- (id)copyWithZone:(NSZone *)zone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;
+ (NSString *)version;

+ (BOOL) domains:(NSArray *)domains containsHostname:(NSString *)hostname;
+ (NSArray *) cookiesMatchingDomains:(NSArray *)matchDomains match:(BOOL)value;
+ (void) deleteCookies:(NSArray *)deleteCookies;
+ (NSString *) siteDomainName:(NSString *)domain;


@end
