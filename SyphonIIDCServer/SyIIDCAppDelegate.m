//
//  SyIIDCAppDelegate.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SyIIDCAppDelegate.h"
#import "MainWindowController.h"

#import "StatusItemManager.h"
#import "IIDCContext.h"
#import "IIDCCamera.h"
#import "IIDCCaptureSessionController.h"

@interface SyIIDCAppDelegate () <StatusItemManagerDatasource, IIDCCaptureSessionDelegate>
@property (strong ) IIDCCaptureSessionController *captureSession;
@property (nonatomic, strong) NSArray *orderedArrayOfDevicesGUIDs;
@property (nonatomic, strong) IIDCContext *iidcContext;

@end

@implementation SyIIDCAppDelegate
@synthesize mainWindowController;

	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    self.iidcContext = [IIDCContext new];
    
    [[StatusItemManager sharedManager] updateStatusItem];
    [StatusItemManager sharedManager].dataSource = self;
    
    // Insert code here to initialize your application
 /*   mainWindowController = [[MainWindowController alloc] init] ;
    [mainWindowController showWindow: self];*/
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    if (self.captureSession) {
        [self.captureSession stopCapturing: nil];
        self.captureSession = nil;
    }
}

#pragma mark - StatusItemManagerDatasource

- (void) updateAvailableDevicesListIfNeeded {
    [self willChangeValueForKey:@"orderedArrayOfDevicesGUIDs"];
    _orderedArrayOfDevicesGUIDs = nil;
    [self didChangeValueForKey:@"orderedArrayOfDevicesGUIDs"];
    
}

- (NSNumber *)activeCameraGUID {
    return self.captureSession.camera.deviceIdentifier;
}

- (NSNumber *)currentResolutionID {
    return @([self.captureSession.camera videomode]);
}


- (NSArray *)orderedArrayOfDevicesGUIDs {
    if (_orderedArrayOfDevicesGUIDs) return _orderedArrayOfDevicesGUIDs;
    
    NSDictionary *availableCameras = self.iidcContext.availableCameras;
    _orderedArrayOfDevicesGUIDs = [availableCameras keysSortedByValueUsingComparator:^NSComparisonResult(IIDCCamera *camera1, IIDCCamera *camera2) {
        return [camera1.deviceName compare: camera2.deviceName];
    }];
    return _orderedArrayOfDevicesGUIDs;
}

- (NSDictionary *)dictionaryRepresentingAvailableDevices {
    
    NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
    for (NSString *deviceGUID in [self orderedArrayOfDevicesGUIDs]) {
        IIDCCamera *camera = self.iidcContext.availableCameras[deviceGUID];
        [mDict setObject:camera.deviceName forKey:deviceGUID];
    }
    return [mDict copy];
}

- (NSArray *)arrayOfDictionariesRepresentingAvailableVideoModesForDeviceWithGUID:(NSNumber *)guid {
    IIDCCamera *camera = self.iidcContext.availableCameras[guid];
    
    NSArray *orderedVideoModes = [camera.videomodes sortedArrayUsingDescriptors: @[
                                                                                   [NSSortDescriptor sortDescriptorWithKey:@"color_mode" ascending:YES],
                                                                                   [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:YES]]];
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSDictionary *videomode in orderedVideoModes) {
        // TODO: quale chiave usare per le risoluzioni ?
        [mArray addObject:@{@"name" :   videomode[@"description"],
                            @"id"   :   videomode[@"dc1394_videomode"]}];
    }
    return [mArray copy];
    
}


#pragma mark - UI actions

- (void) selectVideoModeOfCamera: (id)sender {
    
    NSMenuItem *menuItem = (NSMenuItem*)sender;
    NSMenuItem *parentItem = menuItem.parentItem;
    
    NSString *videoModeId = menuItem.representedObject;
    NSNumber *deviceId = parentItem.representedObject;
    
    IIDCCamera *camera = [self.iidcContext availableCameras][deviceId];
    if (!camera) {
        // TODO: error handling (the camera has been disconnected)
    }
    
    if (camera == self.captureSession.camera) {
        NSError *error;
        [self.captureSession stopCapturing: &error];
        [camera setVideomode: videoModeId.integerValue];
        [self.captureSession startCapturing: &error];
    } else {
        
        // TODO:
        // [self.captureSession closeSession];
        self.captureSession = nil;
        
        [camera reset];
        
        IIDCCaptureSessionController *captureSession = [[IIDCCaptureSessionController alloc] initWithCamera: camera];
        NSError *error;
        BOOL result = [captureSession startCapturing: &error];
        if (!result) {
            // TODO: error handling
            NSLog(@"%@", error.localizedDescription);
            return;
        }
        self.captureSession = captureSession;
    }
//    [self.dataSource selectVideoModeWithId: videoModeId videoDevice: deviceId];
}

- (void) disconnectCamera: (id)sender {
    IIDCCaptureSessionController *captureSession = self.captureSession;
    [captureSession stopCapturing: nil];
    self.captureSession = nil;
}



#pragma mark -Capture session delegate
-(void)captureSession:(IIDCCaptureSessionController *)captureSession didCaptureFrame:(void *)capturedFrame {
    
}

@end
