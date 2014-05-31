//
//  IIDCCamera.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import "IIDCCamera.h"
#import <dc1394/dc1394.h>

#import <camwire/camwire.h>

@interface IIDCCamera ()
@property Camwire_handle cameraHandler;
@property (strong) NSLock *cameraLock;
@property (strong) NSThread *captureThread;
@property (nonatomic, readwrite, strong) NSDictionary *features;
@property (nonatomic, readwrite, strong) NSArray *videomodes;
@property (strong) NSThread *thread;

@end

#define NUM_DMA_BUFFERS					(10)
#define MAX_FEATURE_KEY					(4)
#define SECONDS_IN_RUNLOOP				(1)

@implementation IIDCCamera

- (id) initWithCameraOpaqueObject: (dc1394camera_t *)camera {
    self = [super init];
    if (self) {
        
        Camwire_handle camwire_handle =  (Camwire_bus_handle *) malloc(sizeof(Camwire_bus_handle));
        camwire_handle->camera = camera;
        camwire_handle->userdata = 0;

        _cameraHandler = camwire_handle;
        _cameraLock = [[NSLock alloc] init];
    }
    return self;
}

-(void)dealloc {
    self.features = nil;
    dc1394_camera_free(_cameraHandler->camera);
    free(_cameraHandler);
}

- (void) didDisconnect {
    // tells the delegate
}


#pragma mark - system functions

-(BOOL)isSaving {
    dc1394bool_t value;
    dc1394_memory_busy(_cameraHandler->camera, &value);
    return value;
}

- (void) saveSettingsInCameraMemoryBank: (int) channel {
    
    dc1394error_t dcError = dc1394_memory_save(_cameraHandler->camera, channel);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
    
}

- (void) restoreSettingsFromMemoryBank: (int) channel {
    dc1394error_t dcError = dc1394_memory_load(_cameraHandler->camera, channel);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
    
}

- (void) broadcast: (void(^)())block {
    
    dc1394error_t dcError = dc1394_camera_set_broadcast(_cameraHandler->camera, YES);
    if (dcError == DC1394_SUCCESS) {
        block();
        
        dcError = dc1394_camera_set_broadcast(_cameraHandler->camera, NO);
    }
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

- (void) setPower: (BOOL) power {
    dc1394error_t dcError = dc1394_camera_set_power(_cameraHandler->camera, power);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

- (void) reset {
    dc1394error_t dcError = dc1394_camera_reset(_cameraHandler->camera);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
    
}


#pragma mark - Features

- (NSDictionary *)features {
    
    if (_features) return _features;
    
    NSMutableDictionary *featuresDict = [NSMutableDictionary dictionary];
    
    dc1394featureset_t features;
    dc1394error_t dcError = dc1394_feature_get_all(_cameraHandler->camera, &features);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
        return @{};
    }

    // TODO: usa camwire qui
    /*    User_handle internal_status = camwire_bus_get_userdata(_cameraHandler);
     if (!internal_status)
     {
     // TODO: error handling
     NSLog(@"");
     return @{};
     }
     
     dc1394featureset_t features = internal_status->feature_set;
     */
    
	for (dc1394feature_t i=DC1394_FEATURE_MIN; i<=DC1394_FEATURE_MAX; i++) {
        
		dc1394feature_info_t featureInfo = features.feature[i];
		
        NSString *key = @"";
        switch (i) {
            case DC1394_FEATURE_BRIGHTNESS: key= @"brightness"; break;
            case DC1394_FEATURE_EXPOSURE: key= @"exposure"; break;
            case DC1394_FEATURE_SHARPNESS: key= @"sharpness"; break;
            case DC1394_FEATURE_WHITE_BALANCE: key= @"white_balance"; break;
            case DC1394_FEATURE_HUE: key= @"hue"; break;
            case DC1394_FEATURE_SATURATION: key= @"saturation"; break;
            case DC1394_FEATURE_GAMMA: key= @"gamma"; break;
            case DC1394_FEATURE_SHUTTER: key= @"shutter"; break;
            case DC1394_FEATURE_GAIN: key= @"gain"; break;
            case DC1394_FEATURE_IRIS: key= @"iris"; break;
            case DC1394_FEATURE_FOCUS: key= @"focus"; break;
            case DC1394_FEATURE_TEMPERATURE: key= @"temperature"; break;
            case DC1394_FEATURE_TRIGGER: key= @"trigger"; break;
            case DC1394_FEATURE_TRIGGER_DELAY: key= @"trigger_delay"; break;
            case DC1394_FEATURE_WHITE_SHADING: key= @"white_shading"; break;
            case DC1394_FEATURE_FRAME_RATE: key= @"frame_rate"; break;
            case DC1394_FEATURE_ZOOM: key= @"zoom"; break;
            case DC1394_FEATURE_PAN: key= @"pan"; break;
            case DC1394_FEATURE_TILT: key= @"tilt"; break;
            case DC1394_FEATURE_OPTICAL_FILTER: key= @"optical_filter"; break;
            case DC1394_FEATURE_CAPTURE_SIZE: key= @"capture_size"; break;
            case DC1394_FEATURE_CAPTURE_QUALITY: key= @"capture_quality"; break;
                
            default:
                break;
        }
        
        NSDictionary *curFeatureDict = @{@"feature_index" : @(i),
                                         @"min_value" : @(featureInfo.min),
                                         @"max_value" : @(featureInfo.max)};
        
        // TODO: save value in another place
        // @"value" : @(featureInfo.value)
        
		int j;
        
        bool supported = false, automode=false, oneShotAuto = false;
		for (j=0; j<featureInfo.modes.num; j++) {
			if (DC1394_FEATURE_MODE_MANUAL == featureInfo.modes.modes[j]) {
                supported = true;
            }
			else if (DC1394_FEATURE_MODE_AUTO == featureInfo.modes.modes[j]) {
                automode=true;
            } else if (DC1394_FEATURE_MODE_ONE_PUSH_AUTO == featureInfo.modes.modes[j]) {
                oneShotAuto=true;
            }
		}
        
        if ((featureInfo.available == 1) && supported) {
            if (automode) {
                bool curMode= featureInfo.current_mode == DC1394_FEATURE_MODE_AUTO;
                [curFeatureDict setValue: @(curMode) forKey: @"auto"];
            }
            if (oneShotAuto) {
                [curFeatureDict setValue: @YES forKey: @"onePushAuto"];
            }
            [featuresDict setValue: curFeatureDict forKey: key];
        }
		// we try setting to 'auto' even if this feature doesn't have a manual mode on this camera
		//[self setFeatureWithIndex:i toAutoMode:YES];
	}
    
    _features = featuresDict;
    
    return _features;
}

#pragma mark - properties

-(NSString *)deviceIdentifier {
	
    dc1394camera_t *camera = self.cameraHandler->camera;
    
	NSString* cameraName = nil;
	if (NULL != camera->model && NULL != camera->vendor)
		cameraName = [NSString stringWithFormat:@"%s (%s)", camera->model, camera->vendor];
	else if (NULL != camera->model)
		cameraName = @(camera->model);
	else if (NULL != camera->vendor)
		cameraName = [NSString stringWithFormat: @"Unknown camera (%s)", camera->vendor];
	
	return cameraName;

}

NSDictionary *resolutionDictionary (float width, float height, NSString* color_mode)
{
    return @{
             @"width" : @(width),
             @"height" : @(height),
             @"color_mode" : color_mode };
}


- (NSArray *)videomodes
{
    if (_videomodes) return _videomodes;
    
    int i;
    
    dc1394video_modes_t list;
    dc1394camera_t *camera = self.cameraHandler->camera;

    if (DC1394_SUCCESS != dc1394_video_get_supported_modes(camera, &list))
        return nil;
    
    NSMutableArray *videomodesArray = [NSMutableArray array];
    
    
    
    int j;
    for (j=0; j<list.num; j++) {
        NSDictionary *curresolutionDictionary;
        switch(list.modes[j]) {
            case DC1394_VIDEO_MODE_320x240_YUV422:
                curresolutionDictionary = resolutionDictionary (320., 240., @"YUV422"); break;
                break;
            case DC1394_VIDEO_MODE_640x480_RGB8:
                curresolutionDictionary = resolutionDictionary (640., 480., @"RGB8"); break;
            case DC1394_VIDEO_MODE_640x480_MONO8:
                curresolutionDictionary = resolutionDictionary (640., 480., @"MONO8"); break;
            case DC1394_VIDEO_MODE_640x480_MONO16:
                curresolutionDictionary = resolutionDictionary (640., 480., @"MONO16"); break;
            case DC1394_VIDEO_MODE_640x480_YUV422:
                curresolutionDictionary = resolutionDictionary (640., 480., @"YUV422"); break;
            case DC1394_VIDEO_MODE_640x480_YUV411:
                curresolutionDictionary = resolutionDictionary (640., 480., @"YUV411"); break;
            case DC1394_VIDEO_MODE_160x120_YUV444:
                curresolutionDictionary = resolutionDictionary (160., 120., @"YUV444"); break;
            case DC1394_VIDEO_MODE_800x600_RGB8:
                curresolutionDictionary = resolutionDictionary (800., 600., @"RGB8"); break;
            case DC1394_VIDEO_MODE_800x600_MONO8:
                curresolutionDictionary = resolutionDictionary (800., 600., @"MONO8"); break;
            case DC1394_VIDEO_MODE_800x600_MONO16:
                curresolutionDictionary = resolutionDictionary (800., 600., @"MONO16"); break;
            case DC1394_VIDEO_MODE_800x600_YUV422:
                curresolutionDictionary = resolutionDictionary (800., 600., @"YUV422"); break;
            case DC1394_VIDEO_MODE_1024x768_RGB8:
                curresolutionDictionary = resolutionDictionary (1024., 768., @"RGB8"); break;
            case DC1394_VIDEO_MODE_1024x768_MONO8:
                curresolutionDictionary = resolutionDictionary (1024., 768., @"MONO8"); break;
            case DC1394_VIDEO_MODE_1024x768_MONO16:
                curresolutionDictionary = resolutionDictionary (1024., 768., @"MONO16"); break;
            case DC1394_VIDEO_MODE_1024x768_YUV422:
                curresolutionDictionary = resolutionDictionary (1024., 768., @"YUV422"); break;
            case DC1394_VIDEO_MODE_1280x960_RGB8:
                curresolutionDictionary = resolutionDictionary (1280., 960., @"RGB8"); break;
            case DC1394_VIDEO_MODE_1280x960_MONO8:
                curresolutionDictionary = resolutionDictionary (1280., 960., @"MONO8"); break;
            case DC1394_VIDEO_MODE_1280x960_MONO16:
                curresolutionDictionary = resolutionDictionary (1280., 960., @"MONO16"); break;
            case DC1394_VIDEO_MODE_1280x960_YUV422:
                curresolutionDictionary = resolutionDictionary (1280., 960., @"YUV422"); break;
            case DC1394_VIDEO_MODE_1600x1200_RGB8:
                curresolutionDictionary = resolutionDictionary (1600., 1200., @"RGB8"); break;
            case DC1394_VIDEO_MODE_1600x1200_MONO8:
                curresolutionDictionary = resolutionDictionary (1600., 1200., @"MONO8"); break;
            case DC1394_VIDEO_MODE_1600x1200_MONO16:
                curresolutionDictionary = resolutionDictionary (1600., 1200., @"MONO16"); break;
            case DC1394_VIDEO_MODE_1600x1200_YUV422:
                curresolutionDictionary = resolutionDictionary (1600., 1200., @"YUV422"); break;
            default:
                curresolutionDictionary = resolutionDictionary (0., 0., @"Not supported yet"); break;
        }
        curresolutionDictionary = [curresolutionDictionary mutableCopy];
        [curresolutionDictionary setValue: @(list.modes[j]) forKey:@"dc1394_videomode"];
        [curresolutionDictionary setValue: [NSString stringWithFormat: @"%@ %@x%@", [curresolutionDictionary valueForKey:@"color_mode"], [curresolutionDictionary valueForKey:@"width"], [curresolutionDictionary valueForKey:@"height"] ] forKey:@"description"];
        [videomodesArray addObject: curresolutionDictionary];
    }
    _videomodes = videomodesArray;
    return videomodesArray;
}

#pragma mark -capturing
- (BOOL)isCapturing
{
	if (NULL == self.cameraHandler)
		return NO;
	
	dc1394switch_t status;
	if (DC1394_SUCCESS != dc1394_video_get_transmission(self.cameraHandler->camera, &status))
		return NO;
	
	return (DC1394_ON == status);
}

- (BOOL)setVideoMode: (dc1394video_mode_t)videoMode
{
    BOOL wasRunning = [self isCapturing];
	if (wasRunning)
		if (![self stopCapturing:nil])
			return NO;
    dc1394error_t err = dc1394_video_set_mode(self.cameraHandler->camera, videoMode);
    if (wasRunning) {
		if (![self startCapturing:nil])
			return NO;
	}
	return (DC1394_SUCCESS == err);
}

- (BOOL)startCapturing:(NSError**)error
{
	NSError* dummy;
	
	@synchronized(_cameraLock) {
		if (nil != _thread || [self isCapturing])
			return YES;
        
		_thread = [[NSThread alloc] initWithTarget:self
										  selector:@selector(_videoCaptureThread)
											object:nil];
		[_thread start];
        
		[self performSelector:@selector(_setupCapture:)
					 onThread:_thread
				   withObject:[NSValue valueWithPointer:error]
				waitUntilDone:YES];
		
		if (nil != *error) {
			[_thread cancel];
			_thread = nil;
			
			return NO;
		}
	}
    
	return YES;
}

- (BOOL)stopCapturing:(NSError**)error
{
    if (![self isCapturing])
        return YES;
    
	return YES;
}


- (void)_setupCapture:(NSError**)error
{
    dc1394camera_t *c_handle = self.cameraHandler->camera;
    
    if (camwire_create(c_handle) != CAMWIRE_SUCCESS)
    { // TODO: error handling
/*        *error = [NSError errorWithDomain:SICErrorDomain
                                     code:SICErrorDc1394CaptureSetupFailed
                                 userInfo:@{NSLocalizedDescriptionKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorDesc", @"TFDc1394CaptureSetupErrorDesc"),
                                            NSLocalizedFailureReasonErrorKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorReason", @"TFDc1394CaptureSetupErrorReason"),
                                            NSLocalizedRecoverySuggestionErrorKey: TFLocalizedString(@"TFDc1394CaptureSetupErrorRecovery", @"TFDc1394CaptureSetupErrorRecovery"),
                                            NSStringEncodingErrorKey: @(NSUTF8StringEncoding)}];*/
        return;
    
    }
    
    // TODO:
    
    // Reads the camera's parameters and default values
    // get_camera_settings(c_handle, &settings);
    
    //Sets default values to the non-camera paramenters
    // default_noncamera_settings(&settings);
    
	dc1394_capture_schedule_with_runloop(c_handle,
										 [[NSRunLoop currentRunLoop] getCFRunLoop],
										 kCFRunLoopDefaultMode);
    

}

- (void)_stopCapture:(NSError**)error
{
    dc1394camera_t *camera = self.cameraHandler->camera;
	
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

            }
        } while (![[NSThread currentThread] isCancelled]);
        
        _thread = nil;
        
    }
}

static void libdc1394_frame_callback(dc1394camera_t* c_handle, void* data)
{
    void *capturebuffer = NULL;
    @autoreleasepool {
        
        /* Get and display the next frame:*/
        /* Avoid getting blocked if not running.*/
     if (camwire_point_next_frame(c_handle, &capturebuffer,
                                  NULL) != CAMWIRE_SUCCESS) {
         // TODO: error handling
         
     }
           /* errorexit(c_handle, current_cam,
                      "Could not point to the next frame.");*/
        
/*        // Display:
        if (NULL != frame) {
            [(__bridge IIDCCamera*)data dispatchFrame:frame];
            dc1394_capture_enqueue(c, frame);
        }*/
        
        camwire_unpoint_frame(c_handle);
        manage_buffer_level(c_handle, NULL);
        
    }
    

}

@end
