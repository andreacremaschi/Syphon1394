//
//  IIDCCameraController.m
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 17/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "IIDCCameraController.h"
#import "TFLibDC1394Capture.h"
#import <OpenGL/CGLMacro.h>
#import <dc1394/dc1394.h>
#import "KCanvas.h"
#import "KBO.h"

@implementation IIDCCameraController

@synthesize delegate;
@synthesize dc1394Camera;
@synthesize canvas;

@synthesize features;
@dynamic brightness;
@dynamic gain;
@dynamic focus;
@dynamic exposure;
@dynamic shutter;




+ (NSArray *)featuresKeys {
    
    return [NSArray arrayWithObjects: @"brightness", @"gain", @"focus", @"shutter", @"exposure", nil];
}

- (id) initWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject {
    self = [super init];
    if (self) {

            canvas = [[KCanvas canvasWithSize: CGSizeZero] retain];
        
        NSArray *featuresKeys = [IIDCCameraController featuresKeys];
        features = [[NSMutableDictionary dictionary] retain];
        int i=0;
        for (NSString* key in featuresKeys)
        {
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithBool: [captureObject featureIsMutable: i]], @"mutable",
                                  [NSNumber numberWithBool: [captureObject featureSupportsAutoMode: i]], @"supportsAutoMode",
                                  [NSNumber numberWithBool: [captureObject featureInAutoMode: i]], @"autoMode",                                  
                                  [NSNumber numberWithFloat: [captureObject valueForFeature: i]], @"value",
                                  nil];
            [features setValue: dict forKey: key];
            i++;
        }
        
        dc1394camera_t *camera_struct = [captureObject cameraStruct];
        captureObject.delegate = self;
        dc1394Camera = captureObject;
        
    }
    return self;
}

-(void)dealloc
{
    [canvas release];
    [features release];
    [super dealloc];
}

+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject {
    
    return [[IIDCCameraController alloc] initWithTFLibDC1394CaptureObject: captureObject];
}
#pragma mark - Accessors

-(GLuint)textureName
{
    return canvas.textureName;
}

- (CGSize) currentSize 
{
    return dc1394Camera.frameSize;
}

#pragma mark - Lock/unlock texture
- (void)lockTexture
{
	CGLLockContext(canvas.openGLContext.CGLContextObj);
}

- (void)unlockTexture
{
	CGLUnlockContext(canvas.openGLContext.CGLContextObj);
}

-(NSOpenGLContext *)openGLContext
{
    return canvas.openGLContext;
}

#pragma mark libdc1394 delegate
- (void)capture:(TFLibDC1394Capture*)capture
didCaptureFrame:(dc1394video_frame_t*)frame
{
    
    
    CGSize size = CGSizeMake(frame->size[0], frame->size[1]);
    if (nil==canvas) {
        canvas = [KCanvas canvasWithSize: size];
    }
    
    if (!CGSizeEqualToSize(size, canvas.size)) [canvas setSize: size];
    
    
    CGLContextObj cgl_ctx = canvas.openGLContext.CGLContextObj;
    CGLLockContext(cgl_ctx);
    {
        
        [canvas.bo attachPBO];

        glBufferDataARB(GL_PIXEL_UNPACK_BUFFER, frame->total_bytes, frame->image, GL_STREAM_DRAW_ARB);
        glDrawPixels(frame->size[0],  frame->size[1], GL_LUMINANCE,  GL_UNSIGNED_BYTE, frame->image);
        glFlush();
        
        [canvas.bo detachPBO];
        
    }
    CGLUnlockContext(cgl_ctx);
    
    
    CIImage *frameOnGPU= canvas.image;
    
    
    [self.delegate captureObject:self
                 didCaptureFrame:frameOnGPU];

    return;  
}

#pragma mark property setter
- (void) setValue:(id)value forKey:(NSString *)key  {
    NSArray *featuresKeys = [IIDCCameraController featuresKeys];
    if (![featuresKeys containsObject: key]) return;
    
    NSUInteger i = [featuresKeys indexOfObject: key];
    [dc1394Camera setFeature: i toValue: [value floatValue]];
}


- (id)valueForKey:(NSString *)key
{
        if ([[features allKeys] containsObject: key])
            return [[features valueForKey: key] valueForKey: @"value"];
    if ([key isEqualToString:@"features"]) return features;
    return [super valueForKey: key];
    
}

@end
