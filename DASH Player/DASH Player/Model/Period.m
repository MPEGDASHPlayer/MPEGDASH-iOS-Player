//
//  Period.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "Period.h"
#import "ANXsdDurationParser.h"

@interface Period ()
@property (nonatomic, strong) NSMutableArray *adaptationSetMutableArray;
@property (nonatomic, strong) ANXsdDurationParser *durationParser;
@end

@implementation Period
- (id)init {
    self = [super init];
    if (self){
        self.durationParser = [[ANXsdDurationParser alloc] init];
    }
    return self;
}

- (void)setDurationFromString:(NSString *)durationString {
    self.duration = [self.durationParser timeIntervalFromString:durationString];
}

- (void)setStartFromString:(NSString *)startString {
    self.start = [self.durationParser timeIntervalFromString:startString];
}

- (NSArray *)adaptationSet {
    return self.adaptationSetMutableArray;
}

- (void)setAdaptationSet:(NSArray *)adaptationSet {
    self.adaptationSetMutableArray = [NSMutableArray arrayWithArray:adaptationSet];
}

- (void)addAdaptationSetElement:(AdaptationSet *)adaptionSetElement {
    if (!self.adaptationSetMutableArray){
        _adaptationSetMutableArray = [NSMutableArray array];
    }
    [self.adaptationSetMutableArray addObject:adaptionSetElement];
}

@end
