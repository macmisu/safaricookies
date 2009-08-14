#import <Cocoa/Cocoa.h>
#import "NSPreferences.h"
#import "SCController.h"


@interface SCPreferencesModule : NSPreferencesModule <NSPreferencesModule> {
	IBOutlet id numberOfCookiesStatusLine;
	SCController *sharedController;
	NSString *versionLabel;
	IBOutlet id tabView;
	IBOutlet id cookiesTreeController;
	IBOutlet id cookiesOutlineView;
	NSSize _defaultWindowSize;
	BOOL _isDeletingCookie;
}

@property(copy, readwrite) NSString *versionLabel;


- (IBAction)uninstall:(id)sender;
- (void)uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

// Policy
//- (int) SCcookieAcceptPolicyTag;
//- (void) SCsetCookieAcceptPolicyTag:(int)tag;
+ (void) updateCookiePolicy;
+ (void) updateSafariPolicy;
@property (retain) id tabView;
@property (retain) id cookiesTreeController;
@property (retain) id cookiesOutlineView;
@property BOOL _isDeletingCookie;

@end
