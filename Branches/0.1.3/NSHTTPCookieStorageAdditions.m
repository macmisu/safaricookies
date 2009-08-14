//
//  NSHTTPCookieStorageAdditions.m
//  SafariCookies
//
//  Created by John R Chang on 2006-02-08.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSHTTPCookieStorageAdditions.h"

#import "NSHTTPCookieStoragePriv.h"
#import "NSHTTPCookieDiskStorage.h"


@interface NSHTTPCookieStorageInternal (SafariCookies)
- (NSHTTPCookieDiskStorage *) storage;
@end


@implementation NSHTTPCookieStorage (SafariCookies)

- (void) _spFlush
{
	//[self _connectToCookieStorage];
	NSHTTPCookieDiskStorage * storage = [self->_internal storage];
	[storage _saveCookies];
}

@end


@implementation NSHTTPCookieStorageInternal (SafariCookies)

- (NSHTTPCookieDiskStorage *) storage
{
	return storage;
}

@end
