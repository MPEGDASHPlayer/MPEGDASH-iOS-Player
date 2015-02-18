//
//  ANMultimediaData.m
//  DASH Player
//
//  Created by DataArt Apps on 05.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANMultimediaData.h"

@implementation ANMultimediaData

- (void)setTimescale:(NSUInteger)timescale {
    _timescale = timescale;
    _mediaDurationScaled = 0.0;
}

- (void)setMediaDuration:(NSUInteger)mediaDuration {
    _mediaDuration = mediaDuration;
    _mediaDurationScaled = 0.0;
}

// scaled video or audio segment duratio, calculated according to timescale value that is provided in MPD file
- (double)mediaDurationScaled {
    if (!_mediaDurationScaled){
        if (_timescale) {
            _mediaDurationScaled = ((double)_mediaDuration / (double)_timescale);
        } else {
            _mediaDurationScaled = (double)_mediaDuration;
        }
    }
    return _mediaDurationScaled;
}

@end
