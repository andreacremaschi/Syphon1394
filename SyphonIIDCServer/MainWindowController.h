//
//  MainWindowController.h
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TFLibDC1394Capture;
@interface MainWindowController : NSWindowController {
    
}

@property (readonly) NSArray * IIDCCameraList;
@property (nonatomic, retain) NSString *selectedCameraUUID;
@property (nonatomic, retain) TFLibDC1394Capture *captureObject;



@end
