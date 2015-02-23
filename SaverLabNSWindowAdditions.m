//
//  SaverLabNSWindowAdditions.m
//  SaverLab
//
//  Created by brian on Sat Jun 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "SaverLabNSWindowAdditions.h"


@implementation NSWindow (SaverLabNSWindowAdditions)

-(void)reallyClose:(id)sender {
  [self close];
}

@end
