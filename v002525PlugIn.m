//
//  v002525PlugIn.m
//  v002525
//
//  Created by vade on 6/23/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002525PlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch 525"
#define	kQCPlugIn_Description		@"v002 Glitch 525 displays faux video signal information normally outside of the raster ; color burst, h/v sync, timecode, flyback, closed captioning, etc."

#pragma mark -
#pragma mark FBO Texture creation.

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

@implementation v002525PlugIn


@dynamic inputImage, outputImage;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeNone;
}

- (id) init
{
    self = [super init];
	if(self)
	{
		self.pluginShaderName = @""; // not using a shader
	}
	
	return self;
}

- (void) finalize
{
	[super finalize];
}

- (void) dealloc
{
	[super dealloc];
}

@end

@implementation v002525PlugIn (Execution)


- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLContextObj cgl_ctx = [context CGLContextObj];
	CGLLockContext(cgl_ctx);

	id<QCPlugInInputImageSource> image = self.inputImage;

	if(image && [image lockTextureRepresentationWithColorSpace:[image imageColorSpace] forBounds:[image imageBounds]])
	{	
		NSUInteger width = [image imageBounds].size.width;
		NSUInteger height = [image imageBounds].size.height;
		NSRect bounds = [image imageBounds];
		
		[image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:NO];

		GLuint finalOutput = [self renderToFBO:cgl_ctx width:width height:height bounds:bounds texture:[image textureName]];

#if __BIG_ENDIAN__
#define v002PlugInPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002PlugInPixelFormat QCPlugInPixelFormatBGRA8
#endif		
		id provider;
		
		// properly handle grey colorspaces. Need to determine how to handle float data, but for now, 8bit RGB or 8Bit grey.
		if(CGColorSpaceGetNumberOfComponents([image imageColorSpace]) > 1)			
			// output our final image as a QCPluginOutputImageProvider using the QCPluginContext convinience method. No need to go through the trouble of making our own conforming object.	
			provider = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:[image textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[image imageColorSpace] shouldColorMatch:YES];
		else
		{
			// handle greyscale to RGB conversion by forcing colorspace.
			CGColorSpaceRef cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
			provider = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:[image textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:cspace shouldColorMatch:NO];				
			CGColorSpaceRelease(cspace);
		}
		if(provider == nil)
			return NO;
		
		self.outputImage = provider;
		//[provider release];
		
		[image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
		[image unlockTextureRepresentation];
	}	
	else
		self.outputImage = nil;
	
	CGLUnlockContext(cgl_ctx);
	
	return YES;
}

- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh bounds:(NSRect)bounds texture:(GLuint)texture
{
	GLsizei width = bounds.size.width,	height = bounds.size.height;
	
    [pluginFBO pushAttributes:cgl_ctx];
    
    GLuint fboTex = 0;
    glGenTextures(1, &fboTex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, fboTex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    [pluginFBO pushFBO:cgl_ctx];
    [pluginFBO attachFBO:cgl_ctx withTexture:fboTex width:width height:height];
	
	GLuint flybackSize = 40;
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);			
	
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
//	glEnable(GL_TEXTURE_RECTANGLE_EXT);
//	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, texture);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	
	// render our black background , no texturing
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	
	glColor4f(0.0, 0.0, 0.0, 1.0);
	glBegin(GL_QUADS);
	glVertex2f(pixelsWide, pixelsHigh);
	glVertex2f(0, pixelsHigh);
	glVertex2f(0, 0);
	glVertex2f(pixelsWide, 0);
	glEnd();
	
	// render our slightly grey background 
	glColor4f(0.2, 0.2, 0.2, 1.0);
	glBegin(GL_QUADS);
	glVertex2f(5 , 0);
	glVertex2f(35, 0);
	glVertex2f(35, 15);
	glVertex2f(5,  15);
	glEnd();		
	
	glPushMatrix();
	
	// 28 px to the right
	glTranslatef(28.0, 0.0, 0.0); 
	
	glBegin(GL_QUADS);
	glVertex2f(pixelsWide - 35.0, pixelsHigh);	// dont go past our bounds
	glVertex2f(0, pixelsHigh);
	glVertex2f(0, 0);
	glVertex2f(pixelsWide - 35.0, 0);			// dont go past our bounds
	glEnd();
	
	glTranslatef(-38.0, 0.0, 0.0); 
	
	// draw our input video
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, texture);
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	glBegin(GL_QUADS);
	glTexCoord2f(0, 0);
	glVertex2f(flybackSize, flybackSize);
	glTexCoord2f(0, pixelsHigh);
	glVertex2f(flybackSize, height);
	glTexCoord2f(pixelsWide, pixelsHigh);
	glVertex2f(width, height);
	glTexCoord2f(pixelsWide, 0);
	glVertex2f(width, flybackSize);
	glEnd();		
	
	/*		glBegin(GL_QUADS);
	 glTexCoord2f(pixelsWide, pixelsHigh);
	 glVertex2f(width, height);
	 glTexCoord2f(pixelsWide, 0);
	 glVertex2f(width, flybackSize);
	 glTexCoord2f(0, 0);
	 glVertex2f(flybackSize, flybackSize);
	 glTexCoord2f(0, pixelsHigh);
	 glVertex2f(flybackSize, height);
	 glEnd();		
	 */		
	glPopMatrix();	
	
	// draw our ornaments, making the output image look like what is seen on a frame scan.
	
	// vsync ornaments
	GLuint halfWidth = pixelsWide/2.0;		
	
	// no texturing
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	
	glColor4f(0.0, 0.0, 0.0, 1.0);
	glBegin(GL_QUADS);
	glVertex2f(halfWidth + 20 , 0);
	glVertex2f(halfWidth - 20, 0);
	glVertex2f(halfWidth - 20, 13);
	glVertex2f(halfWidth + 20, 13);
	glEnd();	
	
	glBegin(GL_QUADS);
	glVertex2f(pixelsWide - 40 ,  5);
	glVertex2f(halfWidth + 20 ,  5);
	glVertex2f(halfWidth + 20 ,  7);
	glVertex2f(pixelsWide - 40 , 7);
	glEnd();
	
	glBegin(GL_QUADS);
	glVertex2f(halfWidth - 60 , 5);
	glVertex2f(5 ,  5);
	glVertex2f(5 ,  7);
	glVertex2f(halfWidth - 60 , 7);
	glEnd();
	// end vsync ornaments
	
	// color burst
	glColor4f(0.5, 0.5, 0.5, 1.0);
	glBegin(GL_QUADS);
	glVertex2f(15 ,  20);
	glVertex2f(25 ,  20);
	glVertex2f(25 , pixelsHigh);
	glVertex2f(15 , pixelsHigh);
	glEnd();
	
	// testbars
	
	// going to draw 20 segments
	glTranslatef(30, 15 , 0.0);
	
	int i;
	float j = (float) (pixelsWide - 40) / 20.0;
	
	for (i = 0; i < 20 ; ++i)
	{			
		glPushMatrix();
		glColor4f((float)i/20.0, (float)i/20.0, (float)i/20.0, 1.0);
		glBegin(GL_QUADS);
		glVertex2f(0 , 20);
		glVertex2f(j , 20);
		glVertex2f(j , 0);
		glVertex2f(0 , 0);
		glEnd();
		glTranslatef(j, 0, 0);
	}
	
	for (i = 0; i < 20; ++i)
	{
		glPopMatrix();
	}
	
	glTranslatef(0, 26, 0);
	
	// VITC/closed captioning
	j = (float) (pixelsWide - 40) / 30.0;
	float rand;
	
	for (i = 0; i < 30; ++i)
	{
		rand = random() & 01; // random binary
		
		glColor4f(rand,rand, rand, 1.0);
		glPushMatrix();				
		glBegin(GL_QUADS);
		glVertex2f(0 ,  -1);
		glVertex2f(j , -1);
		glVertex2f(j , 0);
		glVertex2f(0 , 0);
		glEnd();
		glTranslatef(j, 0, 0);
		
	}
	
	for (i = 0; i < 30; ++i)
	{
		glPopMatrix();
	}	
	
    [pluginFBO detachFBO:cgl_ctx]; // pops out and resets cached FBO state from above.
    [pluginFBO popFBO:cgl_ctx];
    [pluginFBO popAttributes:cgl_ctx];
	return fboTex;
}
@end