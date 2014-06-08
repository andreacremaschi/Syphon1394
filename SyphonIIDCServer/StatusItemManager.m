//
//  StatusItemManager.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 21/05/14.
//
//

#import "StatusItemManager.h"

@interface StatusItemManager () <NSMenuDelegate>

@property (strong) NSStatusItem *statusItem;

// Outlets
@property (weak) IBOutlet NSMenuItem *connectionStatusMenuItem;
@property (weak) IBOutlet NSMenuItem *disconnectMenuItem;

@property (weak) IBOutlet NSMenuItem *connectToSeparatorMenuItem;
@property (weak) IBOutlet NSMenuItem *connectToMenuItem;

@property (weak) IBOutlet NSMenuItem *actionsSeparatorMenuItem;
@property (weak) IBOutlet NSMenuItem *enableSyphonServerMenuItem;
@property (weak) IBOutlet NSMenuItem *setupCameraSettingsMenuItem;
@property (weak) IBOutlet NSMenuItem *resetCameraBusMenuItem;

@end

@implementation StatusItemManager

+(instancetype)sharedManager {
    static StatusItemManager *__sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSStatusBar *bar = [NSStatusBar systemStatusBar];
        NSStatusItem *statusItem = [bar statusItemWithLength: NSSquareStatusItemLength];

        __sharedManager = [StatusItemManager new];
        __sharedManager.statusItem = statusItem;
    });
    return __sharedManager;
}

- (void) updateStatusItem
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // load menu from xib
        NSStatusBar *bar = [NSStatusBar systemStatusBar];
        _statusItem = [bar statusItemWithLength: NSSquareStatusItemLength];
        
        NSArray *objects;
        NSMenu *menu;
        if ([[NSBundle mainBundle] loadNibNamed:@"StatusItemMenu" owner:self topLevelObjects:&objects]) {
            for (id obj in objects) {
                if ([obj isKindOfClass:[NSMenu class]]) {
                    menu = obj;
                    break;
                }
                
            }
        }
        menu.delegate = self;

        [_statusItem setMenu:menu];

    });
    
    NSImage *statusImage = [NSImage imageNamed:@"shape_red"];
    [self.statusItem setImage: statusImage];
}


#pragma mark - NSMenuDelegate

-(void)menuNeedsUpdate:(NSMenu *)menu {

    if (menu.supermenu == nil) {
        
        // Root menu
        [self.dataSource updateAvailableDevicesListIfNeeded];
        
        NSDictionary *availableDevices = [self.dataSource dictionaryRepresentingAvailableDevices];
        NSInteger availableCamerasCount = availableDevices.count;
        NSString *activeCameraGUID = [self.dataSource activeCameraGUID];
        NSNumber *currentResolutionID = [self.dataSource currentResolutionID];
        
        BOOL isCameraConnected = activeCameraGUID != nil;
        
        // Show label status
        self.connectionStatusMenuItem.title = !isCameraConnected ? NSLocalizedString( @"No camera connected", @"") : NSLocalizedString( @"Camera connected", @"");
        
        // Hide/show "Disconnect device" menu item
        [self.disconnectMenuItem setHidden: !isCameraConnected];
        
        // Hide/show "Connect to video device" related menu items
        BOOL areCamerasAvailable = availableCamerasCount > 0;
        [self.connectToSeparatorMenuItem setHidden: !areCamerasAvailable];
        [self.connectToMenuItem setHidden: !areCamerasAvailable];
        
        // Hide/show "Actions" related menu items
        [self.actionsSeparatorMenuItem setHidden: !isCameraConnected];
        [self.enableSyphonServerMenuItem setHidden: !isCameraConnected];
        [self.setupCameraSettingsMenuItem setHidden: !isCameraConnected];
        [self.resetCameraBusMenuItem setHidden:!isCameraConnected];
        
        // delete all previous devices
        NSMenuItem *menuItem = menu.itemArray[4];
        while (menuItem != self.actionsSeparatorMenuItem) {
            [menu removeItemAtIndex:4];
            menuItem = menu.itemArray[4];
        }
        
        NSArray *orderedKeys = [availableDevices keysSortedByValueUsingSelector:@selector(compare:)];
        int i=0;
        
        // Create a menu item for every available video device
        for (NSString *key in orderedKeys) {
            
            NSString *deviceName = availableDevices[key];
            
            BOOL isActiveCamera = (activeCameraGUID ? [key isEqualToString: activeCameraGUID] : 0);
            NSMenuItem *deviceItem = [NSMenuItem new];
            deviceItem.title = deviceName;
            deviceItem.representedObject = key;
            [deviceItem setState: isActiveCamera];
            
            deviceItem.submenu = ({
                NSMenu *submenu = [NSMenu new];

                NSArray *videomodes =
                [self.dataSource arrayOfDictionariesRepresentingAvailableVideoModesForDeviceWithGUID: key];

                for (NSDictionary *videoModeDict in videomodes) {
                    
                    NSNumber *videoModeId = videoModeDict[@"id"];
                    BOOL isActiveVideoMode = isActiveCamera && currentResolutionID && [currentResolutionID isEqualToNumber: videoModeId];
                    
                    NSMenuItem *videoModeMenuItem = [NSMenuItem new];
                    videoModeMenuItem.title = videoModeDict[@"name"];
                    [videoModeMenuItem setState: isActiveVideoMode];
                    videoModeMenuItem.representedObject = videoModeId;
                    videoModeMenuItem.target = nil;
                    videoModeMenuItem.action = @selector(selectVideoModeOfCamera:);
                    [submenu addItem: videoModeMenuItem];
                }
                submenu;
                
            });
            
            [menu insertItem:deviceItem atIndex: i+4];
            i++;
        }
        
        
    }
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel {
    NSLog(@"ABCDE");
    return NO;
}



@end
