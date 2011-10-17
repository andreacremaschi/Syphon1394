//
//  TFLibDC1394Capture.h
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

//#import <Cocoa/Cocoa.h>
#import <dc1394/dc1394.h>
#import <QuartzCore/QuartzCore.h>


enum {
	TFLibDC1394CaptureFeatureBrightness		= 0,
	TFLibDC1394CaptureFeatureFocus			= 1,
	TFLibDC1394CaptureFeatureGain			= 2,
	TFLibDC1394CaptureFeatureShutter		= 3,
	TFLibDC1394CaptureFeatureExposure		= 4
};

#define TFLibDC1394CaptureNumFeatures	(5)

struct TFLibDC1394CaptureConversionContext;

@interface TFLibDC1394Capture : NSObject {
	dc1394_t*			_dc;
	dc1394camera_t*		_camera;
	NSThread*			_thread;
	
	BOOL				_supportedFeatures[TFLibDC1394CaptureNumFeatures];
	BOOL				_automodeFeatures[TFLibDC1394CaptureNumFeatures];
	NSInteger			_featureMinMax[TFLibDC1394CaptureNumFeatures][2];
	
	dc1394video_mode_t	_currentVideoMode;
	dc1394framerates_t	_frameratesForCurrentVideoMode;
	dc1394framerate_t	_currentFrameRate;
	
	id					_threadLock, _cameraLock;
	
	CVPixelBufferPoolRef	_pixelBufferPool;
	BOOL					_pixelBufferPoolNeedsUpdating;
	
	struct TFLibDC1394CaptureConversionContext* _pixelConversionContext;
    
    id		delegate;
}

@property (assign) id delegate;

- (id)initWithCameraUniqueId:(NSNumber*)uid;
- (id)initWithCameraUniqueId:(NSNumber*)uid error:(NSError**)error;

- (dc1394camera_t*)cameraStruct;
- (NSNumber*)cameraUniqueId;
- (NSString*)cameraDisplayName;
- (BOOL)setCameraToCameraWithUniqueId:(NSNumber*)uid error:(NSError**)error;
- (BOOL)featureIsMutable:(NSInteger)feature;
- (BOOL)featureSupportsAutoMode:(NSInteger)feature;
- (BOOL)featureInAutoMode:(NSInteger)feature;
- (BOOL)setFeature:(NSInteger)feature toAutoMode:(BOOL)val;
- (float)valueForFeature:(NSInteger)feature;
- (BOOL)setFeature:(NSInteger)feature toValue:(float)val;
- (BOOL)setMinimumFramerate:(NSUInteger)frameRate;

- (CGSize)frameSize;
- (BOOL)setFrameSize:(CGSize)size error:(NSError**)error;
- (BOOL)supportsFrameSize:(CGSize)size;

+ (NSDictionary*)connectedCameraNamesAndUniqueIds;
+ (BOOL)cameraConnectedWithGUID:(NSNumber*)guidNumber;
+ (NSNumber*)defaultCameraUniqueId;
+ (CGSize)defaultResolutionForCameraWithUniqueId:(NSNumber*)uid;
+ (BOOL)cameraWithUniqueId:(NSNumber*)uid supportsResolution:(CGSize)resolution;

+ (NSArray*)supportedVideoModesForFrameSize:(CGSize)frameSize 
                                  forCamera:(dc1394camera_t*)cam 
                                      error:(NSError**)error;

@end

@interface NSObject (TFLibDC1394CaptureDelegate)
- (void)capture:(TFLibDC1394Capture*)capture didCaptureFrame:(dc1394video_frame_t*)capturedFrame;
@end