//
//  IIDCCaptureSessionController.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 31/05/14.
//
//

#import "IIDCCaptureSessionController.h"
#import "IIDCContext.h"
#import "IIDCCamera.h"

#import <dc1394/dc1394.h>

@interface IIDCCaptureSessionController ()
@property (strong) IIDCCamera *activeCamera;
@property (strong) NSLock *cameraLock;
@property (strong) NSLock *threadLock;
@property (strong) NSThread *thread;

@end

#define NUM_DMA_BUFFERS					(10)
#define MAX_FEATURE_KEY					(4)
#define SECONDS_IN_RUNLOOP				(1)

@interface IIDCCamera (PrivateMethods)
@property dc1394camera_t *cameraHandler;
@end

@implementation IIDCCaptureSessionController

-(id)initWithCamera:(IIDCCamera *)camera {
    self = [super init];
    if (self) {
        _camera = camera;
        _cameraLock = [[NSLock alloc] init];
        _threadLock = [[NSLock alloc] init];
    }
    return self;
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
	NSError* dummy;
	
	@synchronized(_cameraLock) {
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
		
        /*		if (nil != *error) {
         [_thread cancel];
         _thread = nil;
         
         return NO;
         }*/
	}
    
	return YES;
}

- (BOOL)stopCapturing:(NSError**)error
{
	NSError* dummy;
    
	@synchronized(_cameraLock) {
		if (nil == _thread || ![self.camera isCapturing])
			return YES;
        
		[self performSelector:@selector(_stopCapture:)
					 onThread:_thread
				   withObject:nil
				waitUntilDone:YES];
		
		// wait for the thread to exit
		@synchronized (_threadLock) {
			_thread = nil;
		}
	}
	
	BOOL success = YES;
    
	return success;
}

- (void)_setupCapture:(NSError**)error
{
    dc1394camera_t *camera = self.camera.cameraHandler;
    
    // just to be sure!
	dc1394video_mode_t mode;
	dc1394framerate_t framerate;
	dc1394_video_get_mode(camera, &mode);
	dc1394_video_get_framerate(camera, &framerate);
	dc1394_video_set_mode(camera, mode);
	dc1394_video_set_framerate(camera, framerate);
    
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
		
		return;
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
		
		return;
	}
    
    
    // TODO:
    
    // Reads the camera's parameters and default values
    // get_camera_settings(c_handle, &settings);
    
    //Sets default values to the non-camera paramenters
    // default_noncamera_settings(&settings);
    
}

- (void)_stopCapture:(NSError**)error
{
	dc1394camera_t *camera = self.cameraHandler;
	[self.thread cancel];
	
	dc1394error_t transmissionErr, captureErr;
	transmissionErr = dc1394_video_set_transmission(camera, DC1394_OFF);
	captureErr = dc1394_capture_stop(camera);
	
	dc1394_iso_release_all(camera);
    
	if (DC1394_SUCCESS != transmissionErr) {
        /*		if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394StopTransmissionFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorDesc", @"TFDc1394StopTransmissionErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorReason", @"TFDc1394StopTransmissionErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopTransmissionErrorRecovery", @"TFDc1394StopTransmissionErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
        
		return;
	}
	
	if (DC1394_SUCCESS != captureErr) {
        /*	if (NULL != error)
         *error = [NSError errorWithDomain:SICErrorDomain
         code:SICErrorDc1394StopCapturingFailed
         userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394StopCapturingErrorDesc", @"TFDc1394StopCapturingErrorDesc"),
         NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorReason", @"TFDc1394StopCapturingErrorReason"),
         NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394StopCapturingErrorRecovery", @"TFDc1394StopCapturingErrorRecovery"),
         NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
		
		return;
	}
}


- (void)_videoCaptureThread
{
	@synchronized(_threadLock) {
        @autoreleasepool {
            
            do {
                @autoreleasepool {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:SECONDS_IN_RUNLOOP]];
                    
                    /*                retry = 0;
                     over_run = 1;
                     while (over_run && retry < 10)
                     {
                     if (camwire_get_run_stop(c_handle, &runsts) !=
                     CAMWIRE_SUCCESS)
                     {
                     fprintf(stderr, "Could not get activity status.\n");
                     }
                     if (runsts != 0)  settings.activity = running;
                     else              settings.activity = stopped;
                     over_run =
                     (settings.acqtype == single && settings.activity == running);
                     if (over_run)
                     {  // Wait for camera to stop after single-shot.
                     nap.tv_sec = 0;
                     nap.tv_nsec = 1000000;  // 1 ms.
                     nanosleep(&nap, NULL);
                     }
                     ++retry;
                     }*/
                    
                    // TODO: if the DMA buffer overflows the callback is never called again.
                    // here is a good place to flush the buffer if it happens
                    
                    /*How do I flush the DMA ring buffer?
                     
                     1) Stop the camera ISO transmission (optional); 2) wait (sleep) at least one frame period to be sure the last frame being transmitted reached the host (optional); 3) call dc1394_capture_dequeue() using the DC1394_VIDEO1394_POLL policy (second argument), and repeat until the frame pointer (the third argument) gets set to NULL while the function returns DC1394_SUCCESS. That means the buffer has been drained.
                     
                     Remember to also call dc1394_enqueue_buffer() after every successful call to a DMA capture function, IOW everytime the capture function returns a valid frame (non-NULL third argument)
                     
                     Side note: the two first steps are not required if you wish to flush the buffer on-the-fly. However, the sync you get from this buffer flush will then be short-lived as frames continue to reach the host. Also, there is a (remote) possibility that you won't be able to empty the buffer faster than it fills, and your buffer-flushing function will then become a nice infinite loop... To be safe you could detect such condition by limiting the number of frame flushes to the size of the buffer (plus 1 or 2).*/
                    
                }
            } while (![[NSThread currentThread] isCancelled]);
            
            _thread = nil;
            
        }
    }
}


static void libdc1394_frame_callback(dc1394camera_t* c, void* data)
{
    IIDCCaptureSessionController *captureSession = (__bridge IIDCCaptureSessionController*)data;
    @autoreleasepool {
        
        NSLog(@"A new frame was received.");
        
		dc1394video_frame_t* frame;
		dc1394error_t err = dc1394_capture_dequeue(c, DC1394_CAPTURE_POLICY_POLL, &frame);
		
		if (DC1394_SUCCESS != err || NULL == frame) {
			return;
		}
		
		// if this is not the most recent frame, drop it and continue
		if (frame->frames_behind > 0) {
			do {
				dc1394_capture_enqueue(c, frame);
				dc1394_capture_dequeue(c, DC1394_CAPTURE_POLICY_POLL, &frame);
			} while (NULL != frame && 0 < frame->frames_behind);
		}
		
		if (NULL != frame) {
            if ([(NSObject*)captureSession.delegate respondsToSelector: @selector(captureSession:didCaptureFrame:)])
                [captureSession.delegate captureSession:captureSession didCaptureFrame: frame];
            
			dc1394_capture_enqueue(c, frame);
		}
        
	}
}


@end
