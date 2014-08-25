//
//  IIDCCaptureSessionController.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 31/05/14.
//
//

#import <Foundation/Foundation.h>

extern NSString *CapturedFrameNotification;

typedef NS_ENUM(int, IIDCCaptureSessionState)  {
    IIDCCaptureSessionState_Initial,
    IIDCCaptureSessionState_Capturing,
    IIDCCaptureSessionState_Error,
    IIDCCaptureSessionState_Terminated
};

@class IIDCCamera;
@protocol IIDCCaptureSessionDelegate;

@interface IIDCCaptureSession : NSObject

@property (readonly) IIDCCamera *camera;
@property (weak) id <IIDCCaptureSessionDelegate> delegate;

@property (readonly) double fps;
@property (readonly) IIDCCaptureSessionState state;

-(id)initWithCamera: (IIDCCamera *)camera;

-(BOOL)startCapturing:(NSError**)error;
-(BOOL)stopCapturing:(NSError**)error;

@end

@protocol IIDCCaptureSessionDelegate <NSObject>
- (void)captureSession:(IIDCCaptureSession*)captureSession didCaptureFrame:(void*)capturedFrame;
- (void)captureSession:(IIDCCaptureSession*)captureSession didFailWithError:(NSError*)error;

@end