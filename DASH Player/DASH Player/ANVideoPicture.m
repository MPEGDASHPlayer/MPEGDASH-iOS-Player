//
//  ANVideoPicture.m
//  DASH Player
//
//  Created by DataArt Apps on 24.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANVideoPicture.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

@implementation ANVideoPicture

@synthesize pts = pts, ready = ready, image = _image;

- (id)init {
    if (self = [super init]){
        
    }
    return self;
}

@end
