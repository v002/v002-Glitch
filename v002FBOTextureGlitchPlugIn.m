//
//  v002FBOGlitchPlugIn.m
//  v002FBOGlitch
//
//  Created by vade on 6/26/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002FBOTextureGlitchPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch FBO Texture"
#define	kQCPlugIn_Description		@"Glitches input texture by rendering to FBO with incorrect target texture settings"

// GL texture formats/types for texgen
//#define kRGBTextureTypes [NSArray arrayWithObjects: [NSNumber numberWithInt:GL_LUMINANCE], [NSNumber numberWithInt:GL_LUMINANCE4], [NSNumber numberWithInt:GL_LUMINANCE8], [NSNumber numberWithInt:GL_LUMINANCE12], [NSNumber numberWithInt:GL_LUMINANCE16], [NSNumber numberWithInt:GL_R3_G3_B2], [NSNumber numberWithInt:GL_RGB4], [NSNumber numberWithInt:GL_RGB5], [NSNumber numberWithInt:GL_RGB8], [NSNumber numberWithInt:GL_RGB10], [NSNumber numberWithInt:GL_RGB12], [NSNumber numberWithInt:GL_RGB16], [NSNumber numberWithInt:GL_RGB16F_ARB], [NSNumber numberWithInt:GL_RGBA2], [NSNumber numberWithInt:GL_RGBA4], [NSNumber numberWithInt:GL_RGB5_A1], [NSNumber numberWithInt:GL_RGBA8], [NSNumber numberWithInt:GL_RGB10_A2], [NSNumber numberWithInt:GL_RGBA12], [NSNumber numberWithInt:GL_RGBA16], [NSNumber numberWithInt:GL_RGBA16F_ARB],  nil]
#define kRGBTextureTypes [NSArray arrayWithObjects:[NSNumber numberWithInt:GL_RGB4], [NSNumber numberWithInt:GL_RGB5], [NSNumber numberWithInt:GL_RGB8], [NSNumber numberWithInt:GL_RGB10], [NSNumber numberWithInt:GL_RGB12], [NSNumber numberWithInt:GL_RGB16], [NSNumber numberWithInt:GL_RGB16F_ARB], [NSNumber numberWithInt:GL_RGBA2], [NSNumber numberWithInt:GL_RGBA4], [NSNumber numberWithInt:GL_RGB5_A1], [NSNumber numberWithInt:GL_RGBA8], [NSNumber numberWithInt:GL_RGB10_A2], [NSNumber numberWithInt:GL_RGBA12], [NSNumber numberWithInt:GL_RGBA16], [NSNumber numberWithInt:GL_RGBA16F_ARB],  nil]
// strings for menus
//#define kRGBTextureTypesString [NSArray arrayWithObjects:@"GL_INTENSITY", @"GL_INTENSITY4", @"GL_INTENSITY8", @"GL_INTENSITY12", @"GL_INTENSITY16",@"GL_R3_G3_B2",  @"GL_RGB4", @"GL_RGB5", @"GL_RGB8",@"GL_RGB10", @"GL_RGB12", @"GL_RGB16", @"GL_RGB16F_ARB", @"GL_RGBA2", @"GL_RGBA4", @"GL_RGB5_A1", @"GL_RGBA8", @"GL_RGB10_A2", @"GL_RGBA12", @"GL_RGBA16", @"GL_RGBA16F_ARB", nil]
#define kRGBTextureTypesString [NSArray arrayWithObjects:@"GL_RGB4", @"GL_RGB5", @"GL_RGB8",@"GL_RGB10", @"GL_RGB12", @"GL_RGB16", @"GL_RGB16F_ARB", @"GL_RGBA2", @"GL_RGBA4", @"GL_RGB5_A1", @"GL_RGBA8", @"GL_RGB10_A2", @"GL_RGBA12", @"GL_RGBA16", @"GL_RGBA16F_ARB", nil]



static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

/* Generates a texture containing a linear gradient - Requires FBO support */
static GLuint fboGlitchCreate(CGLContextObj cgl_ctx, NSUInteger pixelsWide, NSUInteger pixelsHigh, NSRect bounds, GLuint videoTexture, GLenum videoTextureTarget, BOOL newRandomValues, int rgbType)
{

	GLint previousFBO, previousReadFBO, previousDrawFBO;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);	
	
	// figure out what texture format to use... 
	NSUInteger i = 0;
	NSUInteger lastRandom = 0;
	NSUInteger type;
	NSUInteger rand;

	if(newRandomValues)	
	{
		srandom(i % 10000);
		rand = random();
		lastRandom = rand;
		++i;
		type = rand  % [kRGBTextureTypes count];
	}
	else
	{
		type =  rgbType;
	}	
	
	GLsizei							width = bounds.size.width,	height = bounds.size.height;
	GLuint							name,frameBuffer;
	GLint							saveName, saveViewport[4], saveMode;
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
	glGetIntegerv(GL_TEXTURE_BINDING_RECTANGLE_EXT, &saveName);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);
	glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, [[kRGBTextureTypes objectAtIndex:type] intValue] , width, height, 0, rgbOrRGBA, GL_UNSIGNED_BYTE, NULL);
	
	// Create temporary FBO to render in texture 
	glGenFramebuffersEXT(1, &frameBuffer);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, frameBuffer);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, name, 0);

	// Assume FBOs JUST WORK, because we checked on startExecution	
//	status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
//	if(status == GL_FRAMEBUFFER_COMPLETE_EXT)
	{	
			
		// Setup OpenGL states 
		glGetIntegerv(GL_VIEWPORT, saveViewport);
		glViewport(0, 0, width, height);
		glGetIntegerv(GL_MATRIX_MODE, &saveMode);
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		
		glOrtho(bounds.origin.x, bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.origin.y + bounds.size.height, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();

//		glEnable(GL_BLEND);
//		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

		glBindTexture(videoTextureTarget, videoTexture);

		//glTranslatef(((float)rand1 / 17.0) * (float)pixelsWide , ((float)rand1 / 17.0) * (float)pixelsHigh, 0);
		glBegin(GL_QUADS);
		glTexCoord2f(pixelsWide , pixelsHigh);
		glVertex3f(pixelsWide , pixelsHigh, 0);
		
		glTexCoord2f(0, pixelsHigh);
		glVertex3f(0 , pixelsHigh , 0);
		
		glTexCoord2f(0, 0);
		glVertex3f(0 , 0 , 0);
		
		glTexCoord2f(pixelsWide, 0);
		glVertex3f(pixelsWide , 0 , 0);
		glEnd();
		
		glBindTexture(videoTextureTarget,0);


		// Restore OpenGL states 
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(saveMode);

		glViewport(saveViewport[0], saveViewport[1], saveViewport[2], saveViewport[3]);	
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, saveName);

	}

/*	else
	{
		glDeleteTextures(1, &name);
		name = 0;
	}
*/
	// return to parent FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
	
	glDeleteFramebuffersEXT(1, &frameBuffer);
	
	// Check for OpenGL errors 
	status = glGetError();
	if(status)
	{
		NSLog(@"OpenGL error %04X", status);
		glDeleteTextures(1, &name);
		name = 0;
	}
	
	return name;
}	



@implementation v002FBOTextureGlitchPlugIn

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/

@dynamic inputImage,inputNewRandomValues, inputInternalTypeRGB, outputImage;

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
	if([key isEqualToString:@"inputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
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
	return [NSArray arrayWithObjects:@"inputImage", @"inputNewRandomValues",@"inputInternalTypeRGB",  nil];
	
}
+ (QCPlugInExecutionMode) executionMode
{
	/*
	Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	*/
	
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/*
	Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	*/
	
	return kQCPlugInTimeModeNone;
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
	
	[super dealloc];
}

@end

@implementation v002FBOTextureGlitchPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/
	
/*	NSString *informativeText = @"This patch creates genuine video corruption on your graphics card, and behaves very differently depending on driver (OS release) and vendor (ATI, NVidia/Intel).\n\rDepending on various factors including the phase of the moon, you may experience \"very strange things\" including but not limited to crashing your window server or kernel panic'ing.\n\rIt is highly suggested you save any work you have open, or so help you god. If you run across any particular texture format that consistently kills your machine, please contact me. \n\rClicking Cancel will not load the patch. Clicking Ok will load the patch."; 

	NSAlert *alert = [[NSAlert alloc] init];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:@"Stop, and pay attention.."];
	[alert setInformativeText:informativeText];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	if ([alert runModal] == NSAlertFirstButtonReturn)
	{
		[alert release];
		return YES;
	}
	else
	{
		[alert release];
		return NO;
	}
	
	return NO; // no dumb compiler warning
 */
    
    
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
    GLint supportsSeparateAddressSpace = 0;
    CGLSetParameter(cgl_ctx, kCGLCPSupportSeparateAddressSpace, &supportsSeparateAddressSpace);

}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	*/
	
	CGLContextObj cgl_ctx = [context CGLContextObj];
	
	id<QCPlugInInputImageSource>   image = self.inputImage;
	
	if(image && [image lockTextureRepresentationWithColorSpace:[image imageColorSpace] forBounds:[image imageBounds]])
	{	
		NSUInteger width = [image imageBounds].size.width;
		NSUInteger height = [image imageBounds].size.height;
		NSRect bounds = [image imageBounds];

		[image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:NO];

		int randWidth = rand() % width;
		int randHeight = rand() % height;

		GLuint finalOutput =  fboGlitchCreate(cgl_ctx, randWidth, randHeight, bounds, [image textureName], GL_TEXTURE_RECTANGLE_EXT, self.inputNewRandomValues,  self.inputInternalTypeRGB);

		glFlushRenderAPPLE();

		if(finalOutput == 0)
			return NO;
			
#if __BIG_ENDIAN__
#define v002PlugInPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002PlugInPixelFormat QCPlugInPixelFormatBGRA8
#endif	
		
		id provider = nil;
	/*	if(self.inputInternalTypeRGB < 5)
		{
			provider = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:[image textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear) shouldColorMatch:NO];
		}
		else
		{
		// output our final image as a QCPluginOutputImageProvider using the QCPluginContext convinience method. No need to go through the trouble of making our own conforming object.	
			provider = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:[image textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[image imageColorSpace] shouldColorMatch:YES];
		}
	*/
		provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:bounds.size.width pixelsHigh:bounds.size.height name:finalOutput flipped:[self.inputImage textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
		
		if(provider == nil)
			return NO;
		
		self.outputImage = provider;
		
		[image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
		[image unlockTextureRepresentation];
	}	
	else
		self.outputImage = nil;
	
	return YES;	
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/
}

@end
