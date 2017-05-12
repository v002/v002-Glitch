//
//  v002AnalogGlitchPlugIn.m
//  v002AnalogGlitch
//
//  Created by vade on 8/21/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002AnalogGlitchPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch Analog"
#define	kQCPlugIn_Description		@"Emulates classic analog video interference, distortion and sync issues"

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

@implementation v002AnalogGlitchPlugIn

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/
@dynamic inputImage, inputDistortionImage, inputBarsAmount, inputDistortion, inputResolution, inputVSYNC, inputHSYNC, outputImage;

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

	if([key isEqualToString:@"inputDistortionImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Distortion Image", QCPortAttributeNameKey, nil];
	}	
	
	if([key isEqualToString:@"inputDistortion"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Distortion Amount", QCPortAttributeNameKey, nil];
	}	
	
	if([key isEqualToString:@"inputBarsAmount"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Distortion Image Mix Amount", QCPortAttributeNameKey, nil];
	}	
	
	if([key isEqualToString:@"inputVSYNC"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Vertical Sync", QCPortAttributeNameKey, nil];
	}	

	if([key isEqualToString:@"inputHSYNC"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Horizontal Sync", QCPortAttributeNameKey, nil];
	}	
	
	if([key isEqualToString:@"inputResolution"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Scan Line Resolution", QCPortAttributeNameKey,
				[NSNumber numberWithInt:1], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:10], QCPortAttributeMaximumValueKey,
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
	return [NSArray arrayWithObjects:@"inputImage", @"inputDistortionImage", @"inputDistortion", @"inputBarsAmount", @"inputVSYNC", @"inputHSYNC", @"inputResolution", nil];
	
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
		
		self.pluginShaderName = @"v002.AnalogGlitch";
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

@implementation v002AnalogGlitchPlugIn (Execution)

//- (BOOL) startExecution:(id<QCPlugInContext>)context
//{
//	// work around lack of GLMacro.h for now
//	CGLContextObj cgl_ctx = [context CGLContextObj];
//	CGLSetCurrentContext(cgl_ctx);
//	
//	// since we are using FBOs we ought to keep track of what was previously bound
//	GLint previousFBO, previousReadFBO, previousDrawFBO;
//	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);	
//	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
//	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
//
//	// shaders
//	if(![self loadShadersFromResource:@"v002.AnalogGlitch"])
//	{
//		NSLog(@"Cannot compile GLSL shader ");
//		return NO;
//	}
//	
//	// build up and destroy an FBO. If it works, we are good to go and dont do any other slow error checking for our main rendering, 
//	// if we cant make the FBO, fail by returning NO.
//	GLuint name;
//	GLenum status;
//	
//	glGenTextures(1, &name);
//	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);
//	glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, 640, 480, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
//	
//	// Create temporary FBO to render in texture 
//	glGenFramebuffersEXT(1, &frameBuffer);
//	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, frameBuffer);
//	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, name, 0);
//	
//	status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
//	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
//	{	
//		NSLog(@"Cannot create FBO");
//		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
//		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
//		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
//		glDeleteFramebuffersEXT(1, &frameBuffer);
//		glDeleteTextures(1, &name);
//		return NO;
//	}	
//	
//	// cleanup
//	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
//	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
//	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
//	glDeleteTextures(1, &name);
//	
//	return YES;
//}
//


- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	 Called by Quartz Composer whenever the plug-in instance needs to execute.
	 Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	 Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	 
	 The OpenGL context for rendering can be accessed and defined for CGL macros using:
	 CGLContextObj cgl_ctx = [context CGLContextObj];
	 */
	
	CGLContextObj cgl_ctx = [context CGLContextObj];
	CGLLockContext(cgl_ctx);
	
	
	id<QCPlugInInputImageSource>   image = self.inputImage;
	id<QCPlugInInputImageSource>   dImage = self.inputDistortionImage;
	NSUInteger width = [image imageBounds].size.width;
	NSUInteger height = [image imageBounds].size.height;
	NSRect bounds = [image imageBounds];
	NSUInteger distortionWidth = [dImage imageBounds].size.width;
	NSUInteger distortionHeight = [dImage imageBounds].size.height;
	
	GLfloat barsamount = self.inputBarsAmount;
	GLfloat distortion = self.inputDistortion;
	GLint resolution = self.inputResolution + 1.0;;
	GLfloat vsync = self.inputVSYNC;
	GLfloat hsync = self.inputHSYNC;
	
    CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];

	if(image &&  [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]] &&
	   dImage && [dImage lockTextureRepresentationWithColorSpace:cspace forBounds:[dImage imageBounds]])
	{	
		
		[image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:NO];
		[dImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1 normalizeCoordinates:NO];
		
		GLuint finalOutput;
		
		// Make sure to flush as we use FBOs and the passed OpenGL context may not have a surface attached
		//finalOutput = renderToFBO(cgl_ctx, frameBuffer, width, height, bounds, [image textureName], [dImage textureName], distortionWidth, distortionHeight, glslProgramObject, barsamount, distortion, resolution, vsync, hsync);
		finalOutput = [self renderToFBO:cgl_ctx width:width height:height bounds:bounds texture:[image textureName] displacementTexture:[dImage textureName]
						distortionWidth:distortionWidth distortionHeight:distortionHeight barsamount:barsamount distortion:distortion resolution:resolution vsync:vsync hsync:hsync];

        id provider = nil;

		if(!finalOutput == 0)
		{

#if __BIG_ENDIAN__
#define v002PlugInPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002PlugInPixelFormat QCPlugInPixelFormatBGRA8
#endif		
            // output our final image as a QCPluginOutputImageProvider using the QCPluginContext convinience method. No need to go through the trouble of making our own conforming object.	
            provider = [context outputImageProviderFromTextureWithPixelFormat:v002PlugInPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:[image textureFlipped] releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:[image shouldColorMatch]];
            
            self.outputImage = provider;
        }
        
        [image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
        [image unlockTextureRepresentation];
        
        [dImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1];
        [dImage unlockTextureRepresentation];

	}
	else
		self.outputImage = nil;
	
	
	CGLUnlockContext(cgl_ctx);	
	return YES;
}


- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh bounds:(NSRect)bounds texture:(GLuint)texture
   displacementTexture:(GLuint)dTexture distortionWidth:(NSUInteger)distortionWidth distortionHeight:(NSUInteger)distortionHeight
			barsamount:(GLfloat)barsamount distortion:(GLfloat)distortion resolution:(GLint)resolution vsync:(GLfloat)vsync hsync:(GLfloat)hsync
{
	GLsizei width = bounds.size.width,	height = bounds.size.height;
	
    [pluginFBO pushAttributes:cgl_ctx];
    
    GLuint fboTex = 0;
    glGenTextures(1, &fboTex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, fboTex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    [pluginFBO pushFBO:cgl_ctx];
    [pluginFBO attachFBO:cgl_ctx withTexture:fboTex width:width height:height];
    
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);			
	
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, texture);
	
	glActiveTexture(GL_TEXTURE1);
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, dTexture);
		
	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	
	
	// bind our shader program
	glUseProgramObjectARB([pluginShader programObject]);
	
	// set program vars
	glUniform1iARB([pluginShader getUniformLocation:"tex0"], 0); // load tex1 sampler to texture unit 0 
	glUniform1iARB([pluginShader getUniformLocation:"tex1"], 1); // load tex1 sampler to texture unit 0 
	glUniform2fARB([pluginShader getUniformLocation:"texdim0"], pixelsWide, pixelsHigh); // load tex1 sampler to texture unit 0 
	//	glUniform2fARB(getUniformLocation(program, "dim2"), distortionWidth, distortionHeight); // load tex1 sampler to texture unit 0 
	
	glUniform1fARB([pluginShader getUniformLocation:"barsamount"], barsamount); // pass in uniforms
	glUniform1fARB([pluginShader getUniformLocation:"distortion"], distortion); // pass in uniforms
	glUniform1iARB([pluginShader getUniformLocation:"resolution"], resolution); // pass in uniforms
	glUniform1fARB([pluginShader getUniformLocation:"vsync"], vsync); // pass in uniforms
	glUniform1fARB([pluginShader getUniformLocation:"hsync"], hsync); // pass in uniforms
	
	
	glBegin(GL_QUADS);
	glTexCoord2f(0, 0);
	glVertex2f(0, 0);
	glTexCoord2f(0, pixelsHigh);
	glVertex2f(0, height);
	glTexCoord2f(pixelsWide, pixelsHigh);
	glVertex2f(width, height);
	glTexCoord2f(pixelsWide, 0);
	glVertex2f(width, 0);
	glEnd();		
	
	// disable shader program
	glUseProgramObjectARB(NULL);
	
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	glActiveTexture(GL_TEXTURE0);
	
	glDisable(GL_TEXTURE_RECTANGLE_EXT);	
	
    [pluginFBO detachFBO:cgl_ctx]; // pops out and resets cached FBO state from above.
    [pluginFBO popFBO:cgl_ctx];
    [pluginFBO popAttributes:cgl_ctx];
    
    glFlushRenderAPPLE();
    
	return fboTex;
}



@end
