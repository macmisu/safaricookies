#import <Cocoa/Cocoa.h>


@interface NSObject (Swizzle)
+ (BOOL)swizzleMethod:(SEL)old withMethod:(SEL)new;
+ (BOOL)overrideMethod:(NSString *)methodName;
+ (BOOL)overrideMethods:(NSArray *)methods;
@end

void swizzle(Class originalClass, SEL originalName, Class newClass, SEL newName);
