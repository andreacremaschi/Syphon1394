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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
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

- (void)setSelectedCameraUUID:(NSString *)UUID 
{
    NSError * error;
    if (captureObject) {
        if ([captureObject.dc1394Camera isCapturing]) [captureObject.dc1394Camera stopCapturing: &error]; 
        
    }
        
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
    self.captureObject = [IIDCCameraController cameraControllerWithTFLibDC1394CaptureObject: dc1394Camera];
    self.captureObject.delegate = self;
    return;
}


#pragma mark IIDCCameraController delegates
/*- (CGColorSpaceRef)wantedCIImageColorSpaceForCapture:(TFCapture*)capture;
{
}*/
- (void)captureObject:(IIDCCameraController*)capture
didCaptureFrame:(CIImage*)capturedFrame
{

    if ([syServer hasClients])
    {
        // lockTexture just stops the renderer from drawing until we're done with it
   /*     [theRenderer lockTexture];
        
        // publish our frame to our server. We use the whole texture, but we could just publish a region of it
        CGLLockContext(syServer.context);
        [syServer publishFrameTexture:theRenderer.textureName
                        textureTarget:GL_TEXTURE_RECTANGLE_EXT
                          imageRegion:NSMakeRect(0, 0, theRenderer.textureSize.width, theRenderer.textureSize.height)
                    textureDimensions:theRenderer.textureSize
                              flipped:NO];
        CGLUnlockContext(syServer.context);
        // let the renderer resume drawing
        [theRenderer unlockTexture];*/
    }
    
    
    
    
    
    [previewGLView setImageToShow: capturedFrame];
    return;  
}



@end
