/* Copyright 2005 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabQCPlayerViewWrapper.h"

#import <objc/objc-class.h>

/* This class exists so that we can trap frames drawn by the Quartz Composer screen saver view. It doesn't call 
-[NSOpenGLContext makeCurrentContext] like other OpenGL modules, so we have to trap the internal method -_oneStep:
by swapping out the implementation method pointer with a method of our own, which sends a notification after
calling the original method. 
*/

static IMP gOrigAnimateOneFrame = NULL;

@implementation SaverLabQCPlayerViewWrapper

+(void)swizzleMethodForClass:(Class)c {
	Method m = class_getInstanceMethod(c, @selector(_oneStep:));
	if (!m || m->method_imp==[self instanceMethodForSelector:@selector(oneStepReplacement:)]) {
		// do nothing, we've already swizzled
	}
	else {
		gOrigAnimateOneFrame = m->method_imp;
		m->method_imp = [self instanceMethodForSelector:@selector(oneStepReplacement:)];
	}
}

-(void)oneStepReplacement:(id)arg {
	// call the real method
	(* gOrigAnimateOneFrame)(self, @selector(oneStep:), arg);
	// then notify that we drew a frame
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenSaverDrewOpenGLFrame" object:self];
}

@end
