//
//  TFThreadMessagingQueue.m
//  Touché
//
//  Created by Georg Kaindl on 24/3/08.
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

#import "TFThreadMessagingQueue.h"


@implementation TFThreadMessagingQueue

- (id)init
{
	if (!(self == [super init])) {
		[self release];
		
		return nil;
	}
	
	_queueElements = [[NSMutableArray alloc] init];
	_lock = [[NSConditionLock alloc] init];
	
	return self;
}

- (void)dealloc
{
	[_queueElements release];
	[_lock release];
	
	[super dealloc];
}

- (void)enqueue:(id)object
{
	if (nil == object)
		return;

	[_lock lock];
	[_queueElements addObject:object];
	[_lock unlockWithCondition:1];
}

- (id)dequeue
{
	[_lock lockWhenCondition:1];
	
	id el = [[[_queueElements objectAtIndex:0] retain] autorelease];
	[_queueElements removeObjectAtIndex:0];
	
	[_lock unlockWithCondition:([_queueElements count] > 0) ? 1 : 0];
	
	return el;
}

- (BOOL)isEmpty
{
	BOOL rv = NO;

	if ([_lock tryLock]) {
		NSInteger cond = [_lock condition];
		rv = (cond == 0);
		[_lock unlockWithCondition:cond];
	}
		
	return rv;
}

- (NSInteger)queueLength
{
	NSInteger l = 0;

	[_lock lock];
	l = [_queueElements count];
	[_lock unlockWithCondition:(l > 0) ? 1 : 0];
	
	return l;
}

@end
