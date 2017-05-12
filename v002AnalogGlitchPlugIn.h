//
//  v002AnalogGlitchPlugIn.h
//  v002AnalogGlitch
//
//  Created by vade on 8/21/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "v002MasterPluginInterface.h"

@interface v002AnalogGlitchPlugIn : v002MasterPluginInterface
{
}

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) id<QCPlugInInputImageSource> inputDistortionImage;
@property (assign) double inputBarsAmount;
@property (assign) double inputDistortion;
@property (assign) NSUInteger inputResolution;
@property (assign) double inputVSYNC;
@property (assign) double inputHSYNC;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;


@end


@interface v002AnalogGlitchPlugIn (Execution)
- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh bounds:(NSRect)bounds texture:(GLuint)texture
   displacementTexture:(GLuint)dTexture distortionWidth:(NSUInteger)distortionWidth distortionHeight:(NSUInteger)distortionHeight
			barsamount:(GLfloat)barsamount distortion:(GLfloat)distortion resolution:(GLint)resolution vsync:(GLfloat)vsync hsync:(GLfloat)hsync;


//GLuint dTexture, NSUInteger distortionWidth, NSUInteger distortionHeight ,  GLhandleARB program, GLfloat barsamount, GLfloat distortion, GLint resolution, GLfloat vsync, GLfloat hsync;
@end
