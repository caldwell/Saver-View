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

@end
