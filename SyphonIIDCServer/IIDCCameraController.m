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

#import "KBO.h"
#import <OpenGL/CGLMacro.h>


@interface IIDCCameraController (PrivateMethods)
- (NSNumber *)featureIndexForKey: (NSString *)key;
@end

@implementation IIDCCameraController

@synthesize delegate;
@synthesize dc1394Camera;
@synthesize openGLContext;

@synthesize features;
@synthesize videoModes  ;
@synthesize colorModes;




- (id) initWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject openGLContext: (NSOpenGLContext *)context{
    self = [super init];
    if (self) {

        self.openGLContext = context;
        
        features = [[captureObject featuresDictionary] mutableCopy];
        videoModes = [captureObject videomodes];
        
        NSMutableArray *colModes = [NSMutableArray array];
        for (NSDictionary *dict in videoModes) {
            id col_mode = [dict valueForKey: @"color_mode"];
            if (![colModes containsObject: col_mode])
                [colModes addObject: col_mode];
            
        }
        colorModes = colModes;
        
//        dc1394camera_t *camera_struct = [captureObject cameraStruct];
        captureObject.delegate = self;
        dc1394Camera = captureObject;
        
    }
    return self;
}


+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject openGLContext: (NSOpenGLContext *)context {
    
    return [[IIDCCameraController alloc] initWithTFLibDC1394CaptureObject: captureObject openGLContext: context];
}

#pragma mark - Accessors

-(GLuint)textureName
{
    return _texture;
}

- (CGSize) textureSize 
{
    return _bufferSize;
}

- (void) setVideoMode:(NSNumber *)videoMode 
{
    [dc1394Camera setVideoMode: [videoMode intValue]];
}

-(NSNumber *)videoMode
{
    return @(selectedVideoMode);    
}

#pragma mark - Lock/unlock texture
- (void)lockTexture
{
	CGLLockContext(openGLContext.CGLContextObj);
}

- (void)unlockTexture
{
	CGLUnlockContext(openGLContext.CGLContextObj);
}



#pragma mark libdc1394 delegate
- (void)capture:(TFLibDC1394Capture*)capture
didCaptureFrame:(dc1394video_frame_t*)frame
{    
    CVReturn theError;
    CGLContextObj cgl_ctx = openGLContext.CGLContextObj;
    CGLLockContext(cgl_ctx);
    {

        CGSize size = CGSizeMake(frame->size[0], frame->size[1]);
        if (!CGSizeEqualToSize(size, _bufferSize)) 
        {
            
            _bufferSize = size;
            uploadingData = false;
            
            GLuint oldTexture = self.textureName;
            if(oldTexture)
            {
                glDeleteTextures(1, &oldTexture);
            }
                     
           /* if(_fbo)
            {
                glDeleteFramebuffersEXT(1, &_fbo);
                _fbo = 0;
            }
            if(_depthBuffer)
            {
                glDeleteRenderbuffersEXT(1, &_depthBuffer);
                _depthBuffer = 0;
            }*/
            
            if (_pixelBuffer)
            {
                glDeleteBuffers(1, &_pixelBuffer);
            }
            
            // texture / color attachment
            glGenTextures(1, &_texture);
            glEnable(GL_TEXTURE_RECTANGLE_EXT);
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _texture);
            glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
                         
            
            //PBO
            /*glGenBuffersARB(1, &_pixelBuffer );
            glBindBufferARB(GL_PIXEL_PACK_BUFFER, _pixelBuffer);
            // Draw black so we have output if the renderer isn't loaded
            glClearColor(1.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glBindBufferARB(GL_PIXEL_PACK_BUFFER, 0);
            */
        }
        
     
        /* GL_PIXEL_PACK_BUFFER_ARB and GL_PIXEL_UNPACK_BUFFER_ARB. GL_PIXEL_PACK_BUFFER_ARB is for transferring pixel data from OpenGL to your application, and GL_PIXEL_UNPACK_BUFFER_ARB means transferring pixel data from an application to OpenGL*/
        
       /* glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, _pixelBuffer);
        
        if (uploadingData) {

            uploadingData=false;

        }
        
        glViewport(0, 0, size.width,  size.height);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, size.width, 0, size.height, -1, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadIdentity();

        



        */
        
        glViewport(0, 0, size.width,  size.height);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, size.width, 0, size.height, -1, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadIdentity();
        
        //upload camera frame to GPU memory
        /*glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, _pixelBuffer);
        glBufferDataARB(GL_PIXEL_UNPACK_BUFFER_ARB, frame->total_bytes, frame->image, GL_STREAM_DRAW_ARB);
        glDrawPixels(frame->size[0],  frame->size[1], GL_LUMINANCE,  GL_UNSIGNED_BYTE, frame->image);
        glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, 0);     
        //        glFlush();
        
        
        //copy PBO image to texture for drawing
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _texture);
        glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, _pixelBuffer);
        glTexImage2D(GL_TEXTURE_2D, 0, 0, size.width, size.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        
        glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB, 0);
*/
        
        
        
        //direct copy CPU memory -> texture
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _texture);
        glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, size.width, size.height, 0,
                     frame->data_depth == 8 ? GL_LUMINANCE : GL_LUMINANCE, 
                     frame->data_depth == 8 ? GL_UNSIGNED_BYTE : GL_UNSIGNED_SHORT, frame->image);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        
        
        

        
                // Restore OpenGL states
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix();
        
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        // back to main rendering.
        // glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

        /* glClearColor(1.0, 0.0, 0.0, 0.0);
         glClear(GL_COLOR_BUFFER_BIT);*/

        
        uploadingData = true;
        
    }
    CGLUnlockContext(cgl_ctx);

    [self.delegate captureObject:self
                 didCaptureFrame:nil];
    return;  
}

#pragma mark property setter
- (void) setValue:(id)value forKey:(NSString *)key  {
    NSArray *featuresKeys = [features allKeys];

    if ((key.length >   5) && [[key substringWithRange: NSMakeRange(0, 5)] isEqualToString: @"auto_"]) {
        NSString *featureKey = [key substringWithRange: NSMakeRange(5, key.length-5)];
        if (![featuresKeys containsObject: featureKey]) 
            [super setValue:value forKey:key]; 
        
        NSUInteger i = [[self featureIndexForKey: featureKey] intValue];
        if ([dc1394Camera setFeatureWithIndex: (dc1394feature_t) i toAutoMode: [value boolValue]]) {
            [self willChangeValueForKey: [NSString stringWithFormat: @"auto_%@", featureKey]];
            [[features valueForKey: featureKey] setValue: value forKey: @"auto"];
            [self didChangeValueForKey: [NSString stringWithFormat: @"auto_%@", featureKey]];            
        };
        
        
    } else
        if (![featuresKeys containsObject: key]) [super setValue:value forKey:key]; ;
    
    NSUInteger i = [[self featureIndexForKey: key] intValue];
    [dc1394Camera setFeatureWithIndex: i toValue: [value floatValue]];
}


- (id)valueForKey:(NSString *)key
{

    //check if we want to set an "auto" property
    if ((key.length > 5) && [[key substringWithRange: NSMakeRange(0, 5)] isEqualToString: @"auto_"]) {
        NSString *featureKey = [key substringWithRange: NSMakeRange(5, key.length-5)];
        return [[features valueForKey: featureKey] valueForKey: @"auto"];
        
    } else if ([[features allKeys] containsObject: key])
        return [[features valueForKey: key] valueForKey: @"value"];
    if ([key isEqualToString:@"features"]) return features;
    return [super valueForKey: key];
    
}

#pragma mark TFLibDC1394 methods


- (NSNumber *)featureIndexForKey: (NSString *)key {
    return [[features valueForKey: key] valueForKey:@"feature_index"];
    
}

- (BOOL)setFeature:(NSString *)featureKey toValue:(float)val {
    NSNumber *featureIndex = [self featureIndexForKey: featureKey];
    if (!featureIndex) return false;
    NSUInteger feature = [featureIndex intValue];
    return [dc1394Camera setFeatureWithIndex:(dc1394feature_t)feature toValue: val];
    
}

- (BOOL)setFeature:(NSString *)featureKey toAutoMode:(BOOL)val {
    NSNumber *featureIndex = [self featureIndexForKey: featureKey];
    if (!featureIndex) return false;
    NSUInteger feature = [featureIndex intValue];
    return [dc1394Camera setFeatureWithIndex:(dc1394feature_t)feature toAutoMode: val];
    
}
- (float)valueForFeature:(NSString *)featureKey {
    NSNumber *featureIndex = [self featureIndexForKey: featureKey];
    if (!featureIndex) return -1.0;
    NSUInteger feature = [featureIndex intValue];
    return [dc1394Camera valueForFeatureWithIndex:(dc1394feature_t)feature];
    
    
}
- (float)pushToAutoFeatureWithKey: (NSString *)featureKey {
    NSNumber *featureIndex = [self featureIndexForKey: featureKey];
    if (!featureIndex) return -1;
    NSUInteger feature = [featureIndex intValue];
    return [dc1394Camera pushToAutoFeatureWithIndex:(dc1394feature_t)feature];
    
}

@end
