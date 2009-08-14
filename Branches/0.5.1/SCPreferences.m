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

