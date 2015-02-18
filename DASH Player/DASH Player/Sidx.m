//
//  sidx.m
//  DASH Player
//
//  Created by DataArt Apps on 09.11.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "Sidx.h"

@implementation Sidx

-(instancetype)parseSidx:(NSData *)sidxData withFirstByteOffset:(uint32_t)byteOffset {
    
    NSData *d = sidxData;
    NSUInteger pos = 0;
    uint32_t offset;
    uint32_t time;
    uint32_t sidxEnd;
    uint32_t i;
    uint32_t ref_type;
    uint32_t ref_size;
    uint32_t ref_dur;
    NSMutableString *type;
    uint32_t size;
    char charCode;
    
    while (![type isEqualToString:@"sidx"] && pos < d.length) {
        size = [self valueFromData:d atPosition:pos forBitCount:4];

        pos += 4;
        
        type = [NSMutableString string];
        for (i = 0; i < 4; ++i) {
            charCode = [self valueFromData:d atPosition:pos forBitCount:1];

            NSString* string = [NSString stringWithFormat:@"%c" , charCode];
            [type appendString:string];
            pos += 1;
        }
        
        if (![type isEqualToString:@"moof"] && ![type isEqualToString:@"traf"] && ![type isEqualToString:@"sidx"]) {
            pos += size - 8;
        } else if ([type isEqualToString:@"sidx"]) {
            // reset the position to the beginning of the box...
            // if we do not reset the position, the evaluation
            // of sidxEnd to ab.byteLength will fail.
            pos -= 8;
        }
    }
    if (pos >= d.length){
        self.error = [[NSError alloc] initWithDomain:@"Sidx parse error"
                                                code:1
                                            userInfo:@{@"Error" : @"Incorrect sidx block."}];
        return nil;

    }

    sidxEnd = [self valueFromData:d atPosition:pos forBitCount:4];
    sidxEnd += pos;

    if (sidxEnd > d.length) {
        self.error = [[NSError alloc] initWithDomain:@"Sidx parse error"
                                                code:1
                                            userInfo:@{@"Error" : @"Sidx terminates after array buffer"}];
        return nil;
    }
    
    [d getBytes:&_version range:NSMakeRange(pos + 8, 1)];

    pos += 12;
    
    _timescale = [self valueFromData:d atPosition:pos + 4 forBitCount:4];
    pos += 8;
    
    if (self.version == 0) {
        _earliestPresentationTime = [self valueFromData:d atPosition:pos forBitCount:4];
        _firstOffset = [self valueFromData:d atPosition:pos + 4 forBitCount:4];
        pos += 8;
    } else {
        // TODO(strobe): Overflow checks
        uint32_t a, b;
        a = [self valueFromData:d atPosition:pos + 4 forBitCount:4];
        b = [self valueFromData:d atPosition:pos forBitCount:4];
        
        self.earliestPresentationTime = (uint32_t)[self to64BitNumber:a high:b];


        
        a = [self valueFromData:d atPosition:pos + 8 forBitCount:4];
        b = [self valueFromData:d atPosition:pos + 12 forBitCount:4];

        self.firstOffset = (a << 32) + b;

        pos += 16;
    }

    self.firstOffset += sidxEnd + byteOffset;
    
    // skipped reserved(16)
    _referenceCount = [self valueFromData:d atPosition:pos + 2 forBitCount:2];

    pos += 4;

    NSMutableArray *references = [NSMutableArray array];

    offset = self.firstOffset;
    time = self.earliestPresentationTime;
    
    for (i = 0; i < self.referenceCount; i++) {
        ref_size = [self valueFromData:d atPosition:pos forBitCount:4];

        
        ref_type = (ref_size >> 31);
        ref_size = ref_size & 0x7fffffff;
        ref_dur = [self valueFromData:d atPosition:pos + 4 forBitCount:4];

        pos += 12;
        NSDictionary *dic = @{ANSidxConstantSize        : @(ref_size),
                              ANSidxConstantType        : @(ref_type),
                              ANSidxConstantOffset      : @(offset),
                              ANSidxConstantDuration    : @(ref_dur),
                              ANSidxConstantTime        : @(time),
                              ANSidxConstantTimescale   : @(self.timescale)};
        [references addObject:dic];
        offset += ref_size;
        time += ref_dur;
    }
    self.references = references;
    if (pos != sidxEnd) {
        NSString *error = [NSString stringWithFormat:@"Error: final pos %lu differs from SIDX end %d", (unsigned long)pos, sidxEnd];
        self.error = [[NSError alloc] initWithDomain:@"Sidx parse error"
                                                code:3
                                            userInfo:@{@"Error" : error}];
        return nil;
    }

    return self;
}

- (uint32_t)valueFromData:(NSData *)data atPosition:(NSUInteger) pos forBitCount:(Byte)bitCount{
    if (pos >= data.length){
        self.error = [[NSError alloc] initWithDomain:@"Sidx parse error"
                                                code:2
                                            userInfo:@{@"Error" : @"Requested position exceeds sidx length"}];
        return -1;
    }
    
    NSData *data4 = [data subdataWithRange:NSMakeRange(pos, bitCount)];
    uint32_t value = 0;
    if (bitCount == 4){
        value = CFSwapInt32BigToHost(*(uint32_t*)([data4 bytes]));
    } else if (bitCount == 2) {
        value = CFSwapInt16BigToHost(*(uint16_t*)([data4 bytes]));
    } else {
        value = *(uint8_t*)([data4 bytes]);
    }
        
    return value;
}

-(NSUInteger)to64BitNumber:(int32_t)low high:(int32_t)high {
    return  4294967296 * high + low;
}

- (NSTimeInterval)scaledDurationForReferenceNumber:(NSUInteger)referenceNumber {
    if (referenceNumber < self.referenceCount){
        NSDictionary *dic = self.references[referenceNumber];
        NSUInteger duration = [dic[ANSidxConstantDuration] unsignedIntegerValue];
        NSUInteger timescale = [dic[ANSidxConstantTimescale] unsignedIntegerValue];
        NSTimeInterval scaledDuration = duration / (double)timescale;
        return scaledDuration;
    }
    
    return -1.0;
}
@end
