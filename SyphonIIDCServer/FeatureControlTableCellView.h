//
//  FeatureControlTableCellView.h
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 01/06/14.
//
//

#import <Cocoa/Cocoa.h>

@interface FeatureControlTableCellView : NSTableCellView
@property (weak) IBOutlet NSView *autoButton;
@property (weak) IBOutlet NSTextField *featureNameLabel;
@property (weak) IBOutlet NSSlider *valueSlider;
@property (weak) IBOutlet NSTextField *valueTextField;
@property (weak) IBOutlet NSButton *onOffButton;
@property (weak) IBOutlet NSButton *onePushAuto;
@end
