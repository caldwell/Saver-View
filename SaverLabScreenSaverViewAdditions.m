/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabScreenSaverViewAdditions.h"
#include <OpenGL/glu.h>

// corrects a vertically mirrored image by re-flipping. Pixels are assumed to be int-sized.
static void fixVerticalMirroredBitmap(int *data, int w, int h) {
  int cols = h/2;
  int x, y;
  // could probably optimize by unrolling inner loop and using doubles
  for(y=0; y<cols; y++) {
    int *topptr = data + (y*w);
    int *botptr = data + ((h-y-1)*w);
    for(x=0; x<w; x++) {
      int tmp = *topptr;
      *topptr = *botptr;
      *botptr = tmp;
      topptr++;
      botptr++;
    }
  }
}


@implementation ScreenSaverView (SaverLabScreenSaverViewAdditions)

-(NSOpenGLView *)_openGLSubview {
  NSArray *subviews = [self subviews];
  int len = [subviews count];
  int i;
  for(i=0; i<len; i++) {
    id view = [subviews objectAtIndex:i];
    if ([view isKindOfClass:[NSOpenGLView class]]) return view;
  }
  return nil;
}

-(BOOL)isOpenGLModule {
  return [self _openGLSubview]!=nil;
}

-(NSBitmapImageRep *)viewContentsAsImageRep {
  NSBitmapImageRep *bitmap = nil;
  NSOpenGLView *openGLView = [self _openGLSubview];
  if (!openGLView) {
    [self lockFocus];
    bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[self frame]] autorelease];
    [self unlockFocus];  
  }  
  else {
    // extracts the pixels from the NSOpenGLView and returns a NSBitmapImageRep. 
    // Thanks to Peter Ammon for sample code.
    // lock the OpenGLView if we can, thanks Mike
    BOOL shouldLock = [self respondsToSelector:@selector(lock)] &&
                      [self respondsToSelector:@selector(unlock)];
    // save previous context  
    NSOpenGLContext *previousContext = [NSOpenGLContext currentContext];
    
    int h=NSHeight([openGLView bounds]);
    int w=NSWidth([openGLView bounds]);
    bitmap=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:w
                                                      pixelsHigh:h
                                                  bitsPerSample:8
                                                samplesPerPixel:4
                                                        hasAlpha:YES
                                                        isPlanar:NO
                                                  colorSpaceName:NSCalibratedRGBColorSpace
                                                    bytesPerRow:0
                                                    bitsPerPixel:0] 
              autorelease];  
    
    if (shouldLock) {
      [openGLView lock];
    }
  
    [[openGLView openGLContext] makeCurrentContext];
    // In OpenGL coordinates, (0,0) is the top left, while in AppKit (0,0) is bottom left
    // so this will return a vertically mirrored bitmap.
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, [bitmap bitmapData]);
  
    // restore previous context
    if (previousContext) [previousContext makeCurrentContext];
    else [NSOpenGLContext clearCurrentContext];
  
    if (shouldLock) {
      [openGLView unlock];
    }
  
    // re-flip the image to get it in the right orientation for AppKit
    fixVerticalMirroredBitmap((int *)[bitmap bitmapData], w, h);
  }
  return bitmap;
}

@end

