#import "SCController.h"
#import "Constants.h"
#import "SCPreferences.h"
#import "Safari.h"
#import "SCNSHTTPCookieStorage.h"

@implementation SCController

#pragma mark -
#pragma mark Singleton

static SCController *sharedController = nil;

+ (SCController*)sharedController
{
    @synchronized(self) {
        if (sharedController == nil) {
            [[self alloc] init];
        }
    }
    return sharedController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedController == nil) {
            sharedController = [super allocWithZone:zone];
            return sharedController;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return UINT_MAX;
}

- (void)release
{
    // do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark -
#pragma mark Misc

- (id) init
{
	self = [super init];
	if (self != nil) {
		
		// Safari?
		if (!([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Safari"] ||
			  [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"org.webkit.nightly.WebKit"]
			  ))
			return nil;
		
		// poseAsClass is depreciated, but... who cares?
		[[SCPreferences class] poseAsClass:[NSPreferences class]];
		[[SCNSHTTPCookieStorage class] poseAsClass:[NSHTTPCookieStorage class]];
	}
	return self;
}

+ (NSString *)version
{
	return [[NSBundle bundleWithIdentifier:BundleIdentifier] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

@end
