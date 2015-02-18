//
//  SegmentTemplate.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SegmentTimeline.h"

@interface SegmentTemplate : NSObject
@property (nonatomic, strong) NSString *media;
@property (nonatomic, strong) NSString *initialization;

@property (nonatomic, assign) NSTimeInterval presentationTimeOffset;
@property (nonatomic, assign) NSInteger timescale;
@property (nonatomic, assign) NSUInteger startNumber;
@property (nonatomic, assign) NSUInteger duration;

@property (nonatomic, strong) SegmentTimeline *segmentTimeline;

- (void)setPresentationTimeOffsetFromString:(NSString *)stringValue;
- (void)setTimescaleFromString:(NSString *)stringValue;
- (void)setStartNumberFromString:(NSString *)stringValue;
- (void)setDurationFromString:(NSString *)stringValue;

@end
