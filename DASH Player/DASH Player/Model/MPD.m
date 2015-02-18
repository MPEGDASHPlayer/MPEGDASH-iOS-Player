//
//  MPD.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "MPD.h"
#import "ANXsdDurationParser.h"
@interface MPD ()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) ANXsdDurationParser *durationParser;
@end

@implementation MPD
- (id)init {
    self = [super init];
    if (self){
        self.durationParser = [[ANXsdDurationParser alloc] init];
    }
    return self;
}
- (NSDateFormatter *)dateFormater {
    if (_dateFormatter){
        _dateFormatter = [[NSDateFormatter alloc] init];
        NSTimeZone *utc = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [_dateFormatter setTimeZone:utc];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
    }
    return _dateFormatter;
}

- (void) setAvailabilityStartTimeFromString:(NSString *)availabilityStartTimeString {
    self.availabilityStartTime = [self.dateFormatter dateFromString:availabilityStartTimeString];
}

- (void) setAvailabilityEndTimeFromString:(NSString *)availabilityEndTimeString {
    self.availabilityStartTime = [self.dateFormatter dateFromString:availabilityEndTimeString];
}

- (void) setMinimumUpdatePeriodFromString:(NSString *)minimumUpdatePeriodString{
    self.minimumUpdatePeriod = [self.durationParser timeIntervalFromString:minimumUpdatePeriodString];
}

- (void) setMinBufferTimeFromString:(NSString *)minBufferTimeString {
     self.minBufferTime = [self.durationParser timeIntervalFromString:minBufferTimeString];
}

- (void) setMediaPresentationDurationFromString:(NSString *)mediaPresentationDurationString {
    self.mediaPresentationDuration = [self.durationParser timeIntervalFromString:mediaPresentationDurationString];
}

- (void) setTimeShiftBufferDepthFromString:(NSString *)timeShiftBufferDepthString {
    self.timeShiftBufferDepth = [self.durationParser timeIntervalFromString:timeShiftBufferDepthString];
}

#pragma mark - public getters
- (NSTimeInterval)updatePeriod {
    return _minimumUpdatePeriod;
}

- (AdaptationSet *)videoAdaptionSet {
    AdaptationSet *videoAs = nil;
    NSString *video = @"video";
    
    for (AdaptationSet *as in _period.adaptationSet){
        if (as.mimeType && [[as.mimeType lowercaseString] rangeOfString:video].location != NSNotFound) {
            videoAs = as;
            break;
        } else {
            Representation *rep = as.representationArray[0];
            if (rep.mimeType && [[rep.mimeType lowercaseString] rangeOfString:video].location != NSNotFound){
                videoAs = as;
                break;
            }
        }
    }
    return videoAs;
}
- (SegmentTemplate *)videoSegmentTemplate {
    AdaptationSet *videoAs = [self videoAdaptionSet];
    if (videoAs){
        if (videoAs.segmentTemplate){
            return videoAs.segmentTemplate;
        } else {
            Representation *rep = videoAs.representationArray[0];
            if (rep.segmentTemplate){
                return rep.segmentTemplate;
            }
        }
    }
    
    return nil;
}
- (AdaptationSet *)audioAdaptionSet {
    NSString *audio = @"audio";
    AdaptationSet *audioAs = nil;
    for (AdaptationSet *as in _period.adaptationSet){
        if (as.mimeType && [[as.mimeType lowercaseString] rangeOfString:audio].location != NSNotFound) {
            audioAs = as;
            break;
        } else {
            Representation *rep = as.representationArray[0];
            if (rep.mimeType && [[rep.mimeType lowercaseString] rangeOfString:audio].location != NSNotFound){
                audioAs = as;
                break;
            }
        }
    }
    return audioAs;
}

- (SegmentTemplate *)audioSegmentTemplate {
    AdaptationSet *audioAs = [self audioAdaptionSet];
    if (audioAs){
        if (audioAs.segmentTemplate){
            return audioAs.segmentTemplate;
        } else {
            Representation *rep = audioAs.representationArray[0];
            if (rep.segmentTemplate){
                return rep.segmentTemplate;
            }
        }
    }
    return nil;
}

- (ANStreamType)streamType {
    if (_type.length){
        return [[_type lowercaseString] isEqualToString:@"static"] ? ANStreamTypeStatic : ANStreamTypeDynamic;
    }
    return ANStreamTypeNone;
}

- (BOOL)isVideoRanged {
    AdaptationSet *as = self.period.adaptationSet[0];
    Representation *rep = as.representationArray[0];

    if (rep.segmentBase.indexRange){
        return YES;
    }
    
    return NO;
}
@end
