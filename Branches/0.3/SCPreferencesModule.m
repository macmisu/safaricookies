#import "SCPreferencesModule.h"
#import "Constants.h"
#import "SCHelper.h"
#import "SCController.h"
#import "SCPreferencesModule.h"
#import "SafariCookies.h"
#import "SCPreferences.h"
#import "SCLogFile.h"
#import "CookiesOutlineViewController.h"


@implementation SCPreferencesModule
@synthesize versionLabel, tabView, cookiesTreeController, cookiesOutlineView, _isDeletingCookie,
				removeAllNonFavoritesButton;

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

- (void) _applicationWillTerminateNotification:(NSNotification *)notification
{			
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
			
			[SafariCookies deleteCookies:deleteCookies];
		}
	}
	[self autorelease];
}

- (void) windowWillClose:(NSNotification *)Notification
{	
	NSNotificationCenter * ncchange = [NSNotificationCenter defaultCenter];
	[ncchange removeObserver:self name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	NSNotificationCenter * ncpolicy = [NSNotificationCenter defaultCenter];
	[ncpolicy removeObserver:self name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	
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