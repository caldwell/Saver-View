/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>

@interface SaverLabPrefsWindowController : NSObject
{
    // "General" widgets
    IBOutlet id restoreWindowsCheckbox;
    IBOutlet id showListWhenNoWindowsOpenCheckbox;
    IBOutlet id showListOnStartupCheckbox;
    IBOutlet id autoUpdateModulesCheckbox;
    IBOutlet id sizePopupMenu;
    IBOutlet id consoleWindowEnabledCheckbox;
    IBOutlet id showConsoleWindowCheckbox;
    
    // "Recording" widgets
    IBOutlet id createYesDeleteYesRadioButton;
    IBOutlet id createYesDeleteNoRadioButton;
    IBOutlet id createNoDeleteNoRadioButton;
    
    IBOutlet id moduleRateRadioButton;
    IBOutlet id customRateRadioButton;
    IBOutlet id customRateTextField;
    
    IBOutlet id imagesDirectoryTextField;
    
    IBOutlet id window;
}
-(IBAction)showWindow:(id)sender;
-(IBAction)cancelPreferences:(id)sender;
-(IBAction)savePreferences:(id)sender;
-(IBAction)chooseImagesDirectory:(id)sender;
-(IBAction)resetImagesDirectory:(id)sender;

-(void)readPreferences;
-(void)writePreferences;
@end
