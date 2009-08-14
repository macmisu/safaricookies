//
//  SafariCookies.m
//  SafariCookies
//
//  Created by John R Chang on 2005-12-07.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "SafariCookies.h"
#import "SCNSHTTPCookieStorage.h"
#import "SCPreferences.h"
#import "SCPreferencesModule.h"
#import "CookiesOutlineViewController.h"
#import "BooleanToStringTransformer.h"


@implementation SafariCookies

- (id) init
{
	NSBundle * mainBundle = [NSBundle mainBundle];
	if ([[mainBundle bundleIdentifier] isEqualToString:SCPreferencesDomainNameKey] == NO)
	{
		[self release];
		return nil;
	}
		
	//NSLog(@"SafariCookies");
	if ((self = [super init]))
	{	
		[[self class] setupUserDefaults];
		
		// Insert preference menu item
		NSMenu * mainMenu = [NSApp mainMenu];
		NSMenu * applicationMenu = [[mainMenu itemAtIndex:0] submenu];
		NSString * title = NSLocalizedString(@"SafariCookies...", nil);
		NSMenuItem * menuItem = [applicationMenu insertItemWithTitle:title
			action:@selector(showSCPreferences:) keyEquivalent:@"," atIndex:4];
		[menuItem setKeyEquivalentModifierMask:(NSCommandKeyMask | NSAlternateKeyMask)];
		[menuItem setTarget:self];

		// Register value transformers
		NSValueTransformer * transformer = [[[BooleanToStringTransformer alloc] init] autorelease];
		[NSValueTransformer setValueTransformer:transformer forName:@"BooleanToStringTransformer"];
	}
	return self;
}

+ (BOOL) domains:(NSArray *)domains containsHostname:(NSString *)hostname
{
	NSString * domain;
	for (domain in domains)
		if ([hostname hasSuffix:domain])
			return YES;
	return NO;
}

+ (NSArray *) cookiesMatchingDomains:(NSArray *)matchDomains match:(BOOL)value
{
	NSMutableArray * outCookies = [NSMutableArray array];
	
	NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	NSArray * cookies = [cs cookies];
	NSHTTPCookie * cookie;
	for (cookie in cookies)
	{
		NSString * hostname = [cookie domain];
		if (hostname == nil)
			continue;
		
		if ([SafariCookies domains:matchDomains containsHostname:hostname] == value)
			[outCookies addObject:cookie];
	}
	
	return outCookies;
}

+ (void) deleteCookies:(NSArray *)deleteCookies
{
	NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	NSHTTPCookie * cookie;
	for (cookie in deleteCookies)
		[cs deleteCookie:cookie];	
}

@synthesize _prefsController;
@end
