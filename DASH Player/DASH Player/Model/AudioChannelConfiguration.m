//
//  AudioChannelConfiguration.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "AudioChannelConfiguration.h"

@implementation AudioChannelConfiguration
- (void)setValueFromString:(NSString *)valueString {
    self.value = [valueString integerValue];
}
@end
