/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabBrowserWindowController.h"
#import "SaverLabModuleList.h"
#import "SaverLabPreferences.h"
#import "SaverLabModuleController.h"
#import "SaverLabNSButtonAdditions.h"

@implementation SaverLabBrowserWindowController

-(void)awakeFromNib {
  [modulesBrowser setDoubleAction:@selector(moduleDoubleClicked:)];
  [modulesBrowser setTarget:self];
  [window setExcludedFromWindowsMenu:YES];
  [self refresh];
  // set up application hide/unhide notifications
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(appHidden:)
                                               name:NSApplicationWillHideNotification
                                             object:nil];
  lastSelectedModule = nil;
}

- (IBAction)moduleDoubleClicked:(id)sender {
  NSString *name = [[modulesBrowser selectedCell] stringValue];
  Class saverClass = [[SaverLabModuleList sharedInstance] classForModuleName:name];
  SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                              initWithSaverClass:saverClass
                                                           title:name];
  if (controller) {
    [controller setIsInPreviewMode:[openInPreviewModeCheckbox isChecked]];
    [controller showModuleWindow];
    [controller start];
  }
}

-(IBAction)browserModuleSelected:(id)sender {
  NSString *name = [[modulesBrowser selectedCell] stringValue];

  if ([self isPreviewVisible] && ![name isEqualTo:lastSelectedModule]) {
    previewSaverClass = [[SaverLabModuleList sharedInstance] classForModuleName:name];
    if (previewSaverClass) {
      [self removePreviewSaver];
      
      previewSaverView = [[[previewSaverClass alloc] initWithFrame:[previewView bounds] 
                                                         isPreview:YES] autorelease];
      [previewSaverView setFrame:[previewView bounds]];
      [previewView addSubview:previewSaverView];
      [previewSaverView startAnimation];
      [previewSaverView setNeedsDisplay:YES];
      
      [configureButton setEnabled:[previewSaverView hasConfigureSheet]];
      
      [lastSelectedModule release];
      lastSelectedModule = [name retain];
    }
  }
}

-(NSRect)previewFrameRect {
  return [previewView frame];
}

-(BOOL)isPreviewVisible {
  return [previewCheckbox state]==NSOnState;
}


// Stops and removes the preview ScreenSaverView, and sets previewSaverView to nil.
// Does nothing if previewSaverView is nil.
-(void)removePreviewSaver {
  if ([previewSaverView isAnimating]) [previewSaverView stopAnimation];
  [previewSaverView removeFromSuperview];
  previewSaverView = nil;
  lastSelectedModule = nil;
}

-(BOOL)isPreviewCheckboxChecked {
  return [previewCheckbox state]==NSOnState;
}

-(IBAction)previewCheckboxToggled:(id)sender {
  NSRect rect = [self frameRectWithPreviewVisible:[self isPreviewCheckboxChecked]];
  if (![self isPreviewCheckboxChecked]) {
    [self removePreviewSaver];
  }
  [[SaverLabPreferences sharedInstance] setIsPreviewVisible:[self isPreviewCheckboxChecked]];
  [window setFrame:rect display:YES animate:YES];
}

-(NSRect)frameRectWithPreviewVisible:(BOOL)visible {
  NSRect frame = [window frame];
  frame.size.width = [self windowWidthWithPreviewVisible:visible];
  return frame;
}

-(int)windowWidthWithPreviewVisible:(BOOL)visible {
  NSRect previewViewFrame = [previewView frame];
  if (visible) {
    return previewViewFrame.origin.x + previewViewFrame.size.width + 20;
  }
  else {
    return previewViewFrame.origin.x - 1;
  }
}

-(void)refresh {
  [modulesBrowser loadColumnZero];
}

-(IBAction)showWindow:(id)sender {
  if (![window isVisible]) {
    BOOL previewVisible = [[SaverLabPreferences sharedInstance] isPreviewVisible];
    [previewCheckbox setState:((previewVisible) ? NSOnState : NSOffState)];
    [window setFrame:[self frameRectWithPreviewVisible:previewVisible] display:NO];
  }
  [window makeKeyAndOrderFront:self];
}

-(BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
  SEL action = [menuItem action];
  if (action==@selector(showConfigurationSheet:)) {
    return [previewSaverView hasConfigureSheet];
  }
  return YES;
}

// configuration sheet support

-(void)showConfigurationSheet:(id)sender {
  [NSApp beginSheet:[previewSaverView configureSheet]
     modalForWindow:window 
      modalDelegate:self
     didEndSelector:@selector(configureSheetEnded:returnCode:contextInfo:)
        contextInfo:nil];
}

-(void)configureSheetEnded:(NSWindow *)sheet returnCode:(int)code contextInfo:(void *)info {
  // needed to make the sheet go away
  [sheet orderOut:nil];
  // the saver module should restart itself if needed
}


// NSBrowser delegate methods

-(int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column {
  return [[[SaverLabModuleList sharedInstance] sortedModuleNames] count];
}

-(void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
  [cell setStringValue:[[[SaverLabModuleList sharedInstance] sortedModuleNames] objectAtIndex:row]];
  [cell setLeaf:YES];
}

// window delegate methods

-(NSSize)windowWillResize:(NSWindow *)w toSize:(NSSize)size {
  size.width = [self windowWidthWithPreviewVisible:[self isPreviewCheckboxChecked]];
  return size;
}

-(void)windowWillClose:(NSNotification *)note {
  if ([self isPreviewVisible]) {
    [self removePreviewSaver];
  }
}

// app hidden notification
// not worrying about trying to intelligently restart preview, just stop it
-(void)appHidden:(NSNotification *)note {
  if ([self isPreviewVisible]) {
    [self removePreviewSaver];
  }
}

@end
