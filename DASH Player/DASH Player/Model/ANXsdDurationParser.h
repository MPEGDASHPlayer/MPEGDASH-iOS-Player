//
//  ANXsdDurationParser.h
//  DASH Player
//
//  Created by DataArt Apps on 29.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum {
    ANXsdStateBegin = 0,
    ANXsdStateDigit,
    ANXsdStateYear,
    ANXsdStateMonth,
    ANXsdStateDay,
    ANXsdStateT,
    ANXsdStateHours,
    ANXsdStateMinutes,
    ANXsdStateSeconds,
    ANXsdStateDot
} ANXsdState;

@interface ANXsdDurationParser : NSObject
- (NSTimeInterval)timeIntervalFromString:(NSString *)string;
@end
