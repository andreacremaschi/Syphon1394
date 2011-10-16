//
//  TFCapture.m
//  Touché
//
//  Created by Georg Kaindl on 4/1/08.
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

#import "TFCapture.h"

#import "TFIncludes.h"
#import "TFThreadMessagingQueue.h"


@interface TFCapture (PrivateMethods)
- (void)_frameDeliveringThreadFunc;
@end

@implementation TFCapture

@synthesize delegate;

- (void)dealloc
{
	delegate = nil;
	
	[super dealloc];
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
	
	_delegateCapabilities.hasWantedCIImageColorSpace =
		[delegate respondsToSelector:@selector(wantedCIImageColorSpaceForCapture:)];
	
	_delegateCapabilities.hasDidCaptureFrame =
		[delegate respondsToSelector:@selector(capture:didCaptureFrame:)];
}

- (BOOL)isCapturing
{	
	return (nil != _frameQueue);
}

- (BOOL)startCapturing:(NSError**)error
{	
	if (NULL != error)
		*error = nil;
	
	if (nil == _frameQueue && nil == _frameDeliveringThread) {
		_frameQueue = [[TFThreadMessagingQueue alloc] init];
		
		_frameDeliveringThread = [[NSThread alloc] initWithTarget:self
														 selector:@selector(_frameDeliveringThreadFunc)
														   object:nil];
		[_frameDeliveringThread start];		
	}
	
	return YES;
}

- (BOOL)stopCapturing:(NSError**)error
{	
	if (NULL != error)
		*error = nil;
	
	if (nil != _frameQueue && nil != _frameDeliveringThread) {
		[_frameDeliveringThread cancel];
		[_frameDeliveringThread release];
		_frameDeliveringThread = nil;
		
		// wake the delivering thread if necessary
		[_frameQueue enqueue:[NSArray array]];
		[_frameQueue release];
		_frameQueue = nil;
	}
	
	return YES;
}

- (CGSize)frameSize
{
	TFThrowMethodNotImplementedException();
	
	return CGSizeMake(0, 0);
}

- (BOOL)setFrameSize:(CGSize)size error:(NSError**)error
{
	TFThrowMethodNotImplementedException();
	
	if (NULL != error)
		*error = nil;
	
	return NO;
}

- (BOOL)supportsFrameSize:(CGSize)size
{
	TFThrowMethodNotImplementedException();
	
	return NO;
}

- (void)_frameDeliveringThreadFunc
{
	NSAutoreleasePool* outerPool = [[NSAutoreleasePool alloc] init];
	
	TFThreadMessagingQueue* frameQueue = [_frameQueue retain];
	
	while (YES) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
				
		CIImage* frame = [frameQueue dequeue];
				
		if ([[NSThread currentThread] isCancelled]) {
			[pool release];
			break;
		}
		
		if (![frameQueue isEmpty]) {
			[pool release];
			continue;
		}
				
		if ([frame isKindOfClass:[CIImage class]] && _delegateCapabilities.hasDidCaptureFrame)
			[delegate capture:self didCaptureFrame:frame];
		
		[pool release];
	}
		
	[frameQueue release];
	
	[outerPool release];
}

@end
