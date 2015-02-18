//
//  ANPacketQueue.m
//  DASH Player
//
//  Created by DataArt Apps on 18.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANPacketQueue.h"
static NSUInteger ANPacketsMaxCount = 64;
@interface ANPacketQueue () {
    AVPacketList *_firstPkt;
    AVPacketList *_lastPkt;
	int _nbPackets;
	int _size;
	int _eof;
	NSLock *_mutex;
	NSCondition *_getCond;
    NSCondition *_putCond;
}

@end

@implementation ANPacketQueue
- (id)init {
    if (self = [super init]){
        _mutex = [[NSLock alloc] init];
        _getCond = [[NSCondition alloc] init];
        _putCond = [[NSCondition alloc] init];
    }
    return self;
}

-(int) putPacket:(AVPacket *) pkt {
	assert(pkt != NULL);
	
	// Duplicate current packet
	if (av_dup_packet(pkt) < 0) {
		return -1;
	}

    [_mutex lock];
    [_putCond lock];
    while (_nbPackets >= ANPacketsMaxCount){
        [_mutex unlock];
        [_putCond wait];
        [_mutex lock];
    }
	AVPacketList* pktList = av_malloc(sizeof(AVPacketList));
	if (pktList == NULL) {
		return -1;
	}
	
	pktList->pkt = *pkt;
	pktList->next = NULL;
	
	if (!_eof) {
		if (_lastPkt == NULL) {
			// It's a first packet in queue
			_firstPkt = pktList;
		} else {
			// Append to the end of queue
			_lastPkt->next = pktList;
		}
		_lastPkt = pktList;
		_nbPackets++;
		_size += pkt->size;
	}
    [_getCond signal];
    [_putCond unlock];
    [_mutex unlock];
	return 0;
}

-(int) getPacket:(AVPacket *)pkt block:(int) block {
	assert(pkt != NULL);
	[_mutex lock];
	
	AVPacketList* pktList = _firstPkt;
	if (!block && (pktList == NULL)) {
        [_mutex unlock];
		return -1;
	} else {
        [_getCond lock];
		while ((pktList == NULL) && !_eof) {
			// Wait for packets
            [_mutex unlock];
            [_getCond wait];
            [_mutex lock];
            
			pktList = _firstPkt;
		}
        [_getCond unlock];
	}
	
	if ((pktList == NULL) && _eof) {
        [_mutex unlock];
		return -1;
	}
	
	_firstPkt = pktList->next;
	if (_firstPkt == NULL) {
		// No more packets
		_lastPkt = NULL;
	}
    
	*pkt = pktList->pkt;
	_nbPackets--;
	_size -= pkt->size;
	av_free(pktList);
    
    [_putCond signal];
	[_mutex unlock];
	return 0;
}

- (void) endOfQueue {
    [_mutex lock];
	_eof = 1;
    [_getCond broadcast];
    [_putCond broadcast];
    [_mutex unlock];
}

@end
