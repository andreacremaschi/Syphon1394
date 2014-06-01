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

#import <dc1394/dc1394.h>

@interface IIDCCaptureSession ()
@property (strong) IIDCCamera *activeCamera;
@property dispatch_queue_t captureQueue;
@property BOOL isRunning;
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
        
        NSLog(@"New frame available");
        if (frame->frames_behind>0)
            NSLog(@"%i frames behind", frame->frames_behind);
        
        width  = frame->size[0];
        height = frame->size[1];
        
        // Convert to RGB
        dc1394video_frame_t *newFrame = calloc(1, sizeof(dc1394video_frame_t));
/*        frame->color_filter = DC1394_COLOR_FILTER_BGGR;
        frame->color_coding = DC1394_COLOR_CODING_MONO8;*/
        newFrame->color_coding=DC1394_COLOR_CODING_RGB8;
        
        dc1394_convert_frames(frame, newFrame);
        
        // Compute the new frame size
        size_t frameSize = width * height * 3;
        
        // Encapsulate the data into an NSData
        NSData *tempData = [NSData dataWithBytes:newFrame->image length:frameSize];
        
        // free the new frame
        free(newFrame->image);
        free(newFrame);
        
        dc1394_capture_enqueue(camera, frame);
        frame = nil;
        
        // Send a notification with the new data on another thread
      /*  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                       ^{
                           [center postNotificationName:DCAMCapturedFrameNotification object:tempData];
                       });*/
        
    } while (self.isRunning);
    
    return;
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
