//
//  TextureUploader.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 03/06/14.
//
//

#import "DC1394FrameUploader.h"
#import <OpenGL/CGLMacro.h>

#import "dc1394/dc1394.h"
#import <Accelerate/Accelerate.h>

@interface DC1394FrameUploader () {
    CGLContextObj cgl_ctx;
    void *_buffer;
    GLuint _surfaceFBO;
    GLuint _textureId;
    GLuint _depthBuffer;
}
@property (nonatomic) dispatch_queue_t textureLoaderQueue;
@property CGSize frameSize;
@end

@implementation DC1394FrameUploader


- (dispatch_queue_t)textureLoaderQueue {
    if (_textureLoaderQueue) return _textureLoaderQueue;
    self.textureLoaderQueue = dispatch_queue_create("com.syphoniidcserver.uploadqueue", DISPATCH_QUEUE_SERIAL);
    return _textureLoaderQueue;
}

- (instancetype) initWithContext: (CGLContextObj) ctx frameSize: (CGSize) frameSize {
    self = [super init];
    if (self)
    {
        _frameSize = frameSize;

        long bufferSize = frameSize.width * frameSize.height * 4.0;
        _buffer = malloc(bufferSize);
        memset(_buffer, 0, bufferSize); // pulisce la memoria
        
        cgl_ctx = ctx;
        
//        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
        glGenTextures(1, &_textureId);
        
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureId);
		glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, frameSize.width, frameSize.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        
		// depth buffer
		glGenRenderbuffersEXT(1, &_depthBuffer);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _depthBuffer);
		glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, frameSize.width, frameSize.height);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, 0);

		// FBO and connect attachments
		glGenFramebuffersEXT(1, &_surfaceFBO);
		glBindFramebufferEXT(GL_FRAMEBUFFER, _surfaceFBO);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_EXT, _textureId, 0);
		glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER_EXT, _depthBuffer);
		// Draw black so we have output if the renderer isn't loaded
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
		{
			NSLog(@"Frame uploader: OpenGL error %04X", status);
			glDeleteTextures(1, &_textureId);
			glDeleteFramebuffersEXT(1, &_surfaceFBO);
			glDeleteRenderbuffersEXT(1, &_depthBuffer);
			return nil;
		}
		glBindFramebufferEXT(GL_FRAMEBUFFER, 0);

        
        glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, bufferSize, _buffer);


    }
    return self;
}

- (void) uploadFrame: (dc1394video_frame_t*) dc1934frame {
    
    int width = self.frameSize.width;
    int height = self.frameSize.height;
    
    // TODO: controlla che width e height siano ancora validi
    
    // TODO: copia il frame nel formato giusto nel _buffer
    
    void*tmpBuf = malloc(width*height);
    CapturePixelFormatConvertMono8toBGRA8(dc1934frame->image,
                                          dc1934frame->size[0],
                                          _buffer,
                                          width*4,
                                          tmpBuf,
                                          width,
                                          width,
                                          height);
    free(tmpBuf);
    
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureId);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _surfaceFBO);


    // Set a CACHED or SHARED storage hint for requesting VRAM or AGP texturing respectively
    // GL_STORAGE_PRIVATE_APPLE is the default and specifies normal texturing path
glTexParameteri(GL_TEXTURE_RECTANGLE_EXT,
                    GL_TEXTURE_STORAGE_HINT_APPLE,
                    GL_STORAGE_SHARED_APPLE);
    // Eliminate a data copy by the OpenGL framework using the Apple client storage extension
    // glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    // glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    //glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, TEXTURE_WIDTH, TEXTURE_HEIGHT, 0,
    //             GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, &data);

    /*                                glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, _currentSize.width, _currentSize.height, 0,
     GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _clientStorage);*/
    
    // OpenGL likes the GL_BGRA + GL_UNSIGNED_INT_8_8_8_8_REV combination
    glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _buffer);
    
    // Black/white checkerboard
  /*  float pixels[] = {
        0.0f, 0.0f, 0.0f,   1.0f, 1.0f, 1.0f,
        1.0f, 1.0f, 1.0f,   0.0f, 0.0f, 0.0f
    };
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 2, 2, 0, GL_RGB, GL_FLOAT, pixels);*/
    
 /*   glClearColor(0.0, 1.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);*/

    
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
    
}

- (void) destroyResources {
    glDeleteTextures(1, &_textureId);
    glDeleteFramebuffersEXT(1, &_surfaceFBO);
    glDeleteRenderbuffersEXT(1, &_depthBuffer);
    _textureId = _surfaceFBO = _depthBuffer = 0;
}

int CapturePixelFormatConvertMono8toBGRA8(uint8_t* srcBuf,
                                            int srcRowBytes,
                                            uint8_t* dstBuf,
                                            int dstRowBytes,
                                            uint8_t* tmpBuf,
                                            int tmpRowBytes,
                                            int width,
                                            int height)
{
	if (0 == *tmpBuf)
		memset(tmpBuf, UINT8_MAX, tmpRowBytes * height);
    
#if defined(_USES_IPP_)
	IppiSize roiSize = { width, height };
	const uint8_t* channels[] = { tmpBuf, srcBuf, srcBuf, srcBuf };
	
	ippiCopy_8u_P4C4R(channels,
					  srcRowBytes,
					  dstBuf,
					  dstRowBytes,
					  roiSize);
#else
	vImage_Buffer aSrc, mSrc, argbDest;
	
	aSrc.data = tmpBuf;
	aSrc.width = width;
	aSrc.height = height;
	aSrc.rowBytes = tmpRowBytes;
	
	mSrc.data = srcBuf;
	mSrc.width = width;
	mSrc.height = height;
	mSrc.rowBytes = srcRowBytes;
	
	argbDest.data = dstBuf;
	argbDest.width = width;
	argbDest.height = height;
	argbDest.rowBytes = dstRowBytes;
	
	vImageConvert_Planar8toARGB8888(&mSrc,
									&mSrc,
									&mSrc,
									&aSrc,
									&argbDest,
									0);
#endif
	
	return 1;
}

-(GLuint)textureName {
    return _textureId;
}
@end
