//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


#import "Constants.h"
#import "FlashTableViewController.h"
#import "BundleUserDefaults.h"


@implementation SCPreferencesModule (FlashTableView)

- (NSArray *) flashContentArray
{
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	
	NSArray *flashCookiesArray = [[NSFileManager defaultManager]
								  contentsOfDirectoryAtPath:[SCFlashCookiesFolder stringByExpandingTildeInPath] error:nil];
	
	NSMutableArray *newArray = [[NSMutableArray new] autorelease];
	for (NSString *flashCookie in favoriteDomains)							//add all favorites
	{
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									flashCookie, @"flashCookie",
									[NSNumber numberWithBool:YES], @"isFlashFavorite",
									nil];
		[newArray addObject:dict];
	}
	
	for (NSString *flashCookie in flashCookiesArray)
	{
		if ([flashCookie characterAtIndex:0] == '#') {
			flashCookie = [flashCookie substringFromIndex:1];
			
			if ([favoriteDomains containsObject:flashCookie]) {				//set as favorite
				NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											 flashCookie, @"flashCookie",
											 [NSNumber numberWithBool:YES], @"isFlashFavorite",
											 nil];
				[newArray addObject:dict];
				continue;
			}
			
			NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 flashCookie, @"flashCookie",
										[NSNumber numberWithBool:NO], @"isFlashFavorite",
										 nil];
			[newArray addObject:dict];
		}
	}
	NSArray* uniqueCookies = [[NSSet setWithArray:newArray] allObjects];
	return uniqueCookies;
}

- (void) reloadFlashTableView
{	
	[flashArrayController setContent:[self flashContentArray]];
	[flashTableView reloadData];
	[self displayFlashCount];
}

- (IBAction) removeFlash:(id)sender
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	NSMutableArray *flashArray = [NSMutableArray arrayWithArray:[flashArrayController content]];
	NSArray *deleteArray = [flashArrayController selectedObjects];
	NSMutableArray* deleteFavoriteFlashDomains = [[NSMutableArray new] autorelease];
	
	
	for (NSDictionary *flashCookieDict in deleteArray)											//delete Flash cookie folders
	{
		NSString *flashCookie = [flashCookieDict valueForKey:@"flashCookie"];
		flashCookie = [NSString stringWithFormat:@"#%@", flashCookie];
		
		if ([flashCookieDict valueForKey:@"isFlashFavorite"] == [NSNumber numberWithBool:YES]) {
			[deleteFavoriteFlashDomains addObject:flashCookie];
		}
		
		NSString *flashCookiePath = [SCFlashCookiesFolder stringByExpandingTildeInPath];
		flashCookiePath = [flashCookiePath stringByAppendingPathComponent:flashCookie];
		
		[[NSFileManager defaultManager] removeItemAtPath:flashCookiePath error:nil];
	}
	
	[flashArray removeObjectsInArray:[flashArrayController selectedObjects]];
	[flashArrayController setContent:flashArray];
	if ([favoriteDomains count] == [deleteFavoriteFlashDomains count]) {
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		
		[self displayFlashCount];
		[self checkDeleteFlashFolder];
		return;
	}
	
	[favoriteFlashDomains removeObjectsInArray:deleteFavoriteFlashDomains];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	

	[self displayFlashCount];
	[self checkDeleteFlashFolder];
}

- (NSArray *) favoriteFlashFromArrayController
{
	NSMutableArray * domains = [NSMutableArray array];
	for (id node in [flashArrayController arrangedObjects])
	{
		if ([[node valueForKey:@"isFlashFavorite"] boolValue])
			[domains addObject:[node valueForKey:@"flashCookie"]];
	}
	return domains;
}

- (NSArray *) nonFavoriteFlashFromArrayController
{
	NSMutableArray * domains = [NSMutableArray array];
	for (id node in [flashArrayController arrangedObjects])
	{
		if ([[node valueForKey:@"isFlashFavorite"] boolValue] == NO)
			[domains addObject:[node valueForKey:@"flashCookie"]];
	}
	return domains;
}

- (NSArray *) allFlashFromArrayController
{
	NSMutableArray * domains = [NSMutableArray array];
	for (id node in [flashArrayController arrangedObjects])
	{
		[domains addObject:[node valueForKey:@"flashCookie"]];
	}
	return domains;
}

- (NSArray *) flashDeleteArray
{
	NSMutableArray * deleteFlash = [[NSMutableArray new] autorelease];
	for (id node in [flashArrayController arrangedObjects])
	{
		if ([[node valueForKey:@"isFlashFavorite"] boolValue] == NO)
			[deleteFlash addObject:node];
	}
	return deleteFlash;
}

- (NSArray *) flashKeepArray
{
	NSMutableArray * favoriteFlash = [[NSMutableArray new] autorelease];
	for (id node in [flashArrayController arrangedObjects])
	{
		if ([[node valueForKey:@"isFlashFavorite"] boolValue] == YES)
			[favoriteFlash addObject:node];
	}
	return favoriteFlash;
}

- (void) checkDeleteFlashFolder
{
	NSArray * checkDeleteFlash = [self flashDeleteArray];							//If there are no flash cookies, we might
	NSArray * checkFavoriteFlash = [self flashKeepArray];							//as well delete the entire folder
	
	if ([checkDeleteFlash count] == 0 && [checkFavoriteFlash count] == 0) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *flashCookiesFolder = [SCFlashCookiesPath stringByExpandingTildeInPath];
		if ([fm fileExistsAtPath:flashCookiesFolder])
		{
			[fm removeItemAtPath:flashCookiesFolder error:NULL];
		}
	}
}

- (IBAction) removeAllNonFavoriteFlash:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	NSArray * deleteFlash = [self flashDeleteArray];
	
	//if alert has been previously disabled, delete non favorites immediately
	BundleUserDefaults *defaults = [[BundleUserDefaults alloc] initWithPersistentDomainName:BundleIdentifier];
	BOOL noFlashAlert = [defaults boolForKey:SCPreferencesRemoveFlashAlertKey];
	
	if (noFlashAlert == YES)
	{
		NSArray * favoriteFlash = [self flashKeepArray];
		[flashArrayController setContent:favoriteFlash];
		 
		for (NSDictionary *flashDict in deleteFlash)									//delete Flash cookie folders
		{
			NSString *flashCookie = [flashDict valueForKey:@"flashCookie"];
			flashCookie = [NSString stringWithFormat:@"#%@", flashCookie];
			NSString *flashCookiePath = [SCFlashCookiesFolder stringByExpandingTildeInPath];
			flashCookiePath = [flashCookiePath stringByAppendingPathComponent:flashCookie];
			
			[[NSFileManager defaultManager] removeItemAtPath:flashCookiePath error:nil];
		}
		[self reloadFlashTableView];
		[self checkDeleteFlashFolder];
		[defaults release];
		return;
	}
	
	[defaults release];
	
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Remove", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Are you sure you want to remove all \nnon-favorite Flash cookies?",nil, thisBundle, @"Remove non flash favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	
	int numDeleteFlash = [deleteFlash count];
	if (numDeleteFlash == 1)
		[alert setInformativeText:NSLocalizedString(@"1 Flash cookie will be deleted immediately.",@"Remove 1 non favorite Flash confirmation dialog -> informative text")];
	else
	{
		//add number of flash cookies to delete
		[alert setInformativeText: [NSString stringWithFormat: NSLocalizedStringFromTableInBundle(@"%d Flash cookies will be deleted immediately.", nil, thisBundle, @"Remove non Flash favorites confirmation dialog -> informative text"), numDeleteFlash]];
	}
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(removeAllNonFavoriteFlashAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)removeAllNonFavoriteFlashAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			BundleUserDefaults *defaults = [[BundleUserDefaults alloc] initWithPersistentDomainName:BundleIdentifier];
			[defaults setBool:YES forKey:SCPreferencesRemoveFlashAlertKey];
			[defaults release];
		}

		NSArray * deleteFlash = [self flashDeleteArray];
		NSArray * favoriteFlash = [self flashKeepArray];
		[flashArrayController setContent:favoriteFlash];
		
		for (NSDictionary *flashDict in deleteFlash)									//delete Flash cookie folders
		{
			NSString *flashCookie = [flashDict valueForKey:@"flashCookie"];
			flashCookie = [NSString stringWithFormat:@"#%@", flashCookie];
			NSString *flashCookiePath = [SCFlashCookiesFolder stringByExpandingTildeInPath];
			flashCookiePath = [flashCookiePath stringByAppendingPathComponent:flashCookie];
			
			[[NSFileManager defaultManager] removeItemAtPath:flashCookiePath error:nil];
		}
		[self reloadFlashTableView];
		[self checkDeleteFlashFolder];
	}
}

- (IBAction) changeFlashSearchFieldText:(id)sender
{
	[self reloadFlashTableView];
}

@end


@implementation NSObject (NSArrayContollerDataSource)


- (BOOL) isFlashFavorite
{
	return NO;
}


@end