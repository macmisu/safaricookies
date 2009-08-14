//
//  SPNSHTTPCookieStorage.m
//  SafariCookies
//
//  Created by John R Chang on 2005-12-08.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "SPNSHTTPCookieStorage.h"

#import "SafariCookies.h"
#import "SCPreferences.h"
#import "SCLogFile.h"


@implementation SPNSHTTPCookieStorage

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL
{
//	NSLog(@"setCookies:%@ forURL:%@ mainDocumentURL:%@", [cookies description], [theURL description], [mainDocumentURL description]);

	NSString * theDomain = [theURL host];		// used in default_behavior
	if (theURL == nil)
		goto default_behavior;

	/*
		!NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain -> default
	*/
	NSHTTPCookieAcceptPolicy policy = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
	if (policy != NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain)
		goto default_behavior;
	
	int plusPolicy = [[[SCPreferences userDefaults] objectForKey:SCPreferencesCookieAcceptPolicy] intValue];

	/*
		NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain:
			SCPreferencesCookieAcceptPolicy 0,1,2 -> default
	*/
	int x;
	for (x= 0; x <= 2; x++)
	{
		if (plusPolicy == x) //  == NO)
			goto default_behavior;
	}
	/*
		NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain:
			SCPreferencesCookieAcceptPolicy = 3 ->  whitelist
	*/
	
	if (plusPolicy == 3)
	{
		NSArray * domains = [[SCPreferences userDefaults] objectForKey:SCPreferencesAcceptCookieDomainsKey];
		BOOL shouldAcceptCookie = [SafariCookies domains:domains containsHostname:theDomain];
		if (shouldAcceptCookie == YES)
		{
			goto default_behavior;
		}
		if (shouldAcceptCookie == NO)
		{
			[SCLogFile log:[NSString stringWithFormat:@"Cookie (%@): DENY", theDomain]];
			return;
		}
		
	}

default_behavior:
	[SCLogFile log:[NSString stringWithFormat:@"Cookie (%@): Pass-through", theDomain]];
	[super setCookies:cookies forURL:theURL mainDocumentURL:mainDocumentURL];
}

@end
