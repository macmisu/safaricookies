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
#import "NSHTTPCookieStorageAdditions.h"
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

- (IBAction) search:(id)sender
{
	
	[self reloadCookiesOutlineView];
}

- (void) displayCookieCount
{
	NSArray * numFavorites = [self favoriteDomainsFromTreeController];
	NSArray * numDomains = [cookiesTreeController content];
	NSArray * numCookies = [self allDisplayedCookies];
	
	int totalFavoriteDomains = [numFavorites count];
	int totalNumDomains = [numDomains count];
	int totalNumCookies = [numCookies count];
	[numberOfCookiesStatusLine setStringValue:[NSString stringWithFormat:@"%i Domains, %i Favorites, %i unique Cookies", totalNumDomains, totalFavoriteDomains, totalNumCookies]];
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

/*
//Hide disclosure triangles for cookies, and domains with no cookies ***there must be a better/faster way to do this!!
- (void)outlineView:(NSOutlineView *)cookiesOutlineView
		willDisplayOutlineCell:(id)cell 
		forTableColumn:(NSTableColumn *)tableColumn 
		item:(id)item
{
	if ([item count] != 0)
		[cell setTransparent:NO];
	else
		[cell setTransparent:YES];
		
}
*/
 
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

- (void) _cookiesChangedNotification:(NSNotification *)notification
{
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

-(void) awakeFromNib
{
	[self displayCookieCount];
	NSSortDescriptor* theDefaultSortDescriptor = 
    [[NSSortDescriptor alloc] initWithKey:@"domain" ascending:YES];
	[cookiesOutlineView setSortDescriptors:[NSArray arrayWithObject: theDefaultSortDescriptor]];
}

- (void) _applicationWillTerminateNotification:(NSNotification *)notification
{	
	NSArray * domains = [self favoriteDomainsFromTreeController];
	[[SCPreferences userDefaults] setObject:domains forKey:SCPreferencesAcceptCookieDomainsKey];
	[[SCPreferences userDefaults] synchronize];
	if ([[SCPreferences userDefaults] boolForKey:SCPreferencesRemoveNonFavoritesWhenQuitting])
	{
		NSArray * deleteCookies = [self nonFavoriteCookies];
		
		int count = [deleteCookies count];
		if (count > 0)
		{
			int numDeleteCookies = [deleteCookies count];
			if (numDeleteCookies == 1)
				[SCLogFile log:[NSString stringWithFormat:@"Deleting %d non-favorite cookie on quit", count]];
			else
				[SCLogFile log:[NSString stringWithFormat:@"Deleting %d non-favorite cookies on quit", count]];
			
			// Flush
			NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
			[cs _spFlush];
		}
	}
}

@end