/* Copyright 2001-2007 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SaverLabScreenSaverViewAdditions.h"
#import "SaverLabNSWindowAdditions.h"
#include <OpenGL/glu.h>

#import <AGL/agl.h>

@interface NSObject (DC_XScreenSaverCompatibility)
-(AGLContext)aglContext;
@end

// corrects a vertically mirrored image by re-flipping. Pixels are assumed to be int-sized.
static void fixVerticalMirroredBitmap(int *data, int w, int h) {
  int cols = h/2;
  int x, y;
  // could probably optimize by unrolling inner loop and using doubles/Altivec/SSE
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


#import "objc/runtime.h"
@implementation ScreenSaverView (SaverLabScreenSaverViewAdditions)

// Override startAnimation and stopAnimation so that they don't rely on the
// private ScreenSaverModule and ScreenSaverEngine classes.  Acording to
// xscreensaver's SaverRunner.m:
//
// > On 10.8 and earlier, [ScreenSaverView startAnimation] causes the
// > ScreenSaverView to run its own timer calling animateOneFrame.  On 10.9,
// > that fails because the private class ScreenSaverModule is only
// > initialized properly by ScreenSaverEngine, and in the context of
// > SaverRunner, the null ScreenSaverEngine instance behaves as if
// > [ScreenSaverEngine needsAnimationTimer] returned false.

- (void)startAnimation {
    [self slStart];
}

- (void)stopAnimation {
    [self slStop];
}

- (BOOL)isAnimating {
    return !![self slTimer];
}

static char sTimerKey;
- (NSTimer *)slTimer {
    return objc_getAssociatedObject(self, &sTimerKey);
}

- (NSTimer *)slSetTimer:(NSTimer *) t {
    objc_setAssociatedObject(self, &sTimerKey, t, OBJC_ASSOCIATION_RETAIN);
    return t;
}

- (void)slStart {
    [self slStop];
    [self slSetTimer:[NSTimer scheduledTimerWithTimeInterval:[self animationTimeInterval]
                                                      target:self
                                                    selector:@selector(slAnimateOneFrame)
                                                    userInfo:nil
                                                     repeats:YES]];
}

- (void)slStop {
    NSTimer *timer = [self slTimer];
    [timer invalidate];
    [self slSetTimer:nil];
}


- (void)slAnimateOneFrame {
    [self lockFocus];
    [self animateOneFrame];
    [self unlockFocus];
    [self displayIfNeeded];
}

- (void)dealloc {
    NSTimer *timer = [self slTimer];
    [timer invalidate];
    [timer release];
    [super dealloc];
}

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
  static int first = 0;
  NSBitmapImageRep *bitmap = nil;
  NSOpenGLView *openGLView = [self _openGLSubview];
  
  AGLContext aglContext = (!openGLView && [self respondsToSelector:@selector(aglContext)]) ? [self aglContext] : NULL;
  
  if (!openGLView && !aglContext) {
    NSRect r2 = [self convertRect:[self frame] toView:nil];
    [self lockFocus];
    bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:r2] autorelease];
    [self unlockFocus];  
    //NSLog(@"%@ %@ %@", NSStringFromSize([self frame].size), NSStringFromSize(r2.size), NSStringFromSize([bitmap size]));
  }  
  else {
    // extracts the pixels from the NSOpenGLView and returns a NSBitmapImageRep. 
    // Thanks to Peter Ammon for sample code.
    // lock the OpenGLView if we can, thanks Mike
    BOOL shouldLock = [openGLView respondsToSelector:@selector(lock)] &&
                      [openGLView respondsToSelector:@selector(unlock)];
    // save previous context (not necessary and causes crashes with AGLContext?)
    // NSOpenGLContext *previousContext = [NSOpenGLContext currentContext];
    
    float scale = [[self window] userSpaceScaleFactor_];
    NSView *view = (openGLView!=nil) ? openGLView : self;
    int h=NSHeight([view bounds])*scale;
    // apparently width for glReadPixels has to be a multiple of 8, otherwise captured bitmap is distorted
    int w = (((int)(NSWidth([view bounds])*scale))/8) * 8;
    if (!first) {
      //NSLog(@"%d %d", w, h);
      first = 1;
    }
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
  
    if (openGLView) [[openGLView openGLContext] makeCurrentContext];
    else if (aglContext) aglSetCurrentContext(aglContext);
    
    // In OpenGL coordinates, (0,0) is the top left, while in AppKit (0,0) is bottom left
    // so this will return a vertically mirrored bitmap.
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, [bitmap bitmapData]);
  
    // restore previous context
    //if (previousContext) [previousContext makeCurrentContext];
    //else [NSOpenGLContext clearCurrentContext];
  
    if (shouldLock) {
      [openGLView unlock];
    }
  
    // re-flip the image to get it in the right orientation for AppKit
    fixVerticalMirroredBitmap((int *)[bitmap bitmapData], w, h);
  }
  return bitmap;
}

@end

/* XScreenSaver modules explicitly hide the cursor which results in annoying flickering, so we disable that here.
*/
@implementation NSCursor (DC_XScreenSaverHack)
+(void)setHiddenUntilMouseMoves:(BOOL)value {
  // ignore
}
@end


