//
//  MainWindowController.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 16/10/11.
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
@synthesize controlsBox;

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
    }

}

-(void)dealloc
{

    [self stopSyphon];
    [self stopCamera];
    
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
	
    
	NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    
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
    {   NSDictionary *cameraDict =     @{@"UUID": key,
                                        @"cameraName": [cameraListDict valueForKey: key]};
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

- (void)loadControls {
    
    //[controlsBox setSubviews: [NSArray array]];
    
    NSDictionary * features = self.captureObject.features;
    NSView*controlsView = [[NSView alloc] initWithFrame: controlsBox.bounds];
    
    int i=1;
    int marginY = 15;
    int marginX = 15;
    int cellHeight = 60;

    controlsView.frame = NSMakeRect(controlsView.bounds.origin.x, controlsView.bounds.origin.y, controlsView.bounds.size.width, features.allKeys.count*cellHeight);

    for (NSString *featureKey in features.allKeys) {
        
        
        NSDictionary * curFDict = [features valueForKey:featureKey];
        
        NSRect uiFrame = NSMakeRect(marginX, controlsView.bounds.size.height - cellHeight  * i, controlsView.bounds.size.width - marginX * 2, cellHeight);
        
        
        NSView *cell = [[NSView alloc]initWithFrame:uiFrame];        
        
        // label
        uiFrame = NSMakeRect(0, 0, cell.bounds.size.width, 20);
        NSTextField * label = [[NSTextField alloc] initWithFrame: uiFrame];
        label.stringValue = featureKey;
        label.editable=NO;
        label.selectable=NO;
        label.bezeled=NO;
        label.bordered=NO;
        label.backgroundColor = [NSColor clearColor];
        [cell addSubview: label];

        // Slider
        uiFrame = NSMakeRect(0, 20, cell.bounds.size.width, 20);
        NSSlider * slider = [[NSSlider alloc] initWithFrame: uiFrame];
        slider.maxValue = [[curFDict valueForKey: @"max_value"] doubleValue];
        slider.minValue = [[curFDict valueForKey: @"min_value"] doubleValue];
        slider.doubleValue = [[curFDict valueForKey: @"value"] doubleValue];

        [slider bind:@"value"
            toObject:self.captureObject
         withKeyPath:featureKey
             options: nil]; 

        [cell addSubview: slider];
        
        // checkBox
        if ([[curFDict allKeys] containsObject: @"auto"]) {
            uiFrame = NSMakeRect(0, 40, 18, 18);
            NSButton * autoCheckBox = [[NSButton alloc] initWithFrame: uiFrame];
            autoCheckBox.buttonType=NSSwitchButton;
            autoCheckBox.state  = [[curFDict valueForKey: @"auto"] boolValue] ? NSOnState : NSOffState;
        
            [autoCheckBox bind: @"value"
                      toObject: self.captureObject
                   withKeyPath: [NSString stringWithFormat: @"auto_%@", featureKey]
             options: nil];
             /*[NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSValueTransformer valueTransformerForName:@""], NSValueTransformerBindingOption,
                                 , nil];*/
            [cell addSubview: autoCheckBox];
            
            [slider bind: @"enabled"
                      toObject: self.captureObject
                   withKeyPath: [NSString stringWithFormat: @"auto_%@", featureKey]
                 options: @{NSValueTransformerBindingOption: [NSValueTransformer valueTransformerForName:@"NSNegateBoolean"]}];

        }
      
        // one push auto button
        if ([[curFDict allKeys] containsObject: @"onePushAuto"]) {
            uiFrame = NSMakeRect(20, 40, 40, 18);
            NSButton * autoCheckBox = [[NSButton alloc] initWithFrame: uiFrame];
            autoCheckBox.buttonType=NSPushOnPushOffButton;      
            autoCheckBox.title = @"PUSH AUTO";
            autoCheckBox.tag = [[captureObject featureIndexForKey: featureKey] intValue];
            autoCheckBox.action = @selector(pushAuto:);
            /*[NSDictionary dictionaryWithObjectsAndKeys:
             [NSValueTransformer valueTransformerForName:@""], NSValueTransformerBindingOption,
             , nil];*/
            
            
            [cell addSubview: autoCheckBox];
            
        }
        
        [controlsView addSubview: cell];
        
        
        i ++;
    }
    [controlsBox setDocumentView:  controlsView];

        
    
}

- (void)setSelectedCameraUUID:(NSString *)UUID 
{
    NSError * error;
    
    [self stopCamera];
    
    TFLibDC1394Capture *dc1394Camera = [[TFLibDC1394Capture alloc ]initWithCameraUniqueId:@([UUID longLongValue])
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
    
    //load controls
    [self loadControls];
    
    previewGLView.source = captureObject;
    return;
}

#pragma mark Actions


- (void) pushAuto: (id) sender {
    NSUInteger featureIndex = [sender tag];
    [captureObject.dc1394Camera pushToAutoFeatureWithIndex: (dc1394feature_t) featureIndex];
    
    
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
