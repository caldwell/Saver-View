/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>

/** If the "Close" menu command is bound to the FirstResponder's performClose: method,
it will not be enabled when a full screen window is frontmost. Overriding respondsToSelector:
in SaverLabFullScreenWindow doesn't help, so instead this category defines a new method
reallyClose: that closes the window using -[NSWindow close]. The Close menu command can then
be bound to reallyClose: and it will work for full screen and normal windows.
*/

@interface NSWindow (SaverLabNSWindowAdditions)

-(void)reallyClose:(id)sender;

/** Sets mouse clicks to be ignored by both Cocoa and Carbon apps. -setIgnoresMouseEvents:
only works for Cocoa apps, Carbon apps need special handling (see code)
*/
-(void)setClickThrough_:(BOOL)clickThrough;

/** Resolution independence support. Only available in Tiger, so return the default value of 1.0 if
-userSpaceScaleFactor isn't available.
*/
-(float)userSpaceScaleFactor_;

@end
