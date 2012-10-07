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

    NSMutableDictionary *features;
    NSArray* videoModes;
    NSArray* colorModes;
    
    TFLibDC1394Capture *dc1394Camera;
    CGSize _bufferSize;
    	
    GLuint _texture;
    GLuint _fbo;
	GLuint _depthBuffer;
    GLuint _pixelBuffer;
    
    bool uploadingData;
    
    int selectedVideoMode;
    
    id delegate;
    NSOpenGLContext *openGLContext;
}



@property (nonatomic, assign) id delegate;

@property (readonly) TFLibDC1394Capture * dc1394Camera;

@property (nonatomic, retain) NSOpenGLContext *openGLContext;
@property (readonly) CGSize currentSize;

@property (nonatomic, retain) NSNumber *videoMode;

- (BOOL)setFeature:(NSString *)featureKey toValue:(float)val;
- (BOOL)setFeature:(NSString *)featureKey toAutoMode:(BOOL)val;
- (float)valueForFeature:(NSString *)featureKey;
- (NSNumber *)featureIndexForKey: (NSString *)key;

// camera features
@property (readonly) NSDictionary*features;
@property (readonly) NSArray*videoModes;
@property (readonly) NSArray*colorModes;
@property (readonly) GLuint textureName;

+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject openGLContext: (NSOpenGLContext *)context;
- (void)lockTexture;
- (void)unlockTexture;
@end

@interface NSObject (IIDCCameraControllerDelegate)
- (void)captureObject:(IIDCCameraController*)capture didCaptureFrame:(CIImage*)capturedFrame;
@end