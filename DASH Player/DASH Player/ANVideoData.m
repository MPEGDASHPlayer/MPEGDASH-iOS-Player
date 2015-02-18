//
//  ANVideoData.m
//  DASH Player
//
//  Created by DataArt Apps on 05.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANVideoData.h"

@implementation ANVideoData
//- (NSInteger)expectedFramesNumber {
//    if (_framerate.den && _framerate.num && self.mediaDuration){
//        return (self.mediaDuration / _framerate.den) * _framerate.num;
//    }
//    return -1;
//}

- (NSInteger)expectedFramesNumber {
    if (_framerate.den && _framerate.num && self.mediaDuration){
        return (self.mediaDuration / (double)self.timescale) / ( _framerate.den / (double)_framerate.num);
    }
    return -1;
}


@end
