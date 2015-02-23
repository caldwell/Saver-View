/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabModuleController.h"
#import "SaverLabFullScreenWindow.h"
#import "SaverLabPreferences.h"
#import "SaverLabModuleList.h"
#import "SaverLabScreenSaverViewAdditions.h"
#import "SaverLabQTProgressWindowController.h"
#import "SaverLabNSWindowAdditions.h"

#include <OpenGL/glu.h>
#include <GLUT/glut.h>

// default initial window position if not specified
static NSRect defaultContentRect() {
  NSRect screenFrame = [[NSScreen mainScreen] frame];
  NSSize size = [[SaverLabPreferences sharedInstance] defaultModuleWindowSize];
  return NSMakeRect(screenFrame.origin.x+50,
                    screenFrame.origin.y+screenFrame.size.height-size.height-60,
                    size.width, size.height);
}

// keep track of the last directory a background image was opened from
static NSString *gLastImageDirectory = nil;

static float gTransparentWindowAlpha = 0.3;

////////////////////////////////////////////////////////////////////////////////////////

@implementation SaverLabModuleController

@class ScreenSaverView;

-(id)initWithModulePath:(NSString *)path title:(NSString *)t contentRect:(NSRect)contentRect fullscreen:(NSScreen *)screen {
  self = [super init];
  screenSaverClass = [[SaverLabModuleList sharedInstance] classForModulePath:path];
  if (!screenSaverClass) {
    [self release];
    return nil;
  }
  screenSaverPath = [path retain];
  title = [t retain];

  if (screen) {
    window = [self createFullScreenWindowOnScreen:screen];
  }
  else {
    window = [self createWindowWithContentRect:contentRect];
  }
  if (!window) {
    [self release];
    return nil;
  }

  [self finishInit];
  return self;
}

-(id)initWithModulePath:(NSString *)path contentRect:(NSRect)contentRect {
  return [self initWithModulePath:path title:[[path lastPathComponent] stringByDeletingPathExtension] contentRect:contentRect fullscreen:nil];
}

-(id)initWithModuleName:(NSString *)name contentRect:(NSRect)contentRect {
  NSString *path = [[SaverLabModuleList sharedInstance] pathForModuleName:name];
  return [self initWithModulePath:path title:name contentRect:contentRect fullscreen:nil];
}

-(id)initWithModulePath:(NSString *)path {
  return [self initWithModulePath:path title:[[path lastPathComponent] stringByDeletingPathExtension] contentRect:defaultContentRect() fullscreen:nil];
}

-(id)initWithModuleName:(NSString *)name {
  NSString *path = [[SaverLabModuleList sharedInstance] pathForModuleName:name];
  return [self initWithModulePath:path title:name contentRect:defaultContentRect() fullscreen:nil];
}

-(id)initFullScreen:(NSScreen *)screen withModulePath:(NSString *)path {
  if (!screen) screen = [NSScreen mainScreen];
  return [self initWithModulePath:path title:[[path lastPathComponent] stringByDeletingPathExtension] contentRect:defaultContentRect() fullscreen:screen];
}

-(id)initFullScreen:(NSScreen *)screen withModuleName:(NSString *)name {
  if (!screen) screen = [NSScreen mainScreen];
  NSString *path = [[SaverLabModuleList sharedInstance] pathForModuleName:name];
  return [self initWithModulePath:path title:name contentRect:defaultContentRect() fullscreen:screen];
}

-(NSWindow *)createWindowWithContentRect:(NSRect)rect {
  window = [[NSWindow alloc] initWithContentRect:rect
                styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask)
                  backing:[screenSaverClass backingStoreType]
                    defer:YES];
  [window setMinSize:NSMakeSize(120,90)];
  [window setDelegate:self];
  [window setOneShot:NO];
  return window;
}

-(NSWindow *)createFullScreenWindowOnScreen:(NSScreen *)screen {
  // SaverLabFullScreenWindow subclass of NSWindow is used to allow the borderless window
  // to become key and main
  window = [[SaverLabFullScreenWindow alloc] initWithContentRect:[screen frame]
                                                  styleMask:NSBorderlessWindowMask
                                                    backing:[screenSaverClass backingStoreType]
                                                      defer:YES];
  [window setDelegate:self];
  return window;
}

-(void)finishInit {
  isPaused = isAppHidden = isScreenSaverRunning = NO;
  isInPreviewMode = NO;
  backgroundImageRep = nil;
  lastFPSUpdateTime = [[NSDate distantFuture] timeIntervalSinceReferenceDate];
  checkedMenuItems = [[NSMutableArray alloc] init];

  // set up application hide/unhide notifications
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appHidden:)
                                               name:NSApplicationWillHideNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appUnhidden:)
                                               name:NSApplicationDidUnhideNotification
                                             object:nil];

  // screen saver activation/deactivation notifications
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenSaverActivated:)
                                               name:@"ScreenSaverActivated"
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenSaverDeactivated:)
                                               name:@"ScreenSaverDeactivated"
                                             object:nil];

  // frame count timer and notification
  fpsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(updateFPS:)
                                 userInfo:nil
                                  repeats:YES];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenSaverDrewFrame:)
                                               name:@"ScreenSaverDrewFrame"
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenSaverDrewOpenGLFrame:)
                                               name:@"ScreenSaverDrewOpenGLFrame"
                                             object:nil];
}

-(void)dealloc {
  [screenSaverPath release];
  [title release];
  [backgroundImageRep release];
  [checkedMenuItems release];
  // remove self as observer
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  //NSLog(@"Deallocating SaverLabModuleController");
  if (fpsTimer) {
    [fpsTimer invalidate];
    [fpsTimer release];
    fpsTimer = nil;
  }
  [super dealloc];
}

-(NSImageRep *)backgroundImageRep {
  return backgroundImageRep;
}

-(void)setBackgroundImageRep:(NSImageRep *)imageRep {
  id tmp = backgroundImageRep;
  backgroundImageRep = [imageRep retain];
  [tmp release];
}

-(NSString *)title {
  return title;
}

-(void)setTitle:(NSString *)str {
  id tmp = title;
  title = [str retain];
  [tmp release];
}

-(BOOL)isInPreviewMode {
  return isInPreviewMode;
}

-(void)setIsInPreviewMode:(BOOL)value {
  isInPreviewMode = value;
}

// technically these accessors should be synchronized
-(NSString *)lastImageDirectory {
  if (gLastImageDirectory) return gLastImageDirectory;
  else return NSHomeDirectory();
}

-(void)setLastImageDirectory:(NSString *)dir {
  if (gLastImageDirectory!=dir) {
    [gLastImageDirectory release];
    gLastImageDirectory = [dir retain];
  }
}

-(NSWindow *)moduleWindow {
  return window;
}

-(BOOL)isFullScreen {
  return ([window styleMask]==NSBorderlessWindowMask);
}

// returns YES if this module is a slide show (Cosmos, Forest, etc). Used to disable the
// single step functionality for slide shows because it can cause crashes.
-(BOOL)isSlideShow {
  return ([NSStringFromClass([screenSaverView class]) isEqualToString:@"SlideShowView"]);
}

-(void)showModuleWindow {
  NSRect contentViewRect = [[window contentView] frame];
  [self updateWindowTitle];
  // the ScreenSaverView subclass in the is the content view of the window

  screenSaverView = [[[SaverLabModuleList sharedInstance] createScreenSaverViewForModulePath:screenSaverPath frame:contentViewRect isPreview:[self isInPreviewMode]] autorelease];

  [window setContentView:screenSaverView];
  [window makeKeyAndOrderFront:nil];
  // force view to first responder in case this window was already front
  [window makeFirstResponder:screenSaverView];
}

-(void)start {
  if (![screenSaverView isAnimating]) {
    // Start the module's animation timer
    [screenSaverView startAnimation];
    [screenSaverView displayIfNeeded];
    if (backgroundImageRep) {
      // if we draw the image immediately, the ScreenSaverView will overwrite it, so we draw the
      // image in a future run loop iteration
      [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(drawBackgroundImage:)
      userInfo:nil repeats:NO];
    }
  }
}

-(void)drawBackgroundImage:(NSTimer *)timer {
  [screenSaverView lockFocus];
  [backgroundImageRep drawInRect:[screenSaverView frame]];
  [screenSaverView unlockFocus];
  [screenSaverView displayIfNeeded];
}

-(void)stop {
  // This stops the module's animation timer. Some modules also reset their
  // internal state, which can make the single step feature behave oddly.
  if ([screenSaverView isAnimating]) [screenSaverView stopAnimation];
}

/* Starts the animation unless a condition exists in which it should not start
(app is hidden, real screensaver is running, it's already running)
*/
-(void)startIfPossible {
  if (!isPaused && !isAppHidden && !isScreenSaverRunning && ![screenSaverView isAnimating]) {
    [self start];
  }
}

/* Updates the window title to reflect the paused and/or recording states.
*/
-(void)updateWindowTitle {
  NSString *windowTitle = title;
  if (isPaused) windowTitle = [windowTitle stringByAppendingString:NSLocalizedString(@"PAUSED_WINDOW_SUFFIX",nil)];
  if (isRecordingFrames) windowTitle = [windowTitle stringByAppendingString:NSLocalizedString(@"RECORDING_WINDOW_SUFFIX",nil)];
  [window setTitle:windowTitle];
}

//// menu actions

-(void)togglePause:(id)sender {
  BOOL isPausing = [screenSaverView isAnimating];
  if (isPausing) {
    isPaused = YES;
    [self stop];
  }
  else {
    isPaused = NO;
    [self startIfPossible];
  }
  [self updateWindowTitle];
}

-(void)restart:(id)sender {
  // create a new ScreenSaverView and start over
 [self stop];
 isPaused = NO;
 [self showModuleWindow];
 [self startIfPossible];
}

-(void)singleStepAnimation:(id)sender {
  // This doesn't work in all modules, since when this method is called the module
  // thinks that it is not animating. Seems to work in everything but the slideshows.
  if (![self isSlideShow]) {
    if ([screenSaverView isAnimating]) {
      isPaused = YES;
      [self stop];
      [self updateWindowTitle];
    }
    [screenSaverView lockFocus];
    [screenSaverView animateOneFrame];
    [screenSaverView unlockFocus];
    // needed for non-OpenGL modules to update the display
    [screenSaverView displayIfNeeded];
  }
}


//// window layer actions
-(void)moveToFrontLayer:(id)sender {
  [window setLevel:NSFloatingWindowLevel];
  [window setClickThrough_:NO];
}

-(void)moveToStandardLayer:(id)sender {
  [window setLevel:NSNormalWindowLevel];
  [window setClickThrough_:NO];
}

-(void)moveToBackLayer:(id)sender {
  [window setLevel:kCGDesktopIconWindowLevel-1];
  [window setClickThrough_:NO];
}

-(NSString *)windowLayerString {
  if ([window level]==NSFloatingWindowLevel) return @"Front";
  if ([window level]==NSNormalWindowLevel) return @"Normal";
  return @"Back";
}

-(void)setWindowLayerFromString:(NSString *)layerstring {
  if ([layerstring isEqualTo:@"Front"]) [self moveToFrontLayer:nil];
  else if ([layerstring isEqualTo:@"Back"]) [self moveToBackLayer:nil];
  else [self moveToStandardLayer:nil];
}

//// window size methods

/* Full screen windows have no borders, so when the user makes a window full screen
we actually destroy the current window, create a borderless full screen window, and
copy the necessary state. The same applies for making a full screen window not full screen.
*/
-(void)makeFullScreen:(id)sender {
  if (![self isFullScreen]) {
    int level = [window level];
    NSScreen *screen = [window screen];
    isResizingWindow = YES; // prevents release when screen saver window closes
    [window close];
    window = [self createFullScreenWindowOnScreen:screen];
    [window setLevel:level];
    [self showModuleWindow];
    [self start];
    [self updateInfoPanelRefreshingCurrentFPS:NO];
  }
}

// makes the window full screen and puts it in the back layer
-(void)makeDesktopBackground:(id)sender {
  [self makeFullScreen:nil];
  [self moveToBackLayer:nil];
  [self setIsTransparent:NO];
  [window setClickThrough_:YES];
}

-(void)makeTransparentBackground:(id)sender {
  [self makeFullScreen:nil];
  [self moveToBackLayer:nil];
  [self setIsTransparent:YES];
  [window setClickThrough_:YES];
}

-(void)makeTransparentForeground:(id)sender {
  [self moveToFrontLayer:nil];
  [self makeFullScreen:nil];
  [self setIsTransparent:YES];
  [window setClickThrough_:YES];
}

-(NSRect)defaultFrameForWidth:(int)w height:(int)h screen:(NSScreen *)screen {
  NSRect screenFrame = [screen frame];
  return NSMakeRect(screenFrame.origin.x+50, screenFrame.origin.y+screenFrame.size.height-60-h, w, h);
}

-(BOOL)isTransparent {
  return ([window alphaValue]<1.0);
}
-(void)setIsTransparent:(BOOL)value {
  [window setAlphaValue:(value) ? gTransparentWindowAlpha : 1.0];
}

-(void)toggleTransparency:(id)sender {
  [self setIsTransparent:![self isTransparent]];
}

-(BOOL)ignoresMouseEvents {
  return [window ignoresMouseEvents];
}
-(void)setIgnoresMouseEvents:(BOOL)value {
  [window setClickThrough_:value];
}

// width and height are of the content view, not the window itself
-(void)setWindowWidth:(int)w height:(int)h {
  if ([self isFullScreen]) {
    int level = [window level];
    NSScreen *windowScreen = [window screen];
    NSRect newRect = [self defaultFrameForWidth:w height:h screen:windowScreen];
    isResizingWindow = YES; // prevents release when screen saver window closes
    [window close];

    window = [self createWindowWithContentRect:newRect];
    [window setLevel:level];
    [self showModuleWindow];
    [self start];
    [self updateInfoPanelRefreshingCurrentFPS:NO];
  }
  else {
    NSRect frameRect = [window frame];
    NSRect oldContentRect = [NSWindow contentRectForFrameRect:frameRect styleMask:[window styleMask]];
    NSRect contentRect = NSMakeRect(oldContentRect.origin.x,
                                    oldContentRect.origin.y+oldContentRect.size.height-h,
                                    w,
                                    h);
    // convert content view size to frame size
    [window setFrame:[NSWindow frameRectForContentRect:contentRect styleMask:[window styleMask]]
             display:NO];
  }
}

-(void)makeSize160:(id)sender {
  [self setWindowWidth:160 height:120];
}

-(void)makeSize320:(id)sender {
  [self setWindowWidth:320 height:240];
}

-(void)makeSize480:(id)sender {
  [self setWindowWidth:480 height:360];
}

-(void)makeSize640:(id)sender {
  [self setWindowWidth:640 height:480];
}

-(void)makeSize800:(id)sender {
  [self setWindowWidth:800 height:600];
}

-(void)makeSize1024:(id)sender {
  [self setWindowWidth:1024 height:768];
}
-(void)makeSize720p:(id)sender {
  [self setWindowWidth:1280 height:720];
}
-(void)makeSize1080p:(id)sender {
  [self setWindowWidth:1980 height:1080];
}

-(void)selectBackgroundImage:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  int result = [openPanel runModalForDirectory:[self lastImageDirectory] file:nil types:nil];
  if (result==NSOKButton) {
    NSString *filename  = [[openPanel filenames] lastObject];
    NSString *directory = [filename stringByDeletingLastPathComponent];
    NSData *imageData = [NSData dataWithContentsOfFile:[[openPanel filenames] lastObject]];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    [self setLastImageDirectory:directory];
    [self setBackgroundImageRep:imageRep];
    [self restart:nil];
  }
}

-(void)speedUp:(id)sender {
  NSTimeInterval interval = [screenSaverView animationTimeInterval];
  interval /= 1.5;
  if (interval<0.009) interval = 0;
  [screenSaverView setAnimationTimeInterval:interval];
  [self updateInfoPanelRefreshingCurrentFPS:NO];
}

-(void)slowDown:(id)sender {
  NSTimeInterval interval = [screenSaverView animationTimeInterval];
  if (interval<0.01) interval = 0.01;
  else interval *= 1.5;
  [screenSaverView setAnimationTimeInterval:interval];
  [self updateInfoPanelRefreshingCurrentFPS:NO];
}

//// copying and saving images
-(NSData *)tiffDataForSaverImage {
  NSBitmapImageRep *imageRep;
  isFrameCaptureInProgress = YES; // so we don't trigger frame counts
                                  //NSLog(@"%d:getting image",quicktimeFrameCounter);
  imageRep = [screenSaverView viewContentsAsImageRep];
  isFrameCaptureInProgress = NO;
  return [imageRep TIFFRepresentation];
}

-(void)copy:(id)sender {
  NSData *tiffData = [self tiffDataForSaverImage];
  if (tiffData) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
    [pb setData:tiffData forType:NSTIFFPboardType];
  }
  else {
    NSBeep();
  }
}

-(void)cut:(id)sender {
  [self copy:sender];
}

-(void)saveFrame:(id)sender {
  NSData *savedTiffData = [[self tiffDataForSaverImage] retain];
  if (savedTiffData) {
    NSImage *image = [[[NSImage alloc] initWithData:savedTiffData] autorelease];
    NSRect imageRect = NSMakeRect(0,0,160,120);
    NSImageView *imageView = [[[NSImageView alloc] initWithFrame:imageRect] autorelease];
    NSSavePanel *panel = [NSSavePanel savePanel];

    [imageView setImageScaling:NSScaleProportionally];
    [imageView setImageFrameStyle:NSImageFrameNone];
    [imageView setImage:image];
    [panel setAccessoryView:imageView];
    [panel beginSheetForDirectory:nil
                             file:[title stringByAppendingPathExtension:@"tiff"]
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(saveFramePanelEnded:code:tiffData:)
                      contextInfo:[savedTiffData retain]];
  }
}

-(void)saveFramePanelEnded:(NSSavePanel *)panel code:(int)code tiffData:(NSData *)data {
  if (code==NSOKButton) {
    [data writeToFile:[panel filename] atomically:YES];
  }
  [data release];
}

//// menu state

/* -validateMenuItem  sets checkmarks for the front/standard/back window layer items
and the window size items.
*/
-(BOOL)validateMenuItem:(id)menuItem {
  SEL action = [menuItem action];
  if (action==@selector(makeFullScreen:)) {
    [self setMenuItem:menuItem isChecked:[self isFullScreen]];
  }
  else if (action==@selector(selectBackgroundImage:)) {
    // don't allow selecting background images for OpenGL modules
    if ([[[screenSaverView subviews] lastObject] isKindOfClass:[NSOpenGLView class]]) return NO;
    else return YES;
  }
  else if (action==@selector(showConfigurationSheet:)) {
    return [screenSaverView hasConfigureSheet];
  }
  else if (action==@selector(moveToFrontLayer:)) {
    [self setMenuItem:menuItem isChecked:([window level]>NSNormalWindowLevel)];
  }
  else if (action==@selector(moveToStandardLayer:)) {
    [self setMenuItem:menuItem isChecked:([window level]==NSNormalWindowLevel)];
  }
  else if (action==@selector(moveToBackLayer:)) {
    [self setMenuItem:menuItem isChecked:([window level]<NSNormalWindowLevel)];
  }
  else if (action==@selector(makeSize160:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:160 height:120];
  }
  else if (action==@selector(makeSize320:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:320 height:240];
  }
  else if (action==@selector(makeSize480:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:480 height:360];
  }
  else if (action==@selector(makeSize640:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:640 height:480];
  }
  else if (action==@selector(makeSize800:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:800 height:600];
  }
  else if (action==@selector(makeSize1024:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:1024 height:768];
  }
  else if (action==@selector(makeSize720p:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:1280 height:720];
  }
  else if (action==@selector(makeSize1080p:)) {
    [self checkMenuItem:menuItem ifContentViewHasWidth:1920 height:1080];
  }
  else if (action==@selector(makeDesktopBackground:)) {
    return !([self isFullScreen] && [window level]<NSNormalWindowLevel && [window alphaValue]>=1.0);
  }
  else if (action==@selector(makeTransparentForeground:)) {
    return !([self isFullScreen] && [window level]>NSNormalWindowLevel);
  }
  else if (action==@selector(makeTransparentBackground:)) {
    return !([self isFullScreen] && [window level]<NSNormalWindowLevel && [window alphaValue]<1.0);
  }
  else if (action==@selector(toggleTransparency:)) {
    [self setMenuItem:menuItem isChecked:[self isTransparent]];
  }
  else if (action==@selector(singleStepAnimation:)) {
    // disable single step for slide show modules because it can cause crashes.
    // revisit this when ScreenSaver framework is updated
    //return ![self isSlideShow];
  }
  return YES;
}

-(void)checkMenuItem:(id <NSMenuItem>)menuItem ifContentViewHasWidth:(int)w height:(int)h {
  // always uncheck if full screen
  BOOL checked = ![self isFullScreen] && NSEqualSizes([[window contentView] frame].size,NSMakeSize(w,h));
  [self setMenuItem:menuItem isChecked:checked];
}

-(void)setMenuItem:(id <NSMenuItem>)menuItem isChecked:(BOOL)checked {
  if (checked) {
    [menuItem setState:NSOnState];
    [checkedMenuItems addObject:menuItem];
  }
  else {
    [menuItem setState:NSOffState];
    [checkedMenuItems removeObject:menuItem];
  }
}

//// info panel methods

-(NSRect)frameRectForInfoPanel {
  // try to put info panel on right or left of saver window, making sure it fits on the screen
  NSRect moduleRect = [window frame];
  NSRect moduleScreenRect = [[window screen] frame];
  NSSize infoPanelSize = [infoPanel frame].size;
  NSRect infoPanelFrame;
  int border = 10;
  // try right side
  infoPanelFrame = NSMakeRect(moduleRect.origin.x+moduleRect.size.width+border,
                              moduleRect.origin.y+moduleRect.size.height-infoPanelSize.height,
                              infoPanelSize.width,
                              infoPanelSize.height);
  if (NSEqualRects(infoPanelFrame, NSIntersectionRect(infoPanelFrame, moduleScreenRect))) {
    return infoPanelFrame;
  }
  // try left side
  infoPanelFrame.origin.x = moduleRect.origin.x-infoPanelSize.width-border;
  if (NSEqualRects(infoPanelFrame, NSIntersectionRect(infoPanelFrame, moduleScreenRect))) {
    return infoPanelFrame;
  }
  // as a default, move info panel 32 pixels down and right from top left of module window
  infoPanelFrame.origin.x = moduleRect.origin.x+32;
  infoPanelFrame.origin.y = moduleRect.origin.y+moduleRect.size.height-infoPanelSize.height-32;
  return infoPanelFrame;
}

-(void)showInfoPanel:(id)sender {
  if (!infoPanel) {
    [NSBundle loadNibNamed:@"ModuleInfoWindow" owner:self];
    [infoPanel setFrame:[self frameRectForInfoPanel] display:NO];
    [infoPanel setTitle:[NSString stringWithFormat:@"%@ %@", [self title], @"Info"]];
    [self updateInfoPanelRefreshingCurrentFPS:YES];
  }
  [infoPanel makeKeyAndOrderFront:nil];
}

-(void)closeInfoPanel {
  infoPanel = nil;
}

-(void)updateInfoPanelRefreshingCurrentFPS:(BOOL)refreshCurrentFPS {
//NSLog(@"-updateInfoPanel: %0.2lf %0.2lf", [self currentFramesPerSecond], [self targetFramesPerSecond]);
  if (infoPanel) {
    if (refreshCurrentFPS) [currentFPSField setIntValue:[self currentFramesPerSecond]];
    if ([self isTargetFramesPerSecondUnlimited]) {
      [targetFPSField setStringValue:@"Unlimited"];
    }
    else {
      [targetFPSField setIntValue:[self targetFramesPerSecond]];
    }

    {
      NSSize viewRect = [screenSaverView frame].size;
      [saverSizeField setStringValue:[NSString stringWithFormat:@"%d x %d",
                                                                (int)viewRect.width, (int)viewRect.height]];
    }
  }
}

-(int)currentFramesPerSecond {
//NSLog(@"%d", framesInLastSecond);
  return framesInLastSecond;
}

-(int)targetFramesPerSecond {
  NSTimeInterval interval = [screenSaverView animationTimeInterval];
  double fps;
  if (interval<=0) return 0;
  fps = 1.0/interval;
  if (fmod(fps,1.0)>=0.5) return ((int)fps)+1;
  else return (int)fps;
}

-(BOOL)isTargetFramesPerSecondUnlimited {
  return ([screenSaverView animationTimeInterval]<=0);
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
  if ([note object]==window) {
    // restart when the window is resized
    isPaused = NO;
    [self restart:nil];
    [self updateInfoPanelRefreshingCurrentFPS:NO];
  }
}

-(void)windowDidBecomeMain:(NSNotification *)note {
  if ([note object]==window) {
    // give keypresses to the ScreenSaverView
    [window makeFirstResponder:screenSaverView];
  }
}

// uncheck checked menu items
- (void)windowDidResignMain:(NSNotification *)aNotification {
  NSEnumerator *e = [checkedMenuItems objectEnumerator];
  id menuItem;
  while (menuItem=[e nextObject]) {
    [menuItem setState:NSOffState];
  }
  [checkedMenuItems removeAllObjects];
}



//// notification methods
// stop animations when app is hidden, restart when unhidden if it was previously running
-(void)appHidden:(NSNotification *)note {
  isAppHidden = YES;
  [self stop];
}

-(void)appUnhidden:(NSNotification *)note {
  isAppHidden = NO;
  [self startIfPossible];
}

// stop when real screensaver kicks in
-(void)screenSaverActivated:(NSNotification *)note {
  isScreenSaverRunning = YES;
  [self stop];
}

-(void)screenSaverDeactivated:(NSNotification *)note {
  isScreenSaverRunning = NO;
  [self startIfPossible];
}

// notification when screen saver draws itself
-(void)screenSaverDrewFrame:(NSNotification *)note {
  if ([note object]==screenSaverView) {
    ++unlockFocusCount;
    // some OpenGL modules send this notification as well as the GL-specific one, so ignore this if GL
    if (isRecordingFrames && !isFrameCaptureInProgress && ![screenSaverView isOpenGLModule]) {
        [self saveQuicktimeFrame];
    }
    //if (framesDrawn%100==0) NSLog(@"%@ %d", [screenSaverView class], unlockFocusCount);
  }
}

-(void)screenSaverDrewOpenGLFrame:(NSNotification *)note {
  if ([note object]==screenSaverView) {
    ++openGLContextCount;
    if (isRecordingFrames && !isFrameCaptureInProgress) [self saveQuicktimeFrame];
  }
}

-(void)updateFPS:(NSTimer *)timer {
  //NSLog(@"%@ %d fps", [screenSaverView class], unlockFocusCount);
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (now>lastFPSUpdateTime) {
    int frames = (unlockFocusCount > openGLContextCount) ? unlockFocusCount : openGLContextCount;
    double fps = frames/(now-lastFPSUpdateTime);
    // round up if needed
    if (fmod(fps,1.0)>=0.5) framesInLastSecond = ((int)fps)+1;
    else framesInLastSecond = (int)fps;
  }
  lastFPSUpdateTime = now;
  unlockFocusCount = openGLContextCount = 0;
  [self updateInfoPanelRefreshingCurrentFPS:YES];
}

/* free ourselves when the window closes (except when going to or from full screen)
*/
-(void)windowWillClose:(NSNotification *)note {
  if ([note object]==window) {
    if ([screenSaverView isAnimating]) [self stop];
    if (isResizingWindow) {
      // window is switching into or out of full screen; do not release self
      isResizingWindow = NO;
    }
    else {
      // need to kill the timer now or updateFPS can get called when the ScreenSaverView is released
      if (fpsTimer) {
        [fpsTimer invalidate];
        fpsTimer = nil;
      }
      if (infoPanel) [infoPanel close];
      infoPanel = window = nil;
      screenSaverView = nil;
      [self autorelease];
    }
    // abort Quicktime recording
    isRecordingFrames = NO;
    if ([[SaverLabPreferences sharedInstance] deleteRecordedImages])
      [self deleteTemporaryQuicktimeImagesDirectory];
  }
  else if ([note object]==infoPanel) {
    [self closeInfoPanel];
  }
}

// Support for saving animations as Quicktime movies

-(NSString *)temporaryDirectoryForQuicktimeImages {
  if (!temporaryQuicktimeDirectory) {
    NSString *tmpdir = [[SaverLabPreferences sharedInstance] recordedImagesDirectory];
    int i, done=0;
    for(i=0; i<9999 && !done; i++) {
      NSString *testdir = [tmpdir stringByAppendingPathComponent:[NSString stringWithFormat:@"SaverLab%d", i]];
      if (![[NSFileManager defaultManager] fileExistsAtPath:testdir]) {
        if ([[NSFileManager defaultManager] createDirectoryAtPath:testdir attributes:nil]) {
          temporaryQuicktimeDirectory = [testdir retain];
        }
        else {
          // failed to create directory, probably a permissions problem, nil will be returned
        }
        done = 1;
      }
    }
  }
  return temporaryQuicktimeDirectory;
}

-(void)deleteTemporaryQuicktimeImagesDirectory {
  if (temporaryQuicktimeDirectory) {
    [[NSFileManager defaultManager] removeFileAtPath:temporaryQuicktimeDirectory handler:nil];
    [temporaryQuicktimeDirectory release];
    temporaryQuicktimeDirectory = nil;
  }
}

-(void)forgetTemporaryQuicktimeImagesDirectory {
  [temporaryQuicktimeDirectory release];
  temporaryQuicktimeDirectory = nil;
}

-(void)saveQuicktimeFrame {
  if (isRecordingFrames) {
    // for some reason this can't be done in this iteration of the run loop
    [self performSelector:@selector(_saveQuicktimeFrame:) withObject:nil afterDelay:0];
  }
  //[self _saveQuicktimeFrame:nil];
}

-(void)_saveQuicktimeFrame:(id)arg {
  if (isRecordingFrames) {
    NSData *tiffData;
    NSString *filename;
    NSString *path;
    //NSLog(@"%d:getting image",quicktimeFrameCounter);
    tiffData = [self tiffDataForSaverImage];
    if (tiffData) {
      //NSLog(@"%d:getting TIFF data", quicktimeFrameCounter);
      filename = [[[NSNumber numberWithInt:quicktimeFrameCounter] stringValue]
                            stringByAppendingPathExtension:@"tiff"];
      path = [[self temporaryDirectoryForQuicktimeImages] stringByAppendingPathComponent:filename];
      [tiffData writeToFile:path atomically:NO];
      ++quicktimeFrameCounter;
    }
    else {
      NSBeep();
      isRecordingFrames = NO;
    }
  }
}

-(NSDictionary *)quicktimeMovieParameters {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  double frameLength;
  // use either the user-specified rate or the module's current rate
  if ([[SaverLabPreferences sharedInstance] useCustomFrameRate]) {
    frameLength = 1.0/[[SaverLabPreferences sharedInstance] customFrameRate];
  }
  else {
    frameLength = [screenSaverView animationTimeInterval];
    if (frameLength<1.0/60) frameLength = 1.0/60;
  }
  if (frameLength<0.01) frameLength = 0.01;

  [dict setObject:[NSNumber numberWithInt:quicktimeFrameCounter] forKey:@"numFrames"];
  [dict setObject:[NSNumber numberWithDouble:frameLength] forKey:@"frameLength"];
  [dict setObject:[self temporaryDirectoryForQuicktimeImages] forKey:@"imagesDirectory"];
  return dict;
}

-(void)toggleQuicktimeRecording:(id)sender {
  if (isRecordingFrames) {
    isRecordingFrames = NO;
    // only show the save panel if saving movies is enabled
    if ([[SaverLabPreferences sharedInstance] createMovieFromRecordedImages]) {
      [[NSSavePanel savePanel] beginSheetForDirectory:nil
                                                file:[title stringByAppendingPathExtension:@"mov"]
                                      modalForWindow:window
                                        modalDelegate:self
                                      didEndSelector:@selector(quicktimeSavePanelEnded:code:movieInfo:)
                                          contextInfo:[[self quicktimeMovieParameters] retain]];
    }
    else {
      // leave the recorded images where they are
      [self forgetTemporaryQuicktimeImagesDirectory];
    }
  }
  else {
    // make sure we have a directory to write frames to
    if (![self temporaryDirectoryForQuicktimeImages]) {
      int result;
      NSBeep();
      result = NSRunAlertPanel(NSLocalizedString(@"RECORDING_ERROR_TITLE",nil),
                               NSLocalizedString(@"RECORDING_ERROR_MSG",nil),
                               NSLocalizedString(@"RECORDING_ERROR_OK",nil),
                               NSLocalizedString(@"RECORDING_ERROR_PREFERENCES",nil),
                               nil,
                               [[SaverLabPreferences sharedInstance] recordedImagesDirectory]);
      if (result==NSAlertAlternateReturn) {
        [NSApp sendAction:@selector(openPreferencesWindow:) to:nil from:self];
      }
    }
    else {
      isRecordingFrames = YES;
      quicktimeFrameCounter = 0;
    }
  }
  [self updateWindowTitle];
}

-(void)removeTemporaryImagesFromDirectory:(NSString *)dir count:(int)count {
  int i;
  for(i=0; i<count; i++) {
    NSString *file = [[[NSNumber numberWithInt:i] stringValue] stringByAppendingPathExtension:@"tiff"];
    NSString *path = [dir stringByAppendingPathComponent:file];
    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
  }
}


-(void)quicktimeSavePanelEnded:(NSSavePanel *)panel code:(int)code movieInfo:(NSDictionary *)info {
  if (code==NSOKButton) {
    // parameters for movie creation
    NSString *moviePath = [panel filename];
    NSString *imagesDirectory = [info objectForKey:@"imagesDirectory"];
    int numFrames = [[info objectForKey:@"numFrames"] intValue];
    double frameLength = [[info objectForKey:@"frameLength"] doubleValue];
    // images directory is no longer our responsibility, SaverLabQTProgressWindowController will delete it
    [self forgetTemporaryQuicktimeImagesDirectory];
    {
      // display progress window
      SaverLabQTProgressWindowController *controller = [[SaverLabQTProgressWindowController alloc] init];
      [NSBundle loadNibNamed:@"QuicktimeProgressWindow" owner:controller];
      [controller createMovieFile:moviePath
            fromImagesInDirectory:imagesDirectory
                       frameCount:numFrames
                      frameLength:frameLength
             deleteImagesWhenDone:[[SaverLabPreferences sharedInstance] deleteRecordedImages]];
    }
  }
  else {
    if ([[SaverLabPreferences sharedInstance] deleteRecordedImages]) {
      [self deleteTemporaryQuicktimeImagesDirectory];
    }
    else {
      [self forgetTemporaryQuicktimeImagesDirectory];
    }
  }
  [info release];
}


@end

