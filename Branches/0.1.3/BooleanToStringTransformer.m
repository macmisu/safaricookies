//
//  BooleanToStringTransformer.m
//  SafariCookies
//
//  Created by John Chang on 6/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BooleanToStringTransformer.h"

#import "NSLocalizedStringFromThisBundle.h"


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
	
	return ([value boolValue] ? NSLocalizedStringFromThisBundle(@"YES", nil) : NSLocalizedStringFromThisBundle(@"NO", nil));
}

@end
