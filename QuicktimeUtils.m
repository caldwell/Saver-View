/* Copyright 2001 by Brian Nenninger

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "QuicktimeUtils.h"

/* Most of this code is taken from Apple's CocoaCreateMovie example project, with hacks to create
a movie from NSImages returned by an NSEnumerator, and to notify a delegate when an image is
processed. 
*/

static int kTimeUnitsPerSecond = 600;

static OSErr FilePathToFSSpec( NSString *asFilePath, FSSpec* apSpec )
{

   CFURLRef cfUrl = CFURLCreateWithFileSystemPath( kCFAllocatorDefault, 
               (CFStringRef)asFilePath, kCFURLPOSIXPathStyle, false );
   FSRef  fileRef;
   OSErr  err = noErr;

   if ( CFURLGetFSRef( cfUrl, &fileRef ) ) {
     err = FSGetCatalogInfo( &fileRef, kFSCatInfoNone, NULL, 
           NULL, apSpec, NULL );
     if ( err ) return( err );
   }
	
   CFRelease( cfUrl );
   return( err );

}

static StringPtr QTUtils_ConvertCToPascalString (char *theString)
{
	StringPtr	myString = malloc(strlen(theString) + 1);
	short		myIndex = 0;

	while (theString[myIndex] != '\0') {
		myString[myIndex + 1] = theString[myIndex];
		myIndex++;
	}
	
	myString[0] = (unsigned char)myIndex;
	
	return(myString);
}

static void CopyNSImageToGWorld(NSImage *image, GWorldPtr gWorldPtr)
{
    NSArray 		*repArray;
    PixMapHandle 	pixMapHandle;
    Ptr 		pixBaseAddr;
    int			imgRepresentationIndex;

    // Lock the pixels
    pixMapHandle = GetGWorldPixMap(gWorldPtr);
    LockPixels (pixMapHandle);
    pixBaseAddr = GetPixBaseAddr(pixMapHandle);

    repArray = [image representations];
    for (imgRepresentationIndex = 0; imgRepresentationIndex < [repArray count]; ++imgRepresentationIndex)
    {
        NSImageRep *imageRepresentation = [repArray objectAtIndex:imgRepresentationIndex];
        
        if ([imageRepresentation isKindOfClass:[NSBitmapImageRep class]])
        {
            Ptr bitMapDataPtr = (Ptr)[(NSBitmapImageRep *)imageRepresentation bitmapData];
            int hasAlpha = [imageRepresentation hasAlpha];

            if ((bitMapDataPtr != nil) && (pixBaseAddr != nil))
            {
                int i,j;
                int pixmapRowBytes = GetPixRowBytes(pixMapHandle);
                NSSize imageSize = [(NSBitmapImageRep *)imageRepresentation size];
                for (i=0; i< imageSize.height; i++)
                {
                    unsigned char *src = (unsigned char *)(bitMapDataPtr + i * [(NSBitmapImageRep *)imageRepresentation bytesPerRow]);
                    unsigned char *dst = (unsigned char *)(pixBaseAddr + i * pixmapRowBytes);
                    for (j = 0; j < imageSize.width; j++)
                    {
                      // get alpha if present in source
                        if (hasAlpha) {
                          // source is rgba format, dest is argb
                          unsigned char r = *src++;
                          unsigned char g = *src++;
                          unsigned char b = *src++;                          
                          *dst++ = *src++; // alpha
                          *dst++ = r;
                          *dst++ = g;
                          *dst++ = b;
                        }
                        else {
                          *dst++ = 0;
                          *dst++ = *src++;	// Red component
                          *dst++ = *src++;	// Green component
                          *dst++ = *src++;	// Blue component  
                        }
                    }
                }
            }
        }
    }
    UnlockPixels(pixMapHandle);
}

static void CheckError(OSErr err, char *message )
{
    if (err != noErr)
    {
        printf(message);
    }
}

static int addImagesToMedia(NSImage *firstImage, NSEnumerator *imageEnum, Media theMedia, Rect *trackFrame, double frameLength, id delegate) {
	GWorldPtr theGWorld = nil;
	long maxCompressedSize;
	Handle compressedData = nil;
	Ptr compressedDataPtr;
	ImageDescriptionHandle imageDesc = nil;
	CGrafPtr oldPort;
	GDHandle oldGDeviceH;
	OSErr err = noErr;
        NSImage *frameImage;
	int i;
        int aborted=0;
    
        // Create a graphics world
        err = NewGWorld (&theGWorld,	/* pointer to created gworld */	
                32,		/* pixel depth */
                trackFrame, 		/* bounds */
                nil, 			/* color table */
                nil,			/* handle to GDevice */ 
                (GWorldFlags)0);	/* flags */
        CheckError (err, "NewGWorld error");

        // Lock the pixels
        LockPixels (GetGWorldPixMap(theGWorld)/*GetPortPixMap(theGWorld)*/);

        // Determine the maximum size the image will be after compression.
        // Specify the compression characteristics, along with the image.
        err = GetMaxCompressionSize(GetGWorldPixMap(theGWorld),		/* Handle to the source image */
                            trackFrame, 				/* bounds */
                            32, 				/* let ICM choose depth */
                            codecNormalQuality,				/* desired image quality */ 
                            kAnimationCodecType,			/* compressor type */ 
                            (CompressorComponent)anyCodec,  		/* compressor identifier */
                            &maxCompressedSize);		    	/* returned size */
        CheckError (err, "GetMaxCompressionSize error" );

        // Create a new handle of the right size for our compressed image data
        compressedData = NewHandle(maxCompressedSize);
        CheckError( MemError(), "NewHandle error" );

        MoveHHi( compressedData );
        HLock( compressedData );
        compressedDataPtr = *compressedData;

        // Create a handle for the Image Description Structure
        imageDesc = (ImageDescriptionHandle)NewHandle(4);
        CheckError( MemError(), "NewHandle error" );

        // Change the current graphics port to the GWorld
        GetGWorld(&oldPort, &oldGDeviceH);
        SetGWorld(theGWorld, nil);

    i = 0;
    do {
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      frameImage = (firstImage!=nil) ? firstImage : [imageEnum nextObject];
      firstImage = nil;
      
      if (frameImage) {
        //NSLog(@"Adding image %d", i);
        i++;
        
        CopyNSImageToGWorld(frameImage, theGWorld);
        // Use the ICM to compress the image 
        err = CompressImage(GetGWorldPixMap(theGWorld),	/* source image to compress */
                            trackFrame, 		/* bounds */
                            codecNormalQuality,	/* desired image quality */
                            kAnimationCodecType,	/* compressor identifier */
                            imageDesc, 		/* handle to Image Description Structure; will be resized by call */
                            compressedDataPtr);	/* pointer to a location to recieve the compressed image data */
        CheckError( err, "CompressImage error" );

        // Add sample data and a description to a media
        err = AddMediaSample(theMedia,	/* media specifier */ 
                compressedData,	/* handle to sample data - dataIn */
                0,		/* specifies offset into data reffered to by dataIn handle */
                (**imageDesc).dataSize, /* number of bytes of sample data to be added */ 
                (int)(kTimeUnitsPerSecond*frameLength),		 /* frame duration = 1/10 sec */
                (SampleDescriptionHandle)imageDesc,	/* sample description handle */ 
                1,	/* number of samples */
                0,	/* control flag indicating self-contained samples */
                nil);		/* returns a time value where sample was insterted */
        CheckError( err, "AddMediaSample error" );
        
        // check for abort request from delegate
        if ([delegate respondsToSelector:@selector(shouldAbort)] && [delegate shouldAbort]) {
          aborted = 1;
        }
        // notify delegate image was processed
        if (!aborted && [delegate respondsToSelector:@selector(didProcessImage:)]) {
          [delegate didProcessImage:i];
        }
      }
      
      [pool release];
      
    } while (frameImage!=nil && !aborted);
    
        UnlockPixels (GetGWorldPixMap(theGWorld));

        SetGWorld (oldPort, oldGDeviceH);

        // Dealocate our previously alocated handles and GWorld
        if (imageDesc)
        {
                DisposeHandle ((Handle)imageDesc);
        }
        
        if (compressedData)
        {
                DisposeHandle (compressedData);
        }
        
        if (theGWorld)
        {
                DisposeGWorld (theGWorld);
        }

  return 1;
}

static int createVideoTrackFromImageEnumerator(Movie theMovie, NSEnumerator *imageEnum, double frameLength, id delegate) {
  Track theTrack;
  Media theMedia;
  OSErr err = noErr;
  NSImage *firstImage;
  Rect movieRect = {0,0,0,0};
  NSSize movieSize;

  // get the size from the first image
  firstImage = [imageEnum nextObject];                  
  if (!firstImage) return 0;
  movieSize = [firstImage size];
  movieRect.bottom = movieSize.height;
  movieRect.right = movieSize.width;
  
  // 1. Create the track
  theTrack = NewMovieTrack (theMovie, 		/* movie specifier */
                            FixRatio(movieRect.right,1),  /* width */
                            FixRatio(movieRect.bottom,1), /* height */
                            kNoVolume);  /* trackVolume */
  CheckError( GetMoviesError(), "NewMovieTrack error" );
  
  // 2. Create the media for the track
  theMedia = NewTrackMedia (theTrack,		/* track identifier */
                            VideoMediaType,		/* type of media */
                            kTimeUnitsPerSecond, 	/* time coordinate system */
                            nil,	/* data reference - use the file that is associated with the movie  */
                            0);			/* data reference type */
  CheckError( GetMoviesError(), "NewTrackMedia error" );

  // 3. Establish a media-editing session
  err = BeginMediaEdits (theMedia);
  CheckError( err, "BeginMediaEdits error" );

  // 3a. Add Samples to the media
  addImagesToMedia(firstImage, imageEnum, theMedia, &movieRect, frameLength, delegate);
  
  // if we aborted, we shouldn't do any of the following, since we're going to delete the movie anyway

  // 3b. End media-editing session
  err = EndMediaEdits (theMedia);
  CheckError( err, "EndMediaEdits error" );

  // 4. Insert a reference to a media segment into the track
  err = InsertMediaIntoTrack (theTrack,		/* track specifier */
                          0,	/* track start time */
                          0, 	/* media start time */
                          GetMediaDuration(theMedia), /* media duration */
                          fixed1);		/* media rate ((Fixed) 0x00010000L) */
  CheckError( err, "InsertMediaIntoTrack error" );
  
  return (theMovie!=nil && err==noErr);
}

int createMovieFromImageEnumerator(NSString *moviePath, NSEnumerator *imageEnum, double frameLength, id delegate) {
    Movie theMovie = nil;
    FSSpec mySpec;
    short resRefNum = 0;
    short resId = movieInDataForkResID;
    OSErr err = noErr;

    EnterMovies();    

    // create an empty file (needed to get an FSSpec)
    if (![[NSFileManager defaultManager] createFileAtPath:moviePath contents:[NSData data] attributes:nil]) 
      return 0;
      
    err = FilePathToFSSpec(moviePath, &mySpec);
    
    err = CreateMovieFile (&mySpec, 
                            FOUR_CHAR_CODE('TVOD'),
                            smCurrentScript, 
                            createMovieFileDeleteCurFile | createMovieFileDontCreateResFile,
                            &resRefNum, 
                            &theMovie );
                            
    if (theMovie==nil) return 0;

    if (!createVideoTrackFromImageEnumerator(theMovie, imageEnum, frameLength, delegate)) return 0;
    err = AddMovieResource (theMovie, resRefNum, &resId, QTUtils_ConvertCToPascalString ("testing"));
    if (resRefNum)
    {
        CloseMovieFile (resRefNum);
    }

    return (theMovie!=nil && err==noErr);
  
}

