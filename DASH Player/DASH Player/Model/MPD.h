//  MPD.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ANDashMultimediaManager.h"
#import "ProgramInformation.h"
#import "Period.h"

@interface MPD : NSObject

@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSDate *availabilityStartTime;
@property (nonatomic, strong) NSDate *availabilityEndTime;

@property (nonatomic, assign) NSInteger minimumUpdatePeriod;
@property (nonatomic, assign) NSInteger minBufferTime;
@property (nonatomic, assign) NSTimeInterval mediaPresentationDuration;
@property (nonatomic, assign) NSTimeInterval timeShiftBufferDepth;

@property (nonatomic, strong) Period *period;
@property (nonatomic, strong) ProgramInformation *programInformation;

@property (nonatomic, assign, getter=isVideoRanged) BOOL videoIsRanged;

- (void) setAvailabilityStartTimeFromString:(NSString *)availabilityStartTimeString;
- (void) setAvailabilityEndTimeFromString:(NSString *)availabilityEndTimeString;

- (void) setMinimumUpdatePeriodFromString:(NSString *)minimumUpdatePeriodString;
- (void) setMinBufferTimeFromString:(NSString *)minBufferTimeString;
- (void) setMediaPresentationDurationFromString:(NSString *)mediaPresentationDurationString;
- (void) setTimeShiftBufferDepthFromString:(NSString *)timeShiftBufferDepthString;

- (NSTimeInterval)updatePeriod;

- (SegmentTemplate *)audioSegmentTemplate;
- (SegmentTemplate *)videoSegmentTemplate;
- (ANStreamType)streamType;
- (AdaptationSet *)videoAdaptionSet;
- (AdaptationSet *)audioAdaptionSet;
@end
