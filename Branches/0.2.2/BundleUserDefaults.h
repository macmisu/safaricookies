//
//  BundleUserDefaults.h
//
//  Created by John Chang on 6/15/07.
//  This code is Creative Commons Public Domain.  You may use it for any purpose whatsoever.
//  http://creativecommons.org/licenses/publicdomain/
//

#import <Cocoa/Cocoa.h>


@interface BundleUserDefaults : NSUserDefaults {
	NSString * _applicationID;
	NSDictionary * _registrationDictionary;
}

- (id) initWithPersistentDomainName:(NSString *)domainName;

- (id)objectForKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;

- (BOOL)synchronize;

@property (retain) NSString * _applicationID;
@property (retain,setter=registerDefaults:) NSDictionary * _registrationDictionary;
@end


@interface NSUserDefaultsController (SetDefaults)
- (void) _setDefaults:(NSUserDefaults *)defaults;
@end
