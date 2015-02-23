/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabNSWindowAdditions.h"
#import <Carbon/Carbon.h>

@implementation NSWindow (SaverLabNSWindowAdditions)

-(void)reallyClose:(id)sender {
  [self close];
}

// copied from http://cocoa.mamasam.com/MACOSXDEV/2002/12/1/52005.php; workaround for 10.2 bug
-(void)setClickThrough_:(BOOL)clickThrough {
  /* carbon */
  void *ref = [self windowRef];
  if (clickThrough)
      ChangeWindowAttributes(ref, kWindowIgnoreClicksAttribute,
kWindowNoAttributes);
  else
      ChangeWindowAttributes(ref, kWindowNoAttributes,
kWindowIgnoreClicksAttribute);
  /* cocoa */
  [self setIgnoresMouseEvents:clickThrough];
}

-(float)userSpaceScaleFactor_ {
  if ([self respondsToSelector:@selector(userSpaceScaleFactor)]) {
    return (float)[self userSpaceScaleFactor];
  }
  else return 1.0f;
}

@end
