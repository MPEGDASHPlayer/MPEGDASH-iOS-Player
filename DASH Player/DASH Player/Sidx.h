//
//  sidx.h
//  DASH Player
//
//  Created by DataArt Apps on 09.11.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
static NSString *const ANSidxConstantSize       = @"size";
static NSString *const ANSidxConstantType       = @"type";
static NSString *const ANSidxConstantOffset     = @"offset";
static NSString *const ANSidxConstantDuration   = @"duration";
static NSString *const ANSidxConstantTime       = @"time";
static NSString *const ANSidxConstantTimescale  = @"timescale";

@interface Sidx : NSObject
@property (nonatomic, assign) uint8_t version;
@property (nonatomic, assign) uint32_t timescale;
@property (nonatomic, assign) uint32_t earliestPresentationTime;
@property (nonatomic, assign) uint32_t firstOffset;
@property (nonatomic, assign) uint16_t referenceCount;
@property (nonatomic, strong) NSArray *references;

@property (nonatomic, strong) NSError *error;

- (NSTimeInterval)scaledDurationForReferenceNumber:(NSUInteger)referenceNumber;

-(instancetype)parseSidx:(NSData *)sidxData withFirstByteOffset:(uint32_t)byteOffset;

@end
