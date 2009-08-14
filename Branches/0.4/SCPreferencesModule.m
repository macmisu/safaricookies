#import "SCPreferencesModule.h"
#import "Constants.h"
#import "SCHelper.h"
#import "SCController.h"
#import "SCPreferencesModule.h"
#import "SCPreferences.h"
#import "SCLogFile.h"
#import "CookiesOutlineViewController.h"
#import "NSHTTPCookieStorageAdditions.h"


@implementation SCPreferencesModule
@synthesize versionLabel, tabView, cookiesTreeController, cookiesOutlineView, _isDeletingCookie,
				removeAllNonFavoritesButton;

-(id) init
{
	[SCPreferencesModule updateSafariPolicy];
	
	//register observers
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cookiesChangedNotification:) 
			name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_cookiePolicyChangedNotification:) 
			name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	return self;
}

-(void) awakeFromNib
{
	//set initial sort order of cookiesOutlineView
	NSSortDescriptor* theDefaultSortDescriptor = 
    [[NSSortDescriptor alloc] initWithKey:@"domain" ascending:YES];
	[cookiesOutlineView setSortDescriptors:[NSArray arrayWithObject: theDefaultSortDescriptor]];
	[theDefaultSortDescriptor release];
	[self displayCookieCount];
	[self reloadTabOnLaunch];
}

+ (NSImage*) preloadImage: (NSString*) theName
{
	NSImage* image = nil;
	NSString* imagePath = [[NSBundle bundleWithIdentifier: BundleIdentifier] 
						   pathForImageResource: theName];
	if (!imagePath)
	{
		NSLog(@"imagePath for %@ is nil", theName);
		return nil;
	}
	image = [[NSImage alloc] initByReferencingFile: imagePath];
	if (!image)
	{
		NSLog(@"image for %@ is nil", theName);
		return nil;
	}
	[image setName: theName];
	return image;
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
	[self setVersionLabel:[NSString stringWithFormat:NSLocalizedString(@"Current Version: %@",@"Preferences -> General tab -> current version label"),[SCController version]]];
}

- (NSSize) minSize {
	return NSMakeSize(621.0,316);
}

- (BOOL) isResizable {
	return YES;
}

- (void) reloadTabOnLaunch
{
	int tabState;
	tabState = [[SCPreferences userDefaults] integerForKey:SCPreferencesTabStateKey];
	[tabView selectTabViewItemAtIndex:tabState];
}

- (void) displayCookieCount
{
	[self buttonCheck];
	NSArray * numFavorites = [self favoriteDomainsFromTreeController];
	NSArray * numDomains = [cookiesTreeController content];
	NSArray * numCookies = [self allDisplayedCookies];
	
	int totalFavoriteDomains = [numFavorites count];
	int totalNumDomains = [numDomains count];
	int totalNumCookies = [numCookies count];
	[numberOfCookiesStatusLine setStringValue:[NSString stringWithFormat:@"%i Domains, %i Favorites, %i unique Cookies", totalNumDomains, totalFavoriteDomains, totalNumCookies]];
}

//// import/export Favorite domains (saved as Favorites.plist inside bundle)

- (void) exportConfirmed
{
	NSArray * contentFiles = [NSArray arrayWithObjects: @"Favorites.plist", nil];
	NSSavePanel *savePanel;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setExtensionHidden:YES];
	// Only allow our specific file type
	[savePanel setRequiredFileType:@"bundle"];
	// Disable ability to show file extension
	[savePanel setCanSelectHiddenExtension:NO];
	// Make sure files are not treated as directories
	[savePanel setTreatsFilePackagesAsDirectories:NO];
	if( [savePanel runModal] == NSOKButton )
	{
		
		// create the bundle
		NSNumber *num = [NSNumber numberWithBool:YES];
		NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:num, NSFileExtensionHidden, nil];
		if( ![[NSFileManager defaultManager] fileExistsAtPath:[savePanel filename]] )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:[savePanel filename] attributes:attribs];
		}
		
		// Set up project file internal directories
		NSString *contentsPath = [[savePanel filename] stringByAppendingPathComponent:@"Contents"];
		// If this file is new, we'll need to create the Contents directory
		if( ![[NSFileManager defaultManager] fileExistsAtPath:contentsPath] )
			[[NSFileManager defaultManager] createDirectoryAtPath:contentsPath withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *resourcesPath = [contentsPath stringByAppendingPathComponent:@"Resources"];
		// If this file is new, we'll need to create the Contents/Resources directory
		if( ![[NSFileManager defaultManager] fileExistsAtPath:resourcesPath] )
			[[NSFileManager defaultManager] createDirectoryAtPath:resourcesPath withIntermediateDirectories:YES attributes:nil error:nil];
		
		favoritesPlistFilepath = [resourcesPath stringByAppendingPathComponent:@"Favorites.plist"];
		
		// Create our Favorites plist file.
		NSDictionary *output;
		NSArray * domains = [self favoriteDomainsFromTreeController];
		output = [NSDictionary dictionaryWithObjectsAndKeys:domains, @"Domains", nil];
		
		// Write the Favorites plist file.
		[output writeToFile:favoritesPlistFilepath atomically:YES];
		
		// Set the path for our Info plist file.
		NSString *plistFile = [contentsPath stringByAppendingPathComponent:@"Info.plist"];
		
		// If it already exists in the project, delete it.
		if( [[NSFileManager defaultManager] fileExistsAtPath:plistFile] )
			[[NSFileManager defaultManager] removeFileAtPath:plistFile handler:nil];
		
		// Create a dictionary to use to write out our property list file.
		NSDictionary *infoPlist;
		infoPlist = [NSDictionary dictionaryWithObjectsAndKeys:contentFiles, @"Files", nil];
		
		// Write the file.
		[infoPlist writeToFile:plistFile atomically:YES];
	}
}

- (IBAction)exportFavorites:(id)sender
{
	//if alert has been previously disabled, go straight to file save
	if ([[SCPreferences userDefaults] boolForKey:SCPreferencesExportAlertKey])
	{
		[self exportConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:NSLocalizedString(@"Would you like to export all your Favorite domains?",@"Export favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedString(@"Cookies will NOT be exported.",@"Export Cookies confirmation dialog -> informative text")];
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
			[[SCPreferences userDefaults] setBool:YES forKey:SCPreferencesExportAlertKey];
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
	
	// Only allow the user to select our specific file type.
	NSArray *fileTypes = [NSArray arrayWithObjects: @"bundle", nil];
	
	if ([openPanel runModalForTypes:fileTypes] == NSOKButton)
	{		
		NSString *importContentsPath = [[openPanel filename] stringByAppendingPathComponent:@"Contents"];
		NSString *importResourcesPath = [importContentsPath stringByAppendingPathComponent:@"Resources"];
		
		//import favorites into favoritesArray
		plistPath = [importResourcesPath stringByAppendingPathComponent:@"Favorites.plist"];
		NSDictionary* favoritesDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];
		NSMutableArray* favoritesArray = [favoritesDictionary objectForKey:@"Domains"];
		
		// sync favoritesArray to user defaults
		[[SCPreferences userDefaults] setObject:favoritesArray forKey:SCPreferencesAcceptCookieDomainsKey];
		[[SCPreferences userDefaults] synchronize];
		
		// reload cookiesOutlineView with new favorites
		[self importCookiesOutlineView];
	}
}

- (IBAction)importFavorites:(id)sender
{
	//if alert has been previously disabled, go straight to file import
	if ([[SCPreferences userDefaults] boolForKey:SCPreferencesImportAlertKey])
	{
		[self importConfirmed];
		return;
	}
	//nsalert 
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:NSLocalizedString(@"Would you like to import Favorites from a previously exported file?",@"Import favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedString(@"ALL your current favorites will be overwritten. \nThis operation will NOT affect your current cookies.",@"Import Favorites warning dialog -> informative text")];
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
			[[SCPreferences userDefaults] setBool:YES forKey:SCPreferencesImportAlertKey];
		}
		[self importConfirmed];
	}
}

- (IBAction)resetAllWarnings:(id)sender
{
	[[SCPreferences userDefaults] setBool:NO forKey:SCPreferencesImportAlertKey];
	[[SCPreferences userDefaults] setBool:NO forKey:SCPreferencesExportAlertKey];
	[[SCPreferences userDefaults] setBool:NO forKey:SCPreferencesAlertsKey];

}

- (IBAction)uninstall:(id)sender
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Uninstall"];
	[alert setMessageText:NSLocalizedString(@"Are you sure you want to uninstall Safari Cookies?",@"Uninstall Safari Cookies confirmation dialog -> message text; put non breakable space for 'Safari Cookies'")];
	[alert setInformativeText:NSLocalizedString(@"You will be asked for an administrator password.",@"Uninstall Safari Cookies confirmation dialog -> informative text")];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(uninstallAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setAlertStyle:NSWarningAlertStyle];
		if (rmSafariCookies() == noErr) {
			[alert setMessageText:NSLocalizedString(@"Safari Cookies has been successfully uninstalled.",@"Safari Cookies successfully uninstalled alert -> message text")];
			[alert setInformativeText:NSLocalizedString(@"You need to restart Safari for changes to be effective.",@"Safari Cookies successfully uninstalled alert -> informative text")];
		} else {
			[alert setMessageText:NSLocalizedString(@"Safari Cookies could not be uninstalled.",@"Safari Cookies failed to be uninstalled alert -> message text")];
			[alert setInformativeText:NSLocalizedString(@"Get support at: \nhttp://sweetpproductions.com/safaricookies/",@"Safari Cookies failed to be uninstalled alert -> informative text")];
		}
		[alert runModal];
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
	if ([self nonFavoriteCookies] == nil) { 
		[removeAllNonFavoritesButton setEnabled: NO];
	}
	else {
		[removeAllNonFavoritesButton setEnabled: YES];
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
		[[SCPreferences userDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[SCPreferences userDefaults] synchronize];
	}
	if (policy == NSHTTPCookieAcceptPolicyNever)
	{
		int changePolicy = 1;
		[[SCPreferences userDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[SCPreferences userDefaults] synchronize];
	}
	if (policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain)
	{
		int changePolicy = 2;
		[[SCPreferences userDefaults] setInteger:changePolicy forKey:SCPreferencesCookieAcceptPolicy];
		[[SCPreferences userDefaults] synchronize];
	}
}

+ (void) updateSafariPolicy
{
	int policyKey;
	policyKey = [[SCPreferences userDefaults]  integerForKey:SCPreferencesCookieAcceptPolicy];
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
	
	// save last selected tab to defaults
	NSTabViewItem *tabState=[tabView selectedTabViewItem];
	int x;
	for (x= 0; x <= 3; x++)
	{
		if([tabState isEqualTo:[tabView tabViewItemAtIndex:x]])
		[[SCPreferences userDefaults] setInteger:x forKey:SCPreferencesTabStateKey];
		[[SCPreferences userDefaults] synchronize];
	}
	[self autorelease];
}

@end