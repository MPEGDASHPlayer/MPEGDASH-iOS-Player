//
//  AdaptationSet.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ContentComponent.h"
#import "Representation.h"
#import "SegmentTemplate.h"
#import "AudioChannelConfiguration.h"

@interface AdaptationSet : NSObject
@property (nonatomic, strong) NSString *id;
@property (nonatomic, strong) NSString *lang;
@property (nonatomic, strong) NSString *mimeType;

@property (nonatomic, assign) BOOL segmentAlignment;
@property (nonatomic, assign) NSUInteger maxWidth;
@property (nonatomic, assign) NSUInteger maxHeight;
@property (nonatomic, assign) NSUInteger maxFrameRate;
@property (nonatomic, assign) NSUInteger audioSamplingRate;


@property (nonatomic, strong) ContentComponent *contentComponent;
@property (nonatomic, strong) SegmentTemplate *segmentTemplate;
@property (nonatomic, strong) NSArray *representationArray;
@property (nonatomic, strong) AudioChannelConfiguration *audioChannelConfiguration;

- (void)setSegmentAlignmentFromString:(NSString *)valueString;
- (void)setMaxWidthString:(NSString *)valueString;
- (void)setMaxHeightFromString:(NSString *)valueString;
- (void)setMaxFrameRateFromString:(NSString *)valueString;
- (void)setAudioSamplingRateFromString:(NSString *)valueString;

- (void)addRepresentation:(Representation *)representation;

@end
