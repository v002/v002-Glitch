//
//  v002BlurPlugIn.h
//  v002Blur
//
//  Created by vade on 7/10/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface v002FBOGlitchPlugIn : QCPlugIn
{
	const GLcharARB  *fragmentShaderSource;			// the GLSL source for our fragment Shader
	const GLcharARB  *vertexShaderSource;			// the GLSL source for our vertex Shader
	GLhandleARB	glslProgramObject;					// the program object
	
	CGColorSpaceRef cspace;
	
	NSMutableArray* fboArray;
	
	NSUInteger currentFBO;
	id<QCPlugInContext> pluginContext;	
}

/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/

@property (assign) double inputWidth;
@property (assign) double inputHeight;
@property (assign) double inputNumberOfFBOs;
@property (assign) BOOL inputNewRandomValues;
@property (assign) NSUInteger inputInternalTypeRGB;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;


@end


