/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabQCPlayerViewWrapper.h"

#import "SaverLabMethodSwizzler.h"

/* This class exists so that we can trap frames drawn by the Quartz Composer screen saver view. It doesn't call 
-[NSOpenGLContext makeCurrentContext] like other OpenGL modules, so we have to trap the internal method -_oneStep:
by swapping out the implementation method pointer with a method of our own, which sends a notification after
calling the original method. 
*/

static IMP gOrigAnimateOneFrame = NULL;

@implementation SaverLabQCPlayerViewWrapper

+(void)swizzleMethodForClass:(Class)c {
  if (!gOrigAnimateOneFrame) {
    gOrigAnimateOneFrame = [c replaceSelector:@selector(_oneStep:) withSelector:@selector(oneStepReplacement:) fromClass_:self];
  } 
}

-(void)oneStepReplacement:(id)arg {
	// call the real method
	(* gOrigAnimateOneFrame)(self, @selector(_oneStep:), arg);
	// then notify that we drew a frame
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenSaverDrewOpenGLFrame" object:self];
}

@end

/* XScreenSaver subclasses crash in -stopAnimation if there are multiple instances of the same module running.
We disable the -stopAnimation override and just call the ScreenSaverView superclass method to avoid this.
*/
@interface SaverLabXScreenSaverWrapper : NSObject {
}
@end

@implementation SaverLabXScreenSaverWrapper

+(void)swizzle {
  Class xClass = NSClassFromString(@"XScreenSaverView");
  if (!xClass) return;
  //NSLog(@"Swizzing XScreenSaverView");
  [xClass replaceSelector:@selector(stopAnimation) withSelector:@selector(stopAnimationReplacement) fromClass_:self];
}

-(void)stopAnimationReplacement {
  //NSLog(@"In swizzled XScreenSaverView stopAnimation");
  IMP stopImp = [NSClassFromString(@"ScreenSaverView") instanceMethodForSelector:@selector(stopAnimation)];
  stopImp(self, @selector(stopAnimation));
}

@end