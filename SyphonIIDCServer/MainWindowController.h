//
//  MainWindowController.h
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syphon/Syphon.h>

@class IIDCCameraController, SimpleServerGLView;
@interface MainWindowController : NSWindowController {
    SyphonServer *syServer;
    IBOutlet SimpleServerGLView *previewGLView;
    
    NSString *selectedCameraUUID;
    IIDCCameraController * captureObject;
    NSScrollView *controlsBox;
}

@property (readonly) NSArray * IIDCCameraList;
@property (nonatomic, retain) NSString *selectedCameraUUID;
@property (nonatomic, retain) IIDCCameraController *captureObject;

@property (assign) IBOutlet NSScrollView *controlsBox;


@end
