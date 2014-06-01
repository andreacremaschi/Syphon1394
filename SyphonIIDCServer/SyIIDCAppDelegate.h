//
//  SyIIDCAppDelegate.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainWindowController, IIDCCaptureSession;
@interface SyIIDCAppDelegate : NSObject <NSApplicationDelegate> {
    MainWindowController *mainWindowController;
}

@property (strong) MainWindowController *mainWindowController;

// Menu actions
- (IBAction) selectVideoModeOfCamera: (id)sender;
- (IBAction) disconnectCamera: (id)sender;
- (IBAction) enableSyphonServer: (id)sender;
- (IBAction) setupCameraSettings: (id)sender;


@end
