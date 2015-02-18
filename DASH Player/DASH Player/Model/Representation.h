//
//  Representation.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SegmentTemplate.h"
#import "SegmentBase.h"

@interface Representation : NSObject
@property (nonatomic, strong) NSString *id;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *codecs;
@property (nonatomic, assign) NSUInteger audioSamplingRate;
@property (nonatomic, assign) NSUInteger bandwidth;
@property (nonatomic, assign) NSUInteger height;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, strong) SegmentTemplate *segmentTemplate;
@property (nonatomic, strong) NSString *baseUrlString;
@property (nonatomic, strong) SegmentBase *segmentBase;

@property (nonatomic, assign, readonly) double supposedDownloadTime;

@property (nonatomic, assign) double downloadingSpeed;

- (void)setAudioSamplingRateFromString:(NSString *)valueString;
- (void)setBandwidthFromString:(NSString *)valueString;
- (void)setHeightFromString:(NSString *)valueString;
- (void)setWidthFromString:(NSString *)valueString;

@end
