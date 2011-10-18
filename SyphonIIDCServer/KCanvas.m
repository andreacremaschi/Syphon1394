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
@synthesize sharedContext;
@synthesize pixelFormat;
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
	//isOpenGLContextValid = false;
    
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


-(GLuint )textureName
{
    return _texture;
}

#pragma mark Constructors

+ (KCanvas *)canvasWithSize: (NSSize)canvasSize withOpenGLContext: (NSOpenGLContext*)context;
{
	KCanvas *newCanvas = [[KCanvas alloc] initWithOpenGLContext: context];
	
	if (nil != newCanvas) {
		[newCanvas setSize: canvasSize];
	}	
	
	return newCanvas;
	
}

+ (KCanvas *)canvasWithOpenGLContext: (NSOpenGLContext*)context;
{
	KCanvas *newCanvas = [[KCanvas alloc] initWithOpenGLContext: context];
	
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

-(id)initWithOpenGLContext:(NSOpenGLContext *)context
{
    self = [super init];
    if (nil != self)
    {
        
        _openGLContext = context;        isOpenGLContextValid = true;
    }
    return self;
}



#pragma mark openGL methods

- (void) initPBO	{
	CGLContextObj cgl_ctx = _openGLContext.CGLContextObj; 
	CGLLockContext(cgl_ctx);
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
		
		_pbo = [[pboClass alloc]  initPBOWithSize: self.size
									openGLContext: self.openGLContext.CGLContextObj];
        

	}
	CGLUnlockContext(cgl_ctx);
	
}

- (NSOpenGLContext *)openGLContext	{
	if (nil==_openGLContext) {
		NSError *error = nil;
		
		bool result = [self initOpenGLContextWithError: &error 
											  shareContext: sharedContext];
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
