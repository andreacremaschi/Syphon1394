//
//  NSStringToNSNumberValueTransformer.m
//  SyphonIIDCServer
//
//  Created by Andrea Cremaschi on 01/06/14.
//
//

#import "NSStringToNSNumberValueTransformer.h"

@implementation NSStringToNSNumberValueTransformer
+ (Class)transformedValueClass
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}


- (id)transformedValue:(id)value
{
    if (value == nil) return @"-";
    
    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(doubleValue)]) {
        // handles NSString and NSNumber
        return [NSString stringWithFormat: @"%i", [value intValue]];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -floatValue.",
         [value class]];
        return nil;
    }
}

@end
