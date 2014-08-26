//
//  IIDCCamera.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import "IIDCCamera.h"
#import <dc1394/dc1394.h>
#import <dc1394/capture.h>
#import <dc1394/macosx/capture.h>

#import "IIDCContext.h"

@interface IIDCCamera ()
@property dc1394camera_t *cameraHandler;
@property (nonatomic, readwrite, strong) NSDictionary *features;
@property (nonatomic, readwrite, strong) NSArray *videomodes;

@end

@implementation IIDCCamera

- (id) initWithCameraOpaqueObject: (dc1394camera_t *)camera context: (IIDCContext *)context {
    self = [super init];
    if (self) {
        _cameraHandler = camera;
        _context = context;
    }
    return self;
}

-(void)dealloc {
    [self _freeCamera];
    self.features = nil;
}

- (void) didDisconnect {
    // tells the delegate
}

- (void)_freeCamera
{
	if (NULL == _cameraHandler)
		return;
    
    dc1394_iso_release_all(_cameraHandler);
    dc1394_camera_reset(_cameraHandler);
    dc1394_camera_set_power(_cameraHandler, DC1394_OFF);
    dc1394_camera_free(_cameraHandler);
    _cameraHandler = NULL;
    
}

#pragma mark - system functions

-(BOOL)isSaving {
    dc1394bool_t value;
    dc1394_memory_busy(_cameraHandler, &value);
    return value;
}

- (void) saveSettingsInCameraMemoryBank: (int) channel {
    
    dc1394error_t dcError = dc1394_memory_save(_cameraHandler, channel);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
    
}

- (void) restoreSettingsFromMemoryBank: (int) channel {
    dc1394error_t dcError = dc1394_memory_load(_cameraHandler, channel);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
    
}

- (void) broadcast: (void(^)())block {
    
    dc1394error_t dcError = dc1394_camera_set_broadcast(_cameraHandler, YES);
    if (dcError == DC1394_SUCCESS) {
        block();
        
        dcError = dc1394_camera_set_broadcast(_cameraHandler, NO);
    }
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

- (void) setPower: (BOOL) power {
    dc1394error_t dcError = dc1394_camera_set_power(_cameraHandler, power);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

- (void) reset {
    dc1394error_t dcError = dc1394_camera_reset(_cameraHandler);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

-(void)resetCameraBus {
    dc1394error_t dcError = dc1394_reset_bus(_cameraHandler);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
    }
}

#pragma mark - Features

- (NSDictionary *)features {
    
    if (_features) return _features;
    
    NSMutableDictionary *featuresDict = [NSMutableDictionary dictionary];
    
    dc1394featureset_t features;
    dc1394error_t dcError = dc1394_feature_get_all(_cameraHandler, &features);
    if (dcError != DC1394_SUCCESS) {
        // TODO: error handling
        return @{};
    }

	for (dc1394feature_t i=0; i<DC1394_FEATURE_NUM; i++) {
        
		dc1394feature_info_t featureInfo = features.feature[i];
		if (featureInfo.available == DC1394_FALSE)
            continue;
        
        NSString *key = @"";
        switch (featureInfo.id) {
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
        NSMutableDictionary *curFeatureDict = [@{@"feature_index" : @(featureInfo.id),
                                                 @"min_value" : @(featureInfo.min),
                                                 @"max_value" : @(featureInfo.max),
                                                 @"value" : @(featureInfo.value)} mutableCopy];
                
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

        if (featureInfo.on_off_capable == DC1394_TRUE) {
            [curFeatureDict setValue: @(featureInfo.is_on == DC1394_ON) forKey: @"onOff"];
        }
        
        if ((featureInfo.available == 1) && supported) {
            if (automode) {
                bool curMode= featureInfo.current_mode == DC1394_FEATURE_MODE_AUTO;
                [curFeatureDict setValue: @(curMode) forKey: @"auto"];
            }
            if (oneShotAuto) {
                [curFeatureDict setValue: @YES forKey: @"onePushAuto"];
            }
            [featuresDict setValue: curFeatureDict
                            forKey: key];
        }
		// we try setting to 'auto' even if this feature doesn't have a manual mode on this camera
		//[self setFeatureWithIndex:i toAutoMode:YES];
	}
    
    _features = featuresDict;
    
    return _features;
}

- (BOOL)featureInAutoMode:(dc1394feature_t)f
{
	dc1394feature_mode_t mode;
	dc1394camera_t *cameraHandle = self.cameraHandler;
    
	if (DC1394_SUCCESS != dc1394_feature_get_mode(cameraHandle, f, &mode))
		return NO;
	
	return (DC1394_FEATURE_MODE_AUTO == mode);
}

- (BOOL)setFeatureWithIndex:(dc1394feature_t)f toAutoMode:(BOOL)val
{
	dc1394feature_mode_t mode = val ? DC1394_FEATURE_MODE_AUTO : DC1394_FEATURE_MODE_MANUAL;
	dc1394camera_t *cameraHandle = self.cameraHandler;
	
	return (DC1394_SUCCESS == dc1394_feature_set_mode(cameraHandle, f, mode));
}

- (BOOL)pushToAutoFeatureWithIndex:(dc1394feature_t)f
{
	dc1394feature_mode_t mode = DC1394_FEATURE_MODE_ONE_PUSH_AUTO;
	dc1394camera_t *cameraHandle = self.cameraHandler;
    return (DC1394_SUCCESS == dc1394_feature_set_mode(cameraHandle, f, mode));
    /*{
        float newValue = [self valueForFeatureWithIndex:f];
        NSLog(@"%.2f", newValue);
    }
    return YES;*/
}

- (float)valueForFeatureWithIndex:(dc1394feature_t)f
{
	unsigned val;
    dc1394camera_t *cameraHandle = self.cameraHandler;

	if (DC1394_SUCCESS != dc1394_feature_get_value(cameraHandle, f, (void*)&val))
		return 0.0f;
	
	return val;
    
}

- (BOOL)setFeatureWithIndex:(dc1394feature_t)feature toValue:(uint32_t)val
{
	/*if (!_supportedFeatures[feature])
     return NO;
     */
    dc1394camera_t *cameraHandle = self.cameraHandler;

	dc1394feature_t f = feature; //[self _featureFromKey:feature];
	dc1394feature_mode_t mode;
	dc1394bool_t isSwitchable;
	
	if (DC1394_SUCCESS != dc1394_feature_is_switchable(cameraHandle, f, &isSwitchable))
		return NO;
	
	if (isSwitchable) {
		dc1394switch_t isSwitched;
		
		if (DC1394_SUCCESS != dc1394_feature_get_power(cameraHandle, f, &isSwitched))
			return NO;
		
		if (DC1394_ON != isSwitched) {
			isSwitched = DC1394_ON;
			
			if (DC1394_SUCCESS != dc1394_feature_set_power(cameraHandle, f, DC1394_ON))
				return NO;
		}
	}
	
	if (DC1394_SUCCESS != dc1394_feature_get_mode(cameraHandle, f, &mode))
		return NO;
	
	if (DC1394_FEATURE_MODE_MANUAL != mode &&
		DC1394_SUCCESS != dc1394_feature_set_mode(cameraHandle, f, DC1394_FEATURE_MODE_MANUAL))
		return NO;
	
	/*UInt32 newVal = _featureMinMax[feature][0] + val*(_featureMinMax[feature][1]-_featureMinMax[feature][0]);
     */
	if (DC1394_SUCCESS != dc1394_feature_set_value(cameraHandle, f, val)) //newVal))
		return NO;
	
	return YES;
}

#pragma mark - properties

-(NSString *)deviceName {
	
    dc1394camera_t *camera = self.cameraHandler;
    
	NSString* cameraName = nil;
	if (NULL != camera->model && NULL != camera->vendor)
		cameraName = [NSString stringWithFormat:@"%s (%s)", camera->model, camera->vendor];
	else if (NULL != camera->model)
		cameraName = @(camera->model);
	else if (NULL != camera->vendor)
		cameraName = [NSString stringWithFormat: @"Unknown camera (%s)", camera->vendor];
	
	return cameraName;

}

-(NSString *)deviceIdentifier {
    dc1394camera_t *camera = self.cameraHandler;
    
    return [NSString stringWithFormat:@"%"PRIx64"", camera->guid];
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
    dc1394camera_t *camera = self.cameraHandler;

    if (DC1394_SUCCESS != dc1394_video_get_supported_modes(camera, &list))
        return nil;
    
    NSMutableArray *videomodesArray = [NSMutableArray array];
    
    int j;
    for (j=0; j<list.num; j++) {
        NSDictionary *curresolutionDictionary;
        int mode = list.modes[j];
        switch(mode) {
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

            case DC1394_VIDEO_MODE_FORMAT7_0:
            case DC1394_VIDEO_MODE_FORMAT7_1:
            case DC1394_VIDEO_MODE_FORMAT7_2:
            case DC1394_VIDEO_MODE_FORMAT7_3:
            case DC1394_VIDEO_MODE_FORMAT7_4:
            case DC1394_VIDEO_MODE_FORMAT7_5:
            case DC1394_VIDEO_MODE_FORMAT7_6:
            case DC1394_VIDEO_MODE_FORMAT7_7:
                // curresolutionDictionary = @{ @"color_mode" : [NSString stringWithFormat:@"User defined %i", mode-DC1394_VIDEO_MODE_FORMAT7_0]};
                break;
                
            default:
                 break;
        }
        if (curresolutionDictionary == nil) continue;
        curresolutionDictionary = [curresolutionDictionary mutableCopy];
        [curresolutionDictionary setValue: @(mode) forKey:@"dc1394_videomode"];
        if ([curresolutionDictionary.allKeys containsObject:@"width"]) {
            [curresolutionDictionary setValue: [NSString stringWithFormat: @"%@ %@x%@", [curresolutionDictionary valueForKey:@"color_mode"], curresolutionDictionary[@"width"], curresolutionDictionary[@"height"] ] forKey:@"description"];}
        else {
            [curresolutionDictionary setValue: curresolutionDictionary[@"color_mode"] forKey:@"description"];
        }
            
        [videomodesArray addObject: curresolutionDictionary];
    }
    _videomodes = videomodesArray;
    return videomodesArray;
}

- (double) _frameRateForDC1394FrameRateEnum: (dc1394framerate_t)dc1394_framerate {
    double framerate = -1;
    switch (dc1394_framerate) {
            
        case DC1394_FRAMERATE_1_875: framerate = 1.875; break;
        case DC1394_FRAMERATE_3_75: framerate = 3.75; break;
        case DC1394_FRAMERATE_7_5: framerate = 7.5; break;
        case DC1394_FRAMERATE_15: framerate = 15.; break;
        case DC1394_FRAMERATE_30: framerate = 30.; break;
        case DC1394_FRAMERATE_60: framerate = 60.; break;
        case DC1394_FRAMERATE_120: framerate = 120.; break;
        case DC1394_FRAMERATE_240: framerate = 240.; break;
            
        default:
            break;
    }
    return framerate;

}

- (dc1394framerate_t) _DC1394FrameRateEnumFromDouble: (double)framerate {

    dc1394framerate_t dc1394_framerate = 0;
    
    long intFR = round(framerate*1000);
    switch (intFR) {
            
        case 1875: dc1394_framerate = DC1394_FRAMERATE_1_875; break;
        case 3750: dc1394_framerate = DC1394_FRAMERATE_3_75; break;
        case 7500: dc1394_framerate = DC1394_FRAMERATE_7_5; break;
        case 15000: dc1394_framerate = DC1394_FRAMERATE_15; break;
        case 30000: dc1394_framerate = DC1394_FRAMERATE_30; break;
        case 60000: dc1394_framerate = DC1394_FRAMERATE_60; break;
        case 120000: dc1394_framerate = DC1394_FRAMERATE_120; break;
        case 240000: dc1394_framerate = DC1394_FRAMERATE_240; break;
            
        default:
            break;
    }
    return dc1394_framerate ;
    
}

-(BOOL)isFramerateApplicable {
    dc1394camera_t *camera = self.cameraHandler;
    dc1394video_mode_t videoMode;
    dc1394_video_get_mode(camera, &videoMode);
    return !(videoMode >= DC1394_VIDEO_MODE_EXIF);
}

- (NSArray*)availableFrameRatesForCurrentVideoMode {

    dc1394camera_t *camera = self.cameraHandler;
    dc1394video_mode_t videoMode;
    dc1394framerates_t frameRates;
    
    if (![self isFramerateApplicable]) return @[];
    
    dc1394_video_get_mode(camera, &videoMode);
    dc1394_video_get_supported_framerates(camera, videoMode, &frameRates);
	
    NSMutableArray *videomodesArray = [NSMutableArray array];
    for (int i=0;i<frameRates.num;i++) {
        
        dc1394framerate_t dc1394_framerate = frameRates.framerates[i];
        double framerate = [self _frameRateForDC1394FrameRateEnum: dc1394_framerate];
        if (framerate != 0)
            [videomodesArray addObject: @(framerate) ];
    }
    
    return videomodesArray;
}


#pragma mark -capturing
- (BOOL)isCapturing
{
	if (NULL == self.cameraHandler)
		return NO;
	
	dc1394switch_t status;
	if (DC1394_SUCCESS != dc1394_video_get_transmission(self.cameraHandler, &status))
		return NO;
	
	return (DC1394_ON == status);
}

- (BOOL)setVideomode: (dc1394video_mode_t)videoMode
{
    [self willChangeValueForKey:@"framerate"];
    [self willChangeValueForKey:@"videomode"];
    dc1394camera_t *camera = self.cameraHandler;
    dc1394error_t err = dc1394_video_set_mode(camera, videoMode);
    dc1394video_mode_t curVideoMode;
    
    // check if current framerate is supported
    if ([self isFramerateApplicable]) {
        dc1394framerates_t frameRates;
        dc1394_video_get_mode(camera, &curVideoMode);
        dc1394_video_get_supported_framerates(camera, curVideoMode, &frameRates);
        BOOL found = NO;
        for (int i=0;i<frameRates.num;i++) {
            if (frameRates.framerates[i] == curVideoMode) {
                found=YES;
                break;
            }
        }
        if (!found && frameRates.num>0) {
            // if not, set the max available
            dc1394framerate_t frameRate = frameRates.framerates[frameRates.num-1];
            dc1394_video_set_framerate(camera, frameRate);
        }
        [self didChangeValueForKey:@"videomode"];
        [self didChangeValueForKey:@"framerate"];
    }
    // NSLog(@"Supported framerates: %@", [self availableFrameRatesForCurrentVideoMode]);
    
	return (DC1394_SUCCESS == err);
}

- (dc1394video_mode_t)videomode {
    dc1394video_mode_t videoMode;
    dc1394error_t err = dc1394_video_get_mode(self.cameraHandler, &videoMode);
    if (err) {
        // TODO: Error handling
    }
    return videoMode;
    
}

- (double)framerate {
    dc1394camera_t *camera = self.cameraHandler;

    dc1394framerate_t frameRate;
    dc1394error_t err = dc1394_video_get_framerate(camera, &frameRate);
    
    if (DC1394_SUCCESS == err) return [self _frameRateForDC1394FrameRateEnum: frameRate];

    return 0;

}

-(void)setFramerate:(double)framerate {
    dc1394camera_t *camera = self.cameraHandler;
    
    dc1394framerate_t dc1394_frameRate =  [self _DC1394FrameRateEnumFromDouble: framerate];
    if (dc1394_frameRate == 0) return;
    
    dc1394error_t err = dc1394_video_set_framerate(camera, dc1394_frameRate);

    if (DC1394_SUCCESS == err)
    {
        [self willChangeValueForKey:@"framerate"];
        [self didChangeValueForKey:@"framerate"];
    }
    
}

+(NSSet *)keyPathsForValuesAffectingFramerate {
    return [NSSet setWithObject:@"videomode"];
}

@end
