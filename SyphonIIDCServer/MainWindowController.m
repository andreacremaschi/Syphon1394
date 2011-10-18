//
//  MainWindowController.m
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MainWindowController.h"
#import "TFLibDC1394Capture.h"
#import "TFIncludes.h"
#import "KOpenGLView.h"
#import "IIDCCameraController.h"
#import "KCanvas.h"
#import "SimpleServerGLView.h"

@implementation MainWindowController
@synthesize selectedCameraUUID;
@synthesize captureObject;

-(id)init
{
    self = [super initWithWindowNibName:@"MainWindowController"];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}


- (void)windowDidLoad
{
    [super windowDidLoad];
    

}

- (void) stopSyphon 
{
    // You should always stop a server so clients know it has gone
    if (nil!=syServer)
        [syServer stop];  
}

- (void) stopCamera
{
    if (captureObject) {
        previewGLView.source = nil;
        if ([captureObject.dc1394Camera isCapturing]) 
            [captureObject.dc1394Camera stopCapturing: nil]; 
        [captureObject release];
    }

}

-(void)dealloc
{

    [self stopSyphon];
    [self stopCamera];
    
    [super dealloc];
}

#pragma OpenGLContext
- (NSOpenGLContext *) openGLContextWithError: (NSError **)error 
                                shareContext: (NSOpenGLContext *)shareContext size:(CGSize)size{
	
    NSOpenGLPixelFormatAttribute	attributes[] = {
		//NSOpenGLPFAPixelBuffer,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADepthSize,8,
		(NSOpenGLPixelFormatAttribute) 0
	};
	
    
	NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
    
	//Create the OpenGL context to render with (with color and depth buffers)
	NSOpenGLContext * openGLContext = [[NSOpenGLContext alloc] 
					  initWithFormat:format 
					  shareContext: shareContext];
	
	if(openGLContext == nil) {
		//TODO: error management
		NSLog(@"Cannot create OpenGL context");
		return false;
	}
	
    CGLContextObj cgl_ctx = openGLContext.CGLContextObj;
	CGLLockContext( cgl_ctx );	
	{		
        
		glViewport(0, 0, size.width, size.height);
		
		glMatrixMode(GL_MODELVIEW);    // select the modelview matrix
		glLoadIdentity();              // reset it
		
		glMatrixMode(GL_PROJECTION);   // select the projection matrix
		glLoadIdentity();              // reset it
		
		glOrtho(0, size.width, 0, size.height, -1.0, 1.0);// define a 2-D orthographic projection matrix
        
	}
	CGLUnlockContext( cgl_ctx );
	
	//[self initPBO];
	
	return openGLContext;
	
}



#pragma mark Accessors

- (NSArray *)IIDCCameraList {
    
    NSDictionary *cameraListDict = [TFLibDC1394Capture connectedCameraNamesAndUniqueIds];
    
    NSMutableArray *cameraList = [NSMutableArray array];
    
    for (NSString *key in [cameraListDict allKeys])
    {   NSDictionary *cameraDict =     [NSDictionary dictionaryWithObjectsAndKeys: 
                                        key, @"UUID",
                                        [cameraListDict valueForKey: key], @"cameraName",
                                        nil];
        [cameraList addObject: cameraDict];
    }
    return cameraList;
}


- (NSOpenGLContext *)openGLContext
{
    static NSOpenGLContext *context = nil;
    if (nil==context)
        context= [self openGLContextWithError: nil shareContext:previewGLView.openGLContext size: CGSizeMake(1024,768)];
    return context;
}

- (void)setSelectedCameraUUID:(NSString *)UUID 
{
    NSError * error;
    
    [self stopCamera];
    
    TFLibDC1394Capture *dc1394Camera = [[TFLibDC1394Capture alloc ]initWithCameraUniqueId:[NSNumber numberWithLongLong: [UUID longLongValue]]
                                                                 error:&error];
    if (nil==dc1394Camera)
    {
        // error management!
        NSLog (@"%@", TFLocalizedString([error description], nil));
        return;
    }


    if (![dc1394Camera startCapturing: &error]) 
    {
        NSLog (@"%@", TFLocalizedString([error description], nil));
        // error management!
    }
    
    NSOpenGLContext *openGLContext = [self openGLContext];
    
    // init capture object
    self.captureObject = [IIDCCameraController cameraControllerWithTFLibDC1394CaptureObject: dc1394Camera openGLContext: openGLContext];
        self.captureObject.delegate = self;
    
    //init syphon server if needed

    if (nil==syServer) {
        syServer = [[SyphonServer alloc] initWithName:nil context: openGLContext.CGLContextObj options:nil];
    }
    
    previewGLView.source = captureObject;
    return;
}


#pragma mark IIDCCameraController delegates

- (void)captureObject:(IIDCCameraController*)capture
didCaptureFrame:(CIImage*)capturedFrame
{

    if ([syServer hasClients])
    {
        // lockTexture just stops the renderer from drawing until we're done with it
        [capture lockTexture];
        
        // publish our frame to our server. We use the whole texture, but we could just publish a region of it
        CGLLockContext(syServer.context);
        [syServer publishFrameTexture:capture.textureName
                        textureTarget:GL_TEXTURE_RECTANGLE_EXT
                          imageRegion: NSMakeRect(0, 0, capture.textureSize.width, captureObject.textureSize.height)
                    textureDimensions: capture.textureSize
                              flipped:NO];
        CGLUnlockContext(syServer.context);
        // let the renderer resume drawing
        [capture unlockTexture];
    }
    
    [previewGLView setNeedsDisplay: YES];
    
    
    
   // [previewGLView setImageToShow: capturedFrame];
    return;  
}



@end
