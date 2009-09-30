#import "SCPreferences.h"
#import "SCPreferencesModule.h"


@implementation NSPreferences(SCPreferences)

+ (id)mySharedPreferences {
	static BOOL	preferencesAdded = NO;
	id preferences = [self mySharedPreferences];
	
	if (preferences != nil && !preferencesAdded) {
		[preferences addPreferenceNamed:@"Cookies" owner:[SCPreferencesModule sharedInstance]];
		preferencesAdded = YES;
	}
	
	return preferences;
}

@end

