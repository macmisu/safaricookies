//
//  CookiesOutlineViewController.m
//  SafariCookies
//
//  Created by John R Chang on 2006-02-04.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "CookiesOutlineViewController.h"
#import "NSLocalizedStringFromThisBundle.h"
#import "SafariCookies.h"
#import "SCPreferences.h"
#import "SCLogFile.h"
#import "CookieNode.h"

@implementation SCPreferencesModule (CookiesOutlineView)

-(id) init
{
	[SCPreferencesModule updateSafariPolicy];
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(_cookiesChangedNotification:) 
			   name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	NSNotificationCenter * ncquit = [NSNotificationCenter defaultCenter];
	[ncquit addObserver:self selector:@selector(_applicationWillTerminateNotification:) 
				   name:NSApplicationWillTerminateNotification object:nil];
	NSDistributedNotificationCenter * ncpolicy = [NSDistributedNotificationCenter defaultCenter];
	[ncpolicy addObserver:self selector:@selector(_cookiePolicyChangedNotification:) 
					 name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	return self;
}

- (NSArray *) cookiesContentArray
{
	CookieNode * rootNode = [[[CookieNode alloc] initWithPrefsController:self] autorelease];
	return [rootNode cookies];
}

- (void) setupCookiesOutlineView
{
	NSTableColumn * column = [cookiesOutlineView tableColumnWithIdentifier:@"domain"];
	[cookiesOutlineView setOutlineTableColumn:column];
	NSDateFormatter * dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	column = [cookiesOutlineView tableColumnWithIdentifier:@"expiresDate"];
	[[column dataCell] setFormatter:dateFormatter];
}
 
- (void) reloadCookiesOutlineView
{
	if (_isDeletingCookie == YES)
	{
		_isDeletingCookie = NO;
		[self changeFavoriteSites:nil];
		return;
	}


	CookieNode * rootNode = [[CookieNode alloc] initWithPrefsController:self];
	[cookiesTreeController setContent:[rootNode cookies]];
	[rootNode release];
	[self changeFavoriteSites:nil];
	[self displayCookieCount];
}

- (NSArray *) favoriteDomains
{
	if ([[cookiesTreeController content] count] == 0)
		return [[SCPreferences userDefaults] objectForKey:SCPreferencesAcceptCookieDomainsKey];
	else
		return [self favoriteDomainsFromTreeController];
}

- (NSArray *) favoriteDomainsFromTreeController
{
	NSMutableArray * domains = [NSMutableArray array];
	NSEnumerator * nodeEnumerator = [[cookiesTreeController content] objectEnumerator];
	id node;
	while ((node = [nodeEnumerator nextObject]))
	{
		if ([[node valueForKey:@"isFavorite"] boolValue])
			[domains addObject:[node valueForKey:@"domainOnly"]];
	}
	return domains;
}

- (NSArray *) allDomainsFromTreeController
{
	NSMutableArray * domains = [NSMutableArray array];
	NSEnumerator * nodeEnumerator = [[cookiesTreeController content] objectEnumerator];
	id node;
	while ((node = [nodeEnumerator nextObject]))
	{
			[domains addObject:[node valueForKey:@"domainOnly"]];
	}
	return domains;
}

- (IBAction) remove:(id)sender
{
	NSArray * selectedObjects = [cookiesTreeController selectedObjects];

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
	NSArray * moreDeleteCookies = [SafariCookies cookiesMatchingDomains:deleteDomains match:YES];
	[deleteCookies addObjectsFromArray:moreDeleteCookies];
	
	_isDeletingCookie = YES;
	
	//log cookie removal
	//log cookie removal
	int count = [deleteCookies count];
	if (count > 0)
	{
		int numDeleteCookies = [deleteCookies count];
		if (numDeleteCookies == 1)
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d cookie", count]];
		else
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d cookies", count]];
	}
	
	// Delete deleteCookies
	[SafariCookies deleteCookies:deleteCookies];
	[self reloadCookiesOutlineView];

	// Update content
	[cookiesTreeController remove:sender];
	
	// Update counts
	NSEnumerator * nodeEnumerator = [[cookiesTreeController content] objectEnumerator];
	id node;
	while ((node = [nodeEnumerator nextObject]))
	{
		NSString * domain = [node valueForKey:@"domainOnly"];
		NSArray * siteCookies = [node valueForKey:@"cookies"];
		[node setObject:[NSString stringWithFormat:@"%@ (%d)", domain, [siteCookies count]] forKey:@"domain"];
	}
}

- (IBAction) removeAndBlacklist:(id)sender
{
	NSArray * selectedObjects = [cookiesTreeController selectedObjects];
	
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
	NSArray * moreDeleteCookies = [SafariCookies cookiesMatchingDomains:deleteDomains match:YES];
	[deleteCookies addObjectsFromArray:moreDeleteCookies];
	
	_isDeletingCookie = YES;
	
	//log cookie removal and blacklist
	//log cookie removal
	int count = [deleteCookies count];
	int domainCount = [deleteDomains count];
	if (count > 0)
	{
		int numDeleteCookies = [deleteCookies count];
		if (numDeleteCookies == 1)
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d cookie, and added %d domain to blacklist", count, domainCount]];
		else
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d cookies, and added %d domains to blacklist", count, domainCount ]];
	}
	
	// Delete deleteCookies
	[SafariCookies deleteCookies:deleteCookies];
	[self reloadCookiesOutlineView];
	
	// Update content
	[cookiesTreeController remove:sender];
	
	// Update counts
	NSEnumerator * nodeEnumerator = [[cookiesTreeController content] objectEnumerator];
	id node;
	while ((node = [nodeEnumerator nextObject]))
	{
		NSString * domain = [node valueForKey:@"domainOnly"];
		NSArray * siteCookies = [node valueForKey:@"cookies"];
		[node setObject:[NSString stringWithFormat:@"%@ (%d)", domain, [siteCookies count]] forKey:@"domain"];
	}
}

- (IBAction) removeAllNonFavorites:(id)sender
{
	NSArray * deleteCookies = [self nonFavoriteCookies];
	
	//log cookie removal
	int count = [deleteCookies count];
	if (count > 0)
	{
		int numDeleteCookies = [deleteCookies count];
		if (numDeleteCookies == 1)
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d non-favorite cookie", count]];
		else
			[SCLogFile log:[NSString stringWithFormat:@"Deleted %d non-favorite cookies", count]];
	}
	
	// Show alert sheet
	NSString * messageTitle = NSLocalizedStringFromThisBundle(@"Are you sure you want to remove all \nnon-favorite cookies?", nil);
	NSString * informativeString;
	int numDeleteCookies = [deleteCookies count];
	if (numDeleteCookies == 1)
		informativeString = NSLocalizedStringFromThisBundle(@"1 cookie will be deleted immediately.", nil);
	else
		informativeString = [NSString stringWithFormat:NSLocalizedStringFromThisBundle(@"%d cookies will be deleted immediately.", nil), numDeleteCookies];
	NSString * defaultButtonTitle = NSLocalizedStringFromThisBundle(@"Remove", nil);	// R 1
	NSString * alternateButtonTitle = NSLocalizedStringFromThisBundle(@"Cancel", nil);			// L 0
	NSString * otherButtonTitle = nil;															// M -1
	NSAlert * alert = [NSAlert alertWithMessageText:messageTitle defaultButton:defaultButtonTitle alternateButton:alternateButtonTitle otherButton:otherButtonTitle informativeTextWithFormat:informativeString];

	[alert beginSheetModalForWindow:[_preferencesView window] modalDelegate:self didEndSelector:
		@selector(_removeAllNonFavoritesAlertDidEnd:returnCode:contextInfo:) contextInfo:[deleteCookies retain]];
}

- (void)_removeAllNonFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == 0)	// Cancel
		return;

	NSArray * deleteCookies = [(NSArray *)contextInfo autorelease];
	
	// Delete deleteCookies
	[SafariCookies deleteCookies:deleteCookies];
	[self reloadCookiesOutlineView];
}

- (NSArray *) nonFavoriteCookies
{
	NSArray * favoriteDomains = [self favoriteDomainsFromTreeController];
	NSArray * nonFavoriteCookies = [SafariCookies cookiesMatchingDomains:favoriteDomains match:NO];
	if ([nonFavoriteCookies count] == 0)
		return nil;
	return nonFavoriteCookies;
}

- (NSArray *) allDisplayedCookies
{
	NSArray * allDomains = [self allDomainsFromTreeController];
	NSArray * allDisplayedCookies = [SafariCookies cookiesMatchingDomains:allDomains match:YES];
	return allDisplayedCookies;
}

// synchronize Favorite sites, to defaults immediately
- (IBAction) changeFavoriteSites:(id)sender
{
	NSArray * domains = [self favoriteDomainsFromTreeController];
	[[SCPreferences userDefaults] setObject:domains forKey:SCPreferencesAcceptCookieDomainsKey];
	[[SCPreferences userDefaults] synchronize];
	[self displayCookieCount];
}

// synchronize Enable Log, to defaults immediately
- (IBAction) changeLogButton:(id)sender
{
	[[SCPreferences userDefaults] synchronize];
}

// synchronize Remove Cookies on quit, to defaults immediately
- (IBAction) changeRemoveOnQuitButton:(id)sender
{
	[[SCPreferences userDefaults] synchronize];
}

// synchronize Cookie Policy, to defaults and update Safari Cookie Policy immediately
- (IBAction) changeCookiePolicyButton:(id)sender
{	
	[[SCPreferences userDefaults] synchronize];
	[SCPreferencesModule updateSafariPolicy];
}

@end