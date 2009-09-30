//
//  CookiesOutlineViewController.m
//  SafariCookies
//
//  Created by John R Chang on 2006-02-04.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "CookiesOutlineViewController.h"
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
	for (id node in [cookiesTreeController content])
	{
		NSString * domain = [node valueForKey:@"domainOnly"];
		NSArray * siteCookies = [node valueForKey:@"cookies"];
		[node setObject:[NSString stringWithFormat:@"%@ (%d)", domain, [siteCookies count]] forKey:@"domain"];
	}
}

- (IBAction) removeAllNonFavorites:(id)sender
{
	NSArray * deleteCookies = [self nonFavoriteCookies];
	
	//if alert has been previously disabled, delete non favorites immediately
	if ([[SCPreferences userDefaults] boolForKey:SCPreferencesAlertsKey])
	{
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
		
		[SafariCookies deleteCookies:deleteCookies];
		[self reloadCookiesOutlineView];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Remove"];
	[alert setMessageText:NSLocalizedString(@"Are you sure you want to remove all \nnon-favorite cookies?",@"Remove non favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	
	int numDeleteCookies = [deleteCookies count];
	if (numDeleteCookies == 1)
	{
		[alert setInformativeText:NSLocalizedString(@"1 cookie will be deleted immediately.",@"Remove 1 non favorite confirmation dialog -> informative text")];
		goto alert_behaviour;
	}
	else
	{
		//add number of cookies to delete
		[alert setInformativeText: [NSString stringWithFormat: NSLocalizedString(@"%i cookies will be deleted immediately.", @"Remove non favorites confirmation dialog -> informative text"), numDeleteCookies]];
		goto alert_behaviour;
	}
	
alert_behaviour:
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
				[[SCPreferences userDefaults] setBool:YES forKey:SCPreferencesAlertsKey];
			}
		// Delete deleteCookies
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
		
		[SafariCookies deleteCookies:deleteCookies];
		[self reloadCookiesOutlineView];
	}
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