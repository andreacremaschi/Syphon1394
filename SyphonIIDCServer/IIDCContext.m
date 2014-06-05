//
//  IIDCContext.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import "IIDCContext.h"
#import <dc1394/dc1394.h>

#import "IIDCCamera.h"

@interface IIDCCamera (PrivateMethods)

- (id) initWithCameraOpaqueObject: (dc1394camera_t *)camera context: (IIDCContext *)context;
- (void) didDisconnect;
@end

@interface IIDCContext ()
@property (readwrite)  dc1394_t* context;
@property (readwrite) NSDictionary *availableCameras;
@property (readwrite) NSMapTable *connectedCamerasMapTable;

@end

@implementation IIDCContext

-(id)init {
    self = [super init];
    if (self==nil) return nil;

    _context = dc1394_new();
    
    _connectedCamerasMapTable = [NSMapTable strongToWeakObjectsMapTable];
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

                NSString *cameraGUID = [NSString stringWithFormat:@"%"PRIx64"", list->ids[i].guid];
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
                // get the camera name and then discard the object
                IIDCCamera *camera = [[IIDCCamera alloc] initWithCameraOpaqueObject:cam context: self];
                NSString *cameraName = camera.deviceName;
                [cameras setObject: cameraName forKey: cameraGUID];
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


- (IIDCCamera*) cameraWithGUID: (NSString *)wantedGUID {

    // check if an handler for this camera has already been created
    IIDCCamera *camera = [self.connectedCamerasMapTable objectForKey: wantedGUID];
    if (camera) return camera;
    
    dc1394camera_list_t* list;
    dc1394_t *context = _context;

    dc1394camera_t *matchingCameraHandler = NULL;
    if (DC1394_SUCCESS == dc1394_camera_enumerate(context, &list)) {
        if (list && list->num > 0) {
            
            int i;
            for (i=0; i<list->num; i++) {
                NSString *cameraGUID = [NSString stringWithFormat:@"%"PRIx64"", list->ids[i].guid];
                if ([cameraGUID isEqualToString:wantedGUID]) {
                    dc1394camera_t* cam = dc1394_camera_new(context, list->ids[i].guid);
                    matchingCameraHandler = cam;
                    break;
                }
            }
        }

        dc1394_camera_free_list(list);
    }
    
    // if the camera has been found, return it
    if (matchingCameraHandler) {
        IIDCCamera *camera = [[IIDCCamera alloc] initWithCameraOpaqueObject:matchingCameraHandler context: self];
        [self.connectedCamerasMapTable setObject: camera forKey: wantedGUID];
        return camera;
    }
    
    return nil;
}


@end
