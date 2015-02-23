/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabStdoutWindowController.h"
#import "SaverLabPreferences.h"

@implementation SaverLabStdoutWindowController

-(BOOL)loadNibIfNeeded {
  if (!window) {
    [NSBundle loadNibNamed:@"StdoutWindow" owner:self];
    return YES;
  }
  return NO;
}

-(void)showWindow:(id)sender {
  [self loadNibIfNeeded];
  [window makeKeyAndOrderFront:self];
}

-(void)addData:(NSData *)data isStderr:(BOOL)isStderr {
  [self loadNibIfNeeded];
  // show window if this is the first output or if preference is set to always show on new output
  if ([[outputTextView string] length]==0 || [[SaverLabPreferences sharedInstance] showConsoleWindowOnOutput]) {
    [window makeKeyAndOrderFront:self];
  }
  [outputTextView replaceCharactersInRange:NSMakeRange([[outputTextView string] length],0)
     withString:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
  [outputTextView scrollRangeToVisible:NSMakeRange([[outputTextView string] length], 0)];
}

@end
