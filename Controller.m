/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "Controller.h"
#import "SSSController.h"

// for isProcessRunningWithName
#include <sys/sysctl.h>

/* NSStandardLibraryPaths() is in the Foundation docs and worked in the Public Beta, 
but apparently doesn't exist anymore.
*/
NSArray* _myNSStandardLibraryPaths() {
  return [NSArray arrayWithObjects:@"/System/Library",
                                   @"/Library",
                                   [@"~/Library" stringByExpandingTildeInPath],
                                   nil];
}
NSString *SCREEN_SAVER_DIR = @"Screen Savers";
NSString *SCREEN_SAVER_SUFFIX = @".saver";
NSString *HIDE_PREFIX = @"."; // hide saver bundles starting with "."
int MODULE_MENU_PERMANENT_ITEMS = 0;

// apparently the BSD calls to get process names only allow 16 characters, so
// "ScreenSaverEngine" becomes "ScreenSaverEngin"
char *SCREENSAVER_PROCESS_NAME = "ScreenSaverEngin";

/* function to determine if the real screen saver is running. Iterates over all 
running processes looking for a specific process name, returns true if it is found.
*/
int isProcessRunningWithName(const char *procname) {
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

@implementation Controller

-(void)applicationDidFinishLaunching:(NSNotification *)note {
  [self buildModulesMenu];
  // set up timer to poll for ScreenSaverEngine process
  wasScreenSaverRunning = NO;
  [NSTimer scheduledTimerWithTimeInterval:5.0
                                   target:self
                                 selector:@selector(checkForScreenSaver:)
                                 userInfo:nil
                                  repeats:YES];
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
  NSArray *libraryDirs = _myNSStandardLibraryPaths();
  NSEnumerator *saverDirEnum = [libraryDirs objectEnumerator];
  NSString *libdir = nil;
  NSMutableDictionary *saverPathDict = [NSMutableDictionary dictionary];
  // append "Screen Savers" to each library path and search for .saver bundles
  while (libdir = [saverDirEnum nextObject]) {
    NSString *saverDir = [libdir stringByAppendingPathComponent:SCREEN_SAVER_DIR];
    NSEnumerator *saverBundleEnum = [fileManager enumeratorAtPath:saverDir];
    NSString *saverBundle = nil;
    while (saverBundle=[saverBundleEnum nextObject]) {
      if ([saverBundle hasSuffix:SCREEN_SAVER_SUFFIX] && ![saverBundle hasPrefix:HIDE_PREFIX]) {
        NSString *path = [saverDir stringByAppendingPathComponent:saverBundle];
        // this assumes all filenames are unique
        [saverPathDict setObject:path 
                          forKey:[[path lastPathComponent] stringByDeletingPathExtension]];
      }
    }
  }
  // make an item for each bundle, with the full path as the represented object
  {
    NSString *saverName  = nil;
    NSMenuItem *menuItem = nil;
    // sort menu by module name
    NSArray *sortedNames = [[saverPathDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSEnumerator *nameEnum = [sortedNames objectEnumerator];
    while (saverName = [nameEnum nextObject]) {
      NSString *path = [saverPathDict objectForKey:saverName];
      menuItem = [[NSMenuItem alloc] initWithTitle:saverName
                                            action:@selector(moduleSelected:) 
                                     keyEquivalent:@""];
      [menuItem setRepresentedObject:path];
      [[modulesMenu submenu] addItem:menuItem];
    }
  }
}

-(void)moduleSelected:(NSMenuItem *)menuItem {
  // get the bundle from the path, create an SSSController, and start it
  NSString *path = [menuItem representedObject];
  NSBundle *saverBundle = [NSBundle bundleWithPath:path];
  Class saverClass = [saverBundle principalClass];
  SSSController *controller = [[SSSController alloc] initWithSaverClass:saverClass
                                                                  title:[menuItem title]];
  if (controller) {
    [controller showWindow];
    [controller start];
  }
}

/* timer method to poll for the real screen saver being active. If it is, all
modules will stop so as not to slow it down.
*/
-(void)checkForScreenSaver:(NSTimer *)timer {
  if (![NSApp isActive]) {
    BOOL ssRunning = isProcessRunningWithName(SCREENSAVER_PROCESS_NAME);
    if ((!!ssRunning)!=(!!wasScreenSaverRunning)) {
      //NSLog(@"%s running:%d", SCREENSAVER_PROCESS_NAME, (int)ssRunning);
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
