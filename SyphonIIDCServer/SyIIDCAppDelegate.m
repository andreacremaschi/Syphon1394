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
#import "IIDCCaptureSession.h"

// Interface
#import "SettingsWindowController.h"

#import "NSStringToNSNumberValueTransformer.h"

@interface SyIIDCAppDelegate () <StatusItemManagerDatasource, IIDCCaptureSessionDelegate>
@property (strong ) IIDCCaptureSession *captureSession;
@property (nonatomic, strong) NSArray *orderedArrayOfDevicesGUIDs;
@property (nonatomic, strong) IIDCContext *iidcContext;
@property (nonatomic, strong) SettingsWindowController *settingsWindowPanel;

@end

@implementation SyIIDCAppDelegate
@synthesize mainWindowController;

+(void)initialize {
    
    [super initialize];
    
    // create an autoreleased instance of our value transformer
    NSStringToNSNumberValueTransformer *transfomer = [[NSStringToNSNumberValueTransformer alloc] init];
    
    // register it with the name that we refer to it with
    [NSValueTransformer setValueTransformer:transfomer
                                    forName:@"NSStringToNSNumberValueTransformer"];
}

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

- (NSString *)activeCameraGUID {
    return self.captureSession.camera.deviceIdentifier;
}

- (NSNumber *)currentResolutionID {
    return @([self.captureSession.camera videomode]);
}

- (NSString *)currentResolutionDescription {
    IIDCCamera *camera = self.captureSession.camera;
    double framerate = [camera framerate];
    NSInteger videomode = camera.videomode;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"dc1394_videomode == %d", videomode];
    NSArray *item = [camera.videomodes filteredArrayUsingPredicate: predicate];
    
    NSDictionary *videomodeDict = item.firstObject;

    int width = [videomodeDict[@"width"] intValue];
    int height = [videomodeDict[@"height"] intValue];
    
    return [NSString stringWithFormat:@"%ix%i@%.ffps", width, height, framerate];
    
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
        NSString *cameraName = self.iidcContext.availableCameras[deviceGUID];
        [mDict setObject: cameraName forKey:deviceGUID];
    }
    return [mDict copy];
}

- (NSArray *)arrayOfDictionariesRepresentingAvailableVideoModesForDeviceWithGUID:(NSString *)guid {
    IIDCCamera *camera = [self.iidcContext cameraWithGUID: guid];
    
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
    NSString *deviceGUID = parentItem.representedObject;
    
    IIDCCamera *camera = [self.iidcContext cameraWithGUID:deviceGUID];
    if (!camera) {
        // TODO: error handling (the camera has been disconnected)
    }
    
    if (camera == self.captureSession.camera) {
        NSError *error;
        [self.captureSession stopCapturing: &error];
        [camera setVideomode: videoModeId.integerValue];
        [self.captureSession startCapturing: &error];

        [[self settingsWindowPanel] setCaptureSession: self.captureSession];

    } else {
        
        // TODO:
        // [self.captureSession closeSession];
        self.captureSession = nil;
        
        [camera reset];
        [camera setVideomode: videoModeId.integerValue];
        
        IIDCCaptureSession *captureSession = [[IIDCCaptureSession alloc] initWithCamera: camera];
        NSError *error;
        BOOL result = [captureSession startCapturing: &error];
        if (!result) {
            // TODO: error handling
            NSLog(@"%@", error.localizedDescription);
            return;
        }
        self.settingsWindowPanel.captureSession = captureSession;
        self.captureSession = captureSession;
    }
//    [self.dataSource selectVideoModeWithId: videoModeId videoDevice: deviceId];
}

- (IBAction) setupCameraSettings: (id)sender {

    SettingsWindowController *settingsPanel = self.settingsWindowPanel;
    if (!settingsPanel)
        settingsPanel = [[SettingsWindowController alloc] initWithWindowNibName:@"SettingsWindow"];
    
    settingsPanel.captureSession = self.captureSession;
    [settingsPanel.window makeKeyAndOrderFront: self];

    self.settingsWindowPanel = settingsPanel;
}

- (void) disconnectCamera: (id)sender {
    IIDCCaptureSession *captureSession = self.captureSession;
    [captureSession stopCapturing: nil];
    self.captureSession = nil;
    
    // se è aperto, chiudi il pannello delle impostazioni
    self.settingsWindowPanel.captureSession = nil;
    [self.settingsWindowPanel close];
    self.settingsWindowPanel = nil;
}

- (IBAction) resetCameraBus: (id)sender {

    IIDCCaptureSession *captureSession = self.captureSession;
    IIDCCamera *camera = captureSession.camera  ;
    
    [self disconnectCamera: sender];
    
    
    
}



#pragma mark -Capture session delegate
-(void)captureSession:(IIDCCaptureSession *)captureSession didCaptureFrame:(void *)capturedFrame {
    
}

@end
