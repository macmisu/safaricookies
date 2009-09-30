//
//  BooleanToStringTransformer.m
//  SafariCookies
//
//  Created by John Chang on 6/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BooleanToStringTransformer.h"


@implementation BooleanToStringTransformer

+ (Class) transformedValueClass
{
	return [NSString self];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) transformedValue:(id)value
{
	if (value == nil)
		return nil;
	
	NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
	
	return ([value boolValue] ? NSLocalizedStringFromTableInBundle(@"YES", nil, thisBundle, nil) : NSLocalizedStringFromTableInBundle(@"NO", nil, thisBundle, nil));
}

@end
