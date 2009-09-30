//
//  CookieNode.h
//  FilteringTreeController
//
//  Created by John Chang on 6/14/07.
//  Modified by Russell Gray April 2009
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CookiesOutlineViewController.h"


@interface CookieNode : NSObject {
	SCPreferencesModule * _prefsController;
	NSArray * _children;
}

- (id) initWithPrefsController:(SCPreferencesModule *)controller;

- (NSArray *) cookies;
- (unsigned int) cookieCount;
- (BOOL) isLeaf;


@property (retain) SCPreferencesModule * _prefsController;
@property (retain) NSArray * _children;
@end
