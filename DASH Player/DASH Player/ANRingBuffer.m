//
//  ANRingBuffer.m
//  DASH Player
//
//  Created by DataArt Apps on 18.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANRingBuffer.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

@implementation ANRingBuffer
- (id)initWitSize:(int)initialSize maxSize:(int)maxSize {
    if (self = [super init]){
        assert((maxSize <= 0) || (maxSize >= initialSize));
        data = av_malloc(initialSize);
        if (data == NULL) {
            return nil;
        }
        size = initialSize;
        max_size = maxSize;
        mutex = [[NSLock alloc] init];
        readCond = [[NSCondition alloc] init];
        writeCond = [[NSCondition alloc] init];
    }
    return self;
}

// Returns number of bytes written
- (int)write:(void *) buffer withLength:(int)len block:(BOOL)shouldBlock {
	assert(buffer != NULL);
	
	if (len == 0) {
		return 0;
	}
	[mutex lock];
	
	if (eof) {
		// Buffer ended
        [mutex unlock];
		return -1;
	}
	
	uint8_t* buffer_ptr = buffer;
	while (len > 0) {
		int step;
		if ((readIndex < writeIndex) ||  // write forward
			((readIndex == writeIndex) && (lastOp == 0))) // buffer must be free
        {
			step = size - writeIndex;
		} else if (readIndex > writeIndex)
        {
			step = readIndex - writeIndex;
		} else if (shouldBlock)
        {
            [readCond lock];
            [mutex unlock];
            
            [readCond wait];
            
            [readCond unlock];
            [mutex lock];
            
			if (eof) {
				break;
			}
			continue;
		} else {
			break;
		}
		
		if (len < step) {
			step = len;
		}
		memcpy(data + writeIndex, buffer_ptr, step);
		
		writeIndex += step;
		assert(writeIndex <= size);
		if (writeIndex == size) {
			writeIndex = 0;
		}
		lastOp = 1;
        [writeCond signal];
		
		buffer_ptr += step;
		len -= step;
	}
    
	[mutex unlock];
	return (int)(buffer_ptr - (uint8_t*)buffer);
}

- (int)read:(void *)buffer  withLength:(int)len block:(BOOL) shouldBlock {
	assert(buffer != NULL);
	
	if (len == 0) {
		return 0;
	}
	
    [mutex lock];
	
	uint8_t* buffer_ptr = buffer;
	while (len > 0) {
		int step;
		if (readIndex < writeIndex) {  // write forward
			step = writeIndex - readIndex;
		} else if ((readIndex > writeIndex) ||  // read forward
				   ((readIndex == writeIndex) && (lastOp == 1)))// buffer must be full
        {  
			step = size - readIndex;
		} else if (shouldBlock && !eof) {
            [writeCond lock];
            [mutex unlock];
            
            [writeCond wait];
            
            [mutex lock];
            [writeCond unlock];
			continue;
		} else {
			break;
		}
		
		if (len < step) {
			step = len;
		}
        
		memcpy(buffer_ptr, data + readIndex, step);
		
		readIndex += step;
		assert(readIndex <= size);
		if (readIndex == size) {
			readIndex = 0;
		}
		lastOp = 0;
        [readCond signal];
		
		buffer_ptr += step;
		len -= step;
	}
	
	int count = (int)(buffer_ptr - (uint8_t*)buffer);
	if ((count == 0) && eof) {
		count = -1;
	}
	[mutex unlock];
	return count;
}

- (int)size {
	int aSize;
    [mutex lock];
	if (readIndex < writeIndex) {
		aSize = writeIndex - readIndex;
	} else {
		aSize = size - readIndex + writeIndex;
	}
    [mutex unlock];
	return aSize;
}

- (void) eof {
	[mutex lock];
    
    eof = YES;
    [readCond broadcast];
    [writeCond broadcast];
    [mutex unlock];
}

- (BOOL)isEof {
    [mutex lock];
    BOOL val = eof;
    [mutex unlock];
    
    return val;
}

- (void)dealloc {
    av_free(data);
}

@end

