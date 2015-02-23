/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SSSController.h"

@implementation SSSController

@class ScreenSaverView;

NSString *PAUSED_STRING = @": Paused"; // should be localized

-(id)initWithBundle:(NSBundle *)bundle title:(NSString *)t {
  self = [super init];
  if (!self) return nil;
  screenSaverClass = [bundle principalClass];
  if (!screenSaverClass) return nil;
  title = [t retain];
  return self;
}

-(void)dealloc {
  [title release];
  [super dealloc];
}

-(void)showWindow {
  NSRect contentViewRect = [[window contentView] frame];
  [window setTitle:title];
  // the ScreenSaverView subclass in the bundle must be the content view of the window
  screenSaverView = [[[screenSaverClass alloc] initWithFrame:contentViewRect isPreview:NO] autorelease];
  [window setContentView:screenSaverView];
  [window makeKeyAndOrderFront:nil];
  // force view to first responder in case this window was already front
  [window makeFirstResponder:screenSaverView]; 
}

-(void)start {
  // Start the module's animation timer
  [screenSaverView startAnimation];
}

-(void)stop {
  // This stops the module's animation timer. Some modules also reset their
  // internal state, which can make the single step feature behave oddly.
  [screenSaverView stopAnimation];
}

//// menu actions

/* respondsToSelector: is overridden so the "Configure" menu item is only enabled
   if the module has a configure sheet.
*/
-(BOOL)respondsToSelector:(SEL)sel {
  if (sel==@selector(showConfigurationSheet:)) {
    return [screenSaverView hasConfigureSheet];
  }
  return [super respondsToSelector:sel];
}

-(void)togglePause:(id)sender {
  BOOL isPausing = [screenSaverView isAnimating];
  if (isPausing) {
    [window setTitle:[title stringByAppendingString:PAUSED_STRING]];
    [self stop];
  }
  else {
    [window setTitle:title];
    [self start];
  }
}

-(void)restart:(id)sender {
  // create a new ScreenSaverView and start over
 if ([screenSaverView isAnimating]) [self stop];
 [self showWindow];
 [self start];
}

-(void)singleStepAnimation:(id)sender {
  // This doesn't work in all modules, since when this method is called the module
  // thinks that it is not animating. Seems to work in everything but the slideshows.
  if ([screenSaverView isAnimating]) {
    [self stop];
    [window setTitle:[title stringByAppendingString:PAUSED_STRING]];
  }
  [screenSaverView lockFocus];
  [screenSaverView animateOneFrame];
  [screenSaverView unlockFocus];
  // needed for non-OpenGL modules to update the display
  [screenSaverView displayIfNeeded];
}

//// configuration sheet methods

-(void)showConfigurationSheet:(id)sender {
  [NSApp beginSheet:[screenSaverView configureSheet]
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

//// window delegate methods
-(void)windowDidResize:(NSNotification *)note {
  // restart when the window is resized
  [self restart:nil];
}

-(void)windowDidBecomeMain:(NSNotification *)note {
  // give keypresses to the ScreenSaverView
  [window makeFirstResponder:screenSaverView];
}

/* drawing into a minimized window causes exceptions, so stop when the window is minimized
   and resume when it is expanded
*/
-(void)windowWillMiniaturize:(NSNotification *)note {
  if ([screenSaverView isAnimating]) [self stop];
}

-(void)windowDidDeminiaturize:(NSNotification *)note {
  if ([screenSaverView isAnimating]) [self start];
}

/* free ourselves when the window closes
*/
-(void)windowWillClose:(NSNotification *)note {
  if ([screenSaverView isAnimating]) [self stop];
  [self autorelease];
}

@end
