/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabQTProgressWindowController.h"
#import "SaverLabImageEnumerator.h"

#include "QuicktimeUtils.h"

@implementation SaverLabQTProgressWindowController

-(id)init {
  if (self=[super init]) {
    // register for app quit notification to remove image directory and movie
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillQuit:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
  }
  return self;
}

-(void)dealloc {
  //NSLog(@"In SaverLabQTProgressWindowController dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [outputMovieFile release];
  [imagesDirectory release];
  
  [super dealloc];
}

-(void)createMovieFile:(NSString *)movieFile fromImagesInDirectory:(NSString *)imageDir frameCount:(int)numImages frameLength:(double)flength deleteImagesWhenDone:(BOOL)deleteImages {
  outputMovieFile = [movieFile copy];
  imagesDirectory = [imageDir copy];
  numberOfFrames = numImages;
  frameLength = flength;
  deleteImagesDirectoryWhenFinished = deleteImages;
  
  [fileTextField setStringValue:[outputMovieFile lastPathComponent]];
  [framesTextField setStringValue:[NSString stringWithFormat:@"0/%d", numberOfFrames]];
  [progressBar setDoubleValue:0];
  
  [window makeKeyAndOrderFront:nil];
  lastUpdateTime = [NSDate timeIntervalSinceReferenceDate];

  [NSThread detachNewThreadSelector:@selector(runInThread:) toTarget:self withObject:nil];
}

// entry method for the spawned thread
-(void)runInThread:(id)arg {

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
  createMovieFromImageEnumerator(outputMovieFile, 
                                 [[[SaverLabImageEnumerator alloc] initWithPath:imagesDirectory] autorelease], 
                                 frameLength, 
                                 self);
                                 
  if (deleteImagesDirectoryWhenFinished) {
    [[NSFileManager defaultManager] removeFileAtPath:imagesDirectory handler:nil];
  }
  
  // if we aborted, remove the movie file
  if (abortFlag) {
    [[NSFileManager defaultManager] removeFileAtPath:outputMovieFile handler:nil];
  }

  // NSDefaultRunLoopMode is used so we don't close the window if the user is holding down the cancel button until she lets go
  [self performSelectorOnMainThread:@selector(closeWindow) withObject:nil waitUntilDone:NO modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
  
  [pool release];
}

-(void)closeWindow {
  if (![window isReleasedWhenClosed]) {
    [window autorelease];
  }
  [window close];
  [self autorelease];
}

-(void)updateFrameNumber:(NSNumber *)imageNum {
  [framesTextField setStringValue:[NSString stringWithFormat:@"%d/%d", [imageNum intValue], numberOfFrames]];
  [progressBar setDoubleValue:[imageNum doubleValue]/numberOfFrames];
}

// The cancel method sets a flag that is checked by the Quicktime thread
- (IBAction)cancel:(id)sender {
  abortFlag = YES;
}

// delegate methods called from Quicktime thread
-(void)didProcessImage:(int)imageNum {
  //NSLog(@"didProcessImage:%d",imageNum);
  // update UI every 0.2 seconds or at end
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (now-lastUpdateTime>=0.2 || imageNum>=numberOfFrames) {
    lastUpdateTime = now;
    [self performSelectorOnMainThread:@selector(updateFrameNumber:) withObject:[NSNumber numberWithInt:imageNum] waitUntilDone:NO];
  }
}

-(BOOL)shouldAbort {
  return abortFlag;
}

// notification method called before app quits
-(void)appWillQuit:(NSNotification *)note {
  // remove temporary images directory and (incomplete) saved movie
  if (imagesDirectory) {
    [[NSFileManager defaultManager] removeFileAtPath:imagesDirectory handler:nil];
  }
  if (outputMovieFile) {
    [[NSFileManager defaultManager] removeFileAtPath:outputMovieFile handler:nil];
  }
 
}

@end
