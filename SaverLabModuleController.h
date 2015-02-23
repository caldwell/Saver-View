/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

@interface SaverLabModuleController : NSObject
{
    NSWindow *window;
    Class screenSaverClass;
    ScreenSaverView *screenSaverView;
    NSImageRep *backgroundImageRep;
    NSString *title;
    BOOL isInPreviewMode;
    
    BOOL isPaused;
    BOOL isAppHidden;
    BOOL isScreenSaverRunning;
    
    BOOL isResizingWindow;
    
    NSMutableArray *checkedMenuItems;
    
    // fps calculations
    int framesInLastSecond;
    NSTimer *fpsTimer;
    NSTimeInterval lastFPSUpdateTime;
    
    int unlockFocusCount;
    int openGLContextCount;
    
    // outlets for info panel
    NSWindow *infoPanel;
    NSTextField *targetFPSField;
    NSTextField *currentFPSField;
    NSTextField *saverSizeField;
    
    int quicktimeFrameCounter;
    BOOL isRecordingFrames;
    BOOL isFrameCaptureInProgress;
    BOOL isCreatingQuicktimeMovie;
    NSString *temporaryQuicktimeDirectory;
}

-(id)initWithSaverClass:(Class)aClass title:(NSString *)t contentRect:(NSRect)rect;
-(id)initWithSaverClass:(Class)aClass title:(NSString *)t contentSize:(NSSize)contentSize;
-(id)initWithSaverClass:(Class)aClass title:(NSString *)t;
-(id)initFullScreen:(NSScreen *)screen withSaverClass:(Class)aClass title:(NSString *)t;

-(NSWindow *)createWindowWithContentRect:(NSRect)rect;
-(NSWindow *)createFullScreenWindowOnScreen:(NSScreen *)screen;

-(NSString *)title;
-(NSWindow *)moduleWindow;
-(BOOL)isFullScreen;
-(BOOL)isSlideShow;

-(BOOL)isTransparent;
-(void)setIsTransparent:(BOOL)value;

-(BOOL)ignoresMouseEvents;
-(void)setIgnoresMouseEvents:(BOOL)value;

-(void)updateWindowTitle;

-(BOOL)isInPreviewMode;
-(void)setIsInPreviewMode:(BOOL)value;

-(NSString *)windowLayerString;
-(void)setWindowLayerFromString:(NSString *)layerstring;

-(void)showModuleWindow;
-(void)start;
-(void)togglePause:(id)sender;
-(void)stop;
-(void)startIfPossible;

-(void)finishInit;
-(void)setMenuItem:(id <NSMenuItem>)menuItem isChecked:(BOOL)checked;
-(void)checkMenuItem:(id <NSMenuItem>)menuItem ifContentViewHasWidth:(int)w height:(int)h;

-(int)targetFramesPerSecond;
-(BOOL)isTargetFramesPerSecondUnlimited;
-(int)currentFramesPerSecond;
-(void)updateInfoPanelRefreshingCurrentFPS:(BOOL)refreshCurrentFPS;

-(void)saveQuicktimeFrame;
-(void)deleteTemporaryQuicktimeImagesDirectory;

@end

