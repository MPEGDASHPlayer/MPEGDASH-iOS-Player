//
//  Period.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AdaptationSet.h"

@interface Period : NSObject
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval start;
@property (nonatomic, strong) NSString *id;

@property (nonatomic, strong) NSArray *adaptationSet;

- (void)setDurationFromString:(NSString *)durationString;
- (void)setStartFromString:(NSString *)startString;

- (void)addAdaptationSetElement:(AdaptationSet *)adaptionSetElement;

@end
