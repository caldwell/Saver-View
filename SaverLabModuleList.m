/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabModuleList.h"

static SaverLabModuleList *_sharedInstance = nil;
static NSString *slideShowModulePath = nil;
static NSArray *screenSaverSuffixes = nil;

static NSString *SCREEN_SAVER_DIR = @"Screen Savers";
static NSString *HIDE_PREFIX = @"."; // hide saver bundles starting with "."
static NSString *SS_FRAMEWORK_MODULE_PATH = @"/System/Library/Frameworks/ScreenSaver.framework/Resources";
static NSString *MODULE_EXTENSION = @"saver";
static NSString *SLIDESHOW_MODULE_EXTENSION = @"slideSaver";
static NSString *QUARTZ_COMPOSER_MODULE_EXTENSION = @"qtz";

// returns all locations to search for .saver bundles
static NSArray* screenSaverSearchPaths() {
  NSMutableArray *array = [NSMutableArray array];
  NSArray *libPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
  NSString *path;
  NSEnumerator *pathenum = [libPaths objectEnumerator];
  [array addObject:SS_FRAMEWORK_MODULE_PATH];
  while (path=[pathenum nextObject]) {
    [array addObject:[path stringByAppendingPathComponent:SCREEN_SAVER_DIR]];
  }
  //NSLog(@"screenSaverSearchPaths() returning:%@", array);
  return array;
}

static NSArray *gModulesIgnoringHiddenPrefix = nil;

static NSArray *modulesIgnoringHiddenPrefix() {
	if (!gModulesIgnoringHiddenPrefix) {
		// we would allow .Mac here, but it doesn't work anyway
		gModulesIgnoringHiddenPrefix = [[NSArray alloc] initWithObjects:/*@".Mac.slideSaver",*/ nil];
	}
	return gModulesIgnoringHiddenPrefix;
}

@implementation SaverLabModuleList

+(NSArray *)screenSaverSuffixes {
  if (!screenSaverSuffixes) {
    screenSaverSuffixes = [[NSArray arrayWithObjects:MODULE_EXTENSION, SLIDESHOW_MODULE_EXTENSION, QUARTZ_COMPOSER_MODULE_EXTENSION, nil] retain];
  }
  return screenSaverSuffixes;
}

// Jaguar changes the slide show module to "Pictures Folder", it was "Slide Show" in 10.1.x.
// check to see which of them exists inside the ScreenSaver framework
+(NSString *)slideShowModulePath {
  if (!slideShowModulePath) {
    NSArray *ssModuleNames = [NSArray arrayWithObjects:@"Pictures Folder", @"Slide Show", nil];
    NSEnumerator *ne = [ssModuleNames objectEnumerator];
    NSString *name;
    while ((!slideShowModulePath) && (name=[ne nextObject])) {
      NSString *path = [SS_FRAMEWORK_MODULE_PATH stringByAppendingPathComponent:[name stringByAppendingPathExtension:MODULE_EXTENSION]];
      if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        slideShowModulePath = [path retain];
      } 
    }
  }
  return slideShowModulePath;
}

+(NSString *)quartzComposerModulePath {
	return @"/System/Library/Frameworks/ScreenSaver.framework/Resources/.Quartz Composer.saver";
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
  [super dealloc];
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
      if ((![saverBundle hasPrefix:HIDE_PREFIX] || [modulesIgnoringHiddenPrefix() containsObject:saverBundle]) && 
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

-(NSBundle *)bundleForModulePath:(NSString *)path {
  // special case for slideshow and Quartz Composer modules
  if ([path hasSuffix:SLIDESHOW_MODULE_EXTENSION]) {
    path = [[self class] slideShowModulePath];
  }
  else if ([path hasSuffix:QUARTZ_COMPOSER_MODULE_EXTENSION]) {
    path = [[self class] quartzComposerModulePath];
  }
  return [NSBundle bundleWithPath:path];
}

-(NSBundle *)bundleForModuleName:(NSString *)name {
  NSString *path = [self pathForModuleName:name];
  return [self bundleForModulePath:path];
}

-(Class)classForModulePath:(NSString *)path {
  return [[self bundleForModulePath:path] principalClass];
}

-(Class)classForModuleName:(NSString *)name {
  return [[self bundleForModuleName:name] principalClass];
}

-(id)createScreenSaverViewForModulePath:(NSString *)path frame:(NSRect)frame isPreview:(BOOL)preview {
    Class screenSaverClass = [self classForModulePath:path];
    id screenSaverView = nil;
    // Quartz Composer support
    if ([path hasSuffix:QUARTZ_COMPOSER_MODULE_EXTENSION]) {
        screenSaverView = [[screenSaverClass alloc] _initWithComposition:path frame:frame isPreview:preview];
        [NSClassFromString(@"SaverLabQCPlayerViewWrapper") swizzleMethodForClass:screenSaverClass];
        return screenSaverView;
    }
    else {
        // XScreenSaver support
        [NSClassFromString(@"SaverLabXScreenSaverWrapper") swizzle];

        screenSaverView = [[screenSaverClass alloc] initWithFrame:frame isPreview:preview];
        // slideshow support
        if ([path hasSuffix:SLIDESHOW_MODULE_EXTENSION] && [screenSaverView respondsToSelector:@selector(setImageDirectory:)]) {
            [screenSaverView setImageDirectory:[[path stringByAppendingPathComponent:@"Contents"]
                                                      stringByAppendingPathComponent:@"Resources"]];
        }
    }
    return screenSaverView;
}

-(id)createScreenSaverViewForName:(NSString *)name frame:(NSRect)frame isPreview:(BOOL)preview {
  return [self createScreenSaverViewForModulePath:[self pathForModuleName:name] frame:frame isPreview:preview];
}

@end
