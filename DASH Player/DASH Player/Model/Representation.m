//
//  Representation.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "Representation.h"

@implementation Representation

- (void)setAudioSamplingRateFromString:(NSString *)valueString {
    self.audioSamplingRate = [valueString integerValue];
}

- (void)setBandwidthFromString:(NSString *)valueString {
    self.bandwidth = [valueString integerValue];
}

- (void)setHeightFromString:(NSString *)valueString {
    self.height = [valueString integerValue];
}

- (void)setWidthFromString:(NSString *)valueString {
    self.width = [valueString integerValue];
}

//- (double)supposedDownloadTime {
//    if (_bandwidth > 0){
//        
//    }
//}

@end
