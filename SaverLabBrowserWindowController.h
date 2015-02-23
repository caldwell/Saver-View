/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

@interface SaverLabBrowserWindowController : NSObject
{
    IBOutlet id modulesBrowser;
    IBOutlet id window;
    IBOutlet id previewCheckbox;
    IBOutlet id openInPreviewModeCheckbox;
    IBOutlet id previewView;
    IBOutlet id configureButton;
    
    NSString *lastSelectedModule;
    ScreenSaverView *previewSaverView;
}
-(IBAction)browserModuleSelected:(id)sender;
-(IBAction)showWindow:(id)sender;
-(NSRect)frameRectWithPreviewVisible:(BOOL)visible;
-(float)windowWidthWithPreviewVisible:(BOOL)visible;

-(BOOL)isPreviewCheckboxChecked;
-(BOOL)isPreviewVisible;
-(NSRect)previewFrameRect;

-(void)removePreviewSaver;
-(void)refresh;

@end
