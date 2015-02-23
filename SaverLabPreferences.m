//
//  SaverLabPreferences.m
//  SaverLab
//
//  Created by brian on Sat Jun 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "SaverLabPreferences.h"

static SaverLabPreferences *_sharedInstance = nil;

@implementation SaverLabPreferences

+(SaverLabPreferences *)sharedInstance {
  if (!_sharedInstance) {
    _sharedInstance = [[SaverLabPreferences alloc] init];
  }
  return _sharedInstance;
}

-(NSSize)defaultModuleWindowSize {
  float width  = [[NSUserDefaults standardUserDefaults] integerForKey:@"defaultWindowWidth"];
  float height = [[NSUserDefaults standardUserDefaults] integerForKey:@"defaultWindowHeight"];
  if (width<=0 || height<=0) {
    width  = 320;
    height = 240;
  }
  return NSMakeSize(width, height);
}

-(void)setDefaultModuleWindowSize:(NSSize)value {
  [[NSUserDefaults standardUserDefaults] setInteger:(int)value.width  forKey:@"defaultWindowWidth"];
  [[NSUserDefaults standardUserDefaults] setInteger:(int)value.height forKey:@"defaultWindowHeight"];
}

// defaults to false
-(BOOL)showModuleListOnStartup {
  NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showListOnStartup"];
  return ([value intValue]!=0);
}
-(void)setShowModuleListOnStartup:(BOOL)value {
  NSString *string = (value) ? @"1" : @"0";
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"showListOnStartup"];
}

// defaults to true
-(BOOL)showModuleListWhenNoOpenWindows {
  NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showListWhenNoOpenWindows"];
  return (!value || [value intValue]!=0);
}
-(void)setShowModuleListWhenNoOpenWindows:(BOOL)value {
  NSString *string = (value) ? @"1" : @"0";
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"showListWhenNoOpenWindows"];
}

// defaults to true
-(BOOL)restoreModuleWindowsOnStartup {
  NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"restoreWindowsOnStartup"];
  return (!value || [value intValue]!=0);
}
-(void)setRestoreModuleWindowsOnStartup:(BOOL)value {
  NSString *string = (value) ? @"1" : @"0";
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"restoreWindowsOnStartup"];
}

// defaults to true
-(BOOL)autoUpdateModuleList {
  NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"autoUpdateModuleList"];
  return (!value || [value intValue]!=0);
}
-(void)setAutoUpdateModuleList:(BOOL)value {
  NSString *string = (value) ? @"1" : @"0";
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"autoUpdateModuleList"];
}

// defaults to false
-(BOOL)isPreviewVisible {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"isPreviewVisible"];
}
-(void)setIsPreviewVisible:(BOOL)value {
  [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"isPreviewVisible"];
}


@end
