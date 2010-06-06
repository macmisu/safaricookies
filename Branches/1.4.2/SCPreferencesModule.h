//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


#import "NSPreferences.h"
#import "SCController.h"
#include <CoreServices/CoreServices.h>


@class SUUpdater;

@interface SCPreferencesModule : NSPreferencesModule <NSPreferencesModule> {
	FSEventStreamRef _stream;
	
	SUUpdater *updater;
	IBOutlet id numberOfCookiesStatusLine;
	IBOutlet id numberOfFlashCookiesStatusLine;
	IBOutlet NSButton *removeAllNonFavoritesButton;
	IBOutlet NSButton *removeAllNonFavoritesFlashButton;
	IBOutlet id searchField;
	IBOutlet id flashSearchField;
	SCController *sharedController;
	NSString *versionLabel;
	IBOutlet id tabView;
	IBOutlet id cookiesTreeController;
	IBOutlet id cookiesArrayController;
	IBOutlet id cookiesOutlineView;
	IBOutlet id flashArrayController;
	IBOutlet id flashTableView;
	IBOutlet id cookiesScrollView;
	IBOutlet id aboutTextView;
	NSSize _defaultWindowSize;
	BOOL _isDeletingCookie;
	NSString *favoritesPlistExportFilepath;
	NSString *plistPath;
}


- (IBAction)uninstall:(id)sender;
- (IBAction)exportFavorites:(id)sender;
- (IBAction)importFavorites:(id)sender;
- (IBAction)importFavoritesFromBookmarks:(id)sender;
- (IBAction)importFavoritesFromTopSites:(id)sender;
- (IBAction)importFavoritesFromHistory:(id)sender;
- (IBAction)resetAllWarnings:(id)sender;
- (IBAction)selectAll:(id)sender;
- (IBAction)unSelectAll:(id)sender;
- (IBAction)checkAll:(id)sender;
- (IBAction)unCheckAll:(id)sender;
- (IBAction)selectAllFlash:(id)sender;
- (IBAction)unSelectAllFlash:(id)sender;
- (IBAction)checkAllFlash:(id)sender;
- (IBAction)unCheckAllFlash:(id)sender;
- (IBAction) changeFavoriteSites:(id)sender;
- (void)uninstallAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)buttonCheck;
- (void) reloadTabOnLaunch;
- (void) displayCookieCount;
- (void) displayFlashCount;
- (NSImage *) imageForPreferenceNamed:(NSString *) name;
- (NSView *) viewForPreferenceNamed:(NSString *) name;

+ (NSArray *)getBookmarkUrlsFrom:(NSDictionary *)subtree;
+ (NSArray *)getTopSiteUrlsFrom:(NSDictionary *)subtree;
+ (NSArray *)getHistoryUrlsFrom:(NSDictionary *)subtree;
+ (NSArray *)getBookmarks;
+ (NSArray *)getTopSites;
+ (NSArray *)getHistory;
+ (NSArray *) autoModeDomains;

// Policy
+ (void) updateCookiePolicy;
+ (void) updateSafariPolicy;


@property (retain) id tabView;
@property (retain) id cookiesTreeController;
@property (retain) id cookiesArrayController;
@property (retain) id cookiesOutlineView;
@property (retain) id flashArrayController;
@property (retain) id flashTableView;
@property (retain) id cookiesScrollView;
@property (retain) id aboutTextView;
@property (retain) id searchField;
@property (retain) id flashSearchField;
@property (retain) id numberOfCookiesStatusLine;
@property (retain) id numberOfFlashCookiesStatusLine;
@property (retain) NSString *favoritesPlistExportFilepath;
@property (retain) NSString *plistPath;

@property BOOL _isDeletingCookie;
@property(copy, readwrite) NSString *versionLabel;
@property (nonatomic, retain) NSButton  *removeAllNonFavoritesButton;
@property (nonatomic, retain) NSButton  *removeAllNonFavoritesFlashButton;

@property (retain) SUUpdater *updater;

@end
