//
//  SegmentTemplate.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "SegmentTemplate.h"

@implementation SegmentTemplate
- (void)setPresentationTimeOffsetFromString:(NSString *)stringValue {
    self.presentationTimeOffset = [stringValue floatValue];
}

- (void)setTimescaleFromString:(NSString *)stringValue {
    self.timescale = [stringValue integerValue];
}

- (void)setStartNumberFromString:(NSString *)stringValue {
    self.startNumber = [stringValue integerValue];
}

- (void)setDurationFromString:(NSString *)stringValue {
    self.duration = [stringValue integerValue];//miliseconds
}

@end
