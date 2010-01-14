//
//  CookiesOutlineViewController.m
//  SafariCookies
//
//  Created by John R Chang on 2006-02-04.
//  Modified by Russell Gray - www.sweetpproductions.com  April 09
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "CookiesOutlineViewController.h"
#import "SCController.h"
#import "CookieNode.h"


@implementation SCPreferencesModule (CookiesOutlineView)

- (NSArray *) cookiesContentArray
{
	CookieNode * rootNode = [[[CookieNode alloc] initWithPrefsController:self] autorelease];
	return [rootNode cookies];
}
	
- (void) reloadCookiesOutlineView
{
	//get current scrollposition
	NSPoint currentScrollPosition = [[cookiesScrollView contentView] bounds].origin;

	if (_isDeletingCookie == YES)
	{
		_isDeletingCookie = NO;
		return;
	}
		
	CookieNode * rootNode = [[CookieNode alloc] initWithPrefsController:self];
	[cookiesArrayController setContent:[rootNode cookies]];
	[rootNode release];
	
	//restore scroll position
	[[cookiesScrollView documentView] scrollPoint:currentScrollPosition];
	[self displayCookieCount];
}

- (NSArray *) favoriteDomains
{
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* domains = [favoritesDictionary objectForKey:@"Domains"];
	
	return domains;
}

- (NSArray *) favoriteDomainsFromTreeController
{
	NSMutableArray * domains = [NSMutableArray array];
	for (id node in [cookiesTreeController content])
	{
		if ([[node valueForKey:@"isFavorite"] boolValue])
			[domains addObject:[node valueForKey:@"domainOnly"]];
	}
	return domains;
}

- (NSArray *) allDomainsFromTreeController
{
	NSMutableArray * domains = [NSMutableArray array];
	for (id node in [cookiesTreeController content])
	{
		[domains addObject:[node valueForKey:@"domainOnly"]];
	}
	return domains;
}

- (IBAction) remove:(id)sender
{	
	NSArray * selectedObjects = [[self cookiesTreeController] selectedObjects];

	NSMutableArray * deleteCookies = [NSMutableArray array];
	NSMutableArray * deleteDomains = [NSMutableArray array];
	id object;
	for (object in selectedObjects)
	{
		BOOL isCookie = [object isKindOfClass:[NSHTTPCookie class]]; //valueForKey:@"isLeafNode"];
		if (isCookie)
			[deleteCookies addObject:object];
		else
			[deleteDomains addObject:[object valueForKey:@"domainOnly"]];
	}

	// Search for all existing cookies matching deleteDomains
	NSArray * moreDeleteCookies = [SCController cookiesMatchingDomains:deleteDomains match:YES];
	
	[deleteCookies addObjectsFromArray:moreDeleteCookies];
	
	_isDeletingCookie = YES;
	
	// Delete deleteCookies
	[SCController deleteCookies:deleteCookies];
	[self reloadCookiesOutlineView];
	return;
}

- (IBAction) removeAllNonFavorites:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	NSArray * deleteCookies = [self nonFavoriteCookies];
	
	//if alert has been previously disabled, delete non favorites immediately
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesRemoveAllAlertKey])
	{
		[SCController deleteCookies:deleteCookies];
		[self reloadCookiesOutlineView];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Remove", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Are you sure you want to remove all \nnon-favorite cookies?",nil, thisBundle, @"Remove non favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	
	int numDeleteCookies = [deleteCookies count];
	if (numDeleteCookies == 1)
	{
		[alert setInformativeText:NSLocalizedString(@"1 cookie will be deleted immediately.",@"Remove 1 non favorite confirmation dialog -> informative text")];
	}
	else
	{
		//add number of cookies to delete
		[alert setInformativeText: [NSString stringWithFormat: NSLocalizedStringFromTableInBundle(@"%d cookies will be deleted immediately.", nil, thisBundle, @"Remove non favorites confirmation dialog -> informative text"), numDeleteCookies]];
	}
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(removeAllNonFavoritesAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)removeAllNonFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
			{
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesRemoveAllAlertKey];
			}
		// Delete deleteCookies
		NSArray * deleteCookies = [self nonFavoriteCookies];
		
		[SCController deleteCookies:deleteCookies];
		[self reloadCookiesOutlineView];
	}
}

- (NSArray *) nonFavoriteCookies
{
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* domains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray * nonFavoriteCookies = [SCController cookiesMatchingDomains:domains match:NO];
	return nonFavoriteCookies;
	
}

- (NSArray *) allDisplayedCookies
{
	NSArray * allDomains = [self allDomainsFromTreeController];
	NSArray * allDisplayedCookies = [SCController cookiesMatchingDomains:allDomains match:YES];
	return allDisplayedCookies;
}

// save Favorite sites, to plist file immediately
- (IBAction) changeFavoriteSites:(id)sender
{
	NSString *searchString = [searchField stringValue];
	if ([searchString isEqualToString:@""])
	{
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		
		// Create our Favorites plist file.
		NSDictionary *output;
		NSArray * domains = [self favoriteDomainsFromTreeController];
		output = [NSDictionary dictionaryWithObjectsAndKeys:domains, @"Domains", nil];
		
		// Write the Favorites plist file.
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self displayCookieCount];
		
	}
	else
		//used only when favorites are changed within a search
	{
		// Create our Favorites plist file.
		NSDictionary *output;
		
		//get favorites from Favorites.plist
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
		NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
		
				
		//combine Favorites from favoriteDomains
		for (id node in [cookiesTreeController content])
		{
			//add favorites from cookiesTreeController
			if ([[node valueForKey:@"isFavorite"] boolValue])
			{
				[favoriteDomains addObject:[node valueForKey:@"domainOnly"]];
			}
			//remove non-favorites cookiesTreeController
			if  (![[node valueForKey:@"isFavorite"] boolValue])
			{
				[favoriteDomains removeObject:[node valueForKey:@"domainOnly"]];
			}
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self displayCookieCount];
	}
}

// synchronize Automatic Updating, to defaults immediately
- (IBAction) changeButtonState:(id)sender
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self reloadCookiesOutlineView];
	[self buttonCheck];
}

// synchronize Cookie Policy, to defaults and update Safari Cookie Policy immediately
- (IBAction) changeCookiePolicyButton:(id)sender
{	
	[[NSUserDefaults standardUserDefaults] synchronize];
	[SCPreferencesModule updateSafariPolicy];
}

// update cookiesOutlineView when SearchField changes
- (IBAction) changeSearchFieldText:(id)sender
{
	[self reloadCookiesOutlineView];
}

@end