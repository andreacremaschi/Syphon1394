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

#import <OpenGL/CGLMacro.h>

#import <Syphon/Syphon.h>

@interface IIDCCaptureSession ()

@property (strong) IIDCCamera *activeCamera;
@property dispatch_queue_t captureQueue;
@property BOOL isRunning;
@property (strong) DC1394FrameUploader *frameUploader;
@property (strong) SyphonServer *syphonServer;
@property (strong) NSOpenGLContext *openGLContext;
@end

#define NUM_DMA_BUFFERS					(10)
#define MAX_FEATURE_KEY					(4)

@interface IIDCCamera (PrivateMethods)
@property dc1394camera_t *cameraHandler;
@end

@implementation IIDCCaptureSession

-(id)initWithCamera:(IIDCCamera *)camera {
    self = [super init];
    if (self) {
        _camera = camera;
    }
    return self;
}

// In the dealloc method, close the camera
- (void)dealloc
{
    if (self.isRunning)
        [self stopCapturing:nil];
    self.frameUploader = nil;
    if (_captureQueue)
        dispatch_release(_captureQueue);
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
	NSError* setupError;
	
    if (![self _setupCapture: &setupError]) {
        // setup error
        return  NO;
    }

    if (self.captureQueue == nil) {
        self.captureQueue = dispatch_queue_create("com.syphoniidcserver.capturequeue", DISPATCH_QUEUE_SERIAL);
    }
    
    // Start a read thread
    dispatch_async(self.captureQueue,
                   ^{
                       self.isRunning = YES;
                       [self videoCaptureThread];
                   });
    
    NSLog(@"Successfully started camera transfers");
    
    return YES;

}

// Stop isochronous transmission of frames
- (BOOL)stopCapturing:(NSError**)error
{
    // Shut down the transfers
    dc1394camera_t *camera = self.camera.cameraHandler;
    
    // [self flushDMABuffer];
    
    // Stop the read thread
    self.isRunning = NO;
    
	dc1394error_t transmissionErr, captureErr;
	transmissionErr = dc1394_video_set_transmission(camera, DC1394_OFF);
    captureErr = dc1394_capture_stop(camera);

    dispatch_sync(self.captureQueue, ^{}); 
        
	if (DC1394_SUCCESS != transmissionErr) {
        /*		if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394StopTransmissionFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorDesc", @"TFDc1394StopTransmissionErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorReason", @"TFDc1394StopTransmissionErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorRecovery", @"TFDc1394StopTransmissionErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
        
		return NO;
	}
	
	if (DC1394_SUCCESS != captureErr) {
        /*	if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394StopCapturingFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopCapturingErrorDesc", @"TFDc1394StopCapturingErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorReason", @"TFDc1394StopCapturingErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorRecovery", @"TFDc1394StopCapturingErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
		
		return NO;
	}
    
    NSLog(@"Successfully stop camera transfers");
    
    return YES;
}

- (BOOL)_setupCapture:(NSError**)error
{
    dc1394camera_t *camera = self.camera.cameraHandler;
    
    // just to be sure!
	dc1394video_mode_t mode;
	dc1394framerate_t framerate;
	dc1394_video_get_mode(camera, &mode);
	dc1394_video_get_framerate(camera, &framerate);
	dc1394_video_set_mode(camera, mode);
	dc1394_video_set_framerate(camera, framerate);
    
/*	dc1394_capture_schedule_with_runloop(camera,
										 [[NSRunLoop currentRunLoop] getCFRunLoop],
										 kCFRunLoopDefaultMode);
	dc1394_capture_set_callback(camera, libdc1394_frame_callback, (__bridge void *)(self));*/
    
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

- (void)videoCaptureThread
{
    int errors = 0;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    dc1394error_t retval;
    dc1394camera_t *camera = self.camera.cameraHandler;

    uint32_t width, height;
    do {
        
        // Get a frame from the camera
        dc1394video_frame_t *frame = nil;
        retval = dc1394_capture_dequeue(camera, DC1394_CAPTURE_POLICY_WAIT, &frame);
        // The frame memory is owned by the system, do not free it.
        
        if (retval != DC1394_SUCCESS) {
            
            if (!self.isRunning) {
                return;
            }
            
            errors += 1;
            
            if (errors < 100) {
                NSLog(@"Error capturing frame.");
                continue;
            } else {
                NSLog(@"Too many frame errors.");
                return;
            }
        }
        
        // NSLog(@"New frame available");
        if (frame->frames_behind>0)
            NSLog(@"%i frames behind", frame->frames_behind);
        
        width  = frame->size[0];
        height = frame->size[1];
        
        // Convert to RGB
        /*dc1394video_frame_t *newFrame = calloc(1, sizeof(dc1394video_frame_t));
        newFrame->color_coding=DC1394_COLOR_CODING_RGB8;
        
        dc1394_convert_frames(frame, newFrame);
        
        // Compute the new frame size
        size_t frameSize = width * height * 3;
        
        // Encapsulate the data into an NSData
        NSData *tempData = [NSData dataWithBytes:newFrame->image length:frameSize];
        
        // free the new frame
        free(newFrame->image);
        free(newFrame);
        */

        CGSize frameSize = CGSizeMake(width, height);

        CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];

        
        
        DC1394FrameUploader *frameUploader = self.frameUploader;
        if (frameUploader == nil || !CGSizeEqualToSize(frameUploader.frameSize, frameSize)) {
            [frameUploader destroyResources];
            frameUploader = self.frameUploader = [[DC1394FrameUploader alloc] initWithContext: cgl_ctx
                                                                                    frameSize: frameSize];
        }
        [frameUploader uploadFrame: frame];

        
        if (cgl_ctx) {
            
            // Setup OpenGL states
            glViewport(0, 0, frameSize.width, frameSize.height);
            
            glMatrixMode(GL_PROJECTION);
            glLoadIdentity();
            glOrtho(0.0, frameSize.width, 0.0, frameSize.height, -1, 1);
            
            glMatrixMode(GL_MODELVIEW);
            glLoadIdentity();
            
            // glTranslated(frameSize.width * 0.5, frameSize.height * 0.5, 0.0);
            
        }
        // NSDictionary *options = @{SyphonServerOptionDepthBufferResolution: @16};
        SyphonServer *syphonServer = self.syphonServer;
        if (syphonServer == nil) {
            syphonServer = [[SyphonServer alloc] initWithName:nil context:cgl_ctx options:nil];
            self.syphonServer = syphonServer;
        }
        [syphonServer bindToDrawFrameOfSize:frameSize];
        
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
        
        [self.openGLContext flushBuffer];
        
        [syphonServer unbindAndPublish];

        dc1394_capture_enqueue(camera, frame);
        
    } while (self.isRunning);

    [self.frameUploader destroyResources];
    [self.syphonServer stop];

    return;
}

- (NSOpenGLContext *)openGLContext
{
    if (_openGLContext) return _openGLContext;
    
    static NSOpenGLPixelFormatAttribute attrs[] =
    {
//        NSOpenGLPFAPixelBuffer,
//        NSOpenGLPFAAccelerated,
//        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFADoubleBuffer,
//        NSOpenGLPFADepthSize, 24,

        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 8,
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


@end
