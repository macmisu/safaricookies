//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


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
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scookies_applicationWillTerminateNotification:) 
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
	for (NSString *domain in domains)
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

- (void) scookies_applicationWillTerminateNotification:(NSNotification *)notification
{	
	// Automatic Mode
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesAutomaticMode])
	{
		NSArray* domains = [SCPreferencesModule autoModeDomains];
		NSArray * deleteCookies = [SCController cookiesMatchingDomains:domains match:NO];
		
		[SCController deleteCookies:deleteCookies];
		
		
		//Delete Flash Cookies
		NSArray *flashCookiesArray = [[NSFileManager defaultManager]
									  contentsOfDirectoryAtPath:[SCFlashCookiesFolder stringByExpandingTildeInPath] error:nil];

		NSMutableArray *finalArray = [[NSMutableArray new] autorelease];
		
		for (NSString *flashCookie in flashCookiesArray)											//create array of Flash cookies to delete
		{
			if ([flashCookie characterAtIndex:0] == '#') {
				flashCookie = [flashCookie substringFromIndex:1];
				
				if ([flashCookie characterAtIndex:0] == 'w' && [flashCookie characterAtIndex:1] == 'w'
					&& [flashCookie characterAtIndex:2] == 'w' && [flashCookie characterAtIndex:3] == '.')
					flashCookie = [flashCookie substringFromIndex:4];

				[finalArray addObject:flashCookie];
			}
		}
		
		NSMutableArray *deleteArray = [NSMutableArray arrayWithArray:finalArray];
		[deleteArray removeObjectsInArray:domains];
		
		//If there are no flash cookies, we might as well delete the entire folder
		if ([deleteArray count] == [finalArray count]) {
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *flashCookiesFolder = [SCFlashCookiesPath stringByExpandingTildeInPath];
			if ([fm fileExistsAtPath:flashCookiesFolder])
			{
				[fm removeItemAtPath:flashCookiesFolder error:NULL];
			}
		}
		
		for (NSString *deleteFlashCookie in deleteArray)											//delete Flash cookies
		{
			NSString *flashCookiePath = [SCFlashCookiesFolder stringByExpandingTildeInPath];
			
			//delete flash cookies
			NSString *deleteCookie = [NSString stringWithFormat:@"#%@", deleteFlashCookie];
			NSString *deleteCookiePath = [flashCookiePath stringByAppendingPathComponent:deleteCookie];
			[[NSFileManager defaultManager] removeItemAtPath:deleteCookiePath error:nil];
			
			//also delete flash cookies with prefix:www.
			NSString *deleteCookieWWW = [NSString stringWithFormat:@"#www.%@", deleteFlashCookie];
			NSString *deleteCookiePathWWW = [flashCookiePath stringByAppendingPathComponent:deleteCookieWWW];
			[[NSFileManager defaultManager] removeItemAtPath:deleteCookiePathWWW error:nil];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveGoogleAnalyticsCookies])
	{
		NSArray * deleteCookies = [CookieNode googleAnalyticsCookies];;
		
		[SCController deleteCookies:deleteCookies];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveNonFavoritesWhenQuitting] && ![[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesAutomaticMode])
	{
		//get favorites from Favorites.plist
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
		NSArray* domains = [favoritesDictionary objectForKey:@"Domains"];
		NSArray * deleteCookies = [SCController cookiesMatchingDomains:domains match:NO];
		
		[SCController deleteCookies:deleteCookies];													//delete NSHTTP cookies
		
		
		NSMutableArray* flashFavorites = [favoritesDictionary objectForKey:@"Flash"];
		NSArray *flashCookiesArray = [[NSFileManager defaultManager]
									  contentsOfDirectoryAtPath:[SCFlashCookiesFolder stringByExpandingTildeInPath] error:nil];
		
		NSMutableArray *finalArray = [[NSMutableArray new] autorelease];
		
		for (NSString *flashCookie in flashCookiesArray)											//create array of Flash cookies to delete
		{
			if ([flashCookie characterAtIndex:0] == '#') {
				flashCookie = [flashCookie substringFromIndex:1];			
				[finalArray addObject:flashCookie];
				continue;
			}
		}
		
		NSMutableArray *deleteArray = [NSMutableArray arrayWithArray:finalArray];
		[deleteArray removeObjectsInArray:flashFavorites];
		
		//If there are no flash cookies, we might as well delete the entire folder
		if ([deleteArray count] == [finalArray count]) {
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *flashCookiesFolder = [SCFlashCookiesPath stringByExpandingTildeInPath];
			if ([fm fileExistsAtPath:flashCookiesFolder])
			{
				[fm removeItemAtPath:flashCookiesFolder error:NULL];
			}
		}
		
		for (NSString *deleteFlashCookie in deleteArray)											//delete Flash cookies
		{
			NSString *flashCookiePath = [SCFlashCookiesFolder stringByExpandingTildeInPath];
			deleteFlashCookie = [NSString stringWithFormat:@"#%@", deleteFlashCookie];
			flashCookiePath = [flashCookiePath stringByAppendingPathComponent:deleteFlashCookie];
			
			[[NSFileManager defaultManager] removeItemAtPath:flashCookiePath error:nil];
		}		
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
