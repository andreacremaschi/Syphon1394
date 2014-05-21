//
//  KOpenGLView.h
//  kineto
//
//  Created by Andrea Cremaschi on 30/06/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class TFThreadMessagingQueue;
@interface KOpenGLView : NSOpenGLView {
	CIImage *imageToShow;
	NSNumber *pixelAspectRatio;
	CIContext *_ciContext;
	
	NSString *identifier;
	bool needsToFlush;

	NSRecursiveLock *lock;
	
	
}
@property (strong) CIImage* imageToShow;
@property (weak, readonly) CIContext *ciContext;
@property (strong) NSNumber* pixelAspectRatio;
@property (strong) NSString* identifier;


- (void) setGlContextToShare: (NSOpenGLContext *)context;
- (CVReturn)renderTime:(const CVTimeStamp*)outputTime;

@end
