#import "SCPreferencesModule.h"
#import "Constants.h"
#import "SCHelper.h"
#import "SCController.h"
#import "SCPreferencesModule.h"
#import "SCLogFile.h"
#import "CookiesOutlineViewController.h"


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
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	[self setVersionLabel:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Current Version: %@", nil, thisBundle, @"Preferences -> General tab -> current version label"), [SCController version]]];
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

// import/export Favorite domains (saved as Favorites.plist inside bundle, just so its harder to mess with for non-techies)

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
		
		NSFileManager *fm = [NSFileManager defaultManager];
		// create the bundle
		NSNumber *num = [NSNumber numberWithBool:YES];
		NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:num, NSFileExtensionHidden, nil];
		if( ![fm fileExistsAtPath:[savePanel filename]] )
		{
			[fm createDirectoryAtPath:[savePanel filename] attributes:attribs];
		}
		
		// Set up project file internal directories
		NSString *contentsPath = [[savePanel filename] stringByAppendingPathComponent:@"Contents"];
		// If this file is new, we'll need to create the Contents directory
		if( ![fm fileExistsAtPath:contentsPath] )
			[fm createDirectoryAtPath:contentsPath withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *resourcesPath = [contentsPath stringByAppendingPathComponent:@"Resources"];
		// If this file is new, we'll need to create the Contents/Resources directory
		if( ![fm fileExistsAtPath:resourcesPath] )
			[fm createDirectoryAtPath:resourcesPath withIntermediateDirectories:YES attributes:nil error:nil];
		
		favoritesPlistExportFilepath = [resourcesPath stringByAppendingPathComponent:@"Favorites.plist"];
		
		//copy favorites into Application Support folder
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		
		if ([fm fileExistsAtPath:favoriteDomainsPlistPath]) 
		{
			[fm copyPath:favoriteDomainsPlistPath toPath:favoritesPlistExportFilepath handler:nil];
		}
		
		// Set the path for our Info plist file.
		NSString *plistFile = [contentsPath stringByAppendingPathComponent:@"Info.plist"];
		
		// If it already exists in the project, delete it.
		if( [fm fileExistsAtPath:plistFile] )
			[fm removeFileAtPath:plistFile handler:nil];
		
		// Create a dictionary to use to write out our property list file.
		NSDictionary *infoPlist;
		infoPlist = [NSDictionary dictionaryWithObjectsAndKeys:contentFiles, @"Files", nil];
		
		// Write the file.
		[infoPlist writeToFile:plistFile atomically:YES];
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
	
	// Only allow the user to select our specific file type.
	NSArray *fileTypes = [NSArray arrayWithObjects: @"bundle", nil];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([openPanel runModalForTypes:fileTypes] == NSOKButton)
	{		
		NSString *importContentsPath = [[openPanel filename] stringByAppendingPathComponent:@"Contents"];
		NSString *importResourcesPath = [importContentsPath stringByAppendingPathComponent:@"Resources"];
		
		//copy favorites into Application Support folder
		plistPath = [importResourcesPath stringByAppendingPathComponent:@"Favorites.plist"];
		NSString *applicationSupportFolder = [SCApplicationSupportFolderPath stringByExpandingTildeInPath];
		NSString *favoriteDomainsPlistPath = [applicationSupportFolder stringByAppendingPathComponent:SCFavoriteDomainsPlistFullName];
		
		if ([fm fileExistsAtPath:plistPath]) 
		{
			// If it already exists in the project, delete it.
			if( [fm fileExistsAtPath:favoriteDomainsPlistPath] )
			{
				[fm removeFileAtPath:favoriteDomainsPlistPath handler:nil];
			}
			[fm copyPath:plistPath toPath:favoriteDomainsPlistPath handler:nil];
		}
		
		// reload cookiesOutlineView with new favorites
		[self reloadCookiesOutlineView];
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
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Would you like to import Favorites from a previously exported file?", nil, thisBundle, @"Import favorites confirmation dialog -> message text")];
	[alert setShowsSuppressionButton:YES];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"ALL your current favorites will be overwritten. \nThis operation will NOT affect your current cookies.", nil, thisBundle, @"Import Favorites warning dialog -> informative text")];
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

- (IBAction)resetAllWarnings:(id)sender
{	
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesImportAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesExportAlertKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:SCPreferencesRemoveAllAlertsKey];

}

- (IBAction)uninstall:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, thisBundle, nil)];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Uninstall", nil, thisBundle, nil)];
	[alert setMessageText:NSLocalizedStringFromTableInBundle(@"Are you sure you want to uninstall Safari Cookies?", nil, thisBundle, @"Uninstall Safari Cookies confirmation dialog -> message text; put non breakable space for 'Safari Cookies'")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"You will be asked for an administrator password.", nil, thisBundle, @"Uninstall Safari Cookies confirmation dialog -> informative text")];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[_preferencesView window]
					  modalDelegate:self
					 didEndSelector:@selector(uninstallAlertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
	
	// save last selected tab to defaults
	NSTabViewItem *tabState=[tabView selectedTabViewItem];
	int x;
	for (x= 0; x <= 3; x++)
	{
		if([tabState isEqualTo:[tabView tabViewItemAtIndex:x]])
		[[NSUserDefaults standardUserDefaults] setInteger:x forKey:SCPreferencesTabStateKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	[self autorelease];
}

@end