//
//  SettingsWindowController.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 01/06/14.
//
//

#import <Cocoa/Cocoa.h>

@class IIDCCaptureSession;
@interface SettingsWindowController : NSWindowController

// model
@property (nonatomic, weak) IIDCCaptureSession*captureSession;

// interface
@property (weak) IBOutlet NSScrollView *featuresScrollView;
@property (weak) IBOutlet NSTableView *tableView;

@end
