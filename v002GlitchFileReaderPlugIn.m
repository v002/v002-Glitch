//
//  v002CoreVideoGlitchPlugIn.m
//  v002CoreVideoGlitch
//
//  Created by vade on 8/18/08.
//  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002GlitchFileReaderPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch File Reader"
#define	kQCPlugIn_Description		@"Generate images by interpreting arbitrary files as uncompressed image data"

static void _BufferReleaseCallback(const void* address, void* info)
{
	free((void*)address);
}

@implementation v002GlitchFileReaderPlugIn

@dynamic outputImage, inputgrayScale, inputFilePath, inputFileReadOffset, inputWidth, inputHeight, inputComponentWidthOffset;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputFileReadOffset"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"File Read Offset", QCPortAttributeNameKey,
				[NSNumber numberWithInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1], QCPortAttributeMaximumValueKey,
				nil];
		
	}
	
	if([key isEqualToString:@"inputWidth"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Width", QCPortAttributeNameKey,
				[NSNumber numberWithInt:1], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:128], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1920], QCPortAttributeMaximumValueKey,
				nil];
	}
	
	if([key isEqualToString:@"inputHeight"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Height", QCPortAttributeNameKey,
				[NSNumber numberWithInt:1], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:128], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1080], QCPortAttributeMaximumValueKey,
				nil];
	}
	
	if([key isEqualToString:@"inputComponentWidthOffset"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Gray Scale Component", QCPortAttributeNameKey,
				[NSNumber numberWithInt:1], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:3], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:3], QCPortAttributeMaximumValueKey,
				nil];
	}
	if([key isEqualToString:@"inputFilePath"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"File Path", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputgrayScale"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Gray Scale", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputAlphaChannel"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Alpha Channel", QCPortAttributeNameKey, nil];
	}
	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputFilePath", @"inputFileReadOffset", @"inputWidth", @"inputHeight", @"inputgrayScale", @"inputComponentWidthOffset", nil];
}


+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{	
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
    self = [super init];
	if(self)
	{
		lock = [[NSLock alloc] init];
		fileData = [[NSMutableData alloc] init];
	}
	return self;
}

- (void) finalize
{
	[super finalize];
}

- (void) dealloc
{
	[lock release];
	[super dealloc];
}

@end

@implementation v002GlitchFileReaderPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	// setup width/height/rowBytes 
	if([self didValueForInputKeyChange:@"inputWidth"] || [self didValueForInputKeyChange:@"inputHeight"] || [self didValueForInputKeyChange:@"inputComponentWidthOffset"] || [self didValueForInputKeyChange:@"inputgrayScale"])
	{
		width = self.inputWidth;
		height = self.inputHeight;
		
		// make sure width/height/rowbytes is multiple of 16 or all hell breaks loose
		if(width % 16)
			width = (width / 16 + 1) * 16;
		
		if(height % 16)
			height = (height / 16 + 1) * 16;
		
		if(self.inputgrayScale)
			rowBytes = width * (uint) (self.inputComponentWidthOffset + 1);
		else
			rowBytes = width * 4; // force 4 channel or we shit ourselves on ARGB
		
		if(rowBytes % 16)
			rowBytes = (rowBytes / 16 + 1) * 16;
		
		// this should solve any issues of resizing..
		[fileData setLength:(rowBytes * height)];
	}
	
	if([self didValueForInputKeyChange:@"inputFilePath"])
	{
		if([[NSFileManager defaultManager] fileExistsAtPath:self.inputFilePath])
		{				
			if(fileHandle != nil)
			{
				[fileHandle release];
			}
			fileHandle = [[NSFileHandle fileHandleForReadingAtPath:self.inputFilePath] retain];

			NSDictionary* fileMetadata = [[NSFileManager defaultManager] attributesOfItemAtPath:self.inputFilePath error:NULL]; 
			fileDataLength = [[fileMetadata valueForKey:@"NSFileSize"] retain]; 
		}
	}
	
	if([self didValueForInputKeyChange:@"inputFileReadOffset"] || [self didValueForInputKeyChange:@"inputWidth"] || [self didValueForInputKeyChange:@"inputHeight"] || [self didValueForInputKeyChange:@"inputComponentWidthOffset"] || [self didValueForInputKeyChange:@"inputgrayScale"])
	{
		if(fileHandle != nil)
		{
			// do we have enough data to fill our buffer?
			if([fileDataLength integerValue] >= (rowBytes * height))
			{
				// we ave to account for the length of the file - the amount we will read...
				NSNumber* fileOffset = [NSNumber numberWithDouble:(self.inputFileReadOffset * ([fileDataLength doubleValue] - (rowBytes * height)))];
			
				// perform file seeking/access/reading in background :)
				[self performSelectorInBackground:@selector(seekToFileOffsetInBackground:) withObject:fileOffset];
			}
			else
				NSLog(@"not enough data in file..");
		}
	}
	
	id provider = nil;
	
	[lock lock];
	// if we have anything to output....
	if([fileData length] > 0)
	{
		// a buffer for our bytes sir.
		NSUInteger bufferLen = [fileData length];
		unsigned char* aBuffer;
		aBuffer = valloc(bufferLen);  // our QC output image provider callback free's this
		[fileData getBytes:aBuffer];
		
		CVReturn error;
		if(self.inputgrayScale)
			error = CVPixelBufferCreateWithBytes(NULL, width, height, 'b16g', aBuffer, rowBytes, NULL, NULL, NULL, &cvImageBuffer);
		else
			error = CVPixelBufferCreateWithBytes(NULL, width, height, k32ARGBPixelFormat, aBuffer, rowBytes, NULL, NULL, NULL, &cvImageBuffer);

	//	k24RGBPixelFormat , b32a
		
		if(error != kCVReturnSuccess)
			NSLog(@"error is: %i", error);
		
		CGLContextObj cgl_ctx = [context CGLContextObj];
		CGLLockContext(cgl_ctx);
				
		if(CVPixelBufferLockBaseAddress(cvImageBuffer,0) == kCVReturnSuccess)
		{
			if(self.inputgrayScale)
			{
				CGColorSpaceRef cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
				provider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatI8 pixelsWide:width pixelsHigh:height baseAddress:CVPixelBufferGetBaseAddress(cvImageBuffer) bytesPerRow:CVPixelBufferGetBytesPerRow(cvImageBuffer) releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:cspace shouldColorMatch:YES];
				CGColorSpaceRelease(cspace);
			}
			else	
				provider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatARGB8 pixelsWide:width pixelsHigh:height baseAddress:CVPixelBufferGetBaseAddress(cvImageBuffer) bytesPerRow:CVPixelBufferGetBytesPerRow(cvImageBuffer) releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
			CVPixelBufferUnlockBaseAddress(cvImageBuffer,0);	
		}
		
		CGLUnlockContext(cgl_ctx);
	}
	[lock unlock];
	
	self.outputImage = provider;
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
}
			 
 - (void) seekToFileOffsetInBackground:(NSNumber*) offset
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[fileHandle seekToFileOffset:[offset unsignedLongLongValue]];
	NSData* someData = [fileHandle readDataOfLength:(rowBytes * height)];	
	[self performSelectorOnMainThread:@selector(returnDataOnMainThread:) withObject:someData waitUntilDone:NO];
	
	[pool drain];
}

- (void) returnDataOnMainThread:(NSData*) data
{	
	// update the contents of fileData - place contents of data into aBuffer
	NSUInteger bufferLen = [data length];
	unsigned char* aBuffer;
	aBuffer = valloc(bufferLen);
	[data getBytes:aBuffer] ;

	NSRange byteRange = {0, bufferLen};

	// copy  aBuffer into fileData 
	[lock lock];
	[fileData replaceBytesInRange:byteRange withBytes:aBuffer];
	[lock unlock];

	// clean up
	free(aBuffer);
}

@end
