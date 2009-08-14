//
//  SafariCookies.h
//  SafariCookies
//
//  Created by John R Chang on 2005-12-07.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// Globals
extern BOOL gShouldHandleCookies;

@interface SafariCookies : NSObject {
	NSWindowController * _prefsController;
}

@property (retain) NSWindowController * _prefsController;
@end


@interface SafariCookies (Utilities)


+ (BOOL) domains:(NSArray *)domains containsHostname:(NSString *)hostname;
+ (NSArray *) cookiesMatchingDomains:(NSArray *)matchDomains match:(BOOL)value;
+ (void) deleteCookies:(NSArray *)deleteCookies;

@end
