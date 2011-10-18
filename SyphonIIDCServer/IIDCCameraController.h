//
//  IIDCCameraController.h
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 17/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "SimpleServerTextureSource.h"

@class TFLibDC1394Capture, KCanvas;
@interface IIDCCameraController : NSObject <SimpleServerTextureSource>{
    NSDictionary *features;
    TFLibDC1394Capture *dc1394Camera;
    CGSize _bufferSize;
    	
    GLuint _texture;
    GLuint _fbo;
	GLuint _depthBuffer;
    GLuint _pixelBuffer;
    
    bool uploadingData;
}



@property (nonatomic, assign) id delegate;

@property (readonly) TFLibDC1394Capture * dc1394Camera;

@property (nonatomic, retain) NSOpenGLContext *openGLContext;
@property (readonly) CGSize currentSize;



// camera features
@property (nonatomic, retain) NSDictionary *features;
@property float brightness;
@property float gain;
@property float focus;
@property float exposure;
@property float shutter;

@property (readonly) GLuint textureName;

+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject openGLContext: (NSOpenGLContext *)context;
- (void)lockTexture;
- (void)unlockTexture;
@end

@interface NSObject (IIDCCameraControllerDelegate)
- (void)captureObject:(IIDCCameraController*)capture didCaptureFrame:(CIImage*)capturedFrame;
@end