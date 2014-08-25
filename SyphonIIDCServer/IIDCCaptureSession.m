//
//  IIDCCaptureSessionController.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 31/05/14.
//
//

#import "IIDCCaptureSession.h"
#import "IIDCContext.h"
#import "IIDCCamera.h"

#import "DC1394FrameUploader.h"

#import <dc1394/dc1394.h>
#import <dc1394/macosx/capture.h>

#import <OpenGL/CGLMacro.h>

#import <Syphon/Syphon.h>

@interface IIDCCaptureSession ()

@property (strong) IIDCCamera *activeCamera;
@property BOOL isRunning;
@property (strong) DC1394FrameUploader *frameUploader;
@property (strong) SyphonServer *syphonServer;
@property (strong) NSOpenGLContext *openGLContext;

@property (strong) NSThread* thread;
@property (strong) NSLock* threadLock;

@property BOOL isStopping;

@property (strong) id activity;

@property (readwrite) double fps;
@property (readwrite) IIDCCaptureSessionState state;

@property CFAbsoluteTime time;
@property  CFAbsoluteTime lastFrame;

@end

#define SECONDS_IN_RUNLOOP				(2)
#define NUM_DMA_BUFFERS					(10)
#define MAX_FEATURE_KEY					(4)

NSString *IIDCCameraErrorDomain = @"IIDCCameraErrorDomain";

static void libdc1394_frame_callback(dc1394camera_t* c, void* data);

@interface IIDCCamera (PrivateMethods)
@property dc1394camera_t *cameraHandler;
@end

@implementation IIDCCaptureSession

-(id)initWithCamera:(IIDCCamera *)camera {
    self = [super init];
    if (self) {
        _camera = camera;
        _threadLock = [NSLock new];
        _state = IIDCCaptureSessionState_Initial;
    }
    return self;
}

// In the dealloc method, close the camera
- (void)dealloc
{
    if (self.isRunning)
        [self stopCapturing:nil];
    self.frameUploader = nil;
    if (_thread) {
        [_thread cancel];
    }
}

#pragma mark - Accessors

-(IIDCContext *)iidcContext {
    return self.camera.context;
}

-(dc1394camera_t *) cameraHandler {
    return self.camera.cameraHandler;
}

#pragma mark session methods

- (BOOL)startCapturing:(NSError**)error
{
    if (nil != _thread)
        return YES;
   
    _thread = [[NSThread alloc] initWithTarget:self
                                      selector:@selector(_videoCaptureThread)
                                        object:nil];
    [_thread start];
    
    [self performSelector:@selector(_setupCapture:)
                 onThread:_thread
               withObject:[NSValue valueWithPointer:error]
            waitUntilDone:YES];
    
    if (NO) {
        [_thread cancel];
        _thread = nil;

        self.state = IIDCCaptureSessionState_Error;
        
        return NO;
    }
	
    self.state = IIDCCaptureSessionState_Capturing;

    // avoid app nap!
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)])
        self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions: NSActivityUserInitiated | NSActivityIdleDisplaySleepDisabled | NSActivityLatencyCritical
                                                                       reason:@"Streaming firewire camera"];

	return YES;
}

- (BOOL)stopCapturing:(NSError**)error
{
    if (nil == _thread)
        return YES;
    
    self.isStopping = YES;

    [self performSelector:@selector(_stopCapture:)
                 onThread:_thread
               withObject:[NSValue valueWithPointer:error]
            waitUntilDone:YES];
    
    // wait for the thread to exit
    @synchronized (_threadLock) {
        _thread = nil;
    }
	
    [self.frameUploader destroyResources];
    [self.syphonServer stop];
    self.frameUploader = nil;
    self.syphonServer = nil;
    
	BOOL success = YES;
    self.isStopping = NO;

    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(endActivity:)])
        [[NSProcessInfo processInfo] endActivity: self.activity];
    
    self.activity = nil;
    
    if (success) {
        self.state = IIDCCaptureSessionState_Terminated;
    } else {
        self.state = IIDCCaptureSessionState_Error;
    }
    
	return success;
}


- (BOOL)_setupCapture:(NSError**)error
{
    dc1394camera_t *camera = self.camera.cameraHandler;
    
    dc1394error_t dc1394Error;
    
	dc1394_camera_set_power(camera, DC1394_ON);
	
	// turn off the camera's ISO if it's running
	dc1394_video_set_transmission(camera, DC1394_OFF);
	
	// try to set the camera operation mode to 1394B,
	dc1394speed_t isoSpeed;
    dc1394Error = dc1394_video_set_operation_mode(camera, DC1394_OPERATION_MODE_1394B);

    // set ISO speed to the maximum available:
    // if in 1394B to 800 MB/s, if in 1394A to 400 MB/s
    dc1394operation_mode_t mode;
    dc1394_video_get_operation_mode(camera, &mode);
    dc1394_video_set_iso_speed(camera,
                               mode == DC1394_OPERATION_MODE_1394B ?
                               DC1394_ISO_SPEED_800 : DC1394_ISO_SPEED_400);

    // setup the runloop
	dc1394_capture_schedule_with_runloop(camera,
										 [[NSRunLoop currentRunLoop] getCFRunLoop],
										 kCFRunLoopDefaultMode);
	dc1394_capture_set_callback(camera, libdc1394_frame_callback, (__bridge void *)(self));
    
	dc1394error_t err;
	err = dc1394_capture_setup(camera,
                               NUM_DMA_BUFFERS,
                               DC1394_CAPTURE_FLAGS_DEFAULT | DC1394_CAPTURE_FLAGS_AUTO_ISO);
  	
	if (err != DC1394_SUCCESS) {
        /*	if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394CaptureSetupFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorDesc", @"TFDc1394CaptureSetupErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorReason", @"TFDc1394CaptureSetupErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorRecovery", @"TFDc1394CaptureSetupErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
		
		return NO;
	}
	
	if (DC1394_SUCCESS != dc1394_video_set_transmission(camera, DC1394_ON)) {
		dc1394_capture_stop(camera);
		
		/*if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394SetTransmissionFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394SetTransmissionErrorDesc", @"TFDc1394SetTransmissionErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394SetTransmissionErrorReason", @"TFDc1394SetTransmissionErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394SetTransmissionErrorRecovery", @"TFDc1394SetTransmissionErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
		
		return NO;
	}
    
    [self flushDMABuffer];
    
    // TODO:
    
    // Reads the camera's parameters and default values
    // get_camera_settings(c_handle, &settings);
    
    //Sets default values to the non-camera paramenters
    // default_noncamera_settings(&settings);
    return YES;
}

- (void)_stopCapture:(NSError**)error
{
    dc1394camera_t *camera = self.camera.cameraHandler;
    
    
	[_thread cancel];
	
	dc1394error_t transmissionErr, captureErr;
	transmissionErr = dc1394_video_set_transmission(camera, DC1394_OFF);
	captureErr = dc1394_capture_stop(camera);
	
	dc1394_iso_release_all(camera);
    
/*	if (DC1394_SUCCESS != transmissionErr) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
                                         code:SICErrorDc1394StopTransmissionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorDesc", @"TFDc1394StopTransmissionErrorDesc"),
												NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorReason", @"TFDc1394StopTransmissionErrorReason"),
												NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorRecovery", @"TFDc1394StopTransmissionErrorRecovery"),
												NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];
        
		return;
	}
	
	if (DC1394_SUCCESS != captureErr) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
                                         code:SICErrorDc1394StopCapturingFailed
                                     userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopCapturingErrorDesc", @"TFDc1394StopCapturingErrorDesc"),
												NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorReason", @"TFDc1394StopCapturingErrorReason"),
												NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorRecovery", @"TFDc1394StopCapturingErrorRecovery"),
												NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];
		
		return;
	}*/

}

- (void)_videoCaptureThread
{
	@synchronized(_threadLock) {
		@autoreleasepool {
            
			do {
				@autoreleasepool {
					[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:SECONDS_IN_RUNLOOP]];
                    
                    CFAbsoluteTime curTime = CFAbsoluteTimeGetCurrent();
                    CFAbsoluteTime lastFrame = self.lastFrame;
                    CFTimeInterval timePassed = (curTime-lastFrame);
                    if (self.state == IIDCCaptureSessionState_Capturing && timePassed > SECONDS_IN_RUNLOOP) {
                        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey : @"Connection error."};
                        NSError *error = [NSError errorWithDomain:IIDCCameraErrorDomain code:101 userInfo: userInfo];
                        [self terminateCapturingWithError: error];

                    }
				}
			} while (![[NSThread currentThread] isCancelled]);
            
			_thread = nil;
            
		}
	}
}

- (NSOpenGLContext *)openGLContext
{
    if (_openGLContext) return _openGLContext;
    
    static NSOpenGLPixelFormatAttribute attrs[] =
    {
//        NSOpenGLPFAPixelBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFADoubleBuffer,
//        NSOpenGLPFADepthSize, 24,

        NSOpenGLPFAColorSize, 32,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat: pixelFormat shareContext:nil];
    
    if (openGLContext) {
        CGLContextObj cgl_ctx = [openGLContext CGLContextObj];
        
        // Enable the rectangle texture extenstion
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        //glDisable(GL_DEPTH);
    }
    _openGLContext = openGLContext;
    
    return _openGLContext;
}

- (void) _handleFrame: (dc1394video_frame_t*)frame {

    uint32_t width, height;
    width  = frame->size[0];
    height = frame->size[1];

    CGSize frameSize = CGSizeMake(width, height);
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    
    DC1394FrameUploader *frameUploader = self.frameUploader;
    if (frameUploader == nil || !CGSizeEqualToSize(frameUploader.frameSize, frameSize)) {
        [frameUploader destroyResources];
        frameUploader = self.frameUploader = [[DC1394FrameUploader alloc] initWithContext: cgl_ctx
                                                                           prototypeFrame: frame];
    }
    [frameUploader uploadFrame: frame];
    
    
    // NSDictionary *options = @{SyphonServerOptionDepthBufferResolution: @16};
    SyphonServer *syphonServer = self.syphonServer;
    if (syphonServer == nil) {
        syphonServer = [[SyphonServer alloc] initWithName:nil context:cgl_ctx options:nil];
        self.syphonServer = syphonServer;
    }
    [syphonServer bindToDrawFrameOfSize:frameSize];
    
    glViewport(0, 0, frameSize.width, frameSize.height);
    
    // Render our QCRenderer
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();
    
    if (1)
    {
        GLfloat tex_coords[] =
        {
            0.0,	0.0,
            frameSize.width,	0.0,
            frameSize.width,	frameSize.height,
            0.0,	frameSize.height
        };
        
        
        float halfw = 1.0; // frameSize.width * 0.5;
        float halfh = 1.0; //frameSize.height * 0.5;
        
        GLfloat verts[] =
        {
            -halfw, -halfh,
            halfw, -halfh,
            halfw, halfh,
            -halfw, halfh
        };
        
        
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, self.frameUploader.textureName);
        
        // do a nearest linear interp.
        glDisable(GL_BLEND);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
        
        //glColor4f(1.0, 1.0, 0.0, 1.0);
        
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(2, GL_FLOAT, 0, verts );
        glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
        glDisableClientState( GL_TEXTURE_COORD_ARRAY );
        glDisableClientState(GL_VERTEX_ARRAY);
        
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        
    }
    else
    {
        glClearColor(1.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    // Restore OpenGL states
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
    
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    
    //[self.openGLContext flushBuffer];
    
    [syphonServer unbindAndPublish];

}

- (void) flushDMABuffer {
#define RETRY NUM_DMA_BUFFERS+2  /* BUF_SIZE is the number of frames in the buffer, as used when capture was initialized*/
    
    dc1394camera_t *camera = self.camera.cameraHandler;
    dc1394video_frame_t *img;
    
    int i=RETRY;
    int rtn=dc1394_capture_dequeue (camera, DC1394_CAPTURE_POLICY_POLL, &img);
    while (rtn==DC1394_SUCCESS && img!=NULL && i>0) {
        dc1394_capture_enqueue(camera, img);
        rtn=dc1394_capture_dequeue (camera, DC1394_CAPTURE_POLICY_POLL, &img);
        i--;
    }
    if (i==0 && img!=NULL) {
        fprintf(stderr,"Frames coming in too fast, can't flush the buffer!\n");
        dc1394_capture_enqueue(camera, img);
    }
    if (rtn!=DC1394_SUCCESS)
        fprintf(stderr,"Error flushing buffer\n");
    /*if (i==RETRY)
        fprintf(stderr,"Buffer was already empty\n");*/
}

-(void)terminateCapturingWithError: (NSError*)error {
    NSError *stopError;
    [self stopCapturing: &stopError];
    
    self.state = IIDCCaptureSessionState_Error;
    if ([self.delegate respondsToSelector:@selector(captureSession:didFailWithError:)])
        [self.delegate captureSession:self didFailWithError:error];
}

static void libdc1394_frame_callback(dc1394camera_t* c, void* data) {
    @autoreleasepool {
        
        IIDCCaptureSession *captureSession = (__bridge IIDCCaptureSession*)data;
        if (captureSession.isStopping) return;
        @synchronized(captureSession.threadLock) {
            
            int errors = 0;
            dc1394error_t retval;
            
            // calculate framerate with a smoothed average
            double curTime = CFAbsoluteTimeGetCurrent();
            float weightRatio = 0.025;
            CFAbsoluteTime time = captureSession.time;
            CFAbsoluteTime last_frame = captureSession.lastFrame;
            time = curTime;
            time = time * (1.0 - weightRatio) + last_frame * weightRatio;
            last_frame = curTime;
            captureSession.fps =  1.0 / (curTime-time) * weightRatio;
            captureSession.time = time;
            captureSession.lastFrame = last_frame;
            
            IIDCCaptureSession *captureSession = (__bridge IIDCCaptureSession*)data;
            
            // Get a frame from the camera
            dc1394video_frame_t *frame = nil;
            retval = dc1394_capture_dequeue(c, DC1394_CAPTURE_POLICY_WAIT, &frame);
            // The frame memory is owned by the system, do not free it.
            
            if (retval != DC1394_SUCCESS) {
                
                errors += 1;
                
                if (errors < 100) {
                    NSLog(@"Error capturing frame.");
                    return;
                } else {
                    NSLog(@"Too many frame errors.");
                    NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey : @"Too many frame errors."};
                    NSError *error = [NSError errorWithDomain:IIDCCameraErrorDomain code:100 userInfo: userInfo];
                    [captureSession terminateCapturingWithError: error];
                    return;
                }
            }
            
            uint32_t framesBehind = frame->frames_behind;
            [captureSession _handleFrame: frame];
            
            dc1394_capture_enqueue(c, frame);
            
            
            // NSLog(@"New frame available");
            if (framesBehind>0) {
                NSLog(@"%i frames behind. Flushing buffer...", framesBehind);
                [captureSession flushDMABuffer];
            }
            
        }
    }
}

@end
