//
//  v002CoreVideoGlitchPlugIn.h
//  v002CoreVideoGlitch
//
//  Created by vade on 8/18/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface v002GlitchFileReaderPlugIn : QCPlugIn
{	
	CVPixelBufferPoolRef	cvBufferPool;
	CVPixelBufferRef		cvImageBuffer;
	
	NSFileHandle * fileHandle;
	NSMutableData* fileData;
	NSNumber* fileDataLength;
	
	NSUInteger width, height, rowBytes;
	
	NSLock* lock;
}

@property (assign) BOOL	inputgrayScale;
//@property (assign) BOOL inputAlphaChannel;
@property (assign) NSString* inputFilePath;
@property double inputFileReadOffset;
@property NSUInteger inputComponentWidthOffset;
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

@interface v002GlitchFileReaderPlugIn (Execution)

- (void) seekToFileOffsetInBackground:(NSNumber*) offset;
- (void) returnDataOnMainThread:(NSData*) data;

@end
