//
//  IIDCCamera+KVO.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 01/06/14.
//
//

#import "IIDCCamera+KVO.h"
#import <dc1394/dc1394.h>

@interface IIDCCamera (PrivateMethods)
- (BOOL)setFeatureWithIndex:(dc1394feature_t)f toAutoMode:(BOOL)val;
- (BOOL)setFeatureWithIndex:(NSInteger)feature toValue:(uint32_t)val;
@end

@implementation IIDCCamera (KVO)

- (NSNumber *)featureIndexForKey: (NSString *)key {
    return [[self.features valueForKey: key] valueForKey:@"feature_index"];
    
}

#pragma mark - KVO (for easier UI bindings)

- (void) setValue:(id)value forKey:(NSString *)key  {
    NSArray *featuresKeys = [self.features allKeys];
    
    if ((key.length >   5) && [[key substringWithRange: NSMakeRange(0, 5)] isEqualToString: @"auto_"]) {
        NSString *featureKey = [key substringWithRange: NSMakeRange(5, key.length-5)];
        if (![featuresKeys containsObject: featureKey])
            [super setValue:value forKey:key];
        
        NSUInteger i = [[self featureIndexForKey: featureKey] intValue];
        if ([self setFeatureWithIndex: (dc1394feature_t) i toAutoMode: [value boolValue]]) {
            [self willChangeValueForKey: [NSString stringWithFormat: @"auto_%@", featureKey]];
            [[self.features valueForKey: featureKey] setValue: value forKey: @"auto"];
            [self didChangeValueForKey: [NSString stringWithFormat: @"auto_%@", featureKey]];
        };
        
        
    } else {
        if ([featuresKeys containsObject: key]) {
            NSUInteger i = [[self featureIndexForKey: key] intValue];
            [self setFeatureWithIndex: i toValue: [value floatValue]];
            
            [self willChangeValueForKey: [NSString stringWithFormat: @"%@", key]];
            [[self.features valueForKey: key] setValue: value forKey: @"value"];
            [self didChangeValueForKey: [NSString stringWithFormat: @"%@", key]];
            
        } else
            [super setValue:value forKey:key];
    }
    
}


- (id)valueForKey:(NSString *)key
{
    //check if we want to set an "auto" property
    if ((key.length > 5) && [[key substringWithRange: NSMakeRange(0, 5)] isEqualToString: @"auto_"]) {
        NSString *featureKey = [key substringWithRange: NSMakeRange(5, key.length-5)];
        return [[self.features valueForKey: featureKey] valueForKey: @"auto"];
        
    } else if ([[self.features allKeys] containsObject: key])
        return [[self.features valueForKey: key] valueForKey: @"value"];
    if ([key isEqualToString:@"features"]) return self.features;
    return [super valueForKey: key];
    
}


@end
