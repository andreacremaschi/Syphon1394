//
//  TextureUploader.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 03/06/14.
//
//

#import <Foundation/Foundation.h>

@interface DC1394FrameUploader : NSObject

- (instancetype) initWithContext: (CGLContextObj) cgl_ctx prototypeFrame: (void*)prototype;
- (void) uploadFrame: (void*) dc1934frame;

@property (readonly) GLuint textureName;
@property (readonly) CGSize frameSize;

- (void) destroyResources;

@end
