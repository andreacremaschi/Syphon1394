//
//  IIDCContext.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import <Foundation/Foundation.h>

@class IIDCCamera;
@interface IIDCContext : NSObject

- (void *)context;

@property (nonatomic, readonly) NSDictionary *availableCameras;
- (IIDCCamera*) cameraWithGUID: (NSString *)GUID;

@end
