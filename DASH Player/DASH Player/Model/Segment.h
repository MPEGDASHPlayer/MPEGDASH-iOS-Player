//
//  Segment.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Segment : NSObject
@property (nonatomic, assign) NSUInteger t;
@property (nonatomic, assign) NSUInteger d;

- (void)setTimeFromString:(NSString *)stringValue;
- (void)setDurationFromString:(NSString *)stringValue;

@end
