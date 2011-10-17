//
//  KCVBufferPool.h
//  kineto
//
//  Created by Andrea Cremaschi on 14/09/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KBO.h"
#import <QuartzCore/QuartzCore.h>

@interface KCVBufferPool : KBO {
	CVOpenGLBufferPoolRef _bufferPool;
	CVOpenGLBufferRef			_CVPixelBuffer;
	CIImage *_cachedImage;
}

@end
