//
//  SegmentTimeline.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "SegmentTimeline.h"
@interface SegmentTimeline ()
@property (nonatomic, strong) NSMutableArray *segmentsMutableArray;
@end

@implementation SegmentTimeline
- (void)addSegmentElement:(Segment *)segment {
    if (!_segmentsMutableArray){
        _segmentsMutableArray = [NSMutableArray array];
    }
    [self.segmentsMutableArray addObject:segment];
}

- (void)setSegmentArray:(NSArray *)segmentArray {
    self.segmentsMutableArray = [NSMutableArray arrayWithArray:segmentArray];
}

- (NSArray *)segmentArray {
    return self.segmentsMutableArray;
}
@end
