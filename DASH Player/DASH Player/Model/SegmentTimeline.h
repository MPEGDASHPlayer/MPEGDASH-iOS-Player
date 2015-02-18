//
//  SegmentTimeline.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Segment.h"

@interface SegmentTimeline : NSObject
@property (nonatomic, strong) NSArray *segmentArray;

- (void)addSegmentElement:(Segment *)segment;

@end
