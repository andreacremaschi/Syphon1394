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
        if ([captureObject isCapturing]) [captureObject stopCapturing: &error]; 
        
    }
        
    captureObject = [[TFLibDC1394Capture alloc ]initWithCameraUniqueId:[NSNumber numberWithInt: [UUID intValue]]
                                                                 error:&error];
    if (nil==captureObject)
    {
        // error management!
        NSLog (@"%@", TFLocalizedString([error description], nil));
        return;
    }

    captureObject.delegate = self;
    if (![captureObject startCapturing: &error]) 
    {
        NSLog (@"%@", TFLocalizedString([error description], nil));
        // error management!
    }
    return;
}


#pragma mark TFLibDC1394Capture delegates
/*- (CGColorSpaceRef)wantedCIImageColorSpaceForCapture:(TFCapture*)capture;
{
}*/

- (void)capture:(TFCapture*)capture didCaptureFrame:(CIImage*)capturedFrame
{
    return;  
}

@end
