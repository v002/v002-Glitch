//
//  v002CoreVideoGlitchPlugIn.h
//  v002CoreVideoGlitch
//
//  Created by vade on 8/18/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <OpenGL/OpenGL.h>

@interface v002CoreVideoOpenGLGlitchPlugIn : QCPlugIn
{
	CGLContextObj	cvGLContext;
	CGLPixelFormatObj cvPixelFormat;
	
	// PBuffer pool
	CVOpenGLBufferPoolRef	cvBufferPool;
	CVOpenGLBufferRef		cvImageBuffer;

	// texture cache
	CVOpenGLTextureCacheRef cvTextureCache;
	CVOpenGLTextureRef cvTexture;
	
}
@property NSUInteger inputFlushDelay;
@property double inputWidth;
@property double inputHeight;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;

/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/
@end

@interface v002CoreVideoOpenGLGlitchPlugIn (Execution)

- (void) createCVResources;
- (void) destroyCVResources;

@end
