//
//  MainWindowController.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 16/10/11.
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
    NSScrollView *__weak controlsBox;
}

@property (weak, readonly) NSArray * IIDCCameraList;
@property (nonatomic, strong) NSString *selectedCameraUUID;
@property (nonatomic, strong) IIDCCameraController *captureObject;

@property (weak) IBOutlet NSScrollView *controlsBox;


@end
