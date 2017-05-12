//
//  v002GlitchImagePlugin.h
//  v002Glitch
//
//  Created by vade on 12/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <OpenGL/OpenGL.h>
#import "v002FBO.h"
#import "v002TextureDownloader.h"

@interface v002GlitchImagePlugin : QCPlugIn
{	
	// cache this or ... ?
	id provider;
		
	NSThread* glitchThread;
	
	CGColorSpaceRef cspace;
	
	CGContextRef inputContext;
	CGContextRef outputContext;
	
	// mirror input ports for use on background thrad
	NSNumber* glitchQuality;
	NSNumber* glitchOffset;
	NSNumber* glitchLength;
	NSNumber* glitchRandomRange;
	NSNumber* recalulateGlitch;
	BOOL updateGlitch;
	BOOL needNewJpeg;
	
	NSRecursiveLock* inputLock;
	NSRecursiveLock* outputLock;

	// our data (used in background thread)
	NSUInteger bufferRowBytes;
	NSMutableData* uploadTextureData;
	NSRect cachedImageBoundsRect;
	
	// now using toms amazingly badass PBO readback system.
	v002TextureDownloader* downloader;

}
@property (readwrite, retain) NSMutableData* uploadTextureData;
@property (readwrite, assign) CGContextRef inputContext;
@property (readwrite, assign) CGContextRef outputContext;

// for background thread
@property (readwrite, retain) NSNumber* glitchQuality;
@property (readwrite, retain) NSNumber* glitchOffset;
@property (readwrite, retain) NSNumber* glitchLength;
@property (readwrite, retain) NSNumber* recalulateGlitch;
@property (readwrite, assign) BOOL needNewJpeg;

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property double inputGlitchQuality;
@property double inputGlitchOffset;
@property double inputGlitchLength;
@property BOOL inputRecalulateGlitch;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;
@end

@interface v002GlitchImagePlugin (Execution)
- (BOOL) buildGLResources:(CGLContextObj)cgl_ctx withBounds:(NSRect)bounds;
- (void) destroyGLResources:(CGLContextObj)cgl_ctx;

// background Jpeg encoding & glitching
- (void) glitchImageInBackground;
@end

 