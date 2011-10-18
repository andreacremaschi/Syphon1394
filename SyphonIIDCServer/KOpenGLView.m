//
//  KOpenGLView.m
//  kineto
//
//  Created by Andrea Cremaschi on 30/06/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "KOpenGLView.h"
#import <OpenGL/CGLMacro.h>
#import <QuartzCore/QuartzCore.h>

#import "TFThreadMessagingQueue.h"

#define RENDER_THREAD_PRIORITY	(1)

@interface KOpenGLView (PrivateMethods)
- (void) cleanUp;
-(void) renderImage: (CIImage *)image;
@end

@implementation KOpenGLView
@synthesize imageToShow;
@synthesize pixelAspectRatio;
@synthesize identifier;

#pragma mark -
#pragma mark Initialization

- (void) dealloc {

	
	needsToFlush = false;
	
	[self cleanUp];  
	
	[lock release];
	[imageToShow release];
	[pixelAspectRatio release];
	[identifier release];
	
	[super dealloc];
	
}



// it is very important that we clean up the rendering
// objects before the view is disposed, remember that with the
// display link running you're applications render callback may be
// called at any time including when the application is quitting or the
// view is being disposed, additionally you need to make sure you're not
// consuming OpenGL resources or leaking textures -- this clean up routine
// makes sure to stop and release everything
-(void)cleanUp
{    	

    // release the Core Image Context
    if (_ciContext) {
    	[_ciContext release];
        _ciContext = nil;
    }

}


#pragma mark Accessors


- (CIContext *)ciContext {
    if (nil == _ciContext) {
        // create CGColorSpaceRef needed for the contextWithCGLContext method
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        // create CIContext -- the CIContext object provides an evaluation context for
        // rendering a Core Image image (CIImage) through Quartz 2D or OpenGL
        CGLContextObj contextObj = self.openGLContext.CGLContextObj;
        CGLPixelFormatObj pixelFormatObj = self.pixelFormat.CGLPixelFormatObj;

/*        _ciContext = [CIContext contextWithCGLContext:contextObj 
                                          pixelFormat:nil 
                                           colorSpace:NULL 
                                              options:nil];
*/                               
        _ciContext = [[CIContext contextWithCGLContext: contextObj		// Core Image draws all output into the surface attached to this OpenGL context
                                           pixelFormat: pixelFormatObj		// must be the same pixel format used to create the cgl context
                                            colorSpace: colorSpace
                                               options: nil] retain];
        
        // release the colorspace we don't need it anymore
       CGColorSpaceRelease(colorSpace);
    }
    return _ciContext;
    
}

- (void) setImageToShow:(CIImage *) newImage {
	
	@synchronized (self)	{
        CGLLockContext(self.openGLContext.CGLContextObj);
        [newImage retain];
		[self renderImage: newImage];
        [newImage release];
        CGLUnlockContext(self.openGLContext.CGLContextObj);
        /*		if ([self isProcessing])	{
			[_renderingQueue enqueue: newImage];
		}*/
	}
	[self 	setNeedsDisplay: YES];
	
}

#pragma mark -
#pragma mark Drawing

// This is the renderer output callback function
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
    
	return [(KOpenGLView*)displayLinkContext renderTime:outputTime];
}
	
	
// draw
- (void)drawRect:(NSRect)rect {

	if (!needsToFlush) return;

		CGLLockContext ( [[self openGLContext] CGLContextObj] );
		{
			needsToFlush = NO;
			
			//[self renderImage];
			[[self openGLContext] flushBuffer];
			
			
		}		
		CGLUnlockContext ( [[self openGLContext] CGLContextObj] );	
	
}
 
-(void) renderImage: (CIImage *)image	{

	
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	CIImage *retainedImage = image;
	
	if (nil==  image) {
		// Add your drawing codes here
		
		CGLLockContext ( cgl_ctx );
		{
			// clear to black if nothing else
			glClearColor(0, 0, 0, 0);
			glClear(GL_COLOR_BUFFER_BIT);
			
			//glFlush();
		}
		CGLUnlockContext ( cgl_ctx );
        
		return;
	}		
		
	// preserve the correct camera aspect ratio
	float videoPixelAspectRatio = pixelAspectRatio == nil? 1 : [pixelAspectRatio floatValue];
	float paneAspectRatio = [self bounds].size.width / [self bounds].size.height ;
	NSRect destRect = NSMakeRect([retainedImage extent].origin.x, 
								 [retainedImage extent].origin.y, 
								 [retainedImage extent].size.width, 
								 [retainedImage extent].size.height);
	
	float width, height, topx, topy;
	float aspectRatio = destRect.size.width / destRect.size.height * videoPixelAspectRatio;
	if (paneAspectRatio > aspectRatio ) {
		
		// width > height
		height = [self bounds].size.height;
		width = [self bounds].size.height * aspectRatio;
		
	} else {
		
		// height > width
		width = [self bounds].size.width;
		height = [self bounds].size.width / aspectRatio;
		
	}

/*	float frameScaleFactor = 0.96; //margine dx e sx tra immagine e bordo box
	width = width * frameScaleFactor;
	height = height * frameScaleFactor;
	topx = width * (1 - frameScaleFactor )/ 2 + ([self bounds].size.width - width) /2;
	topy = height * (1 - frameScaleFactor ) / 2 + ([self bounds].size.height - height) / 2;*/
	
	topx =  ([self bounds].size.width - width) /2;
	topy =  ([self bounds].size.height - height) / 2;

	CGLLockContext ( cgl_ctx );
	
	{
        
        
		// clear to black if nothing else
		glClearColor(1, 0, 0, 0);
		glClear(GL_COLOR_BUFFER_BIT);
		@try {
            CIContext *ciContext = self.ciContext;
			[ciContext drawImage: retainedImage
								 inRect: CGRectMake(topx, topy, width, height)
							   fromRect: [retainedImage extent]];
		}
		@catch (NSError *error) {
			NSLog(@"%@", error);
		}
        glFlush();

	}
	CGLUnlockContext ( cgl_ctx );	
	needsToFlush = YES;

	
}



- (CVReturn)renderTime:(const CVTimeStamp *)timeStamp
{
    CVReturn rv = kCVReturnError;
    NSAutoreleasePool *pool;
    CFDataRef movieTimeData;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    /*if([self getFrameForTime:timeStamp]) {
        [self drawRect:NSZeroRect];     // refresh the whole view
        rv = kCVReturnSuccess;
    } else {
        rv = kCVReturnError;
    }*/
	
//	[self renderImage];
	
	if ( needsToFlush) 		{
		CGLLockContext ( [[self openGLContext] CGLContextObj] );
		[[self openGLContext] flushBuffer];
		CGLUnlockContext ( [[self openGLContext] CGLContextObj] );
		needsToFlush = NO;
	}
	
	
    
    [pool release];
    
    return rv;
}


#pragma mark NSOpenGLView methods override

- (void)update
{
    CGLLockContext ( [[self openGLContext] CGLContextObj] );
	[super update];
    CGLUnlockContext ( [[self openGLContext] CGLContextObj] );
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat {
	
	NSOpenGLPixelFormatAttribute attr[] = 
	{ NSOpenGLPFADoubleBuffer, 
	//	NSOpenGLPFAPixelBuffer,
	 // NSOpenGLPFAAccelerated,
	//	NSOpenGLPFANoRecovery, //not compatible with SyphonImage openGL renderer
	//  NSOpenGLPFAColorSize, 32, 
//	  NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 32, 
		0};
	
	return  [[[NSOpenGLPixelFormat alloc] initWithAttributes:attr] autorelease];
	
}

- (void)prepareOpenGL {
	
	_ciContext=nil;
	lock = [[NSRecursiveLock alloc] init];
	
	@synchronized (self) {
	// Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
	
	//create cicontext if needed
	// create a Core Image Context -- in Core Image, images are evaluated to a Core Image context
    // which represents a drawing destination. Core Image contexts are created per window rather than
    // one per view and can be created from an OpenGL graphics context
	

		
	
    // Create a display link capable of being used with all active displays
   /* CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	
    // Set the renderer output callback function
    CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, self);
	
    // Set the display link for the current renderer
    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	
    // Activate the display link
    CVDisplayLinkStart(displayLink);*/

	/*	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];

    	glClearColor(0, 0, 0, 0);
		glClear(GL_COLOR_BUFFER_BIT);
		
		glViewport (0, 0, 640, 400);*/
	/* glMatrixMode (GL_PROJECTION);
	 glLoadIdentity ();
	 glOrtho (0, 640, 0, 400, -1, 1);
	 glMatrixMode (GL_MODELVIEW);
	 glLoadIdentity ();
	 glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	 glEnable (GL_BLEND);
	*/

	[super prepareOpenGL];
	}
}

- (void)reshape		// scrolled, moved or resized
{
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    NSRect frame = [self frame];
    NSRect bounds = [self bounds];
    
    GLfloat minX, minY, maxX, maxY;
	
    minX = NSMinX(bounds);
    minY = NSMinY(bounds);
    maxX = NSMaxX(bounds);
    maxY = NSMaxY(bounds);
	
    [self update]; 
	

	CGLLockContext(cgl_ctx);
	{
		if(NSIsEmptyRect([self visibleRect])) {
			glViewport(0, 0, 1, 1);
		} else {
			glViewport(0, 0,  frame.size.width ,frame.size.height);
		}
		
		glMatrixMode(GL_MODELVIEW);    // select the modelview matrix
		glLoadIdentity();              // reset it
		
		glMatrixMode(GL_PROJECTION);   // select the projection matrix
		glLoadIdentity();              // reset it
		
		glOrtho(minX, maxX, minY, maxY, -1.0, 1.0);// define a 2-D orthographic projection matrix
		
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_BLEND);
	}
	CGLUnlockContext(cgl_ctx);
}
// if CIImage will be sent from textures
- (void) setGlContextToShare: (NSOpenGLContext *)context	{

	
	NSOpenGLPixelFormat *pixelFormat = [KOpenGLView defaultPixelFormat];
	
	@synchronized (self) {
		needsToFlush=false;
		// create a new openGLContext, shared with 'context' and use it to draw
		NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat: pixelFormat
																	shareContext: context];
		
		//[self setPixelFormat: pixelFormat];
		[self setOpenGLContext: openGLContext];
		[openGLContext setView:self];
		[[self openGLContext] makeCurrentContext];
		
		//[self prepareOpenGL];
		
		
		if (nil != _ciContext) {
			[_ciContext release];
            _ciContext = nil;
        }
	}


}


@end
