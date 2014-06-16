//
//  SettingsWindowController.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 01/06/14.
//
//

#import "SettingsWindowController.h"
#import "IIDCCamera.h"
#import "IIDCCaptureSession.h"

#import "FeatureControlTableCellView.h"
#import "IIDCCamera+KVO.h"

@interface SettingsWindowController () <NSTableViewDataSource, NSTableViewDelegate>
- (IBAction)setFrameRate:(id)sender;

@end

@implementation SettingsWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)dealloc {
    self.captureSession = nil;
}

-(void)setCaptureSession:(IIDCCaptureSession *)captureSession {
    _captureSession = captureSession;
    [self updateLayout];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (void)updateLayout {
    
    self.window; // costringe la window a caricare
    
    IIDCCaptureSession *session = self.captureSession;
    IIDCCamera *camera = session.camera;
    double curFramerate = [camera framerate];
    
    // riempie il popup button
    NSArray *availableFramerates = camera.availableFrameRatesForCurrentVideoMode;
    NSMenu *frameRateMenu = self.frameratePopupButton.menu;
    [frameRateMenu removeAllItems];
    for (NSNumber *framerate in availableFramerates) {
        NSString *title = framerate.stringValue; //[NSString stringWithFormat: @"%.f", framerate.doubleValue];
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle: title  action:nil keyEquivalent:@""];
        [frameRateMenu addItem:menuItem];
        if (curFramerate == framerate.doubleValue) {
            [self.frameratePopupButton selectItem: menuItem];
        }
    }

    [self.tableView reloadData];

}

#pragma mark -

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.captureSession == nil) return 0;
    
    IIDCCamera *camera = self.captureSession.camera;

    return camera.features.allKeys.count;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {

    IIDCCamera *camera = self.captureSession.camera;
    NSArray *sortedKeys= [camera.features keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj1[@"feature_index"] compare:obj2[@"feature_index"]];
    }];
    NSString *key = sortedKeys[row];
    NSDictionary *featureDict = camera.features[key];
    
    FeatureControlTableCellView *cellView =  [tableView makeViewWithIdentifier:@"FeatureControls" owner:self];
    cellView.featureNameLabel.stringValue = [key capitalizedString];
    cellView.valueSlider.minValue = [featureDict[@"min_value"] doubleValue];
    cellView.valueSlider.maxValue = [featureDict[@"max_value"] doubleValue];
    cellView.autoButton.hidden = ![featureDict.allKeys containsObject:@"auto"];
    cellView.onOffButton.hidden = ![featureDict.allKeys containsObject:@"onOff"];
    
    BOOL onePushAuto = [featureDict.allKeys containsObject:@"onePushAuto"];
    if (onePushAuto) {
        cellView.onePushAuto.tag = [featureDict[@"feature_index"] integerValue];
        cellView.onePushAuto.action = @selector(pushAuto:);
        cellView.onePushAuto.target = self;
    }
    cellView.onePushAuto.hidden = !onePushAuto;
    
    [cellView.valueSlider bind: @"value"
                      toObject: camera
                   withKeyPath: key
                       options: nil];

    [cellView.valueTextField bind: @"value"
                         toObject: camera
                      withKeyPath: key
                          options: @{NSValueTransformerBindingOption: [NSValueTransformer valueTransformerForName:@"NSStringToNSNumberValueTransformer"]}];

    [cellView.valueSlider bind: @"enabled"
                      toObject: camera
                   withKeyPath: [NSString stringWithFormat: @"auto_%@", key]
                       options: @{NSValueTransformerBindingOption: [NSValueTransformer valueTransformerForName:@"NSNegateBoolean"]}];

    [cellView.autoButton bind: @"value"
                     toObject: camera
                  withKeyPath: [NSString stringWithFormat: @"auto_%@", key]
                      options: nil];
    
    
    return cellView;
}


#pragma mark Actions

- (void)pushAuto: (id)sender {
    
    IIDCCamera *camera = self.captureSession.camera;
    
    NSInteger featureIndex = [sender tag];
    [camera pushToAutoFeatureWithIndex: featureIndex];
    
}

- (IBAction)setFrameRate:(NSPopUpButton *)popupbutton {
    
    IIDCCamera *camera = self.captureSession.camera;
    
    NSArray *availableFramerates = camera.availableFrameRatesForCurrentVideoMode;
    NSMenu *frameRateMenu = self.frameratePopupButton.menu;
    
    NSMenuItem *menuItem = [popupbutton selectedItem];
    NSInteger itemIndex = [frameRateMenu indexOfItem:menuItem];
    NSNumber *frameRate = [availableFramerates objectAtIndex: itemIndex];
    
    NSError *error;
    [self.captureSession stopCapturing: &error];
    [camera setFramerate:frameRate.doubleValue];
    [self.captureSession startCapturing: &error];

}

@end
