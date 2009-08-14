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
@synthesize versionLabel, tabView, cookiesTreeController, cookiesOutlineView, _isDeletingCookie;

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


- (BOOL)isResizable;
{
	return NO;
}

- (SCController *)sharedController
{
	if (!sharedController)
		sharedController = [SCController sharedController];
	return sharedController;
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
	if (policyKey == 3)
	{
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy: NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
	}
}

- (void) _cookiePolicyChangedNotification:(NSNotification *)notification
{
	int policyKey;
	policyKey = [[SCPreferences userDefaults]  integerForKey:SCPreferencesCookieAcceptPolicy];
	int x;
	for (x= 0; x <=2; x++)
	{
		if (policyKey == x)
		{
			[SCPreferencesModule updateCookiePolicy];
		}
	}
	if (policyKey == 3)
	{
	}
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self name:NSHTTPCookieManagerCookiesChangedNotification object:nil];	// don't remove all
	NSDistributedNotificationCenter * ncpolicy = [NSDistributedNotificationCenter defaultCenter];
	[ncpolicy removeObserver:self name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];
	
	// cookiesTreeController -> defaultsController
	NSArray * domains = [self favoriteDomainsFromTreeController];
	[[SCPreferences userDefaults] setObject:domains forKey:SCPreferencesAcceptCookieDomainsKey];
	[[SCPreferences userDefaults] synchronize];
}



@end