//
//  AdaptationSet.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "AdaptationSet.h"
@interface AdaptationSet ()
@property (nonatomic, strong) NSMutableArray *representationMutableArray;
@property (nonatomic, strong) NSArray *orderedArray;
@end

@implementation AdaptationSet

- (void)setSegmentAlignmentFromString:(NSString *)valueString {
    self.segmentAlignment = [[valueString uppercaseString] isEqualToString:@"TRUE"] ? YES : NO;
}

- (void)setMaxWidthString:(NSString *)valueString {
    self.maxWidth = [valueString integerValue];
}

- (void)setMaxHeightFromString:(NSString *)valueString {
    self.maxHeight = [valueString integerValue];
}

- (void)setMaxFrameRateFromString:(NSString *)valueString {
    self.maxFrameRate = [valueString integerValue];
}

- (void)setAudioSamplingRateFromString:(NSString *)valueString {
    self.audioSamplingRate = [valueString integerValue];
}

- (void)addRepresentation:(Representation *)representation {
    if (!_representationMutableArray){
        _representationMutableArray = [NSMutableArray array];
    }
    [self.representationMutableArray addObject:representation];
    self.orderedArray = nil;
}

- (NSArray *)representationArray {
    if (!self.orderedArray){
        self.orderedArray = [self.representationMutableArray sortedArrayUsingComparator:^NSComparisonResult(Representation *rep1, Representation *rep2){
            if (rep2.bandwidth > rep1.bandwidth){
                return NSOrderedAscending;
            } else if (rep2.bandwidth < rep1.bandwidth){
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        }];
    }
    return self.orderedArray;
}

- (void)setRepresentationArray:(NSArray *)representationArray {
    self.representationMutableArray = [NSMutableArray arrayWithArray:representationArray];
    self.orderedArray = nil;
}

@end
