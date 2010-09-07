//  Created by Russell Gray 2010.
//  Copyright 2010 SweetP Productions. All rights reserved.


#import "SCPreferencesModule.h"


@interface SCPreferencesModule (FlashTableView)

- (NSArray *) flashContentArray;	// bound from nib
- (NSArray *) allFlashFromArrayController;
- (NSArray *) favoriteFlashFromArrayController;
- (NSArray *) nonFavoriteFlashFromArrayController;
- (NSArray *) flashDeleteArray;
- (NSArray *) flashKeepArray;

- (void) checkDeleteFlashFolder;
- (void) reloadFlashTableView;

- (IBAction) removeFlash:(id)sender;
- (IBAction) removeAllNonFavoriteFlash:(id)sender;
- (IBAction) changeFlashSearchFieldText:(id)sender;

- (void)removeAllNonFavoriteFlashAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;


@end
