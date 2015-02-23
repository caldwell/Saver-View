/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabListWindowController.h"
#import "SaverLabModuleList.h"
#import "SaverLabModuleController.h"

@implementation SaverLabListWindowController

-(void)awakeFromNib {
  if (window) {
    [modulesBrowser setDoubleAction:@selector(moduleSelected:)];
    [modulesBrowser setTarget:self];
    [window setExcludedFromWindowsMenu:YES];
    [self refresh];
  }
}

- (IBAction)moduleSelected:(id)sender {
  NSString *name = [[modulesBrowser selectedCell] stringValue];
  Class saverClass = [[SaverLabModuleList sharedInstance] classForModuleName:name];
  SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                              initWithSaverClass:saverClass
                                                           title:name];
  if (controller) {
    [controller showModuleWindow];
    [controller start];
  }
}

-(void)refresh {
  [modulesBrowser loadColumnZero];
}

-(IBAction)showWindow:(id)sender {
  [window makeKeyAndOrderFront:self];
}

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column {
  return [[[SaverLabModuleList sharedInstance] sortedModuleNames] count];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
  [cell setStringValue:[[[SaverLabModuleList sharedInstance] sortedModuleNames] objectAtIndex:row]];
  [cell setLeaf:YES];
}

@end
