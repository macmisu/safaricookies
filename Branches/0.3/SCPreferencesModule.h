#import <Cocoa/Cocoa.h>
#import "NSPreferences.h"
#import "SCController.h"


@interface SCPreferencesModule : NSPreferencesModule <NSPreferencesModule> {
	IBOutlet id numberOfCookiesStatusLine;
	IBOutlet NSButton *removeAllNonFavoritesButton;
	SCController *sharedController;
	NSString *versionLabel;
	IBOutlet id tabView;
	IBOutlet id cookiesTreeController;
	IBOutlet id cookiesOutlineView;
	NSSize _defaultWindowSize;
	BOOL _isDeletingCookie;
}


- (IBAction)uninstall:(id)sender;
- (void)uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)buttonCheck;
- (void) reloadTabOnLaunch;
- (void) displayCookieCount;
- (NSImage *) imageForPreferenceNamed:(NSString *) name;
- (NSView *) viewForPreferenceNamed:(NSString *) name;

// Policy
+ (void) updateCookiePolicy;
+ (void) updateSafariPolicy;
@property (retain) id tabView;
@property (retain) id cookiesTreeController;
@property (retain) id cookiesOutlineView;
@property BOOL _isDeletingCookie;
@property(copy, readwrite) NSString *versionLabel;
@property (nonatomic, retain) NSButton  *removeAllNonFavoritesButton;
@end
