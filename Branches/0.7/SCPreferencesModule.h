#import <Cocoa/Cocoa.h>
#import "NSPreferences.h"
#import "SCController.h"


@interface SCPreferencesModule : NSPreferencesModule <NSPreferencesModule> {
	IBOutlet id numberOfCookiesStatusLine;
	IBOutlet NSButton *removeAllNonFavoritesButton;
	IBOutlet id searchField;
	SCController *sharedController;
	NSString *versionLabel;
	IBOutlet id tabView;
	IBOutlet id cookiesTreeController;
	IBOutlet id cookiesArrayController;
	IBOutlet id cookiesOutlineView;
	IBOutlet id aboutTextView;
	NSSize _defaultWindowSize;
	BOOL _isDeletingCookie;
	NSString *favoritesPlistExportFilepath;
	NSString *plistPath;
}


- (IBAction)uninstall:(id)sender;
- (IBAction)exportFavorites:(id)sender;
- (IBAction)importFavorites:(id)sender;
- (IBAction)resetAllWarnings:(id)sender;
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
@property (retain) id cookiesArrayController;
@property (retain) id cookiesOutlineView;
@property (retain) id aboutTextView;
@property (retain) id searchField;
@property BOOL _isDeletingCookie;
@property(copy, readwrite) NSString *versionLabel;
@property (nonatomic, retain) NSButton  *removeAllNonFavoritesButton;

@end
