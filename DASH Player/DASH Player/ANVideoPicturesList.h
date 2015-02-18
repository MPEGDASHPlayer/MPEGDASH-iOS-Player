//
//  ANVideoPicturesList.h
//  DASH Player
//
//  Created by DataArt Apps on 20.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"

@class ANPicturesListElement;
@class ANVideoFrameYUV;

@interface ANPicturesListElement : NSObject {
    ANVideoFrameYUV *yuvFrame;
    ANPicturesListElement *next;
}

@property (nonatomic, strong) ANPicturesListElement *next;

@property (nonatomic, strong) ANVideoFrameYUV *yuvFrame;

@end


@interface ANVideoPicturesList : NSObject

@property (nonatomic, assign) NSUInteger count;

- (void)putPictureElement:(ANPicturesListElement *)videoPicture;
- (ANPicturesListElement *)getPictureElement;
- (void)endOfList;
- (BOOL)isEndOfList;

@end


