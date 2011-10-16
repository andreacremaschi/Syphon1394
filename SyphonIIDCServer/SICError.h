//
//  SICError.h
//  SyphonIIDCCamera
//
//  Created by Andrea Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

extern NSString* SICErrorDomain;

typedef enum {
	SICErrorUnknown								= 1000,

	SICErrorServerIsAlreadyRunning,
	SICErrorServerCouldNotRegisterItself,
	
	SICErrorClientUnexpectedlyDisconnected,
	SICErrorClientServerConnectionRefused,
	SICErrorClientServerNameRegistrationFailed,
	SICErrorClientDisconnectedSinceServerWasStopped,
	SICErrorClientRegisteredWithInvalidArguments,
	
	SICErrorWiiRemoteDiscoveryThrewException,
	SICErrorWiiRemoteDiscoveryCreationFailed,
	SICErrorWiiRemoteDiscoveryStartupFailed,
	SICErrorWiiRemoteDiscoveryFailed,
	SICErrorWiiRemoteStartProcessingFailed,
	SICErrorWiiRemoteResolutionChangeFailed,
	SICErrorWiiRemoteDisconnectedUnexpectedly,
	
	SICErrorQTKitCaptureFailedToCreateWithUniqueID,
	SICErrorQTKitCaptureDeviceSetToNil,
	SICErrorQTKitCaptureDeviceInputCouldNotBeCreated,
	SICErrorQTKitCaptureDeviceWithUIDNotFound,
	
	SICErrorDc1394NoDeviceFound,
	SICErrorDc1394LibInstantiationFailed,
	SICErrorDc1394CameraAlreadyInUse,
	SICErrorDc1394CameraCreationFailed,
	SICErrorDc1394CaptureSetupFailed,
	SICErrorDc1394SetTransmissionFailed,
	SICErrorDc1394StopTransmissionFailed,
	SICErrorDc1394StopCapturingFailed,
	SICErrorDc1394ResolutionChangeFailed,
	SICErrorDc1394ResolutionChangeFailedInternalError,
	SICErrorDc1394GettingVideoModesFailed,
	SICErrorDc1394LittleEndianVideoUnsupported,
	SICErrorDc1394CVPixelBufferCreationFailed,
	SICErrorDc1394UnsupportedPixelFormat,
	
	SICErrorInputSourceInvalidArguments,
	
	SICErrorCameraInputSourceCIFilterChainCreationFailed,
	SICErrorCameraInputSourceOpenCVBlobDetectorCreationFailed,
	
	SICErrorSimpleDistanceLabelizerOutOfMemory,
	
	SICErrorCam2ScreenInvalidCalibrationData,
	SICErrorCam2ScreenNilCalibrationPoints,
	SICErrorCam2ScreenCalibrationPointsAmountMismatch,
	SICErrorCam2ScreenCalibrationPointNotCalibrated,
	SICErrorCam2ScreenCalibrationPointContainedTwice,
	SICErrorCam2ScreenCalibrationPointMissing,
	
	SICErrorInverseTextureCam2ScreenInternalError,
	
	SICErrorTrackingPipelineInputIsNotQTKitSource,
	SICErrorTrackingPipelineInputIsNotLibDc1394Source,
	SICErrorTrackingPipelineInputMethodUnknown,
	SICErrorTrackingPipelineBlobInputCreationFailed,
	SICErrorTrackingPipelineBlobLabelizerCreationFailed,
	SICErrorTrackingPipelineCam2ScreenConverterCreationFailed,
	SICErrorTrackingPipelinePipelineNotReady,
	SICErrorTrackingPipelineInputMethodNeverCalibrated,
	
	SICErrorCouldNotEnterFullscreen,
	
	SICErrorCouldNotCreateTUIOXMLFlashServer
} SICErrorType;

#define TFUnknownErrorObj	([NSError errorWithDomain:SICError	\
												 code:SICErrorUnknown	\
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:	\
														NSLocalizedString(@"TFUnknownErrorDesc", @"TFUnknownErrorDesc"),	\
															NSLocalizedDescriptionKey,	\
													    NSLocalizedString(@"TFUnknownErrorReason", @"TFUnknownErrorReason"),	\
															NSLocalizedFailureReasonErrorKey,	\
													    NSLocalizedString(@"TFUnknownErrorRecovery", @"TFUnknownErrorRecovery"),	\
															NSLocalizedRecoverySuggestionErrorKey,	\
													    [NSNumber numberWithInteger:NSUTF8StringEncoding], \
															NSStringEncodingErrorKey,	\
													    nil]])
