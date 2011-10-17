//
//  KCVBufferPool.m
//  kineto
//
//  Created by Andrea Cremaschi on 14/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "KCVBufferPool.h"



@implementation KCVBufferPool

#pragma mark OpenGL specific buffer primitives (were everything happens)

- (bool) _primitiveInitBOWithSize: (CGSize )size 
					openGLContext: (CGLContextObj) cgl_ctx {

	CVReturn		theError;
	
	pboSize = size;
	
	context = cgl_ctx;
	CGLRetainContext(context);
	CGLLockContext( cgl_ctx );
	{
		
		//Create buffer pool
		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		//	[attributes setObject:[NSNumber numberWithUnsignedInt:15] forKey:(NSString*)kCVOpenGLBufferPoolMinimumBufferCountKey];
		//	[attributes setObject:[NSNumber numberWithUnsignedInt:0.3] forKey:(NSString*)kCVOpenGLBufferPoolMaximumBufferAgeKey];
		[attributes setValue:[NSNumber numberWithInt:size.width] forKey:(NSString*)kCVOpenGLBufferWidth];
		[attributes setValue:[NSNumber numberWithInt:size.height] forKey:(NSString*)kCVOpenGLBufferHeight];
		
		theError = CVOpenGLBufferPoolCreate(kCFAllocatorDefault, 
											NULL, 
											(CFDictionaryRef)attributes, 
											&_bufferPool);
		if(theError) {
			NSLog(@"CVPixelBufferPoolCreate() failed with error %i", theError);
			return false;
		}
		CVOpenGLBufferPoolRetain(_bufferPool);
	}
	CGLUnlockContext( cgl_ctx );

	// create coreVideo openGL pixelBuffer
	return ( CVOpenGLBufferCreate( 0,
								  size.width, size.height,	// Whatever dimensions you require 
								  0, &_CVPixelBuffer
								  )== kCVReturnSuccess);
}


- (bool) _primitiveAttachBO: (CGLContextObj) cgl_ctx {
	
	//invalidate cached image
	if (nil != _cachedImage) {
		[_cachedImage release];
		_cachedImage = nil;
	}
	
	//release old CV pixel buffer
	CVPixelBufferRelease(_CVPixelBuffer);
	
	//Get pixel buffer from pool
	CVReturn theError = CVOpenGLBufferPoolCreateOpenGLBuffer (kCFAllocatorDefault, 
															  _bufferPool,
															  &_CVPixelBuffer);
	if(theError) {
		NSLog(@"CVOpenGLBufferPoolCreateOpenGLBuffer() failed with error %i", theError);
		return false;
	}	
	
	theError = CVOpenGLBufferAttach(_CVPixelBuffer, 
									context, 
									0, 0, 
									0);
	if (theError)	{
		NSLog(@"CVOpenGLBufferAttach() failed with error %i", theError);
		return false;
	}
	
	
	return true;
}


- (bool) _primitiveDetachBO: (CGLContextObj) cgl_ctx {

	// i'm not sure how to detach cv opengl pixel buffer..???
	/*int result = CVOpenGLBufferAttach(NULL, 
									  cgl_ctx, 
									  0, 0, 0);
	if (result != kCVReturnSuccess) NSLog(@"CoreVideo error: %i", result);
	return (result == kCVReturnSuccess);*/
	return true;
}



#pragma mark Initialization

- (void)cleanupGL
{
	CGLContextObj cgl_ctx = context;
	
	CGLLockContext(cgl_ctx);
	
	[_cachedImage release];
	CVOpenGLBufferRelease(_CVPixelBuffer );
	CVOpenGLBufferPoolRelease(_bufferPool);	
	
	CGLUnlockContext(cgl_ctx);	
	
	CGLReleaseContext(context);
}


- (CIImage *)image	{

	// NB: caching the image, it means that KCVBufferPools can be written only ONCE!! readonly
	if (nil!=_cachedImage) 
		return _cachedImage;

	CGLLockContext( context );	
		_cachedImage = [[CIImage imageWithCVImageBuffer: _CVPixelBuffer] retain]; 
	CGLUnlockContext( context );
	return _cachedImage;
	
}

@end
