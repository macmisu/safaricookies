//
//  CookiesOutlineViewController.h
//  SafariCookies
//
//  Created by John R Chang on 2006-02-04.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//
//  Modified by Russell Gray 2009/2010
//

#import "SCPreferencesModule.h"


@interface SCPreferencesModule (CookiesOutlineView)

- (NSArray *) cookiesContentArray;	// bound from nib

- (void) reloadCookiesOutlineView;

- (NSArray *) favoriteDomains;
- (NSArray *) favoriteDomainsFromTreeController;
- (NSArray *) allDomainsFromTreeController;

- (IBAction) remove:(id)sender;
- (IBAction) removeAllNonFavorites:(id)sender;

- (NSArray *) allDisplayedCookies;
- (NSArray *) nonFavoriteCookies;	// nil if 0

- (IBAction) changeButtonState:(id)sender;
- (IBAction) changeCookiePolicyButton:(id)sender;
- (IBAction) changeSearchFieldText:(id)sender;

- (void)removeAllNonFavoritesAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;


@end
