#import "SCController.h"
#import "Constants.h"
#import "SCPreferences.h"
#import "SCPreferencesModule.h"
#import "CookiesOutlineViewController.h"
#import "BooleanToStringTransformer.h"
#import "MethodSwizzle.h"
#import "CookieNode.h"




@implementation SCController

+ (void)load
{
	[SCController sharedController];
}

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
            [[[self alloc] init] autorelease];
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
		
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		if (![fm fileExistsAtPath:applicationSupportFolder]) {
			if (![fm createDirectoryAtPath:applicationSupportFolder withIntermediateDirectories:YES attributes:nil error:nil])
				return nil;
		}
		
		//setup defaults
		NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithContentsOfFile:
										 [[NSBundle bundleWithIdentifier:BundleIdentifier] pathForResource:@"Defaults" ofType:@"plist"]];
			
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminateNotification:) 
													 name:NSApplicationWillTerminateNotification object:nil];
		
		
		NSLog(@"Safari Cookies loaded from: /Library/Application Support/SIMBL/Plugins/Safari Cookies.bundle");

		
		// 64bit Swizzle Goodness
		ClassMethodSwizzle(NSClassFromString(@"NSPreferences"), @selector(sharedPreferences), @selector(mySharedPreferences));		
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
		if ([hostname hasSuffix:[domain lowercaseString]])
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
		NSString * hostname = [[cookie domain] lowercaseString];
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

+ (NSString *) siteDomainName:(NSString *)domain
{	
	//ignore local files
	NSRange localFileRange = [domain rangeOfString:@"file:///"];
	if (localFileRange.location != NSNotFound)
		return nil;
	
	// strip out http:// and https://
	NSRange initialRange = [domain rangeOfString:@"//"];
	if (initialRange.location == NSNotFound)
		return nil;
	
	int initialLength = initialRange.location + 2;
	
	domain = [domain substringFromIndex:initialLength];	
	
	// strip down to just the domain
	NSRange range = [domain rangeOfString:@"/"];
	if (range.location == NSNotFound)
		return nil;
	
	int finalLength = range.location;
	
	domain = [domain substringToIndex:finalLength];
	int length = [domain length];
	
	
	//check for numeric IP Adresses
	NSString *checkforNumbers = [domain stringByTrimmingCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
	if ([checkforNumbers length] != 0)
	{
		//check to see if there are any '.'s
		NSString *checkforDots = [checkforNumbers stringByTrimmingCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"."] invertedSet]];
		
		if ([checkforDots length] != 0)
		{
			return checkforNumbers;
		}
	}
	

	// top-level
	NSRange range1 = [domain rangeOfString:@"." options:NSBackwardsSearch range:NSMakeRange(0, length)];
	if (range1.location == NSNotFound)
		return nil;
	
	int length1 = length - range1.location - 1;
	
	
	// second-level
	NSRange range2 = [domain rangeOfString:@"." options:NSBackwardsSearch range:NSMakeRange(0, range1.location)];
	if (range2.location == NSNotFound)
		return [domain lowercaseString];	// e.g. macupdate.com
	int length2 = range1.location - range2.location - 1;
	
	
	if (length1 == 2 && (length2 == 2 || length2 == 3) && ([domain hasSuffix:@".se"] || [domain hasSuffix:@".ru"]) == NO)
	{
		// third-level
		NSRange range3 = [domain rangeOfString:@"." options:NSBackwardsSearch range:NSMakeRange(0, range2.location)];
		if (range3.location == NSNotFound)
			return [domain lowercaseString];
		return [[domain lowercaseString] substringFromIndex:range3.location + 1];
	}
	
	return [[domain lowercaseString] substringFromIndex:range2.location + 1];
}


- (void) _applicationWillTerminateNotification:(NSNotification *)notification
{	
	// Automatic Mode
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesAutomaticMode])
	{
		NSArray* domains = [SCPreferencesModule autoModeDomains];
		NSArray * deleteCookies = [SCController cookiesMatchingDomains:domains match:NO];
		
		[SCController deleteCookies:deleteCookies];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveGoogleAnalyticsCookies])
	{
		NSArray * deleteCookies = [CookieNode googleAnalyticsCookies];;
		
		[SCController deleteCookies:deleteCookies];
	}
	
	// delete Flash Cookies Folder ~/Library/Preferences/Macromedia/Flash Player
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveFlashCookiesWhenQuitting])
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *flashCookiesFolder = [SCFlashCookiesPath stringByExpandingTildeInPath];
		if ([fm fileExistsAtPath:flashCookiesFolder])
		{
			[fm removeItemAtPath:flashCookiesFolder error:NULL];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveNonFavoritesWhenQuitting] && ![[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesAutomaticMode])
	{
		//get favorites from Favorites.plist
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
		NSMutableArray* domains = [favoritesDictionary objectForKey:@"Domains"];
		
		NSArray * deleteCookies = [SCController cookiesMatchingDomains:domains match:NO];
		
		[SCController deleteCookies:deleteCookies];
		
	}
}

- (NSString *)pathToRelaunchForUpdater:(SUUpdater *)updater
{
	return [[NSBundle mainBundle] bundlePath];
}

- (void) dealloc
{
	[super dealloc];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object: nil];
}

@end
