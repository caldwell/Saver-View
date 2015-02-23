/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabNSOpenGLContextPoser.h"

/** This class poses as NSOpenGLContext so that it can send notifications when makeCurrentContext
is called, indicating that an OpenGL view is about to draw a frame. As with SaverLabSSViewPoser,
the notification is received by SaverLabModuleController to compute the number of frames per
second drawn. This class is needed because some modules, such as Aqua Icons, don't call
lockFocus/unlockFocus.
*/

@implementation SaverLabNSOpenGLContextPoser

+(void)load {
//  [self poseAsClass:[NSOpenGLContext class]];
}

-(void)makeCurrentContext {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenSaverDrewOpenGLFrame" object:[[self view] superview]];
  [super makeCurrentContext];
}

@end
