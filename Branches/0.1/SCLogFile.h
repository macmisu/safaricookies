//
//  SCLogFile.h
//  SafariCookies
//
//  Created by John R Chang on 2006-02-08.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SafariCookies.h"


@interface SCLogFile : NSObject

+ (NSString *) logPath;

+ (void) log:(NSString *)string;

@end
