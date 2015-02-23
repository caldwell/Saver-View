/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabController.h"
#import "SaverLabModuleList.h"
#import "SaverLabPreferences.h"

// for isProcessRunningWithName
#include <sys/sysctl.h>
// for stdout/stderr redirection
#include <unistd.h>

static int MODULE_MENU_PERMANENT_ITEMS = 3;

// apparently the BSD calls to get process names only allow 16 characters, so
// "ScreenSaverEngine" becomes "ScreenSaverEngin"
static char *SCREENSAVER_PROCESS_NAME = "ScreenSaverEngin";

/* function to determine if the real screen saver is running. Iterates over all 
running processes looking for a specific process name, returns true if it is found.
*/
static int isProcessRunningWithName(const char *procname) {
  // borrowed from ps source
  struct kinfo_proc *kp;
  int i, nentries;
  int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t bufSize = 0;
  int found = 0;

  if (sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0) {
      NSLog(@"Failure calling sysctl");
      return 0;
  }
  nentries = bufSize/ sizeof(struct kinfo_proc);
  kp = (struct kinfo_proc *)malloc(bufSize);
  if (sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0) {
      NSLog(@"Failure calling sysctl");
      free(kp);
      return 0;
  }	

  for(i=0; i<nentries && !found; i++) {
    char *pname = kp[i].kp_proc.p_comm;
    if (strcmp(procname,pname)==0) found = 1;
  }
  free(kp);
  return found;
}

/* Returns true if there are any visible windows. Should possibly be a category
method on NSApplication.
*/
static BOOL appHasVisibleWindows() {
  NSArray *windows = [NSApp windows];
  NSEnumerator *wenum = [windows objectEnumerator];
  NSWindow *window;
  while (window=[wenum nextObject]) {
    if ([window isVisible]) return YES;
  }
  return NO;
}

/* Given an output stream (as a FILE *), creates a pipe and redirects output to the write end of
the pipe. Returns an NSFileHandle which can read from the read end of the pipe. Used to create
handles for stdout and stderr so that output can be captured and displayed in a text view.
*/
// could be a category on NSFileHandle
static NSFileHandle* createPipeForOuptputStream(FILE *stream) {
  int fd[2];
  NSFileHandle *fileHandle;
  pipe(fd);
  // fd[1] is output, data written appears on fd[0]
  dup2(fd[1], fileno(stream));
  close(fd[1]);
  fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd[0]];
  return fileHandle;
}

////////////////////////////////////////////////////////////////////////////////

@implementation SaverLabController

-(void)applicationDidFinishLaunching:(NSNotification *)note {
  [self rebuildModulesMenu];
  
  // seed random number generator
  srandom(time(NULL));
  
  // set up timer to poll for ScreenSaverEngine process
  wasScreenSaverRunning = NO;
  [NSTimer scheduledTimerWithTimeInterval:5.0
                                   target:self
                                 selector:@selector(checkForScreenSaver:)
                                 userInfo:nil
                                  repeats:YES];
                                  
  // set up stdout/stderr redirection
  stdoutHandle = createPipeForOuptputStream(stdout);
  stderrHandle = createPipeForOuptputStream(stderr);
   
    
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReadStdoutData:)
                                               name:NSFileHandleReadCompletionNotification
                                             object:nil];
  [stdoutHandle readInBackgroundAndNotify];
  [stderrHandle readInBackgroundAndNotify];
                
  // restore window positions and open module list if necessary
  {
    SaverLabPreferences *prefs = [SaverLabPreferences sharedInstance];
    if ([prefs restoreModuleWindowsOnStartup]) [self restoreWindowPositions];
    // show module list if there are no windows open
    if ([prefs showModuleListOnStartup] || 
        ([prefs showModuleListWhenNoOpenWindows] && !appHasVisibleWindows())) {
      [[self listWindowController] showWindow:self];
    }
  }
  
}

/** Called when the application becomes active. Updates the available modules if
the relevant preference is set, broadcasts that the real screen saver is not running,
and possibly shows the browser window if no other windows are open.
*/
-(void)applicationDidBecomeActive:(NSNotification *)note {
  if ([[SaverLabPreferences sharedInstance] autoUpdateModuleList]) {
    [self updateModuleList:nil];
  }
  // restart modules if they were stopped by the real screen saver
  if (wasScreenSaverRunning) {
    wasScreenSaverRunning = NO;
    [self broadcastScreenSaverIsRunning:NO];
  }
  // maybe show module list if there are no windows open
  if ([[SaverLabPreferences sharedInstance] showModuleListWhenNoOpenWindows] && !appHasVisibleWindows()) {
    [[self listWindowController] showWindow:self];
  }
}

/** Rescans for available modules and updates the menu and browser window if the list has changed.
*/
-(void)updateModuleList:(id)sender {
  if ([[SaverLabModuleList sharedInstance] updateList]) {
    [self rebuildModulesMenu];
    [[self listWindowController] refresh];
  }
}

-(void)rebuildModulesMenu {
  // make an item for each bundle
  NSString *saverName  = nil;
  NSMenuItem *menuItem = nil;

  // remove everything
  NSMenu *modulesSubmenu = [modulesMenu submenu];
  while ([modulesSubmenu numberOfItems]>MODULE_MENU_PERMANENT_ITEMS) {
    [modulesSubmenu removeItemAtIndex:[modulesSubmenu numberOfItems]-1];
  }
  
  // create menu items
  {
    NSArray *sortedNames = [[SaverLabModuleList sharedInstance] sortedModuleNames];
    NSEnumerator *nameEnum = [sortedNames objectEnumerator];
    while (saverName = [nameEnum nextObject]) {
      menuItem = [[NSMenuItem alloc] initWithTitle:saverName
                                            action:@selector(moduleSelected:) 
                                      keyEquivalent:@""];
      [[modulesMenu submenu] addItem:menuItem];
    }
  }
}

-(SaverLabModuleController *)openModuleWithName:(NSString *)name {
  NSBundle *saverBundle = [[SaverLabModuleList sharedInstance] bundleForModuleName:name];
  Class saverClass = [saverBundle principalClass];
  SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                               initWithSaverClass:saverClass
                                                            title:name];
  return controller;  
}

-(SaverLabModuleController *)openModuleWithName:(NSString *)name rect:(NSRect)frameRect {
  if (NSIsEmptyRect(frameRect)) return [self openModuleWithName:name];
  else {
    NSBundle *saverBundle = [[SaverLabModuleList sharedInstance] bundleForModuleName:name];
    Class saverClass = [saverBundle principalClass];
    NSRect rect = [NSWindow contentRectForFrameRect:frameRect styleMask:NSTitledWindowMask];
    SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                                initWithSaverClass:saverClass
                                                              title:name
                                                        contentRect:rect];
    return controller;  
  }
}

-(SaverLabModuleController *)openFullScreenModuleWithName:(NSString *)name rect:(NSRect)rect {
  NSBundle *saverBundle = [[SaverLabModuleList sharedInstance] bundleForModuleName:name];
  Class saverClass = [saverBundle principalClass];
  // try to find the screen corresponding to the given NSRect
  NSArray *screens = [NSScreen screens];
  NSScreen *matchingScreen = nil;
  // on a single monitor system, always use the main screen
  if ([screens count]<=1) {
    matchingScreen = [NSScreen mainScreen];
  }
  else {
    int i;
    for(i=[screens count]-1; i>=0 && matchingScreen==nil; i--) {
      NSScreen *screen = [screens objectAtIndex:i];
      if (NSEqualRects([screen frame], rect)) {
        matchingScreen = screen;
      }
    }
  }
  if (matchingScreen!=nil) {
    return [[SaverLabModuleController alloc] initFullScreen:matchingScreen
                                             withSaverClass:saverClass
                                                      title:name];
  }
  else {
    // run in a window if no screen matches. This may not be what we want if the screen resolutions
    // have changed, but it's probably better than the possibility of incorrectly running multiple
    // modules full screen on the same screen.
    return [[SaverLabModuleController alloc] initWithSaverClass:saverClass
                                                          title:name];
  }
}

-(void)moduleSelected:(NSMenuItem *)menuItem {
  // get the bundle from the path, create an SaverLabModuleController, and start it
  SaverLabModuleController *controller = [self openModuleWithName:[menuItem title]];
  if (controller) {
    [controller showModuleWindow];
    [controller start];
  }
}

/* Called when a .saver bundle is opened from the Finder or elsewhere.
*/
-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename{
  NSBundle *saverBundle = [NSBundle bundleWithPath:filename];
  Class saverClass = [saverBundle principalClass];
  NSString *name = [[filename lastPathComponent] stringByDeletingPathExtension];
  SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                               initWithSaverClass:saverClass
                                                            title:name];
  if (controller) {
    [controller showModuleWindow];
    [controller start];
    return YES;
  }
  return NO;
}


/* On application termination, save the location of all open module windows.
*/
-(void)applicationWillTerminate:(NSNotification *)note {
  [self saveWindowPositions];
}

-(NSArray *)moduleWindows {
  NSMutableArray *windows = [NSMutableArray array];
  NSEnumerator *we = [[NSApp windows] objectEnumerator];
  id window;
  while (window=[we nextObject]) {
    if ([[window delegate] isKindOfClass:[SaverLabModuleController class]]) {
      [windows addObject:window];
    }
  }
  return windows;
}

-(void)saveWindowPositions {
  NSWindow *window;
  SaverLabModuleController *moduleController;
  NSEnumerator *enumerator;
  NSMutableArray *moduleAttributes  = [NSMutableArray array];
  // fill moduleAttributes with an NSDictionary for each module
  enumerator = [[self moduleWindows] objectEnumerator];
  while (window = [enumerator nextObject]) {
    moduleController = [window delegate];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[moduleController title] forKey:@"name"];
    if ([moduleController isFullScreen]) {
      [dict setObject:@"YES" forKey:@"fullscreen"];
    }
    if ([moduleController isInPreviewMode]) {
      [dict setObject:@"YES" forKey:@"preview"];
    }
    [dict setObject:NSStringFromRect([[moduleController moduleWindow] frame]) forKey:@"rect"];
    [dict setObject:[moduleController windowLayerString] forKey:@"layer"];
    // save position, paused state, etc.
    [moduleAttributes addObject:dict];
  }
  
  [[NSUserDefaults standardUserDefaults] setObject:moduleAttributes forKey:@"modules"];
}

-(void)restoreWindowPositions {
  NSArray *moduleAttributes = [[NSUserDefaults standardUserDefaults] objectForKey:@"modules"];
  NSEnumerator *modenum = [moduleAttributes objectEnumerator];
  NSDictionary *dict = nil;
  while (dict = [modenum nextObject]) {
    SaverLabModuleController *controller = nil;
    NSString *name = [dict objectForKey:@"name"];
    NSRect rect = NSRectFromString([dict objectForKey:@"rect"]);
    
    if ([dict objectForKey:@"fullscreen"]) {
      controller = [self openFullScreenModuleWithName:name rect:rect];
    }
    else {
      controller = [self openModuleWithName:name rect:rect];
    }
    if (controller) {
      if ([dict objectForKey:@"preview"]) {
        [controller setIsInPreviewMode:YES];
      }
      [controller showModuleWindow];
      [controller setWindowLayerFromString:[dict objectForKey:@"layer"]];
      [controller start];
    }
  }
}

/* Closes all fullscreen windows
*/
-(void)closeFullscreenWindows:(id)sender {
  NSEnumerator *winenum = [[self moduleWindows] objectEnumerator];
  NSWindow *window;
  while (window=[winenum nextObject]) {
    if ([[window delegate] isFullScreen]) {
      [window close];
    }
  }
}

/* Enable "Close Fullscreen Windows" menu item only when there actually is one
*/
-(BOOL)validateMenuItem:(id)menuItem {
  if ([menuItem action]==@selector(closeFullscreenWindows:)) {
    NSEnumerator *winenum = [[self moduleWindows] objectEnumerator];
    NSWindow *window;
    while (window=[winenum nextObject]) {
      if ([[window delegate] isFullScreen]) {
        return YES;
      }
    }
    return NO;
  }
  return YES;
}


/* timer method to poll for the real screen saver being active. If it is, all
modules will stop so as not to slow it down.
*/
-(void)checkForScreenSaver:(NSTimer *)timer {
  if (![NSApp isActive]) {
    BOOL ssRunning = isProcessRunningWithName(SCREENSAVER_PROCESS_NAME);
    if ((!!ssRunning)!=(!!wasScreenSaverRunning)) {
      [self broadcastScreenSaverIsRunning:ssRunning];
      wasScreenSaverRunning = ssRunning;
    }
  }
}

-(void)broadcastScreenSaverIsRunning:(BOOL)ssRunning {
  NSString *name = (ssRunning) ? @"ScreenSaverActivated" : @"ScreenSaverDeactivated";
  [[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
}

// access to other controllers. 
-(SaverLabBrowserWindowController *)listWindowController {
  return listWindowController;
}

-(SaverLabPrefsWindowController *)prefsWindowController {
  return prefsWindowController;
}

-(SaverLabStdoutWindowController *)stdoutWindowController {
  // this is in a separate nib, as the others should be also
  if (!stdoutWindowController) {
    stdoutWindowController = [[SaverLabStdoutWindowController alloc] init];
  }
  return stdoutWindowController;
}


// called when data is written to stdout
-(void)didReadStdoutData:(NSNotification *)note {
  if ([note object]==stdoutHandle || [note object]==stderrHandle) {
    NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
    [[self stdoutWindowController] addData:data isStderr:([note object]==stderrHandle)];
    [[note object] readInBackgroundAndNotify];
  }
}

// opens the preferences window
-(void)openPreferencesWindow:(id)sender {
  [[self prefsWindowController] showWindow:sender];
}

// opens the console window
-(void)openConsoleWindow:(id)sender {
  [[self stdoutWindowController] showWindow:sender];
}


@end
