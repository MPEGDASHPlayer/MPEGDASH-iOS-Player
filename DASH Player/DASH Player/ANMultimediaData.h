//
//  ANMultimediaData.h
//  DASH Player
//
//  Created by DataArt Apps on 05.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "libavutil/rational.h"

@interface ANMultimediaData : NSObject
@property (nonatomic, strong) NSData *mediaData;
@property (nonatomic, assign) NSUInteger mediaDuration;
@property (nonatomic, assign) NSUInteger timescale;
@property (nonatomic, assign) double mediaDurationScaled;

@property (nonatomic, assign) NSUInteger segmentNumber;

@property (nonatomic, assign) BOOL isLastSegmentNumber;

@property (nonatomic, strong) NSData *initialData;
@end
