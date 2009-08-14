//
//  SCPreferences.m
//  SafariCookies
//
//  Created by John Chang on 6/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SCPreferences.h"
#import "Constants.h"
#import "BundleUserDefaults.h"
#import "SCPreferences.h"
#import "SCPreferencesModule.h"


@implementation SCPreferences

+ sharedPreferences {
	static BOOL	preferencesAdded = NO;
	id preferences = [super sharedPreferences];
	
	if (preferences != nil && !preferencesAdded) {
		[preferences addPreferenceNamed:@"Cookies" owner:[SCPreferencesModule sharedInstance]];
		preferencesAdded = YES;
	}
	
	return preferences;
}

+ (void) setupUserDefaults
{
	NSUserDefaults * ud = [[BundleUserDefaults alloc] initWithPersistentDomainName:SCPreferencesDomainNameKey];
	
	[[NSUserDefaultsController sharedUserDefaultsController] _setDefaults:ud];
	
	NSDictionary * appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithInt:SCCookieAcceptPolicySafariBehavior], SCPreferencesCookieAcceptPolicy,
								  nil];
	[ud registerDefaults:appDefaults];
	//	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:appDefaults];
	
	[ud release];
}


+ (NSUserDefaults *) userDefaults
{
	return [[NSUserDefaultsController sharedUserDefaultsController] defaults];
}

@end

