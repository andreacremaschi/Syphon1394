//
//  KBO.m
//  kineto
//
//  Created by Andrea Cremaschi on 17/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "KBO.h"
#import "TFIncludes.h"

@implementation KBO



#pragma mark OpenGL specific buffer primitives (were everything happens)

- (bool) _primitiveInitBOWithSize: (CGSize )size 
					openGLContext: (CGLContextObj) cgl_ctx {
	TFThrowMethodNotImplementedException();
	return false;
}


- (bool) _primitiveAttachBO: (CGLContextObj) cgl_ctx {
	
	TFThrowMethodNotImplementedException();
	return false;
	
}

- (bool) _primitiveDetachBO: (CGLContextObj) cgl_ctx {
	TFThrowMethodNotImplementedException();
	return false;
}

#pragma mark Initialization
- (id ) initPBOWithSize: (CGSize )size 
		  openGLContext: (CGLContextObj) cgl_ctx	{
	
	/*int width = size.width;
	int height = size.height;*/
	pboSize = size;
	wasPBOAttached=false;
	
	context = cgl_ctx;
	CGLRetainContext(context);
	
	
	if (![self _primitiveInitBOWithSize: size 
						  openGLContext: cgl_ctx]) {
		NSLog(@"Cannot create Buffer object"); 
		return nil ;
	}	
	// setup openGL viewport
	//CGLContextObj cgl_ctx = [_openGLContext CGLContextObj];
	
	return self;
}

- (void) _primitivePushBO: (CGLContextObj )cgl_ctx {
	return;
}

- (void) _primitivePopBO: (CGLContextObj )cgl_ctx {
	return;
}

#pragma mark Dealloc

- (void)cleanupGL
{
	TFThrowMethodNotImplementedException();
	return;

}

- (void) dealloc {
	
	[self cleanupGL];
}



#pragma mark Default push/pop schema (valid for every Buffer object (PBO, FBO, CVBuffer, CVBufferPools)
- (void) pushPBO:(CGLContextObj)cgl_ctx
{
	//	CGLContextObj cgl_ctx = context;
	//	glGetIntegerv(GL_DRAW_BUFFER, &previousDrawBuffer);
	//	glGetIntegerv(GL_READ_BUFFER, &previousReadBuffer);
	
	/*	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	 glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	 glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);*/
	[self _primitivePushBO: cgl_ctx];
	
}

- (void) popPBO:(CGLContextObj)cgl_ctx
{

	
	[self _primitivePopBO: cgl_ctx];
	
}

- (void) attachPBO {
	if (wasPBOAttached) return;
	
	CGLContextObj cgl_ctx = context;
	CGLLockContext(cgl_ctx);
	{
		
		[self pushPBO: cgl_ctx];
		
		NSAssert([self _primitiveAttachBO: cgl_ctx], @"Error attaching OpenGL Buffer Object!");
		
/*		{

		glViewport(0, 0,  pboSize.width, pboSize.height);
		
			// Save openGL states			
			glMatrixMode(GL_MODELVIEW);
			glPushMatrix();
			glLoadIdentity();
			
			glMatrixMode(GL_PROJECTION);
			glPushMatrix();
			glLoadIdentity();
			
			glOrtho(0.0, pboSize.width,  0.0,  pboSize.height, -1, 1);
		}
		
		//clear the buffer!
		{
			glClearColor(0.0, 0.0, 0.0, 0.0);
			glClear(GL_COLOR_BUFFER_BIT);
			glFlushRenderAPPLE();	
		}*/
		wasPBOAttached=true;
		
	}
	CGLUnlockContext(cgl_ctx);
}


- (void) detachPBO {
	
	CGLContextObj cgl_ctx = context;
	CGLLockContext(cgl_ctx);
	{
		wasPBOAttached=false;
		
		// Restore OpenGL states
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
		
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		
		NSAssert([self _primitiveDetachBO: context], @"Error detaching OpenGL Buffer Object!");		
		[self popPBO: cgl_ctx];
		
	}
	CGLUnlockContext(cgl_ctx);
}


- (CIImage *)image	{
	TFThrowMethodNotImplementedException();
	return nil;
}



@end
