//
//  IIDCCaptureSessionController.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 31/05/14.
//
//

#import <Foundation/Foundation.h>

extern NSString *CapturedFrameNotification;

@class IIDCCamera;
@protocol IIDCCaptureSessionDelegate;

@interface IIDCCaptureSession : NSObject

@property (readonly) IIDCCamera *camera;
@property (weak) id <IIDCCaptureSessionDelegate> delegate;

- (id) initWithCamera: (IIDCCamera *)camera;

- (BOOL)startCapturing:(NSError**)error;
- (BOOL)stopCapturing:(NSError**)error;

@end

@protocol IIDCCaptureSessionDelegate
- (void)captureSession:(IIDCCaptureSession*)captureSession didCaptureFrame:(void*)capturedFrame;
@end