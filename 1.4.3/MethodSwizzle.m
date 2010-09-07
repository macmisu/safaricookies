//
//  MethodSwizzle.m
//
//  Copyright (c) 2006 Tildesoft. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.

// Implementation of Method Swizzling, inspired by
// http://www.cocoadev.com/index.pl?MethodSwizzling

// solves the inherited method problem

#import "MethodSwizzle.h"
#import <objc/objc-runtime.h>

static BOOL _PerformSwizzle(Class klass, SEL origSel, SEL altSel, BOOL forInstance);

BOOL ClassMethodSwizzle(Class klass, SEL origSel, SEL altSel) {
	return _PerformSwizzle(klass, origSel, altSel, NO);
}

BOOL MethodSwizzle(Class klass, SEL origSel, SEL altSel) {
	return _PerformSwizzle(klass, origSel, altSel, YES);
}

// if the origSel isn't present in the class, pull it up from where it exists
// then do the swizzle
BOOL _PerformSwizzle(Class klass, SEL origSel, SEL altSel, BOOL forInstance) {
	
	// To swizzle class methods, manipulate methods on the metaclass
	Class target = forInstance ? klass : object_getClass(klass);
	
	if (![target instancesRespondToSelector: origSel]) {
		if (forInstance) {
			NSLog(@"Warning: Instances of class %@ do not respond to %@",
				  NSStringFromClass(klass), NSStringFromSelector(origSel));
		} else {
			NSLog(@"Warning: Class %@ does not respond to %@",
				  NSStringFromClass(klass), NSStringFromSelector(origSel));
		}
		return NO;
	}
	
	
	Method orig = class_getInstanceMethod(target, origSel);
	Method repl = class_getInstanceMethod(target, altSel);
	
	// We have (origSel -> origIMP, replSel -> replIMP).
	// But maybe origSel is inherited--we don't want to swap origIMP in superclasses!
	// Check if it's inherited by trying to add origSel.
	if (class_addMethod(target, origSel, method_getImplementation(repl), method_getTypeEncoding(repl))) {
		// Adding succeeded, the method was inherited.
		// We have (origSel -> replIMP, replSel -> replIMP).
		// Just change where replSel points
		class_replaceMethod(target, altSel, method_getImplementation(orig), method_getTypeEncoding(orig));
	} else {
		// Not inherited, we can safely swap IMPs
		method_exchangeImplementations(orig, repl);
	}
	return YES;
}