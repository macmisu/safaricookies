//
//  CookieNode.m
//  FilteringTreeController
//
//  Created by John Chang on 6/14/07
//  Modified by Russell Gray September 2009
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CookieNode.h"
#import "Constants.h"
#import "SCController.h"


@implementation CookieNode
@synthesize _prefsController, _children;


- (id) initWithPrefsController:(SCPreferencesModule *)controller
{
	if ((self = [super init]))
	{
		_prefsController = [controller retain];
	}
	return self;
}

- (void) dealloc
{
	[_prefsController release];
	[super dealloc];
}

+ (NSString *) _siteWithDomainName:(NSString *)domain importCookies:(BOOL)importCookies
{	
	NSRange localFileRange = [domain rangeOfString:@"file:///"];	//ignore local urls
	if (localFileRange.location != NSNotFound)
		return nil;
	
	if ([domain characterAtIndex:1] == '^')							//ignore local file cookies
		return nil;
	
	if (importCookies == YES) {
		domain = [[NSURL URLWithString:domain] host];				//a quick way to remove http:// and https://
	}
	
	if ([domain characterAtIndex:0]=='w' && [domain characterAtIndex:1]=='w'
		&& [domain characterAtIndex:2]=='w' && [domain characterAtIndex:3]=='.')
		domain = [domain substringFromIndex:4];
		
	
	NSArray *domainComponents = [domain componentsSeparatedByString:@"."];
	
	if ([[[domainComponents lastObject] stringByTrimmingCharactersInSet:
		[NSCharacterSet decimalDigitCharacterSet]] length] == 0)	//return domain if it is an ip address
		return domain;
	
	int secondLastObject = [domainComponents count] - 2;
	if ([[domainComponents lastObject] length] == 3) {				//.com .org .biz etc...
		return [NSString stringWithFormat:@"%@.%@", [domainComponents objectAtIndex:secondLastObject],
				[domainComponents lastObject]];
	}
	
	if ([domainComponents count] > 2) {
		int thirdLastObject = [domainComponents count] - 3;			//.com.au .co.uk .co.nz etc...
		return [NSString stringWithFormat:@"%@.%@.%@", [domainComponents objectAtIndex:thirdLastObject],
				[domainComponents objectAtIndex:secondLastObject], [domainComponents lastObject]];
	}
	

	NSRange dotRange = [domain rangeOfString:@"."];					//not a valid domain name
	if (dotRange.location == NSNotFound)
		return nil;
	
	return [domain lowercaseString];								//everything else
}

- (NSArray *) cookies
{
	if (_children == nil)
	{
		// cookies -> cookieBuckets
		NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		NSArray * cookies = [cs cookies];
		NSMutableDictionary * cookieBuckets = [NSMutableDictionary dictionary];
		NSHTTPCookie * cookie;
		for (cookie in cookies)
		{
			NSString * domain = [cookie domain];
			
			NSString * site = [[self class] _siteWithDomainName:domain importCookies:NO];
			if (site == nil)
				continue;
			NSMutableArray * siteCookies = [cookieBuckets objectForKey:site];
			if (siteCookies == nil)
			{
				siteCookies = [NSMutableArray array];
				[cookieBuckets setObject:siteCookies forKey:site];
			}
			[siteCookies addObject:cookie];
		}
		
		//get favorites from Favorites.plist
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
		NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
		NSMutableSet * unusedDomainSet = [NSMutableSet setWithArray:favoriteDomains];

		// cookieBuckets -> contentArray
		_children = [NSMutableArray new];
		for (NSString *key in cookieBuckets)
		{
			BOOL isFavorite = [favoriteDomains containsObject:key];
			if (isFavorite)
				[unusedDomainSet removeObject:key];
				
			NSArray * siteCookies = [cookieBuckets objectForKey:key];
			NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				siteCookies, @"cookies",
				key, @"domainOnly",
				[NSString stringWithFormat:@"%@ (%d)", key, [siteCookies count]], @"domain",
				key, @"searchDescription",
				[NSNumber numberWithBool:isFavorite], @"isFavorite",
				[NSNumber numberWithBool:NO], @"isLeaf",
				nil];
		
			[(NSMutableArray *)_children addObject:dict];
		}
	
		NSString * domain;
		for (domain in unusedDomainSet)
		{
			NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSArray array], @"cookies",
				domain, @"domainOnly",
				[NSString stringWithFormat:@"%@ (%d)", domain, 0], @"domain",
				[NSNumber numberWithBool:YES], @"isFavorite",
				[NSNumber numberWithBool:YES], @"isLeaf",
				nil];
		
			[(NSMutableArray *)_children addObject:dict];
		}
	}	
	return [_children autorelease];
}

+ (NSArray *) googleAnalyticsCookies
{
		NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		NSArray * cookies = [cs cookies];
		NSMutableArray * googleCookies = [NSMutableArray array];
		NSHTTPCookie * cookie;
	
		for (cookie in cookies)
		{
			NSString * name = [cookie name];
			
			NSRange range = [name rangeOfString:@"__utm"];
			if (range.location != NSNotFound)
			{
				[googleCookies addObject:cookie];
			}
		}
	
	return googleCookies;	
}

- (unsigned int) cookieCount
{
	return [[self cookies] count];
}

- (BOOL) isLeaf
{
	return YES;
}

@end


@implementation NSHTTPCookie (NSTreeControllerDataSource)

- (NSString *) searchDescription
{	
	NSMutableArray * strings = [NSMutableArray array];

	NSArray * keys = [NSArray arrayWithObjects:@"domain", @"name", @"path", @"expiresDate", @"value", nil];
	NSString * key;
	for (key in keys)
	{
		NSString * string = [[self valueForKey:key] description];
		[strings addObject:string];
	}

	return [strings componentsJoinedByString:@"\n"];
}

- (BOOL) isFavorite
{
	return NO;
}

- (BOOL) isLeaf
{
	return YES;
}

@end