//
//  KBO.h
//  kineto
//
//  Created by Andrea Cremaschi on 17/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/CGLMacro.h>

@interface KBO : NSObject {
	CGLContextObj				context;
	CGSize pboSize;
	
	bool wasPBOAttached;
		
}


- (id) initPBOWithSize: (CGSize )size 
		 openGLContext: (CGLContextObj) cgl_ctx;

- (CIImage *)image;
- (void) attachPBO;
- (void) detachPBO;

@end
