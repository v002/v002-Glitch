//
//  v002GlitchImageReader.h
//  v002Glitch
//
//  Created by vade on 12/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>


@interface v002GlitchImageReaderPlugIn : QCPlugIn
{	
	NSMutableData* originalFileData;	
	NSMutableData* fileData;
		
	NSLock* lock;
	
	id cachedProvider;
	BOOL makeNewProvider;
}

@property (readwrite, retain) NSMutableData* originalFileData;	
@property (readwrite, retain) NSMutableData* fileData;	


@property (assign) NSString* inputFilePath;
@property double inputGlitchOffset;
@property double inputGlitchLength;
@property BOOL inputReGlitch;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;
@end

/* do we need? :X
@interface v002GlitchImageReaderPlugIn (Execution)

- (void) seekToFileOffsetInBackground:(NSNumber*) offset;
- (void) returnDataOnMainThread:(NSData*) data;

@end
*/