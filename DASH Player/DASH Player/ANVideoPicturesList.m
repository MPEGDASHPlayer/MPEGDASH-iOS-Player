//
//  ANVideoPicturesList.m
//  DASH Player
//
//  Created by DataArt Apps on 20.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANVideoPicturesList.h"

static NSUInteger const ANMaxCount = 32;

@implementation ANPicturesListElement
@synthesize yuvFrame = yuvFrame, next = next;

@end

@interface ANVideoPicturesList () {
    ANPicturesListElement *head;
    ANPicturesListElement *tail;
    BOOL eol;
}

@property (nonatomic, strong) NSLock *mutex;
@property (nonatomic, strong) NSCondition *cond;

@end

@implementation ANVideoPicturesList
@synthesize count = _count;

- (id)init {
    if (self = [super init]){
        self.cond = [[NSCondition alloc] init];
        self.mutex = [[NSLock alloc] init];
    }
    return self;
}

- (void)putPictureElement:(ANPicturesListElement *)videoPictureElement {
    assert(videoPictureElement);
    
    [_mutex lock];
    [_cond lock];
    if (_count){
        if (_count >= ANMaxCount){
            [_mutex unlock];
            [_cond wait];
            [_mutex lock];
        }
        tail.next = videoPictureElement;
        tail = videoPictureElement;
    } else {
        head = videoPictureElement;
        tail = head;
    }
    
    videoPictureElement.next = nil;
    _count++;
    [_mutex unlock];
    [_cond unlock];
}

- (ANPicturesListElement *)getPictureElement {
    [_mutex lock];
    ANPicturesListElement *element = nil;
    
    if (_count){
        element = head;
        head = head.next;
        _count--;
        
        if (!head){
            tail = head;
        }
    }
    
    [_cond signal];
    [_mutex unlock];
    
    return element;
}

- (void) endOfList {
    [_mutex lock];
	eol = YES;
    [_cond broadcast];
    [_mutex unlock];
}

- (BOOL)isEndOfList {
    [_mutex lock];
    BOOL isEnd = eol;
    [_mutex unlock];
    return isEnd;
}

- (NSUInteger)count {
    [_mutex lock];
    NSUInteger ret = _count;
    [_mutex unlock];
    
    return ret;
}
@end
