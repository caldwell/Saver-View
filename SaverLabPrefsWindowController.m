/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabPrefsWindowController.h"
#import "SaverLabPreferences.h"
#import "SaverLabNSButtonAdditions.h"

/* Item tags in the size popup menu are stored as integers in the decimal form 
WWWWHHHH, where WWWW is the width and HHHH is the height. For example, the size
160x120 is represented as 1600120. 
*/
static NSSize sizeForTag(int tag) {
  int width  = tag / 10000;
  int height = tag % 10000;
  return NSMakeSize((float)width, (float)height);
}

static int tagForSize(NSSize size) {
  int width = (int)size.width;
  int height = (int)size.height;
  int tag = 10000*width+height;
  return tag;
}

@implementation SaverLabPrefsWindowController

-(IBAction)showWindow:(id)sender {
  // update controls only if the window is "closed"
  if (![window isVisible]) [self readPreferences];
  
  [window setLevel:NSFloatingWindowLevel];
  [window makeKeyAndOrderFront:self];
}

-(IBAction)cancelPreferences:(id)sender {
  [window close];
}

-(IBAction)savePreferences:(id)sender {
  [self writePreferences];
  [window close];
}

-(void)readPreferences {
  SaverLabPreferences *prefs = [SaverLabPreferences sharedInstance];
  // size popup menu, NSMenuItem tags are widths (160, 320...)
  int tag = tagForSize([prefs defaultModuleWindowSize]);
  int index = [sizePopupMenu indexOfItemWithTag:tag];
  if (index>=0) [sizePopupMenu selectItemAtIndex:index];
  // checkboxes
  [restoreWindowsCheckbox setIsChecked:[prefs restoreModuleWindowsOnStartup]];
  [showListOnStartupCheckbox setIsChecked:[prefs showModuleListOnStartup]];
  [showListWhenNoWindowsOpenCheckbox setIsChecked:[prefs showModuleListWhenNoOpenWindows]];
  [autoUpdateModulesCheckbox setIsChecked:[prefs autoUpdateModuleList]];
  [showConsoleWindowCheckbox setIsChecked:[prefs showConsoleWindowOnOutput]];
  
  // recording settings
  [createYesDeleteYesRadioButton setIsChecked:[prefs createMovieFromRecordedImages] &&
                                              [prefs deleteRecordedImages]];                     
  [createYesDeleteNoRadioButton  setIsChecked:[prefs createMovieFromRecordedImages] &&
                                              ![prefs deleteRecordedImages]];
  [createNoDeleteNoRadioButton   setIsChecked:![prefs createMovieFromRecordedImages] &&
                                              ![prefs deleteRecordedImages]];
  
  [moduleRateRadioButton setIsChecked:![prefs useCustomFrameRate]];
  [customRateRadioButton setIsChecked:[prefs useCustomFrameRate]];
  [customRateTextField setIntValue:[prefs customFrameRate]];
  
  [imagesDirectoryTextField setStringValue:[prefs recordedImagesDirectory]];
}

-(void)writePreferences {
  SaverLabPreferences *prefs = [SaverLabPreferences sharedInstance];
  
  // todo: validate images directory is writeable
  
  // size popup menu
  NSSize size = sizeForTag([[sizePopupMenu selectedItem] tag]);
  [prefs setDefaultModuleWindowSize:size];
  // checkboxes
  [prefs setRestoreModuleWindowsOnStartup:[restoreWindowsCheckbox isChecked]];
  [prefs setShowModuleListOnStartup:[showListOnStartupCheckbox isChecked]];
  [prefs setShowModuleListWhenNoOpenWindows:[showListWhenNoWindowsOpenCheckbox isChecked]];
  [prefs setAutoUpdateModuleList:[autoUpdateModulesCheckbox isChecked]];
  [prefs setShowConsoleWindowOnOutput:[showConsoleWindowCheckbox isChecked]];
  
  // recording settings
  [prefs setCreateMovieFromRecordedImages:[createYesDeleteYesRadioButton isChecked] ||
                                          [createYesDeleteNoRadioButton isChecked]];
  [prefs setDeleteRecordedImages:[createYesDeleteYesRadioButton isChecked]];
  [prefs setUseCustomFrameRate:[customRateRadioButton isChecked]];
  [prefs setCustomFrameRate:[customRateTextField intValue]];
  [prefs setRecordedImagesDirectory:[imagesDirectoryTextField stringValue]];
}

// images directory support
-(IBAction)chooseImagesDirectory:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO];
  [panel beginSheetForDirectory:NSHomeDirectory()
                           file:nil 
                          types:nil
                 modalForWindow:window 
                  modalDelegate:self 
                 didEndSelector:@selector(imageDirectoryPanelClosed:result:info:)
                    contextInfo:nil];
}

-(void)imageDirectoryPanelClosed:(NSOpenPanel *)panel result:(int)result info:(void *)unused {
  if (result==NSOKButton) {
    [imagesDirectoryTextField setStringValue:[panel directory]];
  }
  [panel orderOut:nil];
}

-(IBAction)resetImagesDirectory:(id)sender {
  [imagesDirectoryTextField setStringValue:NSHomeDirectory()];
}


@end
