//
//  TFLibDC1394Capture+CIImageFromDc1394Frame.h
//  Touché
//
//  Created by Georg Kaindl on 15/5/08.
//
//  Copyright (C) 2008 Georg Kaindl
//
//  This file is part of Touché.
//
//  Touché is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as
//  published by the Free Software Foundation, either version 3 of
//  the License, or (at your option) any later version.
//
//  Touché is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with Touché. If not, see <http://www.gnu.org/licenses/>.
//
//

#import <Cocoa/Cocoa.h>


#import "TFLibDC1394Capture.h"

@interface TFLibDC1394Capture (CIImageFromDc1394Frame) 

+ (int)rankingForVideoMode:(dc1394video_mode_t)mode;

- (void)cleanUpCIImageCreator;
- (NSString*)dc1394ColorCodingToString:(dc1394color_coding_t)coding;
- (CIImage*)ciImageWithDc1394Frame:(dc1394video_frame_t*)frame error:(NSError**)error;

@end
