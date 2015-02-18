//
//  ANRingBuffer.h
//  DASH Player
//
//  Created by DataArt Apps on 18.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ANRingBuffer : NSObject {
    uint8_t* data;
	int size;
	int max_size;
	int readIndex;  // Read position
	int writeIndex;  // Write position
	BOOL eof;  // EOF flag
	int lastOp;  // last operation flag: 0 - read, 1 - write
    NSLock *mutex;
    NSCondition *readCond;
    NSCondition *writeCond;
}
- (id)initWitSize:(int)initialSize maxSize:(int)maxSize;

- (int)write:(void *) buffer withLength:(int)len block:(BOOL) block;
- (int)read:(void*)buffer  withLength:(int)len block:(BOOL) block;
- (int)size;
- (void)eof;
- (BOOL)isEof;
@end
