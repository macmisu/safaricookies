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


@implementation CookieNode

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

+ (NSString *) _siteWithDomainName:(NSString *)domain
{	
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

			NSString * site = [[self class] _siteWithDomainName:domain];
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
	return _children;
}

- (unsigned int) cookieCount
{
	return [[self cookies] count];
}

- (BOOL) isLeaf
{
	return YES;
}


@synthesize _prefsController;
@synthesize _children;
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
