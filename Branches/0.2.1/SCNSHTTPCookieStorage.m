//
//  SPNSHTTPCookieStorage.m
//  SafariCookies
//
//  Created by John R Chang on 2005-12-08.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "SCNSHTTPCookieStorage.h"
#import "SafariCookies.h"
#import "SCPreferences.h"
#import "SCLogFile.h"


@implementation SCNSHTTPCookieStorage

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL
{
//	[SCLogFile log:(@"setCookies:%@ forURL:%@ mainDocumentURL:%@", [cookies description], [theURL description], [mainDocumentURL description])];
	
	
	NSString * theDomain = [theURL host];		// used in default_behavior
	if (theURL != nil)
		goto default_behavior;

	/*
		!NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain -> default
	*/
	NSHTTPCookieAcceptPolicy policy = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
	if (policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain)
	{
		NSString * mainDocumentHostname = [mainDocumentURL host];
		NSString * hostname = [theURL host];
		BOOL shouldAcceptCookie = [mainDocumentHostname isEqualToString:hostname];
		if (shouldAcceptCookie == YES)
		{
			goto default_behavior;
		}
		if (shouldAcceptCookie == NO)
		{
			goto deny_behaviour;
		}
	}
	if (policy != NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain)
	{
		goto alternate_behaviour;
	}
	
default_behavior:
	[SCLogFile log:[NSString stringWithFormat:@"Cookie (%@): Pass-through", theDomain]];
	[super setCookies:cookies forURL:theURL mainDocumentURL:mainDocumentURL];
	return;
	
deny_behaviour:
	[SCLogFile log:[NSString stringWithFormat:@"Cookie (%@): DENIED", theDomain]];
	return;
		
	//used when cookieAcceptPolicy is set as "never", all "always" - so we dont fill the log with pointless entries
alternate_behaviour:
	return;
}

@end
