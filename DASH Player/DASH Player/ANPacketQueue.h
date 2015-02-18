//
//  ANPacketQueue.h
//  DASH Player
//
//  Created by DataArt Apps on 18.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

@interface ANPacketQueue : NSObject {
    
}

- (int) putPacket:(AVPacket *) pkt;
- (int) getPacket:(AVPacket*) pkt block:(int) block;
- (void) endOfQueue;
@end
