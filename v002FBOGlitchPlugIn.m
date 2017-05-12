//
//  v002FBOGLSLTemplatePlugIn.m
//  v002FBOGLSLTemplate
//
//  Created by vade on 6/30/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002FBOGlitchPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch FBO"
#define	kQCPlugIn_Description		@"Creates Glitches by rendering a Frame Buffer Object without properly clearing/flushing, resulting in capturing video memory"


#define kRGBTextureTypes [NSArray arrayWithObjects: [NSNumber numberWithInt:GL_INTENSITY], [NSNumber numberWithInt:GL_INTENSITY4], [NSNumber numberWithInt:GL_INTENSITY8], [NSNumber numberWithInt:GL_INTENSITY12], [NSNumber numberWithInt:GL_INTENSITY16], [NSNumber numberWithInt:GL_R3_G3_B2], [NSNumber numberWithInt:GL_RGB4], [NSNumber numberWithInt:GL_RGB5], [NSNumber numberWithInt:GL_RGB8], [NSNumber numberWithInt:GL_RGB10], [NSNumber numberWithInt:GL_RGB12], [NSNumber numberWithInt:GL_RGB16], [NSNumber numberWithInt:GL_RGB16F_ARB], [NSNumber numberWithInt:GL_RGBA2], [NSNumber numberWithInt:GL_RGBA4], [NSNumber numberWithInt:GL_RGB5_A1], [NSNumber numberWithInt:GL_RGBA8], [NSNumber numberWithInt:GL_RGB10_A2], [NSNumber numberWithInt:GL_RGBA12], [NSNumber numberWithInt:GL_RGBA16], [NSNumber numberWithInt:GL_RGBA16F_ARB],  nil]
#define kRGBTextureTypesString [NSArray arrayWithObjects:@"GL_INTENSITY", @"GL_INTENSITY4", @"GL_INTENSITY8", @"GL_INTENSITY12", @"GL_INTENSITY16",@"GL_R3_G3_B2"  @"GL_RGB4", @"GL_RGB5", @"GL_RGB8",@"GL_RGB10", @"GL_RGB12", @"GL_RGB16", @"GL_RGB16F_ARB", @"GL_RGBA2", @"GL_RGBA4", @"GL_RGB5_A1", @"GL_RGBA8", @"GL_RGB10_A2", @"GL_RGBA12", @"GL_RGBA16", @"GL_RGBA16F_ARB", nil]

#pragma mark -
#pragma mark Static Functions


static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

// our render setup
//static GLuint renderToFBO(CGLContextObj cgl_ctx, NSUInteger pixelsWide, NSUInteger pixelsHigh, NSRect bounds)
static GLuint fboGlitchCreate(GLuint frameBuffer,CGLContextObj cgl_ctx, NSUInteger pixelsWide, NSUInteger pixelsHigh, NSRect bounds, BOOL newRandomValues, int rgbType)
{
	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	GLint previousFBO, previousReadFBO, previousDrawFBO;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
	
	static int i = 0;
	static int lastRandom = 0;
	//	int format;
	int type;
	NSUInteger rand;
	if(newRandomValues)	
	{
		//	NSLog(@"new rand value");
		srandom(i % 10000);
		rand = random();
		lastRandom = rand;
		++i;
		
		//	type = (rgba) ? (rand % ([kRGBATextureTypes count])) : (rand % ([kRGBTextureTypes count]));
		type = rand  % [kRGBTextureTypes count];
		//	format = (rgba) ? (rand % ([kRGBAPackedPixelInternalFormats count])) : (rand % ([kRGBPackedPixelInternalFormats count])); 
	}
	else
	{
	//	rand = lastRandom;
		type =  rgbType;
	}	
	
	GLsizei							width = bounds.size.width,	height = bounds.size.height;
	GLuint							name;
	GLenum							status;
	
	GLenum rgbOrRGBA;
	
	// pick GL_RGB vs GL_RGBA 
	if (type > 4)
		rgbOrRGBA = GL_LUMINANCE;
	else if(type > 12)
		rgbOrRGBA = GL_RGBA;
	else
		rgbOrRGBA = GL_RGB;
	
	
	// Create texture to render into 
	glGenTextures(1, &name);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);
	glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, [[kRGBTextureTypes objectAtIndex:type] intValue] , width, height, 0, rgbOrRGBA, GL_UNSIGNED_BYTE, NULL);

	// bind our FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, frameBuffer);
	// attach our just created texture
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, name, 0);

	// Assume FBOs JUST WORK, because we checked on startExecution	
//	status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);	
//	if(status == GL_FRAMEBUFFER_COMPLETE_EXT)


	// return to parent FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
	
	// Check for OpenGL errors 
	status = glGetError();
	if(status)
	{
		NSLog(@"OpenGL error %04X", status);
		glDeleteTextures(1, &name);
		name = 0;
	}
	
	glPopAttrib();
	glPopClientAttrib();
	
	return name;
}

@implementation v002FBOGlitchPlugIn

/*
 Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
 @dynamic inputFoo, outputBar;
 */

@dynamic inputWidth, inputHeight, inputNewRandomValues, inputInternalTypeRGB, inputNumberOfFBOs, outputImage;

+ (NSDictionary*) attributes
{
	/*
	 Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
	 */
	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputNumberOfFBOs"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"FBO Count", QCPortAttributeNameKey,
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
	
	if([key isEqualToString:@"inputNewRandomValues"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Random", QCPortAttributeNameKey, nil];
	}	
	
	if([key isEqualToString:@"inputInternalTypeRGB"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Texture Format", QCPortAttributeNameKey,
				[NSArray arrayWithArray:kRGBTextureTypesString], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInteger:0.0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:[kRGBTextureTypesString count] - 1], QCPortAttributeMaximumValueKey,
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
	return [NSArray arrayWithObjects:@"inputNumberOfFBOs", @"inputWidth", @"inputHeight",  @"inputInternalTypeRGB", @"inputNewRandomValues", nil];
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
		
		fboArray = 	[[NSMutableArray alloc] init];
		cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		currentFBO = 0;
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
	[fboArray release];
	CGColorSpaceRelease(cspace);
	[super dealloc];
}

@end

@implementation v002FBOGlitchPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	currentFBO = 0;
		
	// work around lack of GLMacro.h for now
	CGLContextObj cgl_ctx = [context CGLContextObj];
	
//#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 101000
//    CGLGetParameter(ctx, kCGLCPSupportSeparateAddressSpace, &supportsSeparateAddressSpace);
//    GLint supportsSeparateAddressSpace = 0;
//    CGLSetParameter(cgl_ctx, kCGLCPSupportSeparateAddressSpace, &supportsSeparateAddressSpace);
    CGLDisable(cgl_ctx, kCGLCPSupportSeparateAddressSpace);
    //#endif

    
	// build up and destroy an FBO. If it works, we are good to go and dont do any other slow error checking for our main rendering, 
	// if we cant make the FBO, fail by returning NO.
	GLuint name;
	GLenum status;
	
	GLuint tempFBO;
	
	// state saving for currently bound FBO
	GLint previousFBO, previousReadFBO, previousDrawFBO;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
	
	glGenTextures(1, &name);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);
	glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, 640, 480, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	// Create temporary FBO to render in texture 
	glGenFramebuffersEXT(1, &tempFBO);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, tempFBO);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, name, 0);
	
	status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
	{	
		NSLog(@"Cannot create FBO");
		// return to parent FBO
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
		glDeleteFramebuffersEXT(1, &tempFBO);
		glDeleteTextures(1, &name);
		return NO;
	}	
	
	// cleanup
	// return to parent FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);

	glDeleteTextures(1, &name);
	glDeleteFramebuffersEXT(1, &tempFBO);
	return YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLContextObj cgl_ctx = [context CGLContextObj];	
	
	if([self didValueForInputKeyChange:@"inputNumberOfFBOs"])
	{
		if(self.inputNumberOfFBOs <= 0)
			self.inputNumberOfFBOs = 1;
		
		// lock access to fboArray to prevent dumb shit from happening.
		@synchronized(fboArray)
		{
			// reset our counter
			currentFBO = 0;
			
			// remove all old FBOs
			for(NSNumber* fbo in fboArray)
			{
				GLuint tempFBOiD = [fbo unsignedIntValue];
				glDeleteFramebuffersEXT(1, &tempFBOiD);
			}
			[fboArray removeAllObjects];

			// create a set of new FBOs to use based on the number we need
			for(int i = 0; i < self.inputNumberOfFBOs; i++)
			{
				GLuint tempFBOiD;
				GLenum status;
				glGenFramebuffersEXT(1, &tempFBOiD);
				
				// check to make sure this worked...
				status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);	
				if(status == GL_FRAMEBUFFER_COMPLETE_EXT)
				{
					// yo dawg, I  put a buffer in your buffer, so you can glitch when you glitch...	
					[fboArray addObject:[NSNumber numberWithUnsignedInt:tempFBOiD]];
				}
				else
				{
					glDeleteFramebuffersEXT(1, &tempFBOiD);
				}
			}
		}
	}
	
	
	NSUInteger width = self.inputWidth;
	NSUInteger height = self.inputHeight;
	NSRect bounds = NSMakeRect(0.0, 0.0, width, height);

	GLuint finalOutput;
	id provider = nil;	

	// make sure fboArray is locked or dumb shit will happen
	@synchronized(fboArray)
	{
		// set our current FBO we want for this frame
		currentFBO++;
		if([fboArray count])
		{
			if(currentFBO % [fboArray count] == 0)
				currentFBO = 0;
		
			//NSLog(@"using frameBuffer: %i", currentFBO);
		
			finalOutput =  fboGlitchCreate([[fboArray objectAtIndex:currentFBO] unsignedIntValue] ,cgl_ctx, width, height, bounds, self.inputNewRandomValues,  self.inputInternalTypeRGB);
			glFlushRenderAPPLE();
		}
	}
	
	if(finalOutput != 0)
	{		
		// output our final image as a QCPluginOutputImageProvider using the QCPluginContext convinience method. No need to go through the trouble of making our own conforming object.	

		provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:bounds.size.width pixelsHigh:bounds.size.height name:finalOutput flipped:YES releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
		
	//	#if __BIG_ENDIAN__
	//			provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatARGB8 pixelsWide:bounds.size.width pixelsHigh:bounds.size.height name:finalOutput flipped:NO releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear) shouldColorMatch:YES];
	//	#else
	//			provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:bounds.size.width pixelsHigh:bounds.size.height name:finalOutput flipped:YES releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear) shouldColorMatch:YES];

		if(provider == nil)
		{
			return NO;
		}
	}	
	
	self.outputImage = provider;
		
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	CGLContextObj cgl_ctx = [context CGLContextObj];
	// remove our GLSL program
	@synchronized(fboArray)
	{
		for(NSNumber* fbo in fboArray)
		{
			GLuint tempFBOiD = [fbo unsignedIntValue];
			glDeleteFramebuffersEXT(1, &tempFBOiD);
		}
		[fboArray removeAllObjects];
	}
	
	glslProgramObject = NULL;	
}

@end
