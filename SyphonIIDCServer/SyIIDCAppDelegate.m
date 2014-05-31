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

@interface SyIIDCAppDelegate () <StatusItemManagerDatasource>
@property (strong) IIDCContext *iidcContext;
@property (nonatomic, strong) NSArray *orderedArrayOfDevicesGUIDs;
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

- (NSArray *)orderedArrayOfDevicesGUIDs {
    if (_orderedArrayOfDevicesGUIDs) return _orderedArrayOfDevicesGUIDs;
    
    NSDictionary *availableCameras = self.iidcContext.availableCameras;
    _orderedArrayOfDevicesGUIDs = [availableCameras keysSortedByValueUsingComparator:^NSComparisonResult(IIDCCamera *camera1, IIDCCamera *camera2) {
        return [camera1.deviceIdentifier compare: camera2.deviceIdentifier];
    }];
    return _orderedArrayOfDevicesGUIDs;
}

#pragma mark -StatusItemManagerDatasource

- (void) updateAvailableDevicesListIfNeeded {
    [self willChangeValueForKey:@"orderedArrayOfDevicesGUIDs"];
    _orderedArrayOfDevicesGUIDs = nil;
    [self didChangeValueForKey:@"orderedArrayOfDevicesGUIDs"];
    
}
- (BOOL) isCameraConnected {
    return NO;
}

- (NSDictionary *)dictionaryRepresentingAvailableDevices {
    
    NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
    for (NSString *deviceGUID in [self orderedArrayOfDevicesGUIDs]) {
        IIDCCamera *camera = self.iidcContext.availableCameras[deviceGUID];
        [mDict setObject:camera.deviceIdentifier forKey:deviceGUID];
    }
    return [mDict copy];
}

- (NSArray *)arrayOfDictionariesRepresentingAvailableVideoModesForDeviceWithGUID:(NSString *)guid {
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

#pragma mark -
- (void) selectVideoModeOfCamera: (id)sender {
    
    NSMenuItem *menuItem = (NSMenuItem*)sender;
    NSMenuItem *parentItem = menuItem.parentItem;
    
    NSString *videoModeId = menuItem.representedObject;
    NSNumber *deviceId = parentItem.representedObject;
    
    IIDCCamera *camera = [self.iidcContext availableCameras][deviceId];
    if (camera) {
        NSError *error;
        BOOL result = [camera startCapturing: &error];
        if (!result) {
            // TODO: error handling
            NSLog(@"%@", error.localizedDescription);
        }
    }
//    [self.dataSource selectVideoModeWithId: videoModeId videoDevice: deviceId];
}
@end
