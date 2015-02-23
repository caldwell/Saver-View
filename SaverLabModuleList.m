/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabModuleList.h"

static SaverLabModuleList *_sharedInstance = nil;

static NSString *SCREEN_SAVER_DIR = @"Screen Savers";
static NSArray *screenSaverSuffixes = nil;
static NSString *HIDE_PREFIX = @"."; // hide saver bundles starting with "."
static NSString *SLIDE_SHOW_MODULE_NAME = @"Slide Show";

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


@implementation SaverLabModuleList

+(NSArray *)screenSaverSuffixes {
  if (!screenSaverSuffixes) {
    screenSaverSuffixes = [[NSArray arrayWithObjects:@"saver",@"slideSaver",nil] retain];
  }
  return screenSaverSuffixes;
}

+(SaverLabModuleList *)sharedInstance {
  if (!_sharedInstance) {
    _sharedInstance = [[SaverLabModuleList alloc] init];
    [_sharedInstance updateList];
  }
  return _sharedInstance;
}

// never actually called
-(void)dealloc {
  [modulePathDictionary release];
}

// updates module names and paths, returns true if anything changed
-(BOOL)updateList {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *libraryDirs = screenSaverSearchPaths();
  NSEnumerator *saverDirEnum = [libraryDirs objectEnumerator];
  NSString *saverDir = nil;
  
  NSMutableDictionary *newPathDictionary = [NSMutableDictionary dictionary];
  // append "Screen Savers" to each library path and search for .saver bundles
  while (saverDir = [saverDirEnum nextObject]) {
    NSEnumerator *saverBundleEnum = [fileManager enumeratorAtPath:saverDir];
    NSString *saverBundle = nil;
    while (saverBundle=[saverBundleEnum nextObject]) {
      if (![saverBundle hasPrefix:HIDE_PREFIX] && 
           [[[self class] screenSaverSuffixes] containsObject:[saverBundle pathExtension]]) 
      {
        NSString *path = [saverDir stringByAppendingPathComponent:saverBundle];
        // this assumes all filenames are unique
        [newPathDictionary setObject:path 
                              forKey:[[path lastPathComponent] stringByDeletingPathExtension]];
      }
    }
  }
  
  if ([newPathDictionary isEqualToDictionary:modulePathDictionary]) {
    return NO;
  }
  else {
    [modulePathDictionary release];
    modulePathDictionary = [newPathDictionary retain];
    [sortedModuleNames release];
    sortedModuleNames = [[[modulePathDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)] retain];
    return YES;
  }
}

-(NSArray *)sortedModuleNames {
  return sortedModuleNames;
}

-(NSString *)pathForModuleName:(NSString *)name {
  return [modulePathDictionary objectForKey:name];
}

-(NSBundle *)bundleForModuleName:(NSString *)name {
  // special case for "slideSaver" modules
  NSString *path = [self pathForModuleName:name];
  if ([path hasSuffix:@"slideSaver"]) {
    path = [self pathForModuleName:SLIDE_SHOW_MODULE_NAME];
  }
  return [NSBundle bundleWithPath:path];
}

-(Class)classForModuleName:(NSString *)name {
  return [[self bundleForModuleName:name] principalClass];
}


@end
