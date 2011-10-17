// 
//  KCanvas.m
//  kineto
//
//  Created by Andrea Cremaschi on 07/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "KCanvas.h"
#import "KBO.h"
#import "KCVBufferPool.h"

#import <OpenGL/CGLMacro.h>
#import <QuartzCore/QuartzCore.h>

NSString *CanvasAssetNameDefaultValue = @"Canvas";

@interface KCanvas (PrivateMethods)
- (bool) initOpenGLContextWithError: (NSError **)error 
					   shareContext: (NSOpenGLContext *)shareContext;
- (void) initPBO;
@end


@implementation KCanvas 

@synthesize  height;
@synthesize  width;
@synthesize maxFPS;
//@dynamic cues;
@synthesize canvasType;


- (void) dealloc {
	[_ciContext release];

	[super dealloc];
}


#pragma mark Accessors

- (void)setHeight:(NSNumber *)value 
{
	[self setSize: CGSizeMake( [[self width] floatValue], [value floatValue] )];
}

- (void)setWidth:(NSNumber *)value 
{
	[self setSize: CGSizeMake( [value floatValue], [[self height] floatValue] )];
}

- (CGSize) size	{
		return CGSizeMake( [[self width] floatValue], [[self height] floatValue] );
}

- (void) setSize: (CGSize) newSize	{
    [self willChangeValueForKey:@"height"];
    [self willChangeValueForKey:@"width"];
	isOpenGLContextValid = false;
    
    [height release];
    [width release];
    height = [[NSNumber numberWithFloat: newSize.height] retain];
    width = [[NSNumber numberWithFloat: newSize.width] retain];
	
	[self initPBO];
		
    [self didChangeValueForKey:@"width"];
    [self didChangeValueForKey:@"height"];
	
}

- (void)setCanvasType:(NSNumber *)value 
{
    [self willChangeValueForKey:@"canvasType"];

    [canvasType release];
    canvasType = [value retain];
	
	[self initPBO]; // maybe should init opengl context too TODO!
    [self didChangeValueForKey:@"canvasType"];
}

- (KBO *)bo	{
	if (nil == _pbo) 
		[self initPBO];
	return _pbo;
}

#pragma mark Lazy evaluation
- (void) increaseConsumersCount {
	[self setConsumers_count: [NSNumber numberWithInt: [[self consumers_count] intValue] + 1]]; 
	NSLog (@"%@ cons count++: %i", [self name],  [[self consumers_count] intValue]);
}

- (void) decreaseConsumersCount {
	[self setConsumers_count: [NSNumber numberWithInt: [[self consumers_count] intValue] - 1]];
	NSLog (@"%@ cons count--: %i", [self name],  [[self consumers_count] intValue]);
	if ([[self consumers_count] intValue] <=0) [self releaseOpenGLObjects];
} 

- (bool) wantsToBeDrawn {
	return [self consumers_count] > 0;
}

#pragma mark Constructors

+ (KCanvas *)canvasWithSize: (NSSize)canvasSize{
	KCanvas *newCanvas = [[KCanvas alloc] init];
	
	if (nil != newCanvas) {
		[newCanvas setSize: canvasSize];
	}	
	
	return newCanvas;
	
}

-(id)init
{
    self = [super init];
    if (nil != self)
    {
	
        _openGLContext = nil;
        isOpenGLContextValid = false;
    }
    return self;
}
#pragma mark openGL methods

- (void) initPBO	{
	
	CGLLockContext([_openGLContext CGLContextObj]);
	{
		if (nil !=_pbo) {
			[_pbo release];
			_pbo=nil;
		}
		int canvType = [[self canvasType] intValue];
		
		Class pboClass;
		switch (canvType)	{
			//case K_CANVAS_TYPE_CVSINGLEBUFFER: pboClass = [KCVPBO class]; break;
			case K_CANVAS_TYPE_CVPOOLBUFFER: pboClass = [KCVBufferPool class];break;
//			case K_CANVAS_TYPE_PBO: pboClass = [KPBO class];break;
			//case K_CANVAS_TYPE_FBO: pboClass = [KFBO class]; 
				break;
			default: pboClass = [KCVBufferPool class];break;
		}
		
		_pbo = [[pboClass alloc]  initPBOWithSize: [self size]
									openGLContext: [[self openGLContext] CGLContextObj]];
	}
	CGLUnlockContext([_openGLContext CGLContextObj]);
	
}



- (NSOpenGLPixelFormat *)pixelFormat	{
	NSOpenGLPixelFormatAttribute	attributes[] = {
		//NSOpenGLPFAPixelBuffer,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADepthSize,8,
		(NSOpenGLPixelFormatAttribute) 0
	};
	

	return [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	
}


- (bool) initOpenGLContextWithError: (NSError **)error 
						   shareContext: (NSOpenGLContext *)shareContext {
	
	NSOpenGLPixelFormat *format = [self pixelFormat];
	
	int width = [self.width intValue];
	int height = [self.height intValue];
	
	//Check parameters - Rendering at sizes smaller than 16x16 will likely produce garbage
	if((width < 16) || (height < 16)) {
		//TODO: error management
		return false;
	}

	if (nil != _openGLContext) [_openGLContext release];
	
	// TEMP
	/*NSOpenGLContext* sharedContext = nil;
	if ([[self canvasType] intValue] == K_CANVAS_TYPE_FBO) {
		id parent = [[[self compositing_layers] anyObject] parent] ;
		sharedContext = [parent openGLContext] ;
	}*/
	// TEMP
	//Create the OpenGL context to render with (with color and depth buffers)
	_openGLContext = [[NSOpenGLContext alloc] 
					  initWithFormat:format 
					  shareContext: shareContext];
	
	if(_openGLContext == nil) {
		//TODO: error management
		NSLog(@"Cannot create OpenGL context");
		return false;
	}
	
	CGLContextObj cgl_ctx = [_openGLContext CGLContextObj];
	CGLLockContext( cgl_ctx );	
	{			
		glViewport(0, 0, width, height);
		
		glMatrixMode(GL_MODELVIEW);    // select the modelview matrix
		glLoadIdentity();              // reset it
		
		glMatrixMode(GL_PROJECTION);   // select the projection matrix
		glLoadIdentity();              // reset it
		
		glOrtho(0, width, 0, height, -1.0, 1.0);// define a 2-D orthographic projection matrix
		
	}
	CGLUnlockContext( cgl_ctx );
	
	//[self initPBO];
	
	return true;
	
}

- (NSOpenGLContext *)openGLContext	{
	if (nil==_openGLContext) {
		NSError *error = nil;
		
		NSOpenGLContext *shareContext = nil;
		bool result = [self initOpenGLContextWithError: &error 
											  shareContext: shareContext];
		if (!result)	{
			NSLog(@"Error initalizing openGLContext: %@", [error description]);
			return nil;
		}
	}
	return _openGLContext;
}

- (void) releaseOpenGLObjects	{
		//TODO: destroy openGL thingies
	
}

- (void) flush	{
	
	_lastTimeDrawn = [NSDate date];
	[[self openGLContext] flushBuffer];

}


- (void) drawImage: (CIImage *)image	{	

	[self willChangeValueForKey:@"image"];
	CGLLockContext( [[self openGLContext] CGLContextObj] );
	{
		[[self bo] attachPBO];
		
		[[self ciContext] drawImage: image
							atPoint: CGPointZero
						   fromRect: NSRectToCGRect([image extent])];
		[self flush];

		[[self bo] detachPBO];
	}
	CGLUnlockContext( [[self openGLContext] CGLContextObj] );
	[self didChangeValueForKey:@"image"];

}


- (CIContext *)ciContext	{
	
	if (nil!=_ciContext) return _ciContext;
	
	NSOpenGLContext *openGLContext = [self openGLContext];
	NSOpenGLPixelFormat *pixelFormat = [self pixelFormat];
	
	CGLLockContext([openGLContext CGLContextObj]);
	{
		// create CGColorSpaceRef needed for the contextWithCGLContext method
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); //CGColorSpaceCreateWithName( kCGColorSpaceGenericRGB); // sballa i colori
		
		// create CIContext -- the CIContext object provides an evaluation context for
		// rendering a Core Image image (CIImage) through Quartz 2D or OpenGL
		_ciContext = [[CIContext contextWithCGLContext: [openGLContext CGLContextObj]	// Core Image draws all output into the surface attached to this OpenGL context
										   pixelFormat: [pixelFormat CGLPixelFormatObj]					// must be the same pixel format used to create the cgl context
											colorSpace: colorSpace
											   options: [NSDictionary dictionaryWithObjectsAndKeys:(id)colorSpace, kCIContextOutputColorSpace,	 // dictionary containing color space information
														 (id)colorSpace, kCIContextWorkingColorSpace, nil]] retain];
		
		// release the colorspace we don't need it anymore
		CGColorSpaceRelease(colorSpace);
	}
	CGLUnlockContext([openGLContext CGLContextObj]);

	/*CGLayerRelease(_cgLayer);
	_cgLayer = [_ciContext	createCGLayerWithSize: CGSizeMake([[self width] floatValue], [[self height] floatValue])
												  info: nil] ;*/

	return _ciContext;
}

/*- (CGLayerRef) cgLayer	{		
	if (nil != _cgLayer) return _cgLayer;
	_cgLayer = [[self ciContext]	createCGLayerWithSize: CGSizeMake([[self width] floatValue], [[self height] floatValue])
													  info: nil] ;
	return _cgLayer;
}*/

/*
- (GLuint) textureName	{
	return _textureName;
}*/

- (CIImage *)image	{

	if (nil == _pbo) return [CIImage emptyImage];

	CGLLockContext([_openGLContext CGLContextObj]);
	CIImage *canvasImage = [[_pbo image] retain];
	CGLUnlockContext([_openGLContext CGLContextObj]);

	
	
	return [canvasImage autorelease];

//	return [CIImage imageWithCGLayer: _cgLayer];
	
}
#pragma mark ECNAsset overrides

@end
