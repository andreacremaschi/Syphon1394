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

@implementation IIDCCameraController

@synthesize delegate;
@synthesize dc1394Camera;
@synthesize openGLContext;

@synthesize features;
@dynamic brightness;
@dynamic gain;
@dynamic focus;
@dynamic exposure;
@dynamic shutter;




+ (NSArray *)featuresKeys {
    
    return [NSArray arrayWithObjects: @"brightness", @"gain", @"focus", @"shutter", @"exposure", nil];
}

- (id) initWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject openGLContext: (NSOpenGLContext *)context{
    self = [super init];
    if (self) {

        self.openGLContext = context;
        
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
    [features release];
    [super dealloc];
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
            
            GLuint oldTexture = self.textureName;
            if(oldTexture)
            {
                glDeleteTextures(1, &oldTexture);
            }
                     
            if(_fbo)
            {
                glDeleteFramebuffersEXT(1, &_fbo);
                _fbo = 0;
            }
            if(_depthBuffer)
            {
                glDeleteRenderbuffersEXT(1, &_depthBuffer);
                _depthBuffer = 0;
            }
            
            
            // texture / color attachment
            glGenTextures(1, &_texture);
            glEnable(GL_TEXTURE_RECTANGLE_EXT);
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _texture);
            glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
                         
            // depth buffer
            glGenRenderbuffersEXT(1, &_depthBuffer);
            glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _depthBuffer);
            glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, size.width, size.height);
            glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, 0);
            
            // FBO and connect attachments
            glGenFramebuffersEXT(1, &_fbo);
            glBindFramebufferEXT(GL_FRAMEBUFFER, _fbo);
            glFramebufferTexture2DEXT(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_EXT, _texture, 0);
            glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER_EXT, _depthBuffer);
            // Draw black so we have output if the renderer isn't loaded
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glBindFramebufferEXT(GL_FRAMEBUFFER, 0);
            
            GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER);
            if(status != GL_FRAMEBUFFER_COMPLETE)
            {
                NSLog(@"Simple Client: OpenGL error %04X", status);
                glDeleteTextures(1, &_texture);
                glDeleteFramebuffersEXT(1, &_fbo);
                glDeleteRenderbuffersEXT(1, &_depthBuffer);
                _texture = 0;
                _fbo = 0;
                _depthBuffer = 0;
                CGLUnlockContext(cgl_ctx);
                return;
            }
            
        }
        
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _fbo);
        
        glViewport(0, 0, size.width,  size.height);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        //	glOrtho(0, textureSize.width, 0, textureSize.height, -1, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadIdentity();

        
        
        // check GL_APPLE_client_storage, GL_APPLE_texture_range for async transfer
        
        //upload camera frame to GPU memory
        glBufferDataARB(GL_PIXEL_UNPACK_BUFFER, frame->total_bytes, frame->image, GL_STREAM_DRAW_ARB);
        glDrawPixels(frame->size[0],  frame->size[1], GL_LUMINANCE,  GL_UNSIGNED_BYTE, frame->image);
        glFlush();

        
       /* glClearColor(1.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT);*/
        
        // Restore OpenGL states
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix();
        
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
		
        // back to main rendering.
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
        
        
    }
    CGLUnlockContext(cgl_ctx);
    
    
    [self.delegate captureObject:self
                 didCaptureFrame:nil];

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
