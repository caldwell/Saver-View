/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "Controller.h"
#import "SSSController.h"

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
int MODULE_MENU_PERMANENT_ITEMS = 0;

@implementation Controller

-(void)applicationDidFinishLaunching:(NSNotification *)note {
  [self buildModulesMenu];
}

/** Reload the modules list whenever the app becomes active. This causes a slight
delay which is hopefully not significant unless you have a ton of modules.
*/
-(void)applicationDidBecomeActive:(NSNotification *)note {
  [self updateModulesMenu];
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
      if ([saverBundle hasSuffix:SCREEN_SAVER_SUFFIX]) {
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
  SSSController *controller = [[SSSController alloc] initWithBundle:saverBundle
                                                              title:[menuItem title]];
  if (controller) {
    [NSBundle loadNibNamed:@"ScreenSaverWindow" owner:controller];
    [controller showWindow];
    [controller start];
  }
}

@end
