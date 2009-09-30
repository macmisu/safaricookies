//
//  SCLogFile.m
//  SafariCookies
//
//  Created by John R Chang on 2006-02-08.
//  Modified by Russell Gray - www.sweetpproductions.com  May 09
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "SCLogFile.h"
#import <WebKit/WebKit.h>	 // WebPreferences


@implementation SCLogFile

//~/Library/Logs/SafariCookies.log
+ (NSString *) logPath
{
	NSString * logsPath = [SCLogFilePath stringByExpandingTildeInPath];
	return [logsPath stringByAppendingPathComponent:@"SafariCookies.log"];
}

+ (NSFileHandle *) _logFileHandle
{
	static NSFileHandle * sFileHandle = nil;
	if (sFileHandle == nil)
	{
		NSString * path = [self logPath];

		// Open file handle, creating the file if needed
		sFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
		if (sFileHandle == nil)
		{
			NSFileManager * fm = [NSFileManager defaultManager];
			[fm createFileAtPath:path contents:nil attributes:nil];
			
			sFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
		}
		[sFileHandle retain];
	}
	return sFileHandle;
}

+ (void) log:(NSString *)string
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SCPreferencesShouldLogActivity])
	{
		WebPreferences * wp = [WebPreferences standardPreferences];
		if ([wp privateBrowsingEnabled])
			return;
			
		NSString * logString = [NSString stringWithFormat:@"%@: %@\n", [[NSDate date] description], string];
		NSData * data = [logString dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
	
		NSFileHandle * fh = [self _logFileHandle];
		[fh seekToEndOfFile];
		[fh writeData:data];
		//[fh closeFile];
	}
	return;
}

@end
