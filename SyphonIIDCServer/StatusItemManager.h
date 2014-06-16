//
//  StatusItemManager.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 21/05/14.
//
//

#import <Foundation/Foundation.h>

@protocol StatusItemManagerDatasource;

@interface StatusItemManager : NSObject

+(instancetype)sharedManager;
- (void)updateStatusItem;
@property (weak) id<StatusItemManagerDatasource> dataSource;

@end

#pragma mark - StatusItemManager delegate protocols

@protocol StatusItemManagerDatasource <NSObject>
@required

- (NSDictionary *)dictionaryRepresentingAvailableDevices;
- (NSArray *)arrayOfDictionariesRepresentingAvailableVideoModesForDeviceWithGUID:(NSString *)guid;
- (NSString *)activeCameraGUID;
- (NSNumber *)currentResolutionID;
- (NSString *)currentResolutionDescription;

- (void) updateAvailableDevicesListIfNeeded;

@end
