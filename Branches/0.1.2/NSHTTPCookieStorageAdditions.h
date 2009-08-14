//
//  NSHTTPCookieStorageAdditions.h
//  SafariCookies
//
//  Created by John R Chang on 2006-02-08.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSHTTPCookieStorage (SafariCookies)
- (void) _spFlush;
@end
