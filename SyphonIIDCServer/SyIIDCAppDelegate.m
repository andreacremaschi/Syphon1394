//
//  SyIIDCAppDelegate.m
//  SyphonIIDCServer
//
//  Created by Michele Cremaschi on 16/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SyIIDCAppDelegate.h"
#import "MainWindowController.h"

@implementation SyIIDCAppDelegate
@synthesize mainWindowController;

- (void)dealloc
{
    [mainWindowController release];
    [super dealloc];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    mainWindowController = [[MainWindowController alloc] init] ;
    [mainWindowController showWindow: self];
}

@end
