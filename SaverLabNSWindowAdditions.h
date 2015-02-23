//
//  SaverLabNSWindowAdditions.h
//  SaverLab
//
//  Created by brian on Sat Jun 23 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** If the "Close" menu command is bound to the FirstResponder's performClose: method,
it will not be enabled when a full screen window is frontmost. Overriding respondsToSelector:
in SaverLabFullScreenWindow doesn't help, so instead this category defines a new method
reallyClose: that closes the window using -[NSWindow close]. The Close menu command can then
be bound to reallyClose: and it will work for full screen and normal windows.
*/

@interface NSWindow (SaverLabNSWindowAdditions)

-(void)reallyClose:(id)sender;

@end
