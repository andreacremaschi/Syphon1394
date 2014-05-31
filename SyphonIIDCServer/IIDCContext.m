//
//  IIDCContext.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import "IIDCContext.h"
#import <dc1394/dc1394.h>

#import <camwire.h>
#import <camwirebus.h>

#import "IIDCCamera.h"

@interface IIDCCamera (PrivateMethods)

- (id) initWithCameraOpaqueObject: (dc1394camera_t *)camera;
- (void) didDisconnect;
@end

@interface IIDCContext ()
@property (readwrite)  dc1394_t* context;
@property (readwrite) NSDictionary *availableCameras;

@end

@implementation IIDCContext

-(id)init {
    self = [super init];
    if (self==nil) return nil;

    _context = dc1394_new();
    
    NSError *error;
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    libraryPath = [libraryPath stringByAppendingPathComponent: appName];
    NSString *configurationsPath = [libraryPath stringByAppendingPathComponent: @"Configurations"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:libraryPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:libraryPath withIntermediateDirectories:NO attributes:nil error:&error];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configurationsPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:configurationsPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    setenv("CAMWIRE_CONF", configurationsPath.UTF8String, 1);
    
   /* ioKitNotificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    notificationRunLoopSource = IONotificationPortGetRunLoopSource(ioKitNotificationPort);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), notificationRunLoopSource, kCFRunLoopDefaultMode);
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    
    
    addMatchingNotificationResult = IOServiceAddMatchingNotification(ioKitNotificationPort,
                                                                     kIOPublishNotification,
                                                                     matchingDict,
                                                                     deviceAdded,
                                                                     NULL,*/
    return self;
}

-(void)dealloc {
    dc1394_free(_context);
    _context = nil;
}


static Camwire_handle * handle_array = 0;

-(NSDictionary *)availableCameras {

    // TODO: move camera enumeration in some 1394 plug/unplug callback
    dc1394camera_list_t* list;
    dc1394_t *context = _context;
    
    // enumerate connected cameras
    NSMutableSet *existingCamerasGUIDs = [NSMutableSet setWithArray: _availableCameras.allKeys];
    NSMutableDictionary *cameras;
    if (DC1394_SUCCESS == dc1394_camera_enumerate(context, &list)) {
        
        if (list && list->num > 0) {
            
            cameras = [NSMutableDictionary dictionary];
            int i;
            for (i=0; i<list->num; i++) {

                NSNumber *cameraGUID = @(list->ids[i].guid);
                if ([existingCamerasGUIDs containsObject: cameraGUID]) {
                    [cameras setObject: _availableCameras[cameraGUID] forKey:cameraGUID];

                    continue;
                }
                
                dc1394camera_t* cam = dc1394_camera_new(context, list->ids[i].guid);
                if (cam == NULL)
                    continue;
        
                if ([existingCamerasGUIDs containsObject:cameraGUID]) {
                    [cameras setObject: _availableCameras[cameraGUID] forKey:cameraGUID];
                    dc1394_camera_free(cam);
                    continue;
                }

                // create an Objective-C controller for each new connected camera
                IIDCCamera *camera = [[IIDCCamera alloc] initWithCameraOpaqueObject:cam];
                [cameras setObject: camera forKey: cameraGUID];
            }
            
        }
        dc1394_camera_free_list(list);
    }

    NSSet *availableGUIDs = [NSSet setWithArray:[cameras allKeys]];
    [existingCamerasGUIDs minusSet:availableGUIDs];
    
    [existingCamerasGUIDs enumerateObjectsUsingBlock:^(NSString *cameraGUID, BOOL *stop) {
        IIDCCamera *camera = cameras[cameraGUID];
        // camera disconnected
        [camera didDisconnect];
    }];
    
    _availableCameras = [NSDictionary dictionaryWithDictionary: cameras];
    
    return _availableCameras;
}




@end
