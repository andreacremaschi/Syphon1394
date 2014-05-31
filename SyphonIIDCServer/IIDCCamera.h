//
//  IIDCCamera.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 26/05/14.
//
//

#import <Foundation/Foundation.h>

@interface IIDCCamera : NSObject

@property (readonly) NSString *deviceIdentifier;

// Settings save/restore
-(void)saveSettingsInMemoryBank: (int) channel;
-(void)restoreSettingsFromMemoryBank: (int) channel;
-(BOOL)isSaving;

// Broadcast
-(void)broadcast: (void(^)())block;

// Power and reset
-(void)setPower: (BOOL) power;
-(void)reset;

// Features and videomodes
@property (nonatomic, readonly) NSDictionary *features;
@property (nonatomic, readonly) NSArray *videomodes;

- (BOOL)startCapturing:(NSError**)error;
- (BOOL)stopCapturing:(NSError**)error;

@end
