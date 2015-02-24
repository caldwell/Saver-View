/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

@interface SaverLabModuleController : NSObject <NSWindowDelegate>
{
    NSWindow *window;
    Class screenSaverClass;
    NSString *screenSaverPath;
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
    
    int frameCount;
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

// "master" initializer, not called directly
-(id)initWithModulePath:(NSString *)path title:(NSString *)t contentRect:(NSRect)contentRect fullscreen:(NSScreen *)screen;

// initializers to be called from clients
-(id)initWithModulePath:(NSString *)path;
-(id)initWithModuleName:(NSString *)name;
-(id)initWithModulePath:(NSString *)path contentRect:(NSRect)contentRect;
-(id)initWithModuleName:(NSString *)name contentRect:(NSRect)contentRect;
-(id)initFullScreen:(NSScreen *)screen withModulePath:(NSString *)path;
-(id)initFullScreen:(NSScreen *)screen withModuleName:(NSString *)name;

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

-(IBAction)makeSize720p:(id)sender;
-(IBAction)makeSize1080p:(id)sender;

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

