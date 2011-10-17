//
//  IIDCCameraController.h
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 17/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
@class TFLibDC1394Capture;

@interface IIDCCameraController : NSObject {
    NSDictionary *features;
    TFLibDC1394Capture *dc1394Camera;
}


@property (nonatomic, retain) NSDictionary *features;
@property (nonatomic, assign) id delegate;
@property (readonly) TFLibDC1394Capture * dc1394Camera;


@property float brightness;
@property float gain;
@property float focus;
@property float exposure;
@property float shutter;


+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject;
    
@end

@interface NSObject (IIDCCameraControllerDelegate)
- (void)captureObject:(IIDCCameraController*)capture didCaptureFrame:(CIImage*)capturedFrame;
@end