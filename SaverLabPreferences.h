//
//  SaverLabPreferences.h
//  SaverLab
//
//  Created by brian on Sat Jun 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SaverLabPreferences : NSObject {
}

+(SaverLabPreferences *)sharedInstance;

-(NSSize)defaultModuleWindowSize;
-(void)setDefaultModuleWindowSize:(NSSize)value;

-(BOOL)showModuleListOnStartup;
-(void)setShowModuleListOnStartup:(BOOL)value;

-(BOOL)showModuleListWhenNoOpenWindows;
-(void)setShowModuleListWhenNoOpenWindows:(BOOL)value;

-(BOOL)restoreModuleWindowsOnStartup;
-(void)setRestoreModuleWindowsOnStartup:(BOOL)value;

-(BOOL)isPreviewVisible;
-(void)setIsPreviewVisible:(BOOL)value;

-(BOOL)autoUpdateModuleList;
-(void)setAutoUpdateModuleList:(BOOL)value;

-(BOOL)showConsoleWindowOnOutput;
-(void)setShowConsoleWindowOnOutput:(BOOL)value;

// QuickTime recording preferences

-(BOOL)createMovieFromRecordedImages;
-(void)setCreateMovieFromRecordedImages:(BOOL)value;

-(BOOL)deleteRecordedImages;
-(void)setDeleteRecordedImages:(BOOL)value;

-(BOOL)useCustomFrameRate;
-(void)setUseCustomFrameRate:(BOOL)value;

-(int)customFrameRate;
-(void)setCustomFrameRate:(int)value;

-(NSString *)recordedImagesDirectory;
-(void)setRecordedImagesDirectory:(NSString *)value;

@end
