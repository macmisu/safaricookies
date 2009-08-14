#import "SCController.h"
#import "Constants.h"
#import "SCPreferences.h"
#import "Safari.h"
#import "SCLogFile.h"
#import "SCNSHTTPCookieStorage.h"
#import "SCPreferencesModule.h"
#import "CookiesOutlineViewController.h"
#import "BooleanToStringTransformer.h"
#import "NSHTTPCookieStorageAdditions.h"


@implementation SCController

+ (void)initialize
{
	// Force the creation of the singleton
	[SCController sharedController];
}

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
			\
			return nil;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminateNotification:) 
													 name:NSApplicationWillTerminateNotification object:nil];
		
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
		
		if ([SCController domains:matchDomains containsHostname:hostname] == value)
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

- (void) _applicationWillTerminateNotification:(NSNotification *)notification
{			
	if ([[SCPreferences userDefaults] boolForKey:SCPreferencesRemoveNonFavoritesWhenQuitting])
	{
		NSArray * domains = [[SCPreferences userDefaults] objectForKey:SCPreferencesAcceptCookieDomainsKey];
		NSArray * deleteCookies = [SCController cookiesMatchingDomains:domains match:NO];
		
		int count = [deleteCookies count];
		if (count > 0)
		{
			int numDeleteCookies = [deleteCookies count];
			if (numDeleteCookies == 1)
				[SCLogFile log:[NSString stringWithFormat:@"Deleting %d non-favorite cookie on quit", count]];
			else
				[SCLogFile log:[NSString stringWithFormat:@"Deleting %d non-favorite cookies on quit", count]];
			
			[SCController deleteCookies:deleteCookies];
			
			// Flush
			NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
			[cs _spFlush];
		}
	}
}

-(void) dealloc
{
	[super dealloc];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object: nil];
}

@end
