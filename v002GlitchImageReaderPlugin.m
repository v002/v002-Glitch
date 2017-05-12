//
//  v002GlitchImageReader.m
//  v002Glitch
//
//  Created by vade on 12/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "v002GlitchImageReaderPlugin.h"


/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002GlitchImageReaderPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Glitch Image Reader"
#define	kQCPlugIn_Description		@""



static void _BufferReleaseCallback(const void* address, void* info)
{
	// we dont free, because we want to keep the old data around should it not be updated...
	free((void*)address);
}

@implementation v002GlitchImageReaderPlugIn

@synthesize fileData, originalFileData;

@dynamic outputImage;
@dynamic inputFilePath;
@dynamic inputGlitchOffset;
@dynamic inputGlitchLength;
@dynamic inputReGlitch;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputGlitchOffset"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Glitch Offset", QCPortAttributeNameKey,
				[NSNumber numberWithInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1], QCPortAttributeMaximumValueKey,
				nil];
	}

	if([key isEqualToString:@"inputGlitchLength"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Glitch Length", QCPortAttributeNameKey,
				[NSNumber numberWithInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1], QCPortAttributeMaximumValueKey,
				nil];
	}
	
	
	if([key isEqualToString:@"inputFilePath"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"File Path", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputReGlitch"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Re-Glitch", QCPortAttributeNameKey, nil];
	}
	
	
	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputFilePath", @"inputGlitchOffset", nil];
}


+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	// TODO: is this right?
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
	if(self = [super init])
	{
		lock = [[NSLock alloc] init];
		fileData = [[NSMutableData alloc] init];
		makeNewProvider = TRUE;
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

@implementation v002GlitchImageReaderPlugIn (Execution)

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
	if([self didValueForInputKeyChange:@"inputFilePath"])
	{
		if([[NSFileManager defaultManager] fileExistsAtPath:self.inputFilePath])
		{
			[self setOriginalFileData:[[NSMutableData alloc] initWithContentsOfFile:self.inputFilePath]];
			[self setFileData:[[NSMutableData alloc] initWithBytes:[originalFileData bytes] length:[originalFileData length]]];
		}
		
		makeNewProvider = TRUE;
	}
	
	// now that we have the data, lets fuck with it
	if([self didValueForInputKeyChange:@"inputGlitchOffset"] || [self didValueForInputKeyChange:@"inputGlitchLength"])
	{		
		NSUInteger bufferLen = [originalFileData length];
				
		// TODO: range checking argh.
		NSRange byteRange = {self.inputGlitchOffset * bufferLen,  self.inputGlitchLength * bufferLen};

		unsigned char* glitchBuffer;
		NSUInteger glitchLength = byteRange.length;
		glitchBuffer = valloc(glitchLength);

		// set memory values to random for now
		for(int i = 0; i < glitchLength; i++)
		{
			*(glitchBuffer + i) = random() % 255;
		}
		
		if(!self.inputReGlitch)
		{
			// if we do a new glitch, replace with the original bytes
			NSRange originalRange = {0, [originalFileData length]};
			[fileData replaceBytesInRange:originalRange withBytes:[originalFileData bytes]];
		}
		
		// copy  aBuffer into fileData 
		[fileData replaceBytesInRange:byteRange withBytes:glitchBuffer];
		
		// clean up
		free(glitchBuffer);
		
		makeNewProvider = TRUE;
	}
	
	// create our image from our image data, from fastimage
	if(fileData != nil && makeNewProvider)
	{
		// try and make an image with our glitched file data.
		CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef) fileData, NULL);
		if(source == NULL)
			return NO;
		
		CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
		CFRelease(source);
		if(image == NULL)
		{
			CGImageRelease(image);
			return NO;
		}	
		size_t rowBytes = CGImageGetWidth(image) * 4;
		if(rowBytes % 16)
			rowBytes = ((rowBytes / 16) + 1) * 16;
		
		void* baseAddress = valloc(CGImageGetHeight(image) * rowBytes);
		
		if(baseAddress == NULL)
		{
			CGImageRelease(image);
			return NO;
		}
		
		// Create CGContext and draw image into it
		CGContextRef bitmapContext = CGBitmapContextCreate(baseAddress, CGImageGetWidth(image), CGImageGetHeight(image), 8, rowBytes, [context colorSpace], kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
		if(bitmapContext == NULL)
		{
			free(baseAddress);
			CGImageRelease(image);
			return NO;
		}
		
		CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
		CGContextClearRect(bitmapContext, bounds);
		CGContextDrawImage(bitmapContext, bounds, image);
		
		
		// Create image provider from backing
#if __BIG_ENDIAN__
		cachedProvider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatARGB8 pixelsWide:CGImageGetWidth(image) pixelsHigh:CGImageGetHeight(image) baseAddress:baseAddress bytesPerRow:rowBytes releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
#else
		cachedProvider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:CGImageGetWidth(image) pixelsHigh:CGImageGetHeight(image) baseAddress:baseAddress bytesPerRow:rowBytes releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
#endif
		
		// We don't need the image and context anymore
		CGImageRelease(image);
		CGContextRelease(bitmapContext);
		
		[cachedProvider retain];
		
		makeNewProvider = FALSE;
	}
			
	self.outputImage = cachedProvider;
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{	
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	[originalFileData release];
	[fileData release];
}

/*
- (void) seekToFileOffsetInBackground:(NSNumber*) offset
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[fileHandle seekToFileOffset:[offset unsignedLongLongValue]];
	NSData* someData = [fileHandle readDataOfLength:(rowBytes * height)];	
	[self performSelectorOnMainThread:@selector(returnDataOnMainThread:) withObject:someData waitUntilDone:NO];
	
	[pool release];
}

- (void) returnDataOnMainThread:(NSData*) data
{	
	// update the contents of fileData - place contents of data into aBuffer
	NSUInteger bufferLen = [data length];
	unsigned char* aBuffer;
	aBuffer = malloc(bufferLen);
	[data getBytes:aBuffer] ;
	
	NSRange byteRange = {0, bufferLen};
	
	// copy  aBuffer into fileData 
	[lock lock];
	[fileData replaceBytesInRange:byteRange withBytes:aBuffer];
	[lock unlock];
	
	// clean up
	free(aBuffer);
}
*/

@end
