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
    [self.tableView reloadData];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
   // [self updateLayout];
}

-(void) updateLayout {
    IIDCCamera *camera = self.captureSession.camera;
    NSDictionary *features = camera.features;

    NSView*controlsView = [[NSView alloc] initWithFrame: self.featuresScrollView.bounds];
    controlsView.autoresizingMask = NSViewWidthSizable;
    NSNib *featureNib = [[NSNib alloc] initWithNibNamed:@"FeatureControl" bundle:nil];
    
    int i=0;
    int marginY = 15;
    int marginX = 15;
    int cellHeight = 60;

    NSMutableArray *controlsArray = [NSMutableArray array];
    for (NSString *featureKey in features.allKeys) {
        
        NSDictionary * curFDict = [features valueForKey:featureKey];
        
        NSArray *objects;
        NSViewController *vc = [NSViewController new];
        [featureNib instantiateNibWithOwner:vc topLevelObjects: &objects];

        NSView *controlView = vc.view;
        controlView.frame = ({
            CGRect frame = controlView.frame;
            frame.origin.y = i;
            frame.size.width = controlsView.frame.size.width;
            frame;
        });
        [controlsArray addObject: controlView];
        

        /*
        // label
        uiFrame = NSMakeRect(0, 0, cell.bounds.size.width, 20);
        NSTextField * label = [[NSTextField alloc] initWithFrame: uiFrame];
        label.stringValue = featureKey;
        label.editable=NO;
        label.selectable=NO;
        label.bezeled=NO;
        label.bordered=NO;
        label.backgroundColor = [NSColor clearColor];
        [cell addSubview: label];
        
        // Slider
        uiFrame = NSMakeRect(0, 20, cell.bounds.size.width, 20);
        NSSlider * slider = [[NSSlider alloc] initWithFrame: uiFrame];
        slider.maxValue = [[curFDict valueForKey: @"max_value"] doubleValue];
        slider.minValue = [[curFDict valueForKey: @"min_value"] doubleValue];
        slider.doubleValue = [[curFDict valueForKey: @"value"] doubleValue];
        
        [slider bind:@"value"
            toObject:self.captureObject
         withKeyPath:featureKey
             options: nil];
        
        [cell addSubview: slider];
        
        // checkBox
        if ([[curFDict allKeys] containsObject: @"auto"]) {
            uiFrame = NSMakeRect(0, 40, 18, 18);
            NSButton * autoCheckBox = [[NSButton alloc] initWithFrame: uiFrame];
            autoCheckBox.buttonType=NSSwitchButton;
            autoCheckBox.state  = [[curFDict valueForKey: @"auto"] boolValue] ? NSOnState : NSOffState;
            
            [autoCheckBox bind: @"value"
                      toObject: self.captureObject
                   withKeyPath: [NSString stringWithFormat: @"auto_%@", featureKey]
                       options: nil];
            [cell addSubview: autoCheckBox];
            
            [slider bind: @"enabled"
                toObject: self.captureObject
             withKeyPath: [NSString stringWithFormat: @"auto_%@", featureKey]
                 options: @{NSValueTransformerBindingOption: [NSValueTransformer valueTransformerForName:@"NSNegateBoolean"]}];
            
        }
        
        // one push auto button
        if ([[curFDict allKeys] containsObject: @"onePushAuto"]) {
            uiFrame = NSMakeRect(20, 40, 40, 18);
            NSButton * autoCheckBox = [[NSButton alloc] initWithFrame: uiFrame];
            autoCheckBox.buttonType=NSPushOnPushOffButton;
            autoCheckBox.title = @"PUSH AUTO";
            autoCheckBox.tag = [[captureObject featureIndexForKey: featureKey] intValue];
            autoCheckBox.action = @selector(pushAuto:);
         
            
            [cell addSubview: autoCheckBox];
            
        }*/
        
        i ++;
    }
    
    // set view height
    
    // add subview
    for (NSView *view in controlsArray) {
        
        [controlsView addSubview: view];
    }
    
    
    [self.featuresScrollView setDocumentView:  controlsView];
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

- (void) pushAuto: (id) sender {
    
    IIDCCamera *camera = self.captureSession.camera;
    
    int featureIndex = [sender tag];
    [camera pushToAutoFeatureWithIndex: featureIndex];
    
    
}
@end
