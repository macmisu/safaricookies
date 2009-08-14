#import <Cocoa/Cocoa.h>

@interface SCController : NSObject
{
}

+ (SCController*)sharedController;
+ (id)allocWithZone:(NSZone *)zone;
- (id)copyWithZone:(NSZone *)zone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

@end
