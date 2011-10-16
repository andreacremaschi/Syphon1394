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
@property (retain) CIImage* imageToShow;
@property (readonly) CIContext *ciContext;
@property (retain) NSNumber* pixelAspectRatio;
@property (retain) NSString* identifier;


- (void) setGlContextToShare: (NSOpenGLContext *)context;
- (CVReturn)renderTime:(const CVTimeStamp*)outputTime;

@end
