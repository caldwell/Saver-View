/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabController.h"

// for isProcessRunningWithName
#include <sys/sysctl.h>

static NSString *SCREEN_SAVER_DIR = @"Screen Savers";
static NSString *SCREEN_SAVER_SUFFIX = @".saver";
static NSString *HIDE_PREFIX = @"."; // hide saver bundles starting with "."
static int MODULE_MENU_PERMANENT_ITEMS = 0;

// returns all locations to search for .saver bundles
static NSArray* screenSaverSearchPaths() {
  NSMutableArray *array = [NSMutableArray array];
  NSArray *libPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
  NSString *path;
  NSEnumerator *pathenum = [libPaths objectEnumerator];
  [array addObject:@"/System/Library/Frameworks/ScreenSaver.framework/Resources"];
  while (path=[pathenum nextObject]) {
    [array addObject:[path stringByAppendingPathComponent:SCREEN_SAVER_DIR]];
  }
  //NSLog(@"screenSaverSearchPaths() returning:%@", array);
  return array;
}


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

////////////////////////////////////////////////////////////////////////////////

@implementation SaverLabController

-(void)applicationDidFinishLaunching:(NSNotification *)note {
  [self buildModulesMenu];
  // set up timer to poll for ScreenSaverEngine process
  wasScreenSaverRunning = NO;
  [NSTimer scheduledTimerWithTimeInterval:5.0
                                   target:self
                                 selector:@selector(checkForScreenSaver:)
                                 userInfo:nil
                                  repeats:YES];
  [self restoreWindowPositions];
}

/** Reload the modules list whenever the app becomes active. This causes a slight
delay which is hopefully not significant unless you have a ton of modules.
*/
-(void)applicationDidBecomeActive:(NSNotification *)note {
  [self updateModulesMenu];
  // restart modules if they were stopped by the real screen saver
  if (wasScreenSaverRunning) {
    wasScreenSaverRunning = NO;
    [self broadcastScreenSaverIsRunning:NO];
  }
}

-(void)updateModulesMenu {
  // remove everything
  NSMenu *modulesSubmenu = [modulesMenu submenu];
  while ([modulesSubmenu numberOfItems]>MODULE_MENU_PERMANENT_ITEMS) {
    [modulesSubmenu removeItemAtIndex:[modulesSubmenu numberOfItems]-1];
  }
  [self buildModulesMenu];
}

-(void)buildModulesMenu {
  // get library paths (/System/Library, /Library, ~/Library)
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *libraryDirs = screenSaverSearchPaths();
  NSEnumerator *saverDirEnum = [libraryDirs objectEnumerator];
  NSString *saverDir = nil;
  
  [modulePathDictionary release];
  modulePathDictionary = [[NSMutableDictionary alloc] init];
  
  // append "Screen Savers" to each library path and search for .saver bundles
  while (saverDir = [saverDirEnum nextObject]) {
    NSEnumerator *saverBundleEnum = [fileManager enumeratorAtPath:saverDir];
    NSString *saverBundle = nil;
    while (saverBundle=[saverBundleEnum nextObject]) {
      if ([saverBundle hasSuffix:SCREEN_SAVER_SUFFIX] && ![saverBundle hasPrefix:HIDE_PREFIX]) {
        NSString *path = [saverDir stringByAppendingPathComponent:saverBundle];
        // this assumes all filenames are unique
        [modulePathDictionary setObject:path 
                          forKey:[[path lastPathComponent] stringByDeletingPathExtension]];
      }
    }
  }
  // make an item for each bundle, with the full path as the represented object
  {
    NSString *saverName  = nil;
    NSMenuItem *menuItem = nil;
    // sort menu by module name
    NSArray *sortedNames = [[modulePathDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
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
  NSBundle *saverBundle = [NSBundle bundleWithPath:[modulePathDictionary objectForKey:name]];
  Class saverClass = [saverBundle principalClass];
  SaverLabModuleController *controller = [[SaverLabModuleController alloc] 
                                               initWithSaverClass:saverClass
                                                            title:name];
  return controller;  
}

-(SaverLabModuleController *)openModuleWithName:(NSString *)name rect:(NSRect)frameRect {
  if (NSIsEmptyRect(frameRect)) return [self openModuleWithName:name];
  else {
    NSBundle *saverBundle = [NSBundle bundleWithPath:[modulePathDictionary objectForKey:name]];
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
  NSBundle *saverBundle = [NSBundle bundleWithPath:[modulePathDictionary objectForKey:name]];
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

/* On application termination, save the location of all open module windows.
*/
-(void)applicationWillTerminate:(NSNotification *)note {
  [self saveWindowPositions];
}

-(void)saveWindowPositions {
  NSArray *windows = [NSApp windows]; 
  NSWindow *window;
  SaverLabModuleController *moduleController;
  NSEnumerator *enumerator;
  NSMutableSet *moduleControllers = [NSMutableSet set];
  NSMutableArray *moduleAttributes  = [NSMutableArray array];
  // get all unique SaverLabModuleController objects
  enumerator = [windows objectEnumerator];
  while (window = [enumerator nextObject]) {
    id delegate = [window delegate];
    if ([delegate isKindOfClass:[SaverLabModuleController class]]) {
      [moduleControllers addObject:delegate];  
    }
  }
  // fill moduleAttributes with an NSDictionary for each module
  enumerator = [moduleControllers objectEnumerator];
  while (moduleController = [enumerator nextObject]) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[moduleController title] forKey:@"name"];
    if ([moduleController isFullScreen]) {
      [dict setObject:@"YES" forKey:@"fullscreen"];
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
      [controller showModuleWindow];
      [controller setWindowLayerFromString:[dict objectForKey:@"layer"]];
      [controller start];
    }
  }
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

@end
