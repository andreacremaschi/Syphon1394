//
//  KCanvas.h
//  kineto
//
//  Created by Andrea Cremaschi on 07/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

typedef enum
{
	K_CANVAS_TYPE_CVSINGLEBUFFER =1,
	K_CANVAS_TYPE_CVPOOLBUFFER =2,
	K_CANVAS_TYPE_FBO =3

}	K_CANVAS_TYPE;


@class KCompositingLayer;
@class KBO;

@interface KCanvas :  NSObject  
{
	NSOpenGLContext*			_openGLContext;
	bool	isOpenGLContextValid;	//canvas is not valid anymore: i.e. size has been changed!
	KBO	*	_pbo;
	CIContext *_ciContext;
	NSDate*				_lastTimeDrawn;
    
    NSNumber *height;
    NSNumber *width;
    NSNumber *maxFPS;
    NSNumber *canvasType;
}

@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSNumber * width;
@property (nonatomic, retain) NSNumber * maxFPS;
@property (nonatomic, retain) NSNumber * canvasType;

@property (readonly) KBO* bo;

+ (KCanvas *)canvasWithSize: (NSSize)canvasSize;

// Lazy evaluation
- (void) increaseConsumersCount;
- (void) decreaseConsumersCount;
- (bool) wantsToBeDrawn;

// Accessors
- (NSOpenGLContext *)openGLContext;
- (NSOpenGLPixelFormat *)pixelFormat;
- (CIContext *)ciContext;

//- (GLuint) textureName;
- (CIImage *)image;

- (CGSize) size;
- (void) setSize: (CGSize) newSize;

// draw methods
- (void) drawImage: (CIImage *)image;
- (void) flush;


@end



@interface KCanvas (CoreDataGeneratedAccessors)

- (void)addCompositing_layersObject:(KCompositingLayer *)value;
- (void)removeCompositing_layersObject:(KCompositingLayer *)value;
- (void)addCompositing_layers:(NSSet *)value;
- (void)removeCompositing_layers:(NSSet *)value;
@end


