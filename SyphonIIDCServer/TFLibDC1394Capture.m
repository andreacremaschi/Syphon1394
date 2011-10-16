//
//  TFLibDC1394Capture.m
//  Touché
//
//  Created by Georg Kaindl on 13/5/08.
//
//  Copyright (C) 2008 Georg Kaindl
//
//  This file is part of Touché.
//
//  Touché is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as
//  published by the Free Software Foundation, either version 3 of
//  the License, or (at your option) any later version.
//
//  Touché is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with Touché. If not, see <http://www.gnu.org/licenses/>.
//
//

#import "TFLibDC1394Capture.h"
#import "TFLibDC1394Capture+CIImageFromDc1394Frame.h"

#import <dc1394/macosx/capture.h>

#import "TFIncludes.h"
#import "TFThreadMessagingQueue.h"
//#import "TFPerformanceTimer.h"

#define NUM_DMA_BUFFERS					(10)
#define MAX_FEATURE_KEY					(4)
#define SECONDS_IN_RUNLOOP				(1)

static void libdc1394_frame_callback(dc1394camera_t* c, void* data);

static NSMutableDictionary* _allocatedTFLibDc1394CaptureObjects = nil;

@interface TFLibDC1394Capture (NonPublicMethods)
+ (BOOL)_camera:(dc1394camera_t*)camera supportsResolution:(CGSize)resolution;
- (void)_freeCamera;
+ (NSString*)_displayNameForCamera:(dc1394camera_t*)camera;
- (dc1394feature_t)_featureFromKey:(NSInteger)featureKey;
+ (NSArray*)_supportedVideoModesForFrameSize:(CGSize)frameSize forCamera:(dc1394camera_t*)cam error:(NSError**)error;
+ (BOOL)_getFrameRatesForCamera:(dc1394camera_t*)cam atVideoMode:(dc1394video_mode_t)videoMode intoFramerates:(dc1394framerates_t*)frameRates;
+ (NSNumber*)_bestVideoModeForCamera:(dc1394camera_t*)cam frameSize:(CGSize)frameSize frameRate:(dc1394framerate_t*)frameRate error:(NSError**)error;
- (NSArray*)_supportedVideoModesForFrameSize:(CGSize)frameSize error:(NSError**)error;
- (void)_setupCapture:(NSValue*)errPointer;
- (void)_stopCapture:(NSValue*)errPointer;
- (void)_videoCaptureThread;
@end

@implementation TFLibDC1394Capture

+ (void)initialize
{
	_allocatedTFLibDc1394CaptureObjects = [[NSMutableDictionary alloc] init];
}

- (void)dealloc
{
	if ([self isCapturing])
		[self stopCapturing:NULL];

	[self _freeCamera];
	
	[_threadLock release];
	_threadLock = nil;
	
	[_cameraLock release];
	_cameraLock = nil;
	
	if (NULL != _pixelBufferPool) {
		CVPixelBufferPoolRelease(_pixelBufferPool);
		_pixelBufferPool = NULL;
	}

	if (NULL != _dc) {
		dc1394_free(_dc);
		_dc = NULL;
	}
	
	[self cleanUpCIImageCreator];
	
	[super dealloc];
}

- (id)initWithCameraUniqueId:(NSNumber*)uid
{
	return [self initWithCameraUniqueId:uid error:nil];
}

- (id)initWithCameraUniqueId:(NSNumber*)uid error:(NSError**)error
{
	if (!(self = [super init])) {
		[self release];
		return nil;
	}

	if (nil == uid)
		uid = [[self class] defaultCameraUniqueId];
	
	if (nil == uid) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394NoDeviceFound
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394NoDeviceErrorDesc", @"TFDc1394NoDeviceErrorDesc"),
												NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394NoDeviceErrorReason", @"TFDc1394NoDeviceErrorReason"),
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394NoDeviceErrorRecovery", @"TFDc1394NoDeviceErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];

		[self release];
		return nil;
	}
	
	_dc = dc1394_new();
	if (NULL == _dc) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394LibInstantiationFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorDesc", @"TFDc1394LibInstantiationFailedErrorDesc"),
												NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorReason", @"TFDc1394LibInstantiationFailedErrorReason"),
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorRecovery", @"TFDc1394LibInstantiationFailedErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];

		[self release];
		return nil;
	}
	
	_currentFrameRate = 0;
	_pixelBufferPoolNeedsUpdating = YES;
	
	_threadLock = [[NSLock alloc] init];
	_cameraLock = [[NSLock alloc] init];
	
	if (![self setCameraToCameraWithUniqueId:uid error:error]) {
		[self release];
		return nil;
	}
	
	if (NULL != error)
		*error = nil;
	
	return self;
}

- (void)_freeCamera
{
	if (NULL == _camera)
		return;

	if ([self isCapturing])
		[self stopCapturing:NULL];
		
	if (NULL != _camera) {
		NSNumber* guid = [NSNumber numberWithUnsignedLongLong:_camera->guid];
		
		@synchronized(_cameraLock) {
			dc1394_camera_reset(_camera);
			dc1394_camera_set_power(_camera, DC1394_OFF);
			dc1394_camera_free(_camera);
			_camera = NULL;
		}
					
		@synchronized(_allocatedTFLibDc1394CaptureObjects) {
			[_allocatedTFLibDc1394CaptureObjects removeObjectForKey:guid];
		}
	}
}

- (BOOL)setCameraToCameraWithUniqueId:(NSNumber*)uid error:(NSError**)error;
{
	if (NULL != error)
		*error = nil;
		
	if (NULL != _camera && [uid unsignedLongLongValue] == _camera->guid)
		return YES;
	
	BOOL wasRunning = [self isCapturing];
	BOOL hadCamera = (NULL != _camera);
	CGSize frameSize;

	if (hadCamera) {
		frameSize = [self frameSize];
		[self stopCapturing:NULL];
		[self _freeCamera];
	}
	
	id c;
	@synchronized(_allocatedTFLibDc1394CaptureObjects) {
		c = [_allocatedTFLibDc1394CaptureObjects objectForKey:uid];
	}
	
	if (nil != c) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394CameraAlreadyInUse
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394CameraInUseErrorDesc", @"TFDc1394CameraInUseErrorDesc"),
											   NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394CameraInUseErrorReason", @"TFDc1394CameraInUseErrorReason"),
											   NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394CameraInUseErrorRecovery", @"TFDc1394CameraInUseErrorRecovery"),
											   NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
											   NSStringEncodingErrorKey,
											   nil]];

		return NO;
	}

	_camera = dc1394_camera_new(_dc, [uid unsignedLongLongValue]);
	if (NULL == _camera) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394CameraCreationFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394CameraCreationErrorDesc", @"TFDc1394CameraCreationErrorDesc"),
												NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394CameraCreationErrorReason", @"TFDc1394CameraCreationErrorReason"),
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394CameraCreationErrorRecovery", @"TFDc1394CameraCreationErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];
	
		return NO;
	}
	
	dc1394_camera_reset(_camera);
	dc1394_camera_set_power(_camera, DC1394_ON);
	
	// turn off the camera's ISO if it's running
	dc1394_video_set_transmission(_camera, DC1394_OFF);
	
	// if the camera's currently set ISO speed is < 400MB/S, we set it to 400MB/S
	dc1394speed_t isoSpeed;
	dc1394_video_get_iso_speed(_camera, &isoSpeed);	
	if (isoSpeed < DC1394_ISO_SPEED_400)
		dc1394_video_set_iso_speed(_camera, DC1394_ISO_SPEED_400);
	
	int i;
	for (i=0; i<=MAX_FEATURE_KEY; i++) {
		dc1394feature_t currentFeature = [self _featureFromKey:i];
		
		dc1394feature_info_t featureInfo;
		featureInfo.id = currentFeature;
		
		_supportedFeatures[i] = NO;
		_automodeFeatures[i] = NO;
		
		if (DC1394_SUCCESS != dc1394_feature_get(_camera, &featureInfo))
			continue;
		
		int j;
		for (j=0; j<featureInfo.modes.num; j++)
			if (DC1394_FEATURE_MODE_MANUAL == featureInfo.modes.modes[j])
				_supportedFeatures[i] = YES;
			else if (DC1394_FEATURE_MODE_AUTO == featureInfo.modes.modes[j])
				_automodeFeatures[i] = YES;
		
		if (_supportedFeatures[i]) {
			_featureMinMax[i][0] = featureInfo.min;
			_featureMinMax[i][1] = featureInfo.max;
		}
		
		// we try setting to 'auto' even if this feature doesn't have a manual mode on this camera
		[self setFeature:i toAutoMode:YES];
	}
	
	// store self, so we can access this camera's properties via class methods, too
	@synchronized(_allocatedTFLibDc1394CaptureObjects) {
		// we go via NSValue because we do not want to be retained ourselves...
		[_allocatedTFLibDc1394CaptureObjects setObject:[NSValue valueWithPointer:self] forKey:uid];
	}
	
	// get the default video mode and supported framerates for this mode (no error if we fail here...)
	dc1394_video_get_mode(_camera, &_currentVideoMode);
	dc1394_video_get_supported_framerates(_camera, _currentVideoMode, &_frameratesForCurrentVideoMode);
	dc1394_video_get_framerate(_camera, &_currentFrameRate);
	
	_pixelBufferPoolNeedsUpdating = YES;
	
	if (hadCamera) {
		if (![self setFrameSize:frameSize error:NULL])
			[self setFrameSize:[[self class] defaultResolutionForCameraWithUniqueId:uid] error:NULL];
	}
	
	BOOL success = YES;
	if (wasRunning)
		success = [self startCapturing:error];
	
	return success;
}

- (BOOL)featureIsMutable:(NSInteger)feature
{
	if (feature <= MAX_FEATURE_KEY)
		return _supportedFeatures[feature];
	
	return NO;
}

- (BOOL)featureSupportsAutoMode:(NSInteger)feature
{
	if (feature <= MAX_FEATURE_KEY)
		return _automodeFeatures[feature];
	
	return NO;
}

- (BOOL)featureInAutoMode:(NSInteger)feature
{
	dc1394feature_t f = [self _featureFromKey:feature];
	dc1394feature_mode_t mode;
	
	if (DC1394_SUCCESS != dc1394_feature_get_mode(_camera, f, &mode))
		return NO;
	
	return (DC1394_FEATURE_MODE_AUTO == mode);
}

- (BOOL)setFeature:(NSInteger)feature toAutoMode:(BOOL)val
{
	dc1394feature_t f = [self _featureFromKey:feature];
	dc1394feature_mode_t mode = val ? DC1394_FEATURE_MODE_AUTO : DC1394_FEATURE_MODE_MANUAL;
	
	return (DC1394_SUCCESS == dc1394_feature_set_mode(_camera, f, mode));
}

- (float)valueForFeature:(NSInteger)feature
{
	dc1394feature_t f = [self _featureFromKey:feature];
	unsigned val;
	
	if (DC1394_SUCCESS != dc1394_feature_get_value(_camera, f, (void*)&val))
		return 0.0f;
	
	return ((float)val - (float)_featureMinMax[feature][0]) /
			((float)_featureMinMax[feature][1] - (float)_featureMinMax[feature][0]);
}

- (BOOL)setFeature:(NSInteger)feature toValue:(float)val
{
	if (!_supportedFeatures[feature])
		return NO;
	
	dc1394feature_t f = [self _featureFromKey:feature];
	dc1394feature_mode_t mode;
	dc1394bool_t isSwitchable;
	
	if (DC1394_SUCCESS != dc1394_feature_is_switchable(_camera, f, &isSwitchable))
		return NO;
	
	if (isSwitchable) {
		dc1394switch_t isSwitched;
		
		if (DC1394_SUCCESS != dc1394_feature_get_power(_camera, f, &isSwitched))
			return NO;
		
		if (DC1394_ON != isSwitched) {
			isSwitched = DC1394_ON;
			
			if (DC1394_SUCCESS != dc1394_feature_set_power(_camera, f, DC1394_ON))
				return NO;
		}
	}
	
	if (DC1394_SUCCESS != dc1394_feature_get_mode(_camera, f, &mode))
		return NO;
	
	if (DC1394_FEATURE_MODE_MANUAL != mode &&
		DC1394_SUCCESS != dc1394_feature_set_mode(_camera, f, DC1394_FEATURE_MODE_MANUAL))
		return NO;
	
	UInt32 newVal = _featureMinMax[feature][0] + val*(_featureMinMax[feature][1]-_featureMinMax[feature][0]);
	
	if (DC1394_SUCCESS != dc1394_feature_set_value(_camera, f, newVal))
		return NO;
	
	return YES;
}

- (dc1394camera_t*)cameraStruct
{
	return _camera;
}

- (NSNumber*)cameraUniqueId
{
	NSNumber* uid = nil;
	
	if (NULL != _camera)
		uid = [NSNumber numberWithUnsignedLongLong:_camera->guid];
	
	return uid;
}

- (NSString*)cameraDisplayName
{
	return [[self class] _displayNameForCamera:_camera];
}

- (BOOL)isCapturing
{
	if (NULL == _camera)
		return NO;
	
	dc1394switch_t status;
	if (DC1394_SUCCESS != dc1394_video_get_transmission(_camera, &status))
		return NO;
	
	return (DC1394_ON == status);
}

- (BOOL)startCapturing:(NSError**)error
{
	NSError* dummy;
	if (NULL != error)
		*error = nil;
	else
		error = &dummy;
	
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
			[_thread release];
			_thread = nil;
			
			[*error autorelease];
			return NO;
		}
	}
		
	return [super startCapturing:error];
}

- (BOOL)stopCapturing:(NSError**)error
{
	NSError* dummy;
	if (NULL != error)
		*error = nil;
	else
		error = &dummy;

	@synchronized(_cameraLock) {
		if (nil == _thread || ![self isCapturing])
			return YES;
	
		[self performSelector:@selector(_stopCapture:)
					 onThread:_thread
				   withObject:[NSValue valueWithPointer:error]
				waitUntilDone:YES];
		
		// wait for the thread to exit
		@synchronized (_threadLock) {
			[_thread release];
			_thread = nil;
		}
	}
	
	BOOL success = [super stopCapturing:error];
				
	if (nil != *error) {
		[*error autorelease];
		return NO;
	}
		
	return success;
}

- (void)_setupCapture:(NSValue*)errPointer
{	
	NSError** error = [errPointer pointerValue];
	
	if (NULL != error)
		*error = nil;

	// just to be sure!
	dc1394video_mode_t mode;
	dc1394framerate_t framerate;
	dc1394_video_get_mode(_camera, &mode);
	dc1394_video_get_framerate(_camera, &framerate);
	dc1394_video_set_mode(_camera, mode);
	dc1394_video_set_framerate(_camera, mode);

	dc1394_capture_schedule_with_runloop(_camera,
										 [[NSRunLoop currentRunLoop] getCFRunLoop],
										 kCFRunLoopDefaultMode);
	dc1394_capture_set_callback(_camera, libdc1394_frame_callback, self);

	dc1394error_t err;
	err = dc1394_capture_setup(_camera,
								NUM_DMA_BUFFERS,
								DC1394_CAPTURE_FLAGS_DEFAULT | DC1394_CAPTURE_FLAGS_AUTO_ISO);
		
	if (err != DC1394_SUCCESS) {
		if (NULL != error)
			*error = [[NSError errorWithDomain:SICErrorDomain
										  code:SICErrorDc1394CaptureSetupFailed
									  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												TFLocalizedString(@"TFDc1394CaptureSetupErrorDesc", @"TFDc1394CaptureSetupErrorDesc"),
													NSLocalizedDescriptionKey,
												TFLocalizedString(@"TFDc1394CaptureSetupErrorReason", @"TFDc1394CaptureSetupErrorReason"),
													NSLocalizedFailureReasonErrorKey,
												TFLocalizedString(@"TFDc1394CaptureSetupErrorRecovery", @"TFDc1394CaptureSetupErrorRecovery"),
													NSLocalizedRecoverySuggestionErrorKey,
												[NSNumber numberWithInteger:NSUTF8StringEncoding],
													NSStringEncodingErrorKey,
												nil]] retain];
		
		return;
	}
	
	if (DC1394_SUCCESS != dc1394_video_set_transmission(_camera, DC1394_ON)) {
		dc1394_capture_stop(_camera);
		
		if (NULL != error)
			*error = [[NSError errorWithDomain:SICErrorDomain
										  code:SICErrorDc1394SetTransmissionFailed
									  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												TFLocalizedString(@"TFDc1394SetTransmissionErrorDesc", @"TFDc1394SetTransmissionErrorDesc"),
													NSLocalizedDescriptionKey,
												TFLocalizedString(@"TFDc1394SetTransmissionErrorReason", @"TFDc1394SetTransmissionErrorReason"),
													NSLocalizedFailureReasonErrorKey,
												TFLocalizedString(@"TFDc1394SetTransmissionErrorRecovery", @"TFDc1394SetTransmissionErrorRecovery"),
													NSLocalizedRecoverySuggestionErrorKey,
												[NSNumber numberWithInteger:NSUTF8StringEncoding],
													NSStringEncodingErrorKey,
											   nil]] retain];
		
		return;
	}
}

- (void)_stopCapture:(NSValue*)errPointer
{
	NSError** error = [errPointer pointerValue];
	
	if (NULL != error)
		*error = nil;
		
	[_thread cancel];
	
	dc1394error_t transmissionErr, captureErr;
	transmissionErr = dc1394_video_set_transmission(_camera, DC1394_OFF);
	captureErr = dc1394_capture_stop(_camera);
	
	dc1394_iso_release_all(_camera);
		
	if (DC1394_SUCCESS != transmissionErr) {
		if (NULL != error)
			*error = [[NSError errorWithDomain:SICErrorDomain
										  code:SICErrorDc1394StopTransmissionFailed
									  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												TFLocalizedString(@"TFDc1394StopTransmissionErrorDesc", @"TFDc1394StopTransmissionErrorDesc"),
													NSLocalizedDescriptionKey,
												TFLocalizedString(@"TFDc1394StopTransmissionErrorReason", @"TFDc1394StopTransmissionErrorReason"),
													NSLocalizedFailureReasonErrorKey,
												TFLocalizedString(@"TFDc1394StopTransmissionErrorRecovery", @"TFDc1394StopTransmissionErrorRecovery"),
													NSLocalizedRecoverySuggestionErrorKey,
												[NSNumber numberWithInteger:NSUTF8StringEncoding],
													NSStringEncodingErrorKey,
											   nil]] retain];

		return;
	}
	
	if (DC1394_SUCCESS != captureErr) {
		if (NULL != error)
			*error = [[NSError errorWithDomain:SICErrorDomain
										  code:SICErrorDc1394StopCapturingFailed
									  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												TFLocalizedString(@"TFDc1394StopCapturingErrorDesc", @"TFDc1394StopCapturingErrorDesc"),
													NSLocalizedDescriptionKey,
												TFLocalizedString(@"TFDc1394StopCapturingErrorReason", @"TFDc1394StopCapturingErrorReason"),
													NSLocalizedFailureReasonErrorKey,
												TFLocalizedString(@"TFDc1394StopCapturingErrorRecovery", @"TFDc1394StopCapturingErrorRecovery"),
													NSLocalizedRecoverySuggestionErrorKey,
												[NSNumber numberWithInteger:NSUTF8StringEncoding],
													NSStringEncodingErrorKey,
											   nil]] retain];
		
		return;
	}
}

- (CGSize)frameSize
{
	dc1394video_mode_t currentMode;
	dc1394error_t err = dc1394_video_get_mode(_camera, &currentMode);
	
	if (DC1394_SUCCESS != err)
		return CGSizeMake(0.0f, 0.0f);
	
	switch (currentMode) {
		case DC1394_VIDEO_MODE_160x120_YUV444:
			return CGSizeMake(160.0f, 120.0f);
		case DC1394_VIDEO_MODE_320x240_YUV422:
			return CGSizeMake(320.0f, 240.0f);
		case DC1394_VIDEO_MODE_640x480_YUV411:
		case DC1394_VIDEO_MODE_640x480_YUV422:
		case DC1394_VIDEO_MODE_640x480_RGB8:
		case DC1394_VIDEO_MODE_640x480_MONO8:
		case DC1394_VIDEO_MODE_640x480_MONO16:
			return CGSizeMake(640.0f, 480.0f);
		case DC1394_VIDEO_MODE_800x600_YUV422:
		case DC1394_VIDEO_MODE_800x600_RGB8:
		case DC1394_VIDEO_MODE_800x600_MONO8:
		case DC1394_VIDEO_MODE_800x600_MONO16:
			return CGSizeMake(800.0f, 600.0f);
		case DC1394_VIDEO_MODE_1024x768_YUV422:
		case DC1394_VIDEO_MODE_1024x768_RGB8:
		case DC1394_VIDEO_MODE_1024x768_MONO8:
		case DC1394_VIDEO_MODE_1024x768_MONO16:
			return CGSizeMake(1024.0f, 768.0f);
		case DC1394_VIDEO_MODE_1280x960_YUV422:
		case DC1394_VIDEO_MODE_1280x960_RGB8:
		case DC1394_VIDEO_MODE_1280x960_MONO8:
		case DC1394_VIDEO_MODE_1280x960_MONO16:
			return CGSizeMake(1280.0f, 960.0f);
		case DC1394_VIDEO_MODE_1600x1200_YUV422:
		case DC1394_VIDEO_MODE_1600x1200_RGB8:
		case DC1394_VIDEO_MODE_1600x1200_MONO8:
		case DC1394_VIDEO_MODE_1600x1200_MONO16:
			return CGSizeMake(1600.0f, 1200.0f);
	}
	
	return CGSizeMake(0.0f, 0.0f);
}

- (BOOL)setFrameSize:(CGSize)size error:(NSError**)error
{
	dc1394framerate_t newFrameRate = _currentFrameRate;
	NSNumber* videoMode = [[self class] _bestVideoModeForCamera:_camera
													  frameSize:size
													  frameRate:&newFrameRate
														  error:error];

	if (nil == videoMode) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394ResolutionChangeFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394ResolutionChangeErrorDesc", @"TFDc1394ResolutionChangeErrorDesc"),
												NSLocalizedDescriptionKey,
											   [NSString stringWithFormat:TFLocalizedString(@"TFDc1394ResolutionChangeErrorReason", @"TFDc1394ResolutionChangeErrorReason"),
												size.width, size.height],
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394ResolutionChangeErrorRecovery", @"TFDc1394ResolutionChangeErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];

		return NO;
	}
			
	BOOL wasRunning = [self isCapturing];
	if (wasRunning)
		if (![self stopCapturing:error])
			return NO;

	dc1394error_t err = dc1394_video_set_mode(_camera, [videoMode intValue]);
	if (DC1394_SUCCESS != err) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394ResolutionChangeFailedInternalError
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394ResolutionChangeInternalErrorDesc", @"TFDc1394ResolutionChangeInternalErrorDesc"),
											   NSLocalizedDescriptionKey,
											   [NSString stringWithFormat:TFLocalizedString(@"TFDc1394ResolutionChangeInternalErrorReason", @"TFDc1394ResolutionChangeInternalErrorReason"),
												size.width, size.height],
											   NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394ResolutionChangeInternalErrorRecovery", @"TFDc1394ResolutionChangeInternalErrorRecovery"),
											   NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
											   NSStringEncodingErrorKey,
											   nil]];

		return NO;
	}
	
	_currentVideoMode = [videoMode intValue];
	dc1394_video_get_supported_framerates(_camera, _currentVideoMode, &_frameratesForCurrentVideoMode);
	
	if (newFrameRate != _currentFrameRate) {
		if (DC1394_SUCCESS != dc1394_video_set_framerate(_camera, newFrameRate)) {
		} else
			_currentFrameRate = newFrameRate;
	}
	
	dc1394_video_get_framerate(_camera, &_currentFrameRate);
	_pixelBufferPoolNeedsUpdating = YES;
	
	if (wasRunning) {
		if (![self startCapturing:error])
			return NO;
	}
	
	return YES;
}

- (BOOL)setMinimumFramerate:(NSUInteger)frameRate
{	
	if (NULL == _camera)
		return NO;

	dc1394framerate_t minFPS;
	
	if (frameRate <= 15)
		minFPS = DC1394_FRAMERATE_15;
	else if (frameRate <= 30)
		minFPS = DC1394_FRAMERATE_30;
	else if (frameRate <= 60)
		minFPS = DC1394_FRAMERATE_60;
	else if (frameRate <= 120)
		minFPS = DC1394_FRAMERATE_120;
	else if (frameRate <= 240)
		minFPS = DC1394_FRAMERATE_240;
	else
		return NO;
	
	if (_currentFrameRate == minFPS)
		return YES;
	
	// try to find a video mode at the same resolution that offers minFPS or at least a better
	// framerate than the current framerate
	dc1394framerate_t betterFPS = minFPS;
	NSNumber* betterVideoMode = [[self class] _bestVideoModeForCamera:_camera
															frameSize:[self frameSize]
															frameRate:&betterFPS
																error:NULL];
	
	if (nil != betterVideoMode) {
		if (betterFPS >= minFPS || (betterFPS < minFPS && _currentFrameRate < betterFPS)) {
			BOOL wasRunning = [self isCapturing];
			
			if (wasRunning)
				[self stopCapturing:NULL];
			
			BOOL success = (DC1394_SUCCESS == dc1394_video_set_mode(_camera, [betterVideoMode intValue]));
			if (success)
				success = (DC1394_SUCCESS == dc1394_video_set_framerate(_camera, betterFPS));
			
			if (wasRunning)
				[self startCapturing:NULL];
						
			if (success)
				_currentFrameRate = betterFPS;
			
			_pixelBufferPoolNeedsUpdating = YES;
			
			return success;
		}
	}
		
	return NO;
}

- (BOOL)supportsFrameSize:(CGSize)size
{
	if (NULL == _camera)
		return NO;

	return [[self class] cameraWithUniqueId:[NSNumber numberWithUnsignedLongLong:_camera->guid]
						 supportsResolution:size];
}

- (void)dispatchFrame:(dc1394video_frame_t*)frame
{
//	TFPMStartTimer(TFPerformanceTimerCIImageAcquisition);

	CIImage* image = [self ciImageWithDc1394Frame:frame error:NULL];
				
	if (nil != image && _delegateCapabilities.hasDidCaptureFrame)
			[_frameQueue enqueue:image];
	
//	TFPMStopTimer(TFPerformanceTimerCIImageAcquisition);
}

- (dc1394feature_t)_featureFromKey:(NSInteger)featureKey
{
	switch (featureKey) {
		case TFLibDC1394CaptureFeatureBrightness:
			return DC1394_FEATURE_BRIGHTNESS;
		case TFLibDC1394CaptureFeatureFocus:
			return DC1394_FEATURE_FOCUS;
		case TFLibDC1394CaptureFeatureGain:
			return DC1394_FEATURE_GAIN;
		case TFLibDC1394CaptureFeatureShutter:
			return DC1394_FEATURE_SHUTTER;
		case TFLibDC1394CaptureFeatureExposure:
			return DC1394_FEATURE_EXPOSURE;
	}
	
	return 0;
}

- (void)_videoCaptureThread
{
	@synchronized(_threadLock) {
		NSAutoreleasePool* threadPool = [[NSAutoreleasePool alloc] init];

		do {
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:SECONDS_IN_RUNLOOP]];
			[pool release];
		} while (![[NSThread currentThread] isCancelled]);
	
		[_thread release];
		_thread = nil;
		
		[threadPool release];
	}
}

+ (NSString*)_displayNameForCamera:(dc1394camera_t*)camera
{
	if (NULL == camera)
		return nil;
	
	NSString* cameraName = nil;
	if (NULL != camera->model && NULL != camera->vendor)
		cameraName = [NSString stringWithFormat:@"%s (%s)", camera->model, camera->vendor];
	else if (NULL != camera->model)
		cameraName = [NSString stringWithUTF8String:camera->model];
	else if (NULL != camera->vendor)
		cameraName = [NSString stringWithFormat:TFLocalizedString(@"UnknownDV1394CameraWithVendor",
																  @"Unknown camera (%s)"), camera->vendor];
	
	return cameraName;
}

+ (NSDictionary*)connectedCameraNamesAndUniqueIds
{
	dc1394_t* dc = dc1394_new();
	dc1394camera_list_t* list;
	
	if (DC1394_SUCCESS != dc1394_camera_enumerate(dc, &list)) {
		dc1394_free(dc);
		
		return [NSDictionary dictionary];
	}
	
	if (NULL == list || 0 >= list->num) {
		dc1394_camera_free_list(list);
		dc1394_free(dc);
	
		return [NSDictionary dictionary];
	}
	
	NSMutableDictionary* cameras = [NSMutableDictionary dictionary];
	int i;
	for (i=0; i<list->num; i++) {
		@synchronized(_allocatedTFLibDc1394CaptureObjects) {
			if (nil != [_allocatedTFLibDc1394CaptureObjects objectForKey:[NSNumber numberWithUnsignedLongLong:list->ids[i].guid]])
				continue;
		}
		
		dc1394camera_t* cam = dc1394_camera_new(dc, list->ids[i].guid);
		if (NULL == cam)
			continue;

		NSString* camName = [self _displayNameForCamera:cam];
		
		if (nil != camName)
			[cameras setObject:camName forKey: [[NSNumber numberWithUnsignedLongLong:list->ids[i].guid] stringValue]];
		
		dc1394_camera_free(cam);
	}
	
	// now add the currently running cameras as well...
	@synchronized(_allocatedTFLibDc1394CaptureObjects) {
		for (NSNumber* guid in _allocatedTFLibDc1394CaptureObjects) {
			TFLibDC1394Capture* c = (TFLibDC1394Capture*)((NSValue*)[[_allocatedTFLibDc1394CaptureObjects objectForKey:guid] pointerValue]);
			NSString* camName = [c cameraDisplayName];
			if (camName)
				[cameras setObject:camName forKey:[guid stringValue]];
		}
	}
	
	dc1394_camera_free_list(list);
	dc1394_free(dc);

	return [NSDictionary dictionaryWithDictionary:cameras];
}

+ (BOOL)cameraConnectedWithGUID:(NSNumber*)guidNumber
{
	dc1394_t* dc = dc1394_new();
	dc1394camera_list_t* list;
	
	if (DC1394_SUCCESS != dc1394_camera_enumerate(dc, &list)) {
		dc1394_free(dc);
		
		return NO;
	}
	
	dc1394_free(dc);
	
	unsigned long long guid = [guidNumber unsignedLongLongValue];
	
	int i;
	for (i=0; i<list->num; i++) {
		if (list->ids[i].guid == guid)
			return YES;
	}
	
	return NO;
}

+ (NSNumber*)defaultCameraUniqueId
{
	dc1394_t* dc = dc1394_new();
	dc1394camera_list_t* list;
	
	if (DC1394_SUCCESS != dc1394_camera_enumerate(dc, &list)) {
		dc1394_free(dc);
	
		return nil;
	}
	
	NSNumber* defaultCamId = nil;
	if (NULL != list && 0 < list->num)
		defaultCamId = [NSNumber numberWithUnsignedLongLong:list->ids[0].guid];
	
	dc1394_camera_free_list(list);
	dc1394_free(dc);
	
	return defaultCamId;
}

+ (CGSize)defaultResolutionForCameraWithUniqueId:(NSNumber*)uid
{
	dc1394_t* dc = NULL;
	dc1394camera_t* cam = NULL;

	if (nil == uid)
		goto errorReturn;
	
	dc1394video_modes_t list;
	TFLibDC1394Capture* c = nil;
	@synchronized(_allocatedTFLibDc1394CaptureObjects) {
		c = (TFLibDC1394Capture*)((NSValue*)[[_allocatedTFLibDc1394CaptureObjects objectForKey:uid] pointerValue]);
	}
	
	if (nil != c) {
		if (DC1394_SUCCESS != dc1394_video_get_supported_modes([c cameraStruct], &list))
			goto errorReturn;
	} else {	
		dc = dc1394_new();
		if (NULL == dc)
			goto errorReturn;
		
		cam = dc1394_camera_new(dc, [uid unsignedLongLongValue]);
		if (NULL == cam)
			goto errorReturn2;
		
		if (DC1394_SUCCESS != dc1394_video_get_supported_modes(cam, &list))
			goto errorReturn3;
	}
	
	dc1394_camera_free(cam);
	cam = NULL;
	dc1394_free(dc);
	dc = NULL;
	
	dc1394video_mode_t wantedModes[] = {
		DC1394_VIDEO_MODE_320x240_YUV422,
		DC1394_VIDEO_MODE_640x480_RGB8,
		DC1394_VIDEO_MODE_640x480_MONO8,
		DC1394_VIDEO_MODE_640x480_MONO16,
		DC1394_VIDEO_MODE_640x480_YUV422,
		DC1394_VIDEO_MODE_640x480_YUV411,
		DC1394_VIDEO_MODE_160x120_YUV444,
		DC1394_VIDEO_MODE_800x600_RGB8,
		DC1394_VIDEO_MODE_800x600_MONO8,
		DC1394_VIDEO_MODE_800x600_MONO16,
		DC1394_VIDEO_MODE_800x600_YUV422,
		DC1394_VIDEO_MODE_1024x768_RGB8,
		DC1394_VIDEO_MODE_1024x768_MONO8,
		DC1394_VIDEO_MODE_1024x768_MONO16,
		DC1394_VIDEO_MODE_1024x768_YUV422,
		DC1394_VIDEO_MODE_1280x960_RGB8,
		DC1394_VIDEO_MODE_1280x960_MONO8,
		DC1394_VIDEO_MODE_1280x960_MONO16,
		DC1394_VIDEO_MODE_1280x960_YUV422,
		DC1394_VIDEO_MODE_1600x1200_RGB8,
		DC1394_VIDEO_MODE_1600x1200_MONO8,
		DC1394_VIDEO_MODE_1600x1200_MONO16,
		DC1394_VIDEO_MODE_1600x1200_YUV422
	};
	int numModes = 23;
	
	int i, j;
	for (i=0; i<numModes; i++) {
		for (j=0; j<list.num; j++) {
			if (wantedModes[i] == list.modes[j]) {
				switch(list.modes[j]) {
					case DC1394_VIDEO_MODE_320x240_YUV422:
						return CGSizeMake(320.0f, 240.0f);
					case DC1394_VIDEO_MODE_640x480_RGB8:
					case DC1394_VIDEO_MODE_640x480_MONO8:
					case DC1394_VIDEO_MODE_640x480_MONO16:
					case DC1394_VIDEO_MODE_640x480_YUV422:
					case DC1394_VIDEO_MODE_640x480_YUV411:
						return CGSizeMake(640.0f, 480.0f);
					case DC1394_VIDEO_MODE_160x120_YUV444:
						return CGSizeMake(160.0f, 120.0f);
					case DC1394_VIDEO_MODE_800x600_RGB8:
					case DC1394_VIDEO_MODE_800x600_MONO8:
					case DC1394_VIDEO_MODE_800x600_MONO16:
					case DC1394_VIDEO_MODE_800x600_YUV422:
						return CGSizeMake(800.0f, 600.0f);
					case DC1394_VIDEO_MODE_1024x768_RGB8:
					case DC1394_VIDEO_MODE_1024x768_MONO8:
					case DC1394_VIDEO_MODE_1024x768_MONO16:
					case DC1394_VIDEO_MODE_1024x768_YUV422:
						return CGSizeMake(1024.0f, 768.0f);
					case DC1394_VIDEO_MODE_1280x960_RGB8:
					case DC1394_VIDEO_MODE_1280x960_MONO8:
					case DC1394_VIDEO_MODE_1280x960_MONO16:
					case DC1394_VIDEO_MODE_1280x960_YUV422:
						return CGSizeMake(1280.0f, 960.0f);
					case DC1394_VIDEO_MODE_1600x1200_RGB8:
					case DC1394_VIDEO_MODE_1600x1200_MONO8:
					case DC1394_VIDEO_MODE_1600x1200_MONO16:
					case DC1394_VIDEO_MODE_1600x1200_YUV422:
						return CGSizeMake(1600.0f, 1200.0f);
				}
			}
		}
	}
	
errorReturn3:
	if (NULL != cam)
		dc1394_camera_free(cam);
errorReturn2:
	if (NULL != dc)
		dc1394_free(dc);
errorReturn:
	return CGSizeMake(0.0f, 0.0f);
}

+ (BOOL)_camera:(dc1394camera_t*)camera supportsResolution:(CGSize)resolution
{
	NSArray* supportedModes = [[self class] _supportedVideoModesForFrameSize:resolution
																   forCamera:camera
																	   error:NULL];
	
	return ([supportedModes count] > 0);
}

+ (BOOL)cameraWithUniqueId:(NSNumber*)uid supportsResolution:(CGSize)resolution
{
	if (nil == uid)
		return NO;
	
	TFLibDC1394Capture* c = nil;
	@synchronized(_allocatedTFLibDc1394CaptureObjects) {
		c = (TFLibDC1394Capture*)((NSValue*)[[_allocatedTFLibDc1394CaptureObjects objectForKey:uid] pointerValue]);
	}
	
	if (nil != c) {
		return [[self class] _camera:[c cameraStruct] supportsResolution:resolution];
	}
	
	dc1394_t* dc = dc1394_new();
	if (NULL == dc)
		return NO;
	
	dc1394camera_t* cam = dc1394_camera_new(dc, [uid unsignedLongLongValue]);
	if (NULL == cam) {
		dc1394_free(dc);
		return NO;
	}

	NSArray* supportedModes = [[self class] _supportedVideoModesForFrameSize:resolution
																   forCamera:cam
																	   error:NULL];
					
	
	dc1394_camera_free(cam);
	dc1394_free(dc);
	
	return ([supportedModes count] > 0);
}

+ (NSArray*)_supportedVideoModesForFrameSize:(CGSize)frameSize forCamera:(dc1394camera_t*)cam error:(NSError**)error
{
	if (NULL != error)
		*error = nil;
	
	dc1394_t* dc;
	NSArray* retval = nil;
	
	dc = dc1394_new();
	if (NULL == dc) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394LibInstantiationFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorDesc", @"TFDc1394LibInstantiationFailedErrorDesc"),
												NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorReason", @"TFDc1394LibInstantiationFailedErrorReason"),
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394LibInstantiationFailedErrorRecovery", @"TFDc1394LibInstantiationFailedErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];

		goto errorReturn;
	}
	
	dc1394video_modes_t list;
	dc1394error_t err = dc1394_video_get_supported_modes(cam, &list);
	if (DC1394_SUCCESS != err) {
		if (NULL != error)
			*error = [NSError errorWithDomain:SICErrorDomain
										 code:SICErrorDc1394GettingVideoModesFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											   TFLocalizedString(@"TFDc1394GettingVideoModesErrorDesc", @"TFDc1394GettingVideoModesErrorDesc"),
												NSLocalizedDescriptionKey,
											   TFLocalizedString(@"TFDc1394GettingVideoModesErrorReason", @"TFDc1394GettingVideoModesErrorReason"),
												NSLocalizedFailureReasonErrorKey,
											   TFLocalizedString(@"TFDc1394GettingVideoModesErrorRecovery", @"TFDc1394GettingVideoModesErrorRecovery"),
												NSLocalizedRecoverySuggestionErrorKey,
											   [NSNumber numberWithInteger:NSUTF8StringEncoding],
												NSStringEncodingErrorKey,
											   nil]];

		goto errorReturn2;
	}
	
	NSMutableArray* modes = [NSMutableArray array];
	int i;
	for (i=0; i<list.num; i++) {	
		if (
			(frameSize.width == 160.0f && frameSize.height == 120.0f &&
			 DC1394_VIDEO_MODE_160x120_YUV444 == list.modes[i])			||
			(frameSize.width == 320.0f && frameSize.height == 240.0f &&
			 DC1394_VIDEO_MODE_320x240_YUV422 == list.modes[i])			||
			(frameSize.width == 640.0f && frameSize.height == 480.0f &&
			 (DC1394_VIDEO_MODE_640x480_YUV411 == list.modes[i] ||
			  DC1394_VIDEO_MODE_640x480_YUV422 == list.modes[i] ||
			  DC1394_VIDEO_MODE_640x480_RGB8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_640x480_MONO8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_640x480_MONO16 == list.modes[i]))		||
			(frameSize.width == 800.0f && frameSize.height == 600.0f &&
			 (DC1394_VIDEO_MODE_800x600_YUV422 == list.modes[i] ||
			  DC1394_VIDEO_MODE_800x600_RGB8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_800x600_MONO8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_800x600_MONO16 == list.modes[i]))		||
			(frameSize.width == 1024.0f && frameSize.height == 768.0f &&
			 (DC1394_VIDEO_MODE_1024x768_YUV422 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1024x768_RGB8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1024x768_MONO8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1024x768_MONO16 == list.modes[i]))		||
			(frameSize.width == 1280.0f && frameSize.height == 960.0f &&
			 (DC1394_VIDEO_MODE_1280x960_YUV422 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1280x960_RGB8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1280x960_MONO8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1280x960_MONO16 == list.modes[i]))		||
			(frameSize.width == 1600.0f && frameSize.height == 1200.0f &&
			 (DC1394_VIDEO_MODE_1600x1200_YUV422 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1600x1200_RGB8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1600x1200_MONO8 == list.modes[i] ||
			  DC1394_VIDEO_MODE_1600x1200_MONO16 == list.modes[i]))
			) {
			[modes addObject:[NSNumber numberWithInt:list.modes[i]]];
		}
	}
	
	retval = [NSArray arrayWithArray:modes];
	
errorReturn2:
	dc1394_free(dc);
errorReturn:
	return retval;
}

+ (BOOL)_getFrameRatesForCamera:(dc1394camera_t*)cam
					atVideoMode:(dc1394video_mode_t)videoMode
				 intoFramerates:(dc1394framerates_t*)frameRates
{
	return (DC1394_SUCCESS == dc1394_video_get_supported_framerates(cam, videoMode, frameRates));
}

+ (NSNumber*)_fastestFrameRateForCamera:(dc1394camera_t*)cam videoMode:(dc1394video_mode_t)videoMode;
{
	NSNumber* fastestFrameRate = nil;
	dc1394framerates_t frameRates;
	
	if ([self _getFrameRatesForCamera:cam atVideoMode:videoMode intoFramerates:&frameRates]) {
		if (frameRates.num > 0) {
			dc1394framerate_t bestRate = frameRates.framerates[0];
			
			int i;
			for (i=0; i<frameRates.num; i++)
				if (frameRates.framerates[i] > bestRate)
					bestRate = frameRates.framerates[i];
			
			fastestFrameRate = [NSNumber numberWithInt:bestRate];
		} 
	}
	
	return fastestFrameRate;
}

+ (NSNumber*)_bestVideoModeForCamera:(dc1394camera_t*)cam
						   frameSize:(CGSize)frameSize
						   frameRate:(dc1394framerate_t*)frameRate
							   error:(NSError**)error
{	
	NSArray* modes = [[self class] _supportedVideoModesForFrameSize:frameSize
														  forCamera:cam
															  error:error];
	if (nil == modes || 0 >= [modes count])
		return nil;
	
	dc1394video_mode_t chosenVideoMode = [[modes objectAtIndex:0] intValue];
	dc1394framerate_t chosenFrameRate = [[self _fastestFrameRateForCamera:cam videoMode:[[modes objectAtIndex:0] intValue]] intValue];
	
	int ranking = [self rankingForVideoMode:chosenVideoMode];
	for (NSNumber* mode in modes) {
		int thisRanking = [self rankingForVideoMode:[mode intValue]];
		NSNumber* fastestFrameRate = [self _fastestFrameRateForCamera:cam videoMode:[mode intValue]];
		
		if (ranking < thisRanking || nil == fastestFrameRate)
			continue;
		
		if ((ranking > thisRanking &&
			 ((NULL == frameRate && [fastestFrameRate intValue] >= chosenFrameRate) ||
			  (NULL != frameRate && ([fastestFrameRate intValue] >= *frameRate || [fastestFrameRate intValue] >= chosenFrameRate)))) ||
			(NULL != frameRate && chosenFrameRate < *frameRate && [fastestFrameRate intValue] >= *frameRate)) {
			ranking = thisRanking;
			chosenVideoMode = [mode intValue];
			chosenFrameRate = [fastestFrameRate intValue];
		}
	}
	
	if (NULL != frameRate)
		*frameRate = chosenFrameRate;
	
	return [NSNumber numberWithInt:chosenVideoMode];
}

@end

static void libdc1394_frame_callback(dc1394camera_t* c, void* data)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	dc1394video_frame_t* frame;
	dc1394error_t err = dc1394_capture_dequeue(c, DC1394_CAPTURE_POLICY_POLL, &frame);
	
	if (DC1394_SUCCESS != err || NULL == frame) {
		[pool release];
		return;
	}
	
	// if this is not the most recent frame, drop it and continue
	if (0 < frame->frames_behind) {
		do {
			dc1394_capture_enqueue(c, frame);
			dc1394_capture_dequeue(c, DC1394_CAPTURE_POLICY_POLL, &frame);
		} while (NULL != frame && 0 < frame->frames_behind);
	}
	
	if (NULL != frame) {
		[(TFLibDC1394Capture*)data dispatchFrame:frame];
		dc1394_capture_enqueue(c, frame);
	}
	
	[pool release];
}
