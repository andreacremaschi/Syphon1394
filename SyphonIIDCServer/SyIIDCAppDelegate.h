//
//  SyIIDCAppDelegate.h
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainWindowController;
@interface SyIIDCAppDelegate : NSObject <NSApplicationDelegate> {
    MainWindowController *mainWindowController;
}

@property (retain) MainWindowController *mainWindowController;

@end
