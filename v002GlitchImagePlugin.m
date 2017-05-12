//
//  v002GlitchImagePlugin.m
//  v002Glitch
//
//  Created by vade on 12/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


#import "v002GlitchImagePlugin.h"

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#define	kQCPlugIn_Name				@"v002 Glitch Jpeg"
#define	kQCPlugIn_Description		@"Jpeg compression artifacts and glitches on arbitrary input images."

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

static void _BufferReleaseCallback(const void* address, void* info)
{
	// our outputContext setter handles this. yea. I know...
}

@implementation v002GlitchImagePlugin

//@synthesize readbackTextureData0;
//@synthesize readbackTextureData1;
@synthesize uploadTextureData;

@synthesize glitchQuality;
@synthesize glitchOffset;
@synthesize glitchLength;
@synthesize recalulateGlitch;
@synthesize needNewJpeg;


@dynamic inputContext;
@dynamic outputContext;
//----//

@dynamic outputImage;
@dynamic inputImage;
@dynamic inputGlitchQuality;
@dynamic inputGlitchOffset;
@dynamic inputGlitchLength;
@dynamic inputRecalulateGlitch;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	
/*	if([key isEqualToString:@"inputGlitchFormat"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Format", QCPortAttributeNameKey,
				[NSArray arrayWithObjects:@"Jpeg", @"Jpeg 2000", @"TIFF", @"PICT", @"GIF", @"PNG", @"QT Image", @"ICNS", @"BMP", @"ICO", nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:9], QCPortAttributeMaximumValueKey,
				nil];
	}
*/
	
	if([key isEqualToString:@"inputGlitchQuality"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Glitch Quality", QCPortAttributeNameKey,
				[NSNumber numberWithInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithInt:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithInt:1], QCPortAttributeMaximumValueKey,
				nil];
	}
	
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
	
	
	if([key isEqualToString:@"inputRecalulateGlitch"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Re-Glitch", QCPortAttributeNameKey, nil];
	}
	
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

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputImage", @"inputGlitchQuality", @"inputGlitchOffset", @"inputGlitchLength", @"inputRecalculateGlitch", nil];
}


+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	// TODO: is this right?
	return kQCPlugInTimeModeNone;
}

- (id) init
{
    self = [super init];
	if(self)
	{
		inputLock = [[NSRecursiveLock alloc] init];
		outputLock = [[NSRecursiveLock alloc] init];
		self.inputContext = NULL;
		self.outputContext = NULL;

		self.needNewJpeg = YES;
		
		// init our mutable data to hold a generic image size for now
		self.uploadTextureData = [NSMutableData dataWithLength:640 * 480 * 4];

		// handle all colors in generic RGB :)
		cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	}
	
	return self;
}

- (void) finalize
{
	[super finalize];
}

- (void) dealloc
{
	// we def want to assert our thread is finished before remove shared resources...
	while(![glitchThread isFinished])
		[glitchThread cancel];
	
	self.inputContext = NULL;
	self.outputContext = NULL;
	self.uploadTextureData = nil;
	
	CGColorSpaceRelease(cspace);
	
	[inputLock release];
	[outputLock release];
	[super dealloc];
}


- (void) setInputContext:(CGContextRef)context
{
	[inputLock lock];
	{
		CGContextRelease(inputContext);
		inputContext = context;
	}
	[inputLock unlock];
}

- (CGContextRef) inputContext
{
	return inputContext;
}


- (void) setOutputContext:(CGContextRef)context
{
	[outputLock lock];
	{
		CGContextRelease(outputContext);
		outputContext = context;
	}
	[outputLock unlock];
}

- (CGContextRef) outputContext
{
	return outputContext;
}

@end

@implementation v002GlitchImagePlugin (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	// reset our cached image size so we rebuild our GPU side resources
	cachedImageBoundsRect = NSZeroRect;
	
	// init the background Jpeg encoding/glitching/decoding thread
	glitchThread = [[NSThread alloc] initWithTarget:self
											  selector:@selector(glitchImageInBackground)
												object:nil];
	[glitchThread start];
	
	downloader = [[v002TextureDownloader alloc] initWithContext:[context CGLContextObj] mode:v002TextureDownloaderDoubleBuffered];
	
	return YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{	
	// set keys appropriately for background thread.
	if([self didValueForInputKeyChange:@"inputGlitchQuality"])
		[self setGlitchQuality:[NSNumber numberWithFloat:self.inputGlitchQuality]];
	
	if([self didValueForInputKeyChange:@"inputGlitchOffset"])
	{
		[self setGlitchOffset:[NSNumber numberWithFloat:self.inputGlitchOffset]];
		updateGlitch = YES;
	}
	if([self didValueForInputKeyChange:@"inputGlitchLength"])
	{
		[self setGlitchLength:[NSNumber numberWithFloat:self.inputGlitchLength]];
		updateGlitch = YES;
	}
	
	if([self didValueForInputKeyChange:@"inputRecalulateGlitch"])
		[self setRecalulateGlitch:[NSNumber numberWithBool:self.inputRecalulateGlitch]];
	
	CGLContextObj cgl_ctx = [context CGLContextObj];

	// rebuild GL textures, client side memory etc for new image bounds
	if([self didValueForInputKeyChange:@"inputImage"] && self.inputImage)
	{
		if(!NSEqualRects(cachedImageBoundsRect, [self.inputImage imageBounds]))
		{
			cachedImageBoundsRect = [self.inputImage imageBounds];			
			[self destroyGLResources:cgl_ctx];
			[self buildGLResources:cgl_ctx withBounds:cachedImageBoundsRect];
		}
	}

	// As per Toms optimization, test first, read later.
	if([downloader hasNewBuffer])
	{
		[downloader lockBuffer];
		self.inputContext = CGBitmapContextCreate((void*)[downloader bufferBaseAddress], [downloader bufferWidth], [downloader bufferHeight], 8, [downloader bufferBytesPerRow] , cspace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
		[downloader unlockBuffer];
	}	
	
	if(self.inputImage && [self.inputImage lockTextureRepresentationWithColorSpace:cspace forBounds:[self.inputImage imageBounds]])
	{
		[self.inputImage bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		
		// readback.
		[downloader readFromTexture:[self.inputImage textureName] target:[self.inputImage textureTarget] imageWidth:[self.inputImage imageBounds].size.width imageHeight:[self.inputImage imageBounds].size.height textureWidth:[self.inputImage imageBounds].size.width textureHeight:[self.inputImage imageBounds].size.height pixelFormat:v002TextureDownloaderPixelFormatNative32 requestedBytesPerRow:4 * [self.inputImage imageBounds].size.width atTime:time];

		[self.inputImage unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
		[self.inputImage unlockTextureRepresentation];
	}
			
	// stage 3 - provide a new image from our optimized texture submit as a QC image Provider

	[outputLock lock];
	if(self.outputContext != NULL && !self.needNewJpeg)
	{
		id newProvider = nil;

		glPushAttrib(GL_ALL_ATTRIB_BITS);
		
		GLuint uploadTexture;
		glGenTextures(1, &uploadTexture);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, uploadTexture);		

		glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, cachedImageBoundsRect.size.width, cachedImageBoundsRect.size.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, (void*)[uploadTextureData bytes]);
		
		glPopAttrib();
		
		newProvider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:cachedImageBoundsRect.size.width pixelsHigh:cachedImageBoundsRect.size.height name:uploadTexture flipped:YES releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
		self.outputImage = newProvider;

		self.needNewJpeg = YES;
	}
	[outputLock unlock];
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{	
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	cachedImageBoundsRect = NSZeroRect;

	[glitchThread cancel];
	[glitchThread release];
	glitchThread = nil;

	CGLContextObj cgl_ctx = [context CGLContextObj];
	CGLLockContext(cgl_ctx);
	[self destroyGLResources:cgl_ctx];
	CGLUnlockContext(cgl_ctx);
	cachedImageBoundsRect = NSZeroRect;
}

																																						   
#pragma mark GL Resource Creation
- (BOOL) buildGLResources:(CGLContextObj)cgl_ctx withBounds:(NSRect)bounds
{
	bufferRowBytes = ((unsigned)cachedImageBoundsRect.size.width * 4 + 0xFF) & ~0xFF; // 256 alignment (from RTFM_FTW - he says this is better)
	[uploadTextureData setLength:bufferRowBytes * cachedImageBoundsRect.size.height];	
	self.outputContext = CGBitmapContextCreate((void*)[uploadTextureData bytes], cachedImageBoundsRect.size.width, cachedImageBoundsRect.size.height, 8, bufferRowBytes, cspace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
	return YES;
}

- (void) destroyGLResources:(CGLContextObj)cgl_ctx
{
	
}

#pragma mark Threading code

/*******
 
 Todo : this probably needs a provider queue and a consumer queue, with buffered image encoding. 
 Not sure how much we are 'waiting' for encoded jpegs. Might make more sense to have some ready to go..

*******/

- (void) glitchImageInBackground
{	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	// this is our interim datastore for the compressed Jpeg.
	// its only ever in the background thread, so we dont need it anywhere else.
	UInt8 * glitchBuffer = NULL;

	while(![[NSThread currentThread] isCancelled])
	{
		if(self.inputContext && self.needNewJpeg)
		{
			//[inputLock lock];
			if([inputLock tryLock])
			{				
				// create an image from our input context
				// TODO: this operation does a copy. fix it!
				
				CGImageRef originalImageRef = CGBitmapContextCreateImage(self.inputContext);
				[inputLock unlock];

				// create an image data destination and add our image to it.
				
				// we need to recreate this every frame otherwise we will end up changing the  
				// size of the jpeg buffer to the largest size for the length of the plugin
				// due to replaceBytes:inRange:  and our offset/length params will act weird
				
				NSMutableData* fileData = [[NSMutableData alloc] init];
				CGImageDestinationRef originalImageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)fileData, kUTTypeJPEG, 1, NULL);
				
				// compression quality
				NSDictionary* compressionDict = [NSDictionary dictionaryWithObjectsAndKeys:self.glitchQuality, (NSString*)kCGImageDestinationLossyCompressionQuality,
												 CGColorGetConstantColor(kCGColorBlack), kCGImageDestinationBackgroundColor, nil];
							
				CGImageDestinationAddImage(originalImageDestination, originalImageRef, (CFDictionaryRef)compressionDict);
				
				// commit our image, it is now saved, and encoded into our originalFileData in the encoding we chose.
				if(CGImageDestinationFinalize(originalImageDestination))
				{
					// clean up so far
					CGImageRelease(originalImageRef);
					//CGContextRelease(originalContext);
					CFRelease(originalImageDestination);
					
					// Glitch our data
					NSUInteger bufferLen = [fileData length];
					
					// TODO: range checking argh.
					NSRange byteRange = {[self.glitchOffset floatValue] * bufferLen, [self.glitchLength floatValue] * ((1.0 - [self.glitchOffset floatValue]) * bufferLen)};
					
					if((glitchBuffer == NULL) || [self.recalulateGlitch boolValue] || updateGlitch)
					{	
						if(glitchBuffer != NULL)
							free(glitchBuffer);
						
						glitchBuffer = valloc(byteRange.length);
						
						// set memory values to random for now
						for(int i = 0; i < byteRange.length; i++)
						{
							//if((i == 0) || (i == byteRange.length - 1 ))
								*(glitchBuffer + i) = (*((UInt8*)[fileData bytes] + byteRange.location + i) * (random() % 255) % 255);
						}
						updateGlitch = NO;				 
					}	
					
					// copy  aBuffer into fileData 
					[fileData replaceBytesInRange:byteRange withBytes:glitchBuffer];
					
					//NSLog(@"fileData after glitch length is : %u", [fileData length]);
					
					// try and make an image with our glitched file data.
					CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef) fileData, NULL);					
					
					if(source != NULL)
					{
						CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);						
						CFRelease(source);
						
						if(image != NULL)
						{	
							if(uploadTextureData != nil)
							{
								if([outputLock tryLock])
								{
									if(self.outputContext != NULL)
									{
										CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
										CGContextClearRect(self.outputContext, bounds);
										CGContextDrawImage(self.outputContext, bounds, image);
																							}
									[outputLock unlock];
								}
								
							}// baseAddres
							CGImageRelease(image);
						} // image
					} // source
					
					[fileData release];
				} // destination finalize
				else
				{
					[fileData release];
					CGImageRelease(originalImageRef);
					//CGContextRelease(originalContext);
					CFRelease(originalImageDestination);
				}
			} // tryLock
		}
		
		self.needNewJpeg = NO; // This also gives us a win CPU wise.
		
		// sleep the thread? TODO: this seems amazingly hacky, but saves non trivial amount of CPU
		[NSThread sleepForTimeInterval:1.0/60.0]; 
		
	} // end while
	
	// cleanup jpeg intermediate storage.
	if(glitchBuffer)
		free(glitchBuffer);
	
	[pool drain];
	
	NSLog(@"SHUTDOWN GLITCH THREAD");
	//return YES;
}


@end
