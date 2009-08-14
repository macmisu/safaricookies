//
//  CookiesOutlineViewController.h
//  SafariCookies
//
//  Created by John R Chang on 2006-02-04.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SCPreferencesModule.h"


@interface SCPreferencesModule (CookiesOutlineView)


- (NSArray *) cookiesContentArray;	// bound from nib

- (void) setupCookiesOutlineView;
- (void) reloadCookiesOutlineView;
- (void) importCookiesOutlineView;

- (NSArray *) favoriteDomains;
- (NSArray *) favoriteDomainsFromTreeController;
- (NSArray *) allDomainsFromTreeController;

- (IBAction) remove:(id)sender;
- (IBAction) removeAllNonFavorites:(id)sender;

- (NSArray *) allDisplayedCookies;
- (NSArray *) nonFavoriteCookies;	// nil if 0

- (IBAction) changeFavoriteSites:(id)sender;
- (IBAction) changeLogButton:(id)sender;
- (IBAction) changeRemoveOnQuitButton:(id)sender;
- (IBAction) changeCookiePolicyButton:(id)sender;

- (void)removeAllNonFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end
