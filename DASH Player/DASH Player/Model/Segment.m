//
//  Segment.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "Segment.h"

@implementation Segment

- (void)setTimeFromString:(NSString *)stringValue {
    self.t = [stringValue integerValue];
}

- (void)setDurationFromString:(NSString *)stringValue {
    self.d = [stringValue integerValue];
}

@end
