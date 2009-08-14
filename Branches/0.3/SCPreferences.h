//
//  SCPreferences.h
//  SafariCookies
//
//  Created by John Chang on 6/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SafariCookies.h"
#import <Cocoa/Cocoa.h>
#import "NSPreferences.h"


enum {
    SCCookieAcceptPolicySafariBehavior = 0,
};

@interface SCPreferences : NSPreferences {
}

+ (void) setupUserDefaults;
+ (NSUserDefaults *) userDefaults;
@end