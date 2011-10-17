//
//  IIDCCameraController.m
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 17/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "IIDCCameraController.h"
#import "TFLibDC1394Capture.h"

@implementation IIDCCameraController
@synthesize features;
@synthesize delegate;
@synthesize dc1394Camera;

@dynamic brightness;
@dynamic gain;
@dynamic focus;
@dynamic exposure;
@dynamic shutter;




+ (NSArray *)featuresKeys {
    
    return [NSArray arrayWithObjects: @"brightness", @"gain", @"focus", @"shutter", @"exposure", nil];
}

- (id) initWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject {
    self = [super init];
    if (self) {
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

+ (IIDCCameraController *)cameraControllerWithTFLibDC1394CaptureObject: (TFLibDC1394Capture *) captureObject {
    
    return [[IIDCCameraController alloc] initWithTFLibDC1394CaptureObject: captureObject];
}


#pragma mark libdc1394 delegate
- (void)capture:(TFCapture*)capture
didCaptureFrame:(CIImage*)capturedFrame
{
    [self.delegate captureObject:self
                 didCaptureFrame:capturedFrame];

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
