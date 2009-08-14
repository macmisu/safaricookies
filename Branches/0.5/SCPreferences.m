//
//  SCPreferences.m
//  SafariCookies
//
//  Created by John Chang on 6/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SCPreferences.h"
#import "Constants.h"
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

@end

