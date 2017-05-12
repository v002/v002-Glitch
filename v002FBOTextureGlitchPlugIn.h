//
//  v002FBOGlitchPlugIn.h
//  v002FBOGlitch
//
//  Created by vade on 6/26/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface v002FBOTextureGlitchPlugIn : QCPlugIn
{
}

/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) BOOL inputNewRandomValues;
@property (assign) NSUInteger inputInternalTypeRGB;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;


@end
