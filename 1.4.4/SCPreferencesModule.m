//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


#import "SCPreferencesModule.h"
#import "Constants.h"
#import "SCHelper.h"
#import "SCController.h"
#import "SCPreferencesModule.h"
#import "CookiesOutlineViewController.h"
#import "FlashTableViewController.h"
#import "CookieNode.h"
#import <Sparkle/Sparkle.h>

void flashCallback(ConstFSEventStreamRef streamRef,
					   void *clientCallBackInfo,
					   size_t numEvents,
					   void *eventPaths,
					   const FSEventStreamEventFlags eventFlags[],
					   const FSEventStreamEventId eventIds[])
{
	CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
	CFNotificationCenterPostNotification(center,CFSTR("flashCookiesChanged"),NULL, NULL, true);
}

@implementation SCPreferencesModule
@synthesize versionLabel, tabView, cookiesTreeController, cookiesArrayController, cookiesOutlineView,
			flashArrayController, flashTableView, cookiesScrollView, aboutTextView, _isDeletingCookie,
			removeAllNonFavoritesButton, removeAllNonFavoritesFlashButton, searchField,
			flashSearchField, numberOfCookiesStatusLine, favoritesPlistExportFilepath,
			numberOfFlashCookiesStatusLine, plistPath, updater;


-(id) init
{
	[SCPreferencesModule updateSafariPolicy];
	
	//register observers
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cookiesChangedNotification:) 
			name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_cookiePolicyChangedNotification:) 
			name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFlashTableView) name:@"flashCookiesChanged" object:nil];
	return self;
}

-(void) awakeFromNib
{
	// Sparkle
	updater = [SUUpdater updaterForBundle:[NSBundle bundleWithIdentifier:BundleIdentifier]];
	[updater setDelegate:self];
	[updater setSendsSystemProfile:NO];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesShouldCheckForUpdates])
	{
		[updater setAutomaticallyChecksForUpdates:YES];
	}
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesShouldCheckForUpdates])
	{
		[updater setAutomaticallyChecksForUpdates:NO];
	}
	
	//set initial display setup of cookiesOutlineView
	NSTableColumn * column = [cookiesOutlineView tableColumnWithIdentifier:@"domain"];
	[cookiesOutlineView setOutlineTableColumn:column];
	NSDateFormatter * dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	column = [cookiesOutlineView tableColumnWithIdentifier:@"expiresDate"];
	[[column dataCell] setFormatter:dateFormatter];
	
	NSSortDescriptor* theDefaultSortDescriptor = 
    [[NSSortDescriptor alloc] initWithKey:@"domain" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
	[cookiesOutlineView setSortDescriptors:[NSArray arrayWithObject: theDefaultSortDescriptor]];
	[cookiesOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	
	CookieNode * rootNode = [[CookieNode alloc] initWithPrefsController:self];
	[cookiesArrayController setContent:[rootNode cookies]];
	[rootNode release];
	
	[theDefaultSortDescriptor release];
	
	//set initial display setup of flashTableView
	NSTableColumn * flashColumn = [flashTableView tableColumnWithIdentifier:@"flashdomain"];
	[flashTableView setHighlightedTableColumn:flashColumn];
	NSSortDescriptor* flashSortDescriptor = 
    [[NSSortDescriptor alloc] initWithKey:@"flashCookie" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
	[flashTableView setSortDescriptors:[NSArray arrayWithObject: flashSortDescriptor]];
	[flashTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[flashSortDescriptor release];
	
	
	[self displayCookieCount];
	[self displayFlashCount];
	[self reloadTabOnLaunch];
	
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	NSString * rtfFilePath = [thisBundle pathForResource:@"Credits" ofType:@"rtf"];
	[aboutTextView readRTFDFromFile:rtfFilePath];
	
	//FSEvents
	
	NSString *flashPath = @"~/Library/Preferences/Macromedia";
	flashPath = [flashPath stringByStandardizingPath];
	
	CFStringRef path = (CFStringRef)flashPath;
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&path, 1, NULL);
	void *callbackInfo = NULL;
	CFAbsoluteTime latency = 0;
	
    _stream = FSEventStreamCreate(NULL,
								  &flashCallback,
								  callbackInfo,
								  pathsToWatch,
								  kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
								  latency,
								  kFSEventStreamCreateFlagNone /* Flags explained in reference */
								  );
    
    FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(_stream);
}

+ (NSImage*) preloadImage: (NSString*) theName
{
	NSImage* image = nil;
	NSString* imagePath = [[NSBundle bundleWithIdentifier: BundleIdentifier] 
						   pathForImageResource: theName];
	if (!imagePath)
	{
		return nil;
	}
	image = [[NSImage alloc] initByReferencingFile: imagePath];
	if (!image)
	{
		return nil;
	}
	[image setName: theName];
	return [image autorelease];
}

- (NSString *)preferencesNibName {
	return @"SCPreferences";
}

- (NSImage*) imageForPreferenceNamed: (NSString*) theName
{
	NSImage* image = [NSImage imageNamed: @"SafariCookies.png"];
	if (image == nil) {
		image = [SCPreferencesModule preloadImage: @"SafariCookies.png"];
	}
	return image;
}

- (NSView*)viewForPreferenceNamed:(NSString *)Name
{
#pragma unused(Name)
	if (!_preferencesView)
		[NSBundle loadNibNamed:[self preferencesNibName] owner:self];
	return _preferencesView;
}

- (void)moduleWasInstalled
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	[self setVersionLabel:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Current Version: %@", nil, thisBundle, @"Preferences -> General tab -> current version label"), [SCController version]]];
}

- (NSSize) minSize {
	return NSMakeSize(622.0,332);
}

- (BOOL) isResizable {
	return YES;
}

- (void) reloadTabOnLaunch
{
	int tabState;
	tabState = [[NSUserDefaults standardUserDefaults] integerForKey:SCPreferencesTabStateKey];
	[tabView selectTabViewItemAtIndex:tabState];
}

- (void) displayCookieCount
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	[self buttonCheck];
	NSArray * numFavorites = [self favoriteDomainsFromTreeController];
	NSArray * numDomains = [cookiesTreeController content];
	NSArray * numCookies = [self allDisplayedCookies];
	
	int totalFavoriteDomains = [numFavorites count];
	int totalNumDomains = [numDomains count];
	int totalNumCookies = [numCookies count];
	[numberOfCookiesStatusLine setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Domains, %d Favorites, %d unique Cookies", nil, thisBundle, nil), totalNumDomains, totalFavoriteDomains, totalNumCookies]];
}

- (void) displayFlashCount
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	NSArray * numFlashCookies = [flashArrayController arrangedObjects];
	int count = 0;
	
	for (NSDictionary *flashDict in numFlashCookies)
	{
		if([flashDict valueForKey:@"isFlashFavorite"] == [NSNumber numberWithBool:YES])
		{
			count++;
		}
	}
	
	int totalFavoriteFlashCookies = count;
	int totalNumFlashCookies = [[flashArrayController arrangedObjects] count];
	[numberOfFlashCookiesStatusLine setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Flash Cookies, %d Favorites", nil, thisBundle, nil), totalNumFlashCookies, totalFavoriteFlashCookies]];
}

- (void) exportConfirmed
{
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	
	NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	NSString* favoritesString = [favoriteDomains componentsJoinedByString:@"\n"];
	NSMutableArray* finalFlashArray = [[NSMutableArray new] autorelease];
	
	for (NSString *flashCookie in favoriteFlashDomains)
	{
		flashCookie = [NSString stringWithFormat:@"flashCookie:%@", flashCookie];			
		[finalFlashArray addObject:flashCookie];
	}
	
	NSString* favoritesFlashString = [finalFlashArray componentsJoinedByString:@"\n"];
	
	favoritesString = [NSString stringWithFormat:@"%@\n%@", favoritesString, favoritesFlashString];
	
	
	NSSavePanel *savePanel;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setExtensionHidden:YES];
	// Only allow our specific file type
	[savePanel setRequiredFileType:@"txt"];
	// Disable ability to show file extension
	[savePanel setCanSelectHiddenExtension:NO];
	// Make sure files are not treated as directories
	[savePanel setTreatsFilePackagesAsDirectories:NO];
	if( [savePanel runModal] == NSOKButton )
	{
		
		NSFileManager *fm = [NSFileManager defaultManager];
		// create the file
		
		if( ![fm fileExistsAtPath:[savePanel filename]] )
		{
			[favoritesString writeToFile:[savePanel filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
		
		if( [fm fileExistsAtPath:[savePanel filename]] )
		{
			[fm removeItemAtPath:[savePanel filename] error:nil];
			[favoritesString writeToFile:[savePanel filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

- (IBAction)exportFavorites:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	//if alert has been previously disabled, go straight to file save
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesExportAlertKey])
	{
		[self exportConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to export all your Favorite domains?",nil, thisBundle, @"Export favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"Cookies will NOT be exported.", nil, thisBundle, @"Export Cookies confirmation dialog -> informative text")];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(exportFavoritesAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)exportFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesExportAlertKey];
		}
		[self exportConfirmed];
	}
}

- (void) importConfirmed
{
	NSOpenPanel *openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setResolvesAliases:YES];
	[openPanel setCanChooseFiles:YES];
	
	NSArray *fileTypes = [NSArray arrayWithObjects: @"txt", nil];
	
	if ([openPanel runModalForTypes:fileTypes] == NSOKButton)
	{				
		// Create our Favorites plist file.
		NSDictionary *output;
		
		//get favorites from Favorites.plist
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
		NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
		NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
		
		//get backup Favorites
		NSString *fileContents = [NSString stringWithContentsOfFile:[openPanel filename]
														   encoding:NSASCIIStringEncoding error:nil];
		NSArray* backupDomains = [fileContents componentsSeparatedByString:@"\n"];
		
		if ([favoriteDomains count] == 0 && [favoriteFlashDomains count] == 0)
		{		
			NSMutableArray * moreFavoriteDomains = [NSMutableArray array];
			NSMutableArray * moreFavoriteFlashCookies = [NSMutableArray array];
			for (NSString *favorite in backupDomains)
			{
				if ([favorite isEqualToString:@""])
					continue;
				
				if ([favorite hasPrefix:@"flashCookie:"]) {
					favorite = [favorite substringFromIndex:12];
					[moreFavoriteFlashCookies addObject:favorite];
					continue;
				}
				[moreFavoriteDomains addObject:favorite];
			}
			
			// Write the Favorites plist file
			output = [NSDictionary dictionaryWithObjectsAndKeys:moreFavoriteDomains, @"Domains", moreFavoriteFlashCookies, @"Flash", nil];
			[output writeToFile:favoriteDomainsPlistPath atomically:YES];
			
			[self reloadCookiesOutlineView];
			[self reloadFlashTableView];
			return;
		}
		
		if ([favoriteDomains count] == 0)
		{
			NSMutableArray * moreFavoriteDomains = [NSMutableArray array];
		
			for (NSString *favorite in backupDomains)
			{
				if ([favorite isEqualToString:@""])
					continue;
				
				if ([favorite hasPrefix:@"flashCookie:"]) {
					favorite = [favorite substringFromIndex:12];
					[favoriteFlashDomains addObject:favorite];
					continue;
				}
				[moreFavoriteDomains addObject:favorite];
			}
		
			//use NSSet, so domains don't get added multiple times
			NSArray* uniqueFavoriteFlashDomains = [[NSSet setWithArray:favoriteFlashDomains] allObjects];
		
			// Write the Favorites plist file
			output = [NSDictionary dictionaryWithObjectsAndKeys:moreFavoriteDomains, @"Domains", uniqueFavoriteFlashDomains, @"Flash", nil];
			[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
			[self reloadCookiesOutlineView];
			[self reloadFlashTableView];
			return;
		}
		
		if ([favoriteFlashDomains count] == 0)
		{
			NSMutableArray * moreFavoriteFlashCookies = [NSMutableArray array];
			
			for (NSString *favorite in backupDomains)
			{
				if ([favorite isEqualToString:@""])
					continue;
				
				if ([favorite hasPrefix:@"flashCookie:"]) {
					favorite = [favorite substringFromIndex:12];
					[moreFavoriteFlashCookies addObject:favorite];
					continue;
				}
				[favoriteDomains addObject:favorite];
			}
			
			//use NSSet, so domains don't get added multiple times
			NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
			
			// Write the Favorites plist file
			output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", moreFavoriteFlashCookies, @"Flash", nil];
			[output writeToFile:favoriteDomainsPlistPath atomically:YES];
			
			[self reloadCookiesOutlineView];
			[self reloadFlashTableView];
			return;
		}
		
		for (NSString *favorite in backupDomains)
		{
			if ([favorite hasPrefix:@"flashCookie:"]) {
				favorite = [favorite substringFromIndex:12];
				[favoriteFlashDomains addObject:favorite];
				continue;
			}
			[favoriteDomains addObject:favorite];
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteFlashDomains = [[NSSet setWithArray:favoriteFlashDomains] allObjects];
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", uniqueFavoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		[self reloadFlashTableView];
		return;
	}
}

- (IBAction)importFavorites:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	//if alert has been previously disabled, go straight to file import
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesImportAlertKey])
	{
		[self importConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to import Favorites from a previously exported file?", nil, thisBundle, @"Import favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"Your backup Favorites, will be added to your current Favorites.", nil, thisBundle, @"Import Favorites warning dialog -> informative text")];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(importFavoritesAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)importFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesImportAlertKey];
		}
		[self importConfirmed];
	}
}

+ (NSArray *)getBookmarkUrlsFrom:(NSDictionary *)subtree
{
    NSDictionary *child, *grandchild;
    NSMutableArray *bookmarks = [[[NSMutableArray alloc] init] autorelease];
	
	for (child in subtree)
		if ((grandchild = [child objectForKey:@"URLString"]) != nil)
		{
            [bookmarks addObject:(NSString *)grandchild];
        } else {
            bookmarks = [NSMutableArray
						 arrayWithArray:[bookmarks arrayByAddingObjectsFromArray: [self getBookmarkUrlsFrom:[child objectForKey:@"Children"]]]];
        }
    return bookmarks;
}

+ (NSArray *)getTopSiteUrlsFrom:(NSDictionary *)subtree
{
    NSDictionary *child, *grandchild;
    NSMutableArray *topSites = [[[NSMutableArray alloc] init] autorelease];
	
    for (child in subtree)
        if ((grandchild = [child objectForKey:@"TopSiteURLString"]) != nil)
		{
            [topSites addObject:(NSString *)grandchild];
        } else {
            topSites = [NSMutableArray
						 arrayWithArray:[topSites arrayByAddingObjectsFromArray: [self getTopSiteUrlsFrom:[child objectForKey:@"TopSites"]]]];
        }
    return topSites;
}

+ (NSArray *)getHistoryUrlsFrom:(NSDictionary *)subtree
{
    NSDictionary *child, *grandchild;
    NSMutableArray *history = [[[NSMutableArray alloc] init] autorelease];
	
    for (child in subtree)
        if ((grandchild = [child objectForKey:@""]) != nil)
		{
            [history addObject:(NSString *)grandchild];
        } else {
            history = [NSMutableArray
						 arrayWithArray:[history arrayByAddingObjectsFromArray: [self getHistoryUrlsFrom:[child objectForKey:@"WebHistoryDates"]]]];
        }
    return history;
}

+ (NSArray *)getBookmarks
{
	
	//get the Safari Bookmarks folder
	NSString *safariSupportFolder = [SafariSupportFolderPath stringByExpandingTildeInPath];
	NSString *bookmarksPlistPath = [safariSupportFolder stringByAppendingPathComponent:SafariBookmarksPlistFullName];
    NSDictionary *bookmarksDict = [NSDictionary dictionaryWithContentsOfFile:bookmarksPlistPath];
	
    return [self getBookmarkUrlsFrom:[bookmarksDict objectForKey:@"Children"]];
}

+ (NSArray *)getTopSites
{
	
	//get the Safari TopSites folder
	NSString *safariSupportFolder = [SafariSupportFolderPath stringByExpandingTildeInPath];
	NSString *topSitesPlistPath = [safariSupportFolder stringByAppendingPathComponent:SafariTopSitesPlistFullName];
    NSDictionary *topSitesDict = [NSDictionary dictionaryWithContentsOfFile:topSitesPlistPath];
	
    return [self getTopSiteUrlsFrom:[topSitesDict objectForKey:@"TopSites"]];
}

+ (NSArray *)getHistory
{
	
	//get the Safari History folder
	NSString *safariSupportFolder = [SafariSupportFolderPath stringByExpandingTildeInPath];
	NSString *historyPlistPath = [safariSupportFolder stringByAppendingPathComponent:SafariHistoryPlistFullName];
    NSDictionary *historyDict = [NSDictionary dictionaryWithContentsOfFile:historyPlistPath];
	
    return [self getHistoryUrlsFrom:[historyDict objectForKey:@"WebHistoryDates"]];
}

+ (NSArray *) autoModeDomains
{
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	NSArray *safariBookmarks = [self getBookmarks];
	NSArray *safariTopSites = [self getTopSites];
	NSArray *safariHistory = [self getHistory];
	
	NSMutableArray* domains = [NSMutableArray array];
	
	//process favoriteDomains down to their respective domains, and add to autoModeDomains
	for (id node in favoriteDomains)
	{
		//add favoriteDomains to favorites
		NSString * moreFavoriteDomains = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (moreFavoriteDomains != nil)
		{
			[domains addObject:moreFavoriteDomains];
		}
	}
	
	//add favoriteFlashDomains to autoModeDomains
	[domains addObjectsFromArray:favoriteFlashDomains];
	
	//process safariBookmarks down to their respective domains, and add to autoModeDomains
	for (id node in safariBookmarks)
	{
		//add safariBookmarks to favorites
		NSString * safariBookmarkDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariBookmarkDomain != nil)
		{
			[domains addObject:safariBookmarkDomain];
		}
	}
	
	//process safariTopSites down to their respective domains, and add to autoModeDomains
	for (id node in safariTopSites)
	{
		//add safariTopSites to favorites
		NSString * safariTopSiteDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariTopSiteDomain != nil)
		{
			[domains addObject:safariTopSiteDomain];
		}
	}
	
	//process safariHistory down to their respective domains, and add to autoModeDomains
	for (id node in safariHistory)
	{
		//add safariHistory to favorites
		NSString * safariHistoryDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariHistoryDomain != nil)
		{
			[domains addObject:safariHistoryDomain];
		}
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueDomains = [[NSSet setWithArray:domains] allObjects];
	

	return uniqueDomains;
}

- (void) importFromBookmarksConfirmed
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	
	NSArray *safariBookmarks = [SCPreferencesModule getBookmarks];
	
	if ([favoriteDomains count] == 0)
	{
		NSMutableArray* moreFavoriteDomains = [NSMutableArray array];
		
		//process safariBookmarks down to their respective domains, and add to Favorites
		for (id node in safariBookmarks)
		{
			//add safariBookmarks to favorites
			NSString * safariBookmarkDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
			
			if (safariBookmarkDomain != nil)
			{
				[moreFavoriteDomains addObject:safariBookmarkDomain];
			}
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:moreFavoriteDomains] allObjects];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		return;
	}
	
	//process safariBookmarks down to their respective domains, and add to Favorites
	for (id node in safariBookmarks)
	{
		//add safariBookmarks to favorites
		NSString * safariBookmarkDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariBookmarkDomain != nil)
		{
			[favoriteDomains addObject:safariBookmarkDomain];
		}
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
}

- (IBAction)importFavoritesFromBookmarks:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	//if alert has been previously disabled, go straight to file import
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesImportFromBookmarksAlertKey])
	{
		[self importFromBookmarksConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to import Favorites from your Safari Bookmarks?", nil, thisBundle, @"Import favorites from Bookmarks confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"Your Bookmarks will be added to your current favorites.", nil, thisBundle, @"Import Bookmarks warning dialog -> informative text")];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(importFavoritesFromBookmarksAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)importFavoritesFromBookmarksAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesImportFromBookmarksAlertKey];
		}
		[self importFromBookmarksConfirmed];
	}
}

- (void) importFromTopSitesConfirmed
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	
	NSArray *safariTopSites = [SCPreferencesModule getTopSites];
	
	if ([favoriteDomains count] == 0)
	{
		NSMutableArray* moreFavoriteDomains = [NSMutableArray array];
		
		//process safariTopSites down to their respective domains, and add to Favorites
		for (id node in safariTopSites)
		{
			//add safariTopSites to favorites
			NSString * safariTopSiteDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
			
			if (safariTopSiteDomain != nil)
			{
				[moreFavoriteDomains addObject:safariTopSiteDomain];
			}
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:moreFavoriteDomains] allObjects];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		return;
	}
	
	//process safariTopSites down to their respective domains, and add to Favorites
	for (id node in safariTopSites)
	{
		//add safariTopSites to favorites
		NSString * safariTopSiteDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariTopSiteDomain != nil)
		{	
			[favoriteDomains addObject:safariTopSiteDomain];
		}
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
}

- (IBAction)importFavoritesFromTopSites:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	//if alert has been previously disabled, go straight to file import
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesImportFromTopSitesAlertKey])
	{
		[self importFromTopSitesConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to import Favorites from your Safari TopSites?", nil, thisBundle, @"Import favorites from TopSites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"Your TopSites will be added to your current favorites.", nil, thisBundle, @"Import Topsites warning dialog -> informative text")];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(importFavoritesFromTopSitesAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)importFavoritesFromTopSitesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesImportFromTopSitesAlertKey];
		}
		[self importFromTopSitesConfirmed];
	}
}

- (void) importFromHistoryConfirmed
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	
	NSArray *safariHistory = [SCPreferencesModule getHistory];
	
	
	if ([favoriteDomains count] == 0)
	{
		NSMutableArray* moreFavoriteDomains = [NSMutableArray array];
		
		//process safariHistory down to their respective domains, and add to Favorites
		for (id node in safariHistory)
		{
			//add safariHistory to favorites
			NSString * safariHistoryDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
			
			if (safariHistoryDomain != nil)
			{
				[moreFavoriteDomains addObject:safariHistoryDomain];
			}
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:moreFavoriteDomains] allObjects];
		
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		return;
	}
	
	//process safariHistory down to their respective domains, and add to Favorites
	for (id node in safariHistory)
	{
		//add safariHistory to favorites
		NSString * safariHistoryDomain = [CookieNode _siteWithDomainName:node importCookies:YES];
		
		if (safariHistoryDomain != nil)
		{
			[favoriteDomains addObject:safariHistoryDomain];
		}
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
}

- (IBAction)importFavoritesFromHistory:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	//if alert has been previously disabled, go straight to file import
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesImportFromHistoryAlertKey])
	{
		[self importFromHistoryConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to import Favorites from your Safari History?", nil, thisBundle, @"Import favorites from History confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"All domains from your History will be added to your current favorites.", nil, thisBundle, @"Import History warning dialog -> informative text")];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(importFavoritesFromHistoryAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)importFavoritesFromHistoryAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		if ([[alert suppressionButton] state] == NSOnState)
		{
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SCPreferencesImportFromHistoryAlertKey];
		}
		[self importFromHistoryConfirmed];
	}
}

- (IBAction)selectAll:(id)sender
{
	NSArray * selectedObjects = [[self cookiesTreeController] selectedObjects];
	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	if ([favoriteDomains count] == 0)
	{		
		NSMutableArray * moreFavoriteDomains = [NSMutableArray array];
		for (id node in selectedObjects)
		{
			[moreFavoriteDomains addObject:[node valueForKey:@"domainOnly"]];
		}

		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:moreFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		return;
	}
	
	//combine Favorites and selectedObjects
	for (id node in selectedObjects)
	{
		//add selectedObjects to favorites
		[node valueForKey:@"domain"];
		[favoriteDomains addObject:[node valueForKey:@"domainOnly"]];
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
	return;
}

- (IBAction)unSelectAll:(id)sender
{
	NSArray * selectedObjects = [[self cookiesTreeController] selectedObjects];
	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	
	//combine Favorites and selectedObjects
	for (id node in selectedObjects)
	{
		//remove selectedObjects from favorites
		[node valueForKey:@"domain"];
		[favoriteDomains removeObject:[node valueForKey:@"domainOnly"]];
	}
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
	return;
}

- (IBAction)checkAll:(id)sender
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	if ([favoriteDomains count] == 0)
	{
		//select all Domains in CookiesTreeController
		NSArray *favoriteDomains = [self allDomainsFromTreeController];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadCookiesOutlineView];
		return;
	}
	
	//select all Domains in CookiesTreeController
	NSArray *visibleFavoriteDomains = [self allDomainsFromTreeController];

	//combine favoriteDomains, and visibleFavoriteDomains
	[favoriteDomains addObjectsFromArray:visibleFavoriteDomains];
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
	return;
}

- (IBAction)unCheckAll:(id)sender
{	
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSMutableArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	//select all Domains in CookiesTreeController
	NSArray *visibleFavoriteDomains = [self allDomainsFromTreeController];
	
	//combine favoriteDomains, and visibleFavoriteDomains
	[favoriteDomains removeObjectsInArray:visibleFavoriteDomains];
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadCookiesOutlineView];
	return;
}

- (IBAction)selectAllFlash:(id)sender
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
	NSArray *changedArray = [flashArrayController selectedObjects];
	NSMutableArray* changedFavoriteFlashDomains = [[NSMutableArray new] autorelease];
	
	
	for (NSDictionary *flashCookieDict in changedArray)
	{
		[flashCookieDict setValue:[NSNumber numberWithBool:YES] forKey:@"isFlashFavorite"];
		[changedFavoriteFlashDomains addObject:flashCookieDict];
	}
	
	[flashArray removeObjectsInArray:[flashArrayController selectedObjects]];
	[flashArray addObjectsFromArray:changedFavoriteFlashDomains];
	[flashArrayController setContent:flashArray];
	
	[favoriteFlashDomains removeAllObjects];
	
	
	for (NSDictionary *flashCookieDict in flashArray)
	{
		if ([flashCookieDict valueForKey:@"isFlashFavorite"] == [NSNumber numberWithBool:YES]) {
			[favoriteFlashDomains addObject:[flashCookieDict valueForKey:@"flashCookie"]];
		}
	}
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	
	[self displayFlashCount];
	return;
}

- (IBAction)unSelectAllFlash:(id)sender
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
	NSArray *changedArray = [flashArrayController selectedObjects];
	NSMutableArray* changedFavoriteFlashDomains = [[NSMutableArray new] autorelease];
	
	
	for (NSDictionary *flashCookieDict in changedArray)
	{
		[flashCookieDict setValue:[NSNumber numberWithBool:NO] forKey:@"isFlashFavorite"];
		[changedFavoriteFlashDomains addObject:flashCookieDict];
	}
	
	[flashArray removeObjectsInArray:[flashArrayController selectedObjects]];
	[flashArray addObjectsFromArray:changedFavoriteFlashDomains];
	[flashArrayController setContent:flashArray];
	
	[favoriteFlashDomains removeAllObjects];
	
	
	for (NSDictionary *flashCookieDict in flashArray)
	{
		if ([flashCookieDict valueForKey:@"isFlashFavorite"] == [NSNumber numberWithBool:YES]) {
			[favoriteFlashDomains addObject:[flashCookieDict valueForKey:@"flashCookie"]];
		}
	}

	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", favoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	
	[self displayFlashCount];
	return;
}

- (IBAction)checkAllFlash:(id)sender
{
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	if ([favoriteFlashDomains count] == 0)
	{
		//select all Domains in FlashArrayController
		NSArray *favoriteFlashDomains = [self allFlashFromArrayController];
		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domain", favoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self reloadFlashTableView];
		return;
	}
	
	//select all Domains in FlashArrayController
	NSArray *visibleFavoriteFlashDomains = [self allFlashFromArrayController];
	
	//combine favoriteFlashDomains, and visibleFavoriteFlashDomains
	[favoriteFlashDomains addObjectsFromArray:visibleFavoriteFlashDomains];
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteFlashDomains = [[NSSet setWithArray:favoriteFlashDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domain", uniqueFavoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadFlashTableView];
	return;
}

- (IBAction)unCheckAllFlash:(id)sender
{
	// Create our Favorites plist file.
	NSDictionary *output;
	
	//get favorites from Favorites.plist
	NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
	NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
	NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:favoriteDomainsPlistPath];
	NSArray* favoriteDomains = [favoritesDictionary objectForKey:@"Domains"];
	NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
	
	//select all Domains in FlashArrayController
	NSArray *visibleFavoriteDomains = [self allFlashFromArrayController];
	
	//combine favoriteFlashDomains, and visibleFavoriteFlashDomains
	[favoriteFlashDomains removeObjectsInArray:visibleFavoriteDomains];
	
	//use NSSet, so domains don't get added multiple times
	NSArray* uniqueFavoriteFlashDomains = [[NSSet setWithArray:favoriteFlashDomains] allObjects];
	
	// Write the Favorites plist file
	output = [NSDictionary dictionaryWithObjectsAndKeys:favoriteDomains, @"Domains", uniqueFavoriteFlashDomains, @"Flash", nil];
	[output writeToFile:favoriteDomainsPlistPath atomically:YES];
	
	[self reloadFlashTableView];
	return;
}

- (IBAction)resetAllWarnings:(id)sender
{	
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesImportAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesExportAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesRemoveAllAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesRemoveFlashAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesImportFromBookmarksAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesImportFromTopSitesAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesImportFromHistoryAlertKey];
}

- (IBAction)uninstall:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Uninstall", nil, thisBundle, nil)];
	[alert setIcon:[NSImage imageNamed: @"SafariCookies.png"]];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Are you sure you want to uninstall Safari Cookies?", nil, thisBundle, @"Uninstall Safari Cookies confirmation dialog -> message text; put non breakable space for 'Safari Cookies'")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"You will be asked for an administrator password.", nil, thisBundle, @"Uninstall Safari Cookies confirmation dialog -> informative text")];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(scookies_uninstallAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)scookies_uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	if (returnCode == NSAlertSecondButtonReturn) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"OK", nil, thisBundle, nil)];
		[alert setAlertStyle:NSWarningAlertStyle];
		if (rmSafariCookies() == noErr) {
			[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Safari Cookies has been successfully uninstalled.", nil, thisBundle, @"Safari Cookies successfully uninstalled alert -> message text")];
			[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"You need to restart Safari for changes to be effective.", nil, thisBundle, @"Safari Cookies successfully uninstalled alert -> informative text")];
		} else {
			[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Safari Cookies could not be uninstalled.", nil, thisBundle, @"Safari Cookies failed to be uninstalled alert -> message text")];
			[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"Get support at: \nhttp://sweetpproductions.com/safaricookies/", nil, thisBundle, @"Safari Cookies failed to be uninstalled alert -> informative text")];
		}
		[alert runModal];
	}
}

// save Favorite sites, to plist file immediately
- (IBAction) changeFavoriteSites:(id)sender
{
	NSString *searchString = [searchField stringValue];
	NSString *flashSearchString = [flashSearchField stringValue];
	if ([searchString isEqualToString:@""] && [flashSearchString isEqualToString:@""])
	{
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		
		// Create our Favorites plist file.
		NSDictionary *output;
		NSArray * domains = [self favoriteDomainsFromTreeController];
		NSArray * flashDomains = [self favoriteFlashFromArrayController];
		output = [NSDictionary dictionaryWithObjectsAndKeys:domains, @"Domains", flashDomains, @"Flash", nil];
		
		// Write the Favorites plist file.
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self displayCookieCount];
		[self displayFlashCount];
		
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
		NSMutableArray* favoriteFlashDomains = [favoritesDictionary objectForKey:@"Flash"];
		
		
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
		
		//combine Favorites from favoriteFlashDomains
		for (id node in [flashArrayController content])
		{
			//add favorites from flashArrayController
			if ([[node valueForKey:@"isFlashFavorite"] boolValue])
			{
				[favoriteFlashDomains addObject:[node valueForKey:@"flashCookie"]];
			}
			//remove non-favorites flashArrayController
			if  (![[node valueForKey:@"isFlashFavorite"] boolValue])
			{
				[favoriteFlashDomains removeObject:[node valueForKey:@"flashCookie"]];
			}
		}
		
		//use NSSet, so domains don't get added multiple times
		NSArray* uniqueFavoriteDomains = [[NSSet setWithArray:favoriteDomains] allObjects];
		NSArray* uniqueFavoriteFlashDomains = [[NSSet setWithArray:favoriteFlashDomains] allObjects];

		
		// Write the Favorites plist file
		output = [NSDictionary dictionaryWithObjectsAndKeys:uniqueFavoriteDomains, @"Domains",  uniqueFavoriteFlashDomains, @"Flash", nil];
		[output writeToFile:favoriteDomainsPlistPath atomically:YES];
		
		[self displayCookieCount];
		[self displayFlashCount];
	}
}

- (SCController *)sharedController
{
	if (!sharedController)
		sharedController = [SCController sharedController];
	return sharedController;
}

- (void)buttonCheck
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesAutomaticMode])
	{
		[removeAllNonFavoritesButton setEnabled: NO];
		[removeAllNonFavoritesFlashButton setEnabled:NO];
		return;
	}
	
	if ([[self nonFavoriteCookies] count] == 0)
	{ 
		[removeAllNonFavoritesButton setEnabled: NO];
	}
	else {
		[removeAllNonFavoritesButton setEnabled: YES];
	}
	
	if ([[self flashDeleteArray] count] == 0)
	{ 
		[removeAllNonFavoritesFlashButton setEnabled: NO];
	}
	else {
		[removeAllNonFavoritesFlashButton setEnabled: YES];
	}
}

// Policy
+ (void) updateCookiePolicy
{
	NSHTTPCookieStorage * cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	int policy = [cs cookieAcceptPolicy];
	if (policy == NSHTTPCookieAcceptPolicyAlways)
	{
		int changePolicy = 0;
		[[NSUserDefaults standardUserDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	if (policy == NSHTTPCookieAcceptPolicyNever)
	{
		int changePolicy = 1;
		[[NSUserDefaults standardUserDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	if (policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain)
	{
		int changePolicy = 2;
		[[NSUserDefaults standardUserDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

+ (void) updateSafariPolicy
{
	int policyKey;
	policyKey = [[NSUserDefaults standardUserDefaults]  integerForKey:SCPreferencesCookieAcceptPolicy];
	if (policyKey == 0)
	{
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy: NSHTTPCookieAcceptPolicyAlways];
	}
	if (policyKey == 1)
	{
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy: NSHTTPCookieAcceptPolicyNever];
	}
	if (policyKey == 2)
	{
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy: NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
	}
}

- (void) _cookiePolicyChangedNotification:(NSNotification *)notification
{
	[SCPreferencesModule updateCookiePolicy];
}

- (void) _cookiesChangedNotification:(NSNotification *)notification
{
	[self reloadCookiesOutlineView];
}

- (void) windowWillClose:(NSNotification *)Notification
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	
	//reset searchField, so we don't accidentally delete all our cookies!
	[searchField setStringValue:@""];
	[[[searchField cell] cancelButtonCell] performClick:self];
	[self reloadCookiesOutlineView];
	
	[flashSearchField setStringValue:@""];
	[[[flashSearchField cell] cancelButtonCell] performClick:self];
	[self reloadFlashTableView];
	
	// save last selected tab to defaults
	NSTabViewItem *tabState=[tabView selectedTabViewItem];
	int x;
	for (x= 0; x <= 3; x++)
	{
		if([tabState isEqualTo:[tabView tabViewItemAtIndex:x]])
		[[NSUserDefaults standardUserDefaults] setInteger:x forKey:SCPreferencesTabStateKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	//FSEvents release
	FSEventStreamStop(_stream);
	FSEventStreamInvalidate(_stream); /* will remove from runloop */
	FSEventStreamRelease(_stream);
	
}


@end