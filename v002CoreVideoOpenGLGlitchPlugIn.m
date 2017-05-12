//
//  v002CoreVideoGlitchPlugIn.m
//  v002CoreVideoGlitch
//
//  Created by vade on 8/18/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002CoreVideoOpenGLGlitchPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch Core Video OpenGL"
#define	kQCPlugIn_Description		@"Core Video OpenGL Buffer/Texture glitch exploits some Core Video functions to create some dynamic glitch from pools of PBuffers"


static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	// this is a noop, since we handle releasing/flushing cache in the main execute loop
	//CVOpenGLTextureRelease((CVOpenGLTextureRef) info);
}

@implementation v002CoreVideoOpenGLGlitchPlugIn

@dynamic outputImage, inputFlushDelay, inputWidth, inputHeight;
/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/

+ (NSDictionary*) attributes
{
	/*
	Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
	*/
	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/*
	Specify the optional attributes for property based ports (QCPortAttributeNameKey, QCPortAttributeDefaultValueKey...).
	*/
	
	if([key isEqualToString:@"inputFlushDelay"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Flush Delay", QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeDefaultValueKey,
				nil];
	}
	
	
	if([key isEqualToString:@"inputWidth"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Width", QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeDefaultValueKey,
				nil];
	}
	
	if([key isEqualToString:@"inputHeight"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Height", QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeDefaultValueKey,
				nil];
	}
	
	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputFlushDelay", @"inputWidth", @"inputHeight", nil];
}

+ (QCPlugInExecutionMode) executionMode
{
	/*
	Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	*/
	
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/*
	Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	*/
	
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
    self = [super init];
	if(self)
    {
		/*
		Allocate any permanent resource required by the plug-in.
		*/
		

	}
	
	return self;
}

- (void) finalize
{
	/*
	Release any non garbage collected resources created in -init.
	*/
	
	[super finalize];
}

- (void) dealloc
{
	/*
	Release any resources created in -init.
	*/
//	[cvGLContext release];
//	[cvPixelFormat release];
	
	[super dealloc];
}

@end

@implementation v002CoreVideoOpenGLGlitchPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/
	
	
	// et our parent contexts pixel format
	cvPixelFormat = CGLGetPixelFormat([context CGLContextObj]);
	
	CGLCreateContext(cvPixelFormat, [context CGLContextObj], &cvGLContext);
	
	[self createCVResources];	
	
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	*/
	
	// bind to core video context...
	CGLContextObj cgl_ctx = cvGLContext; 
	
	// handle buffer pool resizing..
	if([self didValueForInputKeyChange:@"inputWidth"] || [self didValueForInputKeyChange:@"inputHeight"])
	{
		NSLog(@"Resizing buffer Pool");
		// resize our CVOpenGLBufferPool
		[self destroyCVResources];
		[self createCVResources];
	}
	
	
	// we have to periodically call CVOpenGLTextureCacheFlush or we get a leak.
	// the longer we wait, the more vram we use, but the more 'frames' of glitch we get.
	// the end user can control this amount as an additional 'effect'.
	
	static int frameCount = 0;
	frameCount = frameCount % (self.inputFlushDelay + 1);
	
	if(frameCount == 0)
	{
		CVOpenGLTextureCacheFlush(cvTextureCache, 0);
	}
	
	frameCount++;
	
	// delete old frame, if we need to... this avoids VRam / texture leak
	if(cvTexture != NULL)
	{
		CVOpenGLTextureRelease(cvTexture);
		cvTexture = NULL;
	}
	
	if(cvImageBuffer != NULL)
	{
		CVOpenGLBufferRelease(cvImageBuffer);
		cvImageBuffer = NULL;
	}
	
	if(CVOpenGLBufferPoolCreateOpenGLBuffer(NULL, cvBufferPool, &cvImageBuffer) == kCVReturnSuccess)
	{		
		//Use the buffer as the OpenGL context destination
		if(CVOpenGLBufferAttach(cvImageBuffer, cvGLContext, 0, 0, 0) == kCVReturnSuccess)
		{
			// dont clear or draw anything in our CVOpenGLBuffer 
			// this causes our glitch :)
		}	
		else
		{
			NSLog(@"Failed Attaching CVOGL buffer");
			CVOpenGLBufferRelease(cvImageBuffer);
			cvImageBuffer = NULL;
		}

		// convert out cvImageBuffer to a texture from our texture cache 
		NSDictionary * emptyAttributes = [NSDictionary dictionary];	
		if(CVOpenGLTextureCacheCreateTextureFromImage(NULL, cvTextureCache, cvImageBuffer, (__bridge CFDictionaryRef) emptyAttributes, &cvTexture) != kCVReturnSuccess)
		{
			cvTexture = NULL;
		}
	}	
		
	// switch to our QC plugin GL context...
	cgl_ctx = [context CGLContextObj];
	
#if __BIG_ENDIAN__
#define v002PlugInPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002PlugInPixelFormat QCPlugInPixelFormatBGRA8
#endif			
	
	self.outputImage = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:self.inputWidth pixelsHigh:self.inputHeight name:CVOpenGLTextureGetName(cvTexture) flipped:NO releaseCallback:_TextureReleaseCallback releaseContext:cvGLContext colorSpace:[context colorSpace] shouldColorMatch:YES];
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
}
	   
- (void) destroyCVResources
{
	CVOpenGLTextureCacheRelease(cvTextureCache);
	CVOpenGLBufferPoolRelease(cvBufferPool);
		
}	

- (void) createCVResources
{
	if(cvGLContext != nil)
	{
		NSMutableDictionary * bufferOptions = [NSMutableDictionary dictionary];
		[bufferOptions setValue:[NSNumber numberWithDouble:self.inputWidth] forKey:(NSString*)kCVOpenGLBufferWidth];
		[bufferOptions setValue:[NSNumber numberWithDouble:self.inputHeight] forKey:(NSString*)kCVOpenGLBufferHeight];
		
		if(CVOpenGLBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)bufferOptions, &cvBufferPool) != kCVReturnSuccess)
			cvBufferPool = NULL;
		
		if(CVOpenGLTextureCacheCreate(NULL, NULL, cvGLContext, cvPixelFormat, NULL, &cvTextureCache) != kCVReturnSuccess)
			cvTextureCache = NULL;
	}
	else
	{
		NSLog(@"could not create cvGLcontext... :(");
	}	
}
	   
@end
