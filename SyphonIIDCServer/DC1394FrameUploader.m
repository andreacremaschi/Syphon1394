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
    GLuint _uploadTextureId;
    GLint _internalFormat;
    GLenum _format, _type;
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

- (instancetype) initWithContext: (CGLContextObj) ctx
                  prototypeFrame:(dc1394video_frame_t *)prototype
{
    self = [super init];
    if (self)
    {
        CGSize frameSize = CGSizeMake( prototype->size[0], prototype->size[1]);

        _frameSize = frameSize;
        
        cgl_ctx = ctx;
        
        BOOL isSupported = NO;
        
        switch (prototype->video_mode) {
            case DC1394_VIDEO_MODE_640x480_YUV411:
                break;

            case DC1394_VIDEO_MODE_1280x960_RGB8:
            case DC1394_VIDEO_MODE_1600x1200_RGB8:
            case DC1394_VIDEO_MODE_640x480_RGB8:
            case DC1394_VIDEO_MODE_800x600_RGB8:
            case DC1394_VIDEO_MODE_1024x768_RGB8:
                _internalFormat = GL_RGB8;
                _format = GL_RGB;
                _type = GL_UNSIGNED_BYTE;
                isSupported = YES;
                break;

            case DC1394_VIDEO_MODE_640x480_MONO8:
            case DC1394_VIDEO_MODE_800x600_MONO8:
            case DC1394_VIDEO_MODE_1024x768_MONO8:
            case DC1394_VIDEO_MODE_1280x960_MONO8:
            case DC1394_VIDEO_MODE_1600x1200_MONO8:
                _internalFormat = GL_LUMINANCE8;
                _format = GL_LUMINANCE;
                _type = GL_UNSIGNED_BYTE;
                isSupported = YES;
                break;

            case DC1394_VIDEO_MODE_640x480_MONO16:
            case DC1394_VIDEO_MODE_800x600_MONO16:
            case DC1394_VIDEO_MODE_1024x768_MONO16:
            case DC1394_VIDEO_MODE_1280x960_MONO16:
            case DC1394_VIDEO_MODE_1600x1200_MONO16:
                _internalFormat = GL_LUMINANCE16;
                _format = GL_LUMINANCE;
                _type = GL_UNSIGNED_SHORT;
                isSupported = YES;
                break;
                
            case DC1394_VIDEO_MODE_320x240_YUV422:
            case DC1394_VIDEO_MODE_640x480_YUV422:
            case DC1394_VIDEO_MODE_800x600_YUV422:
            case DC1394_VIDEO_MODE_1024x768_YUV422:
            case DC1394_VIDEO_MODE_1280x960_YUV422:
            case DC1394_VIDEO_MODE_1600x1200_YUV422:
                _internalFormat = GL_RGB8;
                _format = GL_YCBCR_422_APPLE;
                _type = GL_UNSIGNED_SHORT_8_8_APPLE;
                isSupported = YES;
                break;
                
            case DC1394_VIDEO_MODE_160x120_YUV444:
                break;
                
            case DC1394_VIDEO_MODE_EXIF:
            case DC1394_VIDEO_MODE_FORMAT7_0:
            case DC1394_VIDEO_MODE_FORMAT7_1:
            case DC1394_VIDEO_MODE_FORMAT7_2:
            case DC1394_VIDEO_MODE_FORMAT7_3:
            case DC1394_VIDEO_MODE_FORMAT7_4:
            case DC1394_VIDEO_MODE_FORMAT7_5:
            case DC1394_VIDEO_MODE_FORMAT7_6:
            case DC1394_VIDEO_MODE_FORMAT7_7:
                break;
                
            default:
                break;
        }
        
        glPushAttrib(GL_ALL_ATTRIB_BITS);
        glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
        
        glEnable(GL_TEXTURE_RECTANGLE_EXT);

        // upload texture
        glGenTextures(1, &_uploadTextureId);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _uploadTextureId);
		glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, _internalFormat, frameSize.width, frameSize.height, 0, _format, _type, NULL);
        
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        
        glPopAttrib();
        glPopClientAttrib();

    }
    return self;
}

- (void) uploadFrame: (dc1394video_frame_t*) dc1934frame {
    
    int width = self.frameSize.width;
    int height = self.frameSize.height;
    
    if (_uploadTextureId==0) return;
    
    // State saving
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    
    if (dc1934frame->data_depth == 16 && !dc1934frame->little_endian) {
        glPixelStorei(GL_UNPACK_ALIGNMENT,  4);
        glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_TRUE);
    } else {
        glPixelStorei(GL_UNPACK_ALIGNMENT,  1);
    }
    
    // Upload the frame
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _uploadTextureId);
    glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, dc1934frame->total_bytes, dc1934frame->image);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
    glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, width, height, _format, _type, dc1934frame->image);

    // Reset Texture Storage optimizations.
    glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
    glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, 0, NULL);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_PRIVATE_APPLE);

    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
   
    glFlushRenderAPPLE();
    
    glPopClientAttrib();
    glPopAttrib();
}

- (void) destroyResources {
    glDeleteTextures(1, &_uploadTextureId);
    _uploadTextureId = 0;
}

-(GLuint)textureName {
    return _uploadTextureId;
}

@end
