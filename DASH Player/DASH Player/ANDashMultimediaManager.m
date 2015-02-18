//
//  ANDashMultimediaManager.m
//  DASH Player
//
//  Created by DataArt Apps on 07.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANDashMultimediaManager.h"
#import "MPD.h"
#import "ANHttpClient.h"
#import "ANMpdManager.h"
#import "ANSegmentsManager.h"

#import "ANVideoData.h"
#import "ANAudioData.h"

static NSString * const ANTemplateNumber            = @"$Number$";
static NSString * const ANTemplateRepresentationID  = @"$RepresentationID$";
static NSString * const ANTemplateTime              = @"$Time$";

@interface ANDashMultimediaManager () <ANMpdManagerDelegate> {
    double              _audioTimeScale;
    double              _videoTimeScale;
    
    NSTimeInterval      _totalMediaDuration;
    
    ANAudioData *       _firstAudioData;
    ANVideoData *       _firstVideoData;
    
    NSInteger           statMaxSegmentNumber;// just for static
    NSInteger           dynLastSegmentIndex;
    NSInteger           dynCurrentSegmentIndex;
    
    BOOL                _delegateRespondsToManagerDidFailWithMessage;
    BOOL                _delegateRespondsToManagerDidDownloadVideoData;
    BOOL                _delegateRespondsToManagerDidDownloadAudioData;
    
    BOOL                videoSegmentIsUpdated;
    BOOL                audioSegmentIsUpdated;
    
    BOOL                dynMediaIsFinished;
}
@property (nonatomic, strong) NSURL             *mpdUrl;
@property (nonatomic, strong) MPD               *mpd;
@property (nonatomic, strong) NSURL             *baseUrl;

@property (nonatomic, strong) NSTimer           *mpdUpdateTimer;

@property (nonatomic, strong) ANMpdManager      *mpdManager;
@property (nonatomic, strong) ANHttpClient      *client;

@property (nonatomic, strong) SegmentTemplate   *audioSegmentTemplate;
@property (nonatomic, strong) SegmentTemplate   *videoSegmentTemplate;

@property (nonatomic, strong) ANSegmentsManager *segmentManager;

@property (nonatomic, strong) NSArray           *videoSegmentsInfoArray;
@property (nonatomic, strong) NSArray           *audioSegmentsInfoArray;

@property (nonatomic, strong) Segment           *currentVideoSegment;

@property (nonatomic, strong) Segment           *currentAudioSegment;


@property (nonatomic, strong) NSLock            *nextVideoSegmentLock;
@property (nonatomic, strong) NSLock            *nextAudioSegmentLock;

@property (nonatomic, strong) NSCondition       *downloadsCondition;

@property (nonatomic, strong) NSCondition       *videoSegmentWaitingCondition;
@property (nonatomic, strong) NSCondition       *audioSegmentWaitingCondition;

@property (nonatomic, assign) NSInteger         downloadsConditionPredecate;

@property (nonatomic, assign) double            videoSegmentDuration;
@property (nonatomic, assign) double            audioSegmentDuration;

@property (nonatomic, assign) BOOL              firstStart;

// for static
@property (nonatomic, strong) AdaptationSet     *videoAdaptionSet;
@property (nonatomic, strong) AdaptationSet     *audioAdaptionSet;

@property (nonatomic, strong) NSArray           *videoRepArray;
@property (nonatomic, strong) NSArray           *audioRepArray;

@property (nonatomic, assign) NSInteger         currentVideoSegmentIndex;
@property (nonatomic, assign) NSInteger         currentAudioSegmentIndex;
@property (nonatomic, assign) NSInteger         currentVideoRepIndex;

@property (nonatomic, strong) NSMutableArray    *initialSegmentsArray;
@property (nonatomic, strong) NSMutableArray    *initialSegmentsURLArray;

@end

@implementation ANDashMultimediaManager

+ (void) __attribute__((noreturn)) dashMultimediaThreadEntryPoint:(id)__unused object {
    do {
        @autoreleasepool {
            [[NSThread currentThread] setName:@"ANDashMultimediaManagerThread"];
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}

+ (NSThread *)dashMultimediaThread {
    static NSThread *_dashMultimediaThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _dashMultimediaThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(dashMultimediaThreadEntryPoint:)
                                                          object:nil];
        [_dashMultimediaThread start];
    });
    
    return _dashMultimediaThread;
}

- (id)init {
    self = [super init];
    if (self){
        self.client                         = [ANHttpClient sharedHttpClient];
        
        self.segmentManager                 = [[ANSegmentsManager alloc] init];
        self.firstStart                     = YES;
        
        self.downloadsCondition             = [[NSCondition alloc] init];
        self.videoSegmentWaitingCondition   = [[NSCondition alloc] init];
        self.audioSegmentWaitingCondition   = [[NSCondition alloc] init];
        
        self.nextVideoSegmentLock           = [[NSLock alloc] init];
        self.nextAudioSegmentLock           = [[NSLock alloc] init];
        
        self.initialSegmentsArray           = [NSMutableArray array];
        self.initialSegmentsURLArray        = [NSMutableArray array];
    }
    return self;
}

- (id)initWithMpdUrl:(NSURL *)mpdUrl {
    self = [self init];
    if (self){
        NSAssert(mpdUrl, @"MPD URL cannot be nil");
        self.mpdUrl                         = mpdUrl;
    }
    
    return self;
}

- (void)setMpdUrl:(NSURL *)mpdUrl {
    _mpdUrl = mpdUrl;
    self.baseUrl = [mpdUrl URLByDeletingLastPathComponent];
    self.mpdManager = [[ANMpdManager alloc] initWithMpdUrl:mpdUrl];
    self.mpdManager.delegate = self;
}
- (void)setDelegate:(id<ANDashMultimediaMangerDelegate>)delegate {
    _delegate = delegate;
    
    _delegateRespondsToManagerDidDownloadAudioData = [delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                            didDownloadAudioData:)];
    _delegateRespondsToManagerDidDownloadVideoData = [delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                            didDownloadVideoData:)];
    _delegateRespondsToManagerDidFailWithMessage = [delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                            didFailWithMessage:)];
    
}
#pragma mark - accessors
- (void)setCurrentVideoSegment:(Segment *)currentSegment {
    assert(currentSegment);
    _currentVideoSegment = currentSegment;
}
- (void)setCurrentAudioSegment:(Segment *)currentSegment {
    assert(currentSegment);
    _currentAudioSegment = currentSegment;
}

- (void)setVideoSegmentTemplate:(SegmentTemplate *)videoSegmentTemplate {
    _videoSegmentTemplate = videoSegmentTemplate;
    _videoTimeScale = [videoSegmentTemplate timescale];
    
    self.videoSegmentsInfoArray = videoSegmentTemplate.segmentTimeline.segmentArray;
    dynLastSegmentIndex = ((Segment *)[self.videoSegmentsInfoArray lastObject]).t;
    
    dynMediaIsFinished = self.videoSegmentsInfoArray.count <= 1;
    
    videoSegmentIsUpdated = YES;
    [self.videoSegmentWaitingCondition signal];
}

- (void)setAudioSegmentTemplate:(SegmentTemplate *)audioSegmentTemplate {
    _audioSegmentTemplate = audioSegmentTemplate;
    _audioTimeScale = [audioSegmentTemplate timescale];
    
    self.audioSegmentsInfoArray = audioSegmentTemplate.segmentTimeline.segmentArray;
    

    audioSegmentIsUpdated = YES;
    [self.audioSegmentWaitingCondition signal];
}

- (NSTimeInterval)totalMediaDuration {
    return _totalMediaDuration;
}

- (void)setAudioAdaptionSet:(AdaptationSet *)audioAdaptionSet {
    _audioAdaptionSet = audioAdaptionSet;
    self.audioRepArray = audioAdaptionSet.representationArray;
}
- (void)setVideoAdaptionSet:(AdaptationSet *)videoAdaptionSet {
    _videoAdaptionSet = videoAdaptionSet;
    self.videoRepArray = videoAdaptionSet.representationArray;
}

#pragma mark - launch methods
- (void)launchManager {
    self.firstStart = YES;
    self.mpdManager.currentThread = [[self class] dashMultimediaThread];
    [self performSelector:@selector(startWork)
                 onThread:[[self class] dashMultimediaThread]
               withObject:nil
            waitUntilDone:NO];
}

-(void)startWork {
    [self.mpdManager updateMpd];
}

- (void)setStopped:(BOOL)stopped {
    _stopped = stopped;
    if (stopped){
        [self.client cancelDownloading];
    }
}

#pragma mark - MPDManager Delegate
- (void)mpdManager:(ANMpdManager *)manager didFinishParsingMpdFile:(MPD *)mpd {
    self.mpd = mpd;
    _streamType = [mpd streamType];
    
    self.audioSegmentTemplate = [_mpd audioSegmentTemplate];
    self.videoSegmentTemplate = [_mpd videoSegmentTemplate];
    
    self.videoAdaptionSet = [_mpd videoAdaptionSet];
    self.audioAdaptionSet = [_mpd audioAdaptionSet];
    
    
    if (_firstStart){
        if (_streamType == ANStreamTypeDynamic) {
            [self dynamic_processFirstStart];
        } else if (_streamType == ANStreamTypeStatic) {
            [self static_processFirstStart];
        }
    }
}

#pragma mark - dynamic stream processing
- (void)dynamic_processFirstStart {
    DLog(@"DASH - download initial video segment");
    self.firstStart = NO;
    
    self.currentVideoSegment = _videoSegmentsInfoArray[0];
    self.currentAudioSegment = _audioSegmentsInfoArray[0];
    
    if(![self downloadInitialVideoSegment:[self initialVideoSegmentUrlForRep:self.videoRepArray[0]]
                             audioSegment:[self initialAudioSegmentUrl]]){
        NSLog(@"DASH - Error while downloading init segments");
        if (_delegateRespondsToManagerDidFailWithMessage){
            [self.delegate dashMultimediaManger:self
                             didFailWithMessage:@"DASH - Error while downloading init segments"];
        }
        return;
    }

    for (Representation *rep in self.videoRepArray){
        if (![self downloadAllInitialVideoSegmentForRep:rep]){
            NSLog(@"DASH - Cannot download all initial video segments");
            if (_delegateRespondsToManagerDidFailWithMessage){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download all initial video segments"];
            }
            return;
        }
    }
    
    if (![self downloadFirstVideoSegment:[self dynamic_nextVideoSegmentURL]
                       firstAudioSegment:[self dynamic_nextAudioSegmentURL]]){
        NSLog(@"DASH - Error while downloading media segments");
        if (_delegateRespondsToManagerDidFailWithMessage){
            [self.delegate dashMultimediaManger:self
                             didFailWithMessage:@"DASH - Error while downloading media segments"];
        }
        return;
    }
    [self.delegate dashMultimediaManger:self
           didDownloadFirstVideoSegment:_firstVideoData
                      firstAudioSegment:_firstAudioData];
    
    NSTimeInterval mpdUpdatePeriod = [_mpd updatePeriod];
    if (!mpdUpdatePeriod){
        mpdUpdatePeriod = 5.0;
    }
    
    self.mpdUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:mpdUpdatePeriod
                                                           target:self
                                                         selector:@selector(dynamicTimerFire_updateMpd:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    [self dynamic_downloadNextVideoSegment];
    [self dynamic_downloadNextAudioSegment];
}

- (void)dynamic_downloadNextVideoSegment {
    NSURL *videSegmentURL = [self dynamic_nextVideoSegmentURL];
    if (!videSegmentURL){
        return;
    }
    __weak ANDashMultimediaManager *theWeakSelf = self;
    
    [self.segmentManager downloadVideoSegment:videSegmentURL
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              
                              if (success && theStrongSelf && !theStrongSelf.stopped){
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadVideoData:)])
                                  {
                                      ANVideoData *videoData = [[ANVideoData alloc] init];
                                      videoData.mediaData = theStrongSelf.segmentManager.lastVideoSegmentData;
                                      videoData.mediaDuration = [theStrongSelf videoSegmentDuration];
                                      videoData.timescale = theStrongSelf->_videoTimeScale;
                                      videoData.initialData = [theStrongSelf initialVideoDataForRepIndex:0];
                                      videoData.isLastSegmentNumber = (dynCurrentSegmentIndex == dynLastSegmentIndex) && dynMediaIsFinished;
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadVideoData:videoData];
                                  }
                              } else if (!success){
                                  NSString *message = [NSString stringWithFormat:@"DASH - Video segment download error: %@", error];
                                  NSLog(@"DASH - Video segment download error: %@", message);
                                  if (_delegateRespondsToManagerDidFailWithMessage){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:message];
                                  }
                              }
                          }];
}

- (void)dynamic_downloadNextAudioSegment {
    NSURL *audioSegmentUrl = [self dynamic_nextAudioSegmentURL];
    if (!audioSegmentUrl){
        return;
    }
    __weak ANDashMultimediaManager *theWeakSelf = self;
    
    [self.segmentManager downloadAudioSegment:audioSegmentUrl
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              if (success && theStrongSelf  && !theStrongSelf.stopped){
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadAudioData:)])
                                  {
                                      ANAudioData *audioData = [[ANAudioData alloc] init];
                                      audioData.mediaData = theStrongSelf.segmentManager.lastAudioSegmentData;
                                      audioData.mediaDuration = [theStrongSelf audioSegmentDuration];;
                                      audioData.timescale = theStrongSelf->_audioTimeScale;
                                      
                                      audioData.isLastSegmentNumber = (dynCurrentSegmentIndex == dynLastSegmentIndex) && dynMediaIsFinished;
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadAudioData:audioData];
                                      
                                  }
                              } else if (!success){
                                  NSString *message = [NSString stringWithFormat:@"DASH - Video segment download error: %@", error];
                                  NSLog(@"DASH - Video segment download error: %@", message);
                                  if (_delegateRespondsToManagerDidFailWithMessage){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:message];
                                  }
                              }
                          }];
}

#pragma mark - NSTimer
// timer fire method for regular updated of MPD file
- (void)dynamicTimerFire_updateMpd:(NSTimer *)timer {
    [self startWork];
}

#pragma mark - video segments
// get next S element in SegmentTimeline section of SegmentTemplate for video
- (Segment *)dynamic_nextVideoSegment {
    if (dynMediaIsFinished){
        return nil;
    }
    
    [_nextVideoSegmentLock lock];
    
    Segment *segment = nil;
    int tries = 0;
    
    while (!segment && tries < 2) {
        NSUInteger index = [self.videoSegmentsInfoArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop){
            Segment *s = (Segment *)obj;
            if (s.t == self.currentVideoSegment.t) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        
        if (index != NSNotFound){
            if (index + 1 < self.videoSegmentsInfoArray.count){
                segment = self.videoSegmentsInfoArray[index + 1];
            } else {
                [self.videoSegmentWaitingCondition lock];
                while (!videoSegmentIsUpdated) {
                    [self.videoSegmentWaitingCondition wait];
                }
                videoSegmentIsUpdated = NO;
                [self.videoSegmentWaitingCondition unlock];
            }
        } else {
            segment = self.videoSegmentsInfoArray[0];
        }
        tries++;
    }
    self.videoSegmentDuration = segment.d;
    [_nextVideoSegmentLock unlock];
    return segment;
}

// create URL for next video segment using SegmentTimeline section of mpd file
- (NSURL *)dynamic_nextVideoSegmentURL {
    self.currentVideoSegment = [self dynamic_nextVideoSegment];
    if (!self.currentVideoSegment){
        return nil;
    }
    NSString *pathComponent = [self.videoSegmentTemplate media];
    NSString *tString = [NSString stringWithFormat:@"%lu", (unsigned long)self.currentVideoSegment.t];
    dynCurrentSegmentIndex = self.currentVideoSegment.t;
    
    pathComponent = [pathComponent stringByReplacingOccurrencesOfString:ANTemplateTime
                                                             withString:tString];
    
    return [self.baseUrl URLByAppendingPathComponent:pathComponent];
}

#pragma mark - audio segments

// get next S element in SegmentTimeline section of SegmentTemplate for audio
- (Segment *)dynamic_nextAudioSegment {
    if (dynMediaIsFinished){
        return nil;
    }
    
    [_nextAudioSegmentLock lock];
    
    Segment *segment = nil;
    int tries = 0;
    
    while (!segment && tries < 2) {
        NSUInteger index = [self.audioSegmentsInfoArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop){
            Segment *s = (Segment *)obj;
            if (s.t == self.currentAudioSegment.t) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        
        if (index != NSNotFound){
            if (index + 1 < _audioSegmentsInfoArray.count) {
                segment = self.audioSegmentsInfoArray[index + 1];
            } else {
                [self.audioSegmentWaitingCondition lock];
                while (!audioSegmentIsUpdated) {
                    [self.audioSegmentWaitingCondition wait];
                }
                audioSegmentIsUpdated = NO;
                [self.audioSegmentWaitingCondition unlock];
            }
        } else {
            segment = self.audioSegmentsInfoArray[0];
        }
        tries++;
    }
    
    self.audioSegmentDuration = segment.d;
    [_nextAudioSegmentLock unlock];
    return segment;
}

// create URL for next audio segment using SegmentTimeline section of mpd file
- (NSURL *)dynamic_nextAudioSegmentURL {
    self.currentAudioSegment = [self dynamic_nextAudioSegment];
    if (!self.currentAudioSegment){
        return nil;
    }
    NSString *template = [self.audioSegmentTemplate media];

    NSString *tString = [NSString stringWithFormat:@"%lu", (unsigned long)self.currentAudioSegment.t];
    template = [template stringByReplacingOccurrencesOfString:ANTemplateTime
                                                   withString:tString];
    return [self.baseUrl URLByAppendingPathComponent:template];
}

#pragma mark -
#pragma mark - static stream processing
- (void)static_processFirstStart {
    DLog(@"DASH - static_processMPD");
    self.videoSegmentDuration = [_videoSegmentTemplate duration];
    self.audioSegmentDuration = [_audioSegmentTemplate duration];
    _totalMediaDuration = [_mpd mediaPresentationDuration];
    
    statMaxSegmentNumber = ((_totalMediaDuration / (self.videoSegmentDuration / _videoTimeScale)) + 1);
    
    self.currentVideoSegmentIndex = self.videoSegmentTemplate.startNumber;
    self.currentAudioSegmentIndex = self.audioSegmentTemplate.startNumber ;
    
    if(![self downloadInitialVideoSegment:[self initialVideoSegmentUrlForRep:self.videoRepArray[0]]
                             audioSegment:[self initialAudioSegmentUrl]]){
        NSLog(@"DASH - Error while downloading init segments");
        if (_delegateRespondsToManagerDidFailWithMessage){
            [self.delegate dashMultimediaManger:self
                             didFailWithMessage:@"DASH - Error while downloading init segments"];
        }
        return;
    }
    
    for (Representation *rep in self.videoRepArray){
        if (![self downloadAllInitialVideoSegmentForRep:rep]){
            NSLog(@"DASH - Cannot download all initial video segments");
            if (_delegateRespondsToManagerDidFailWithMessage){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download some of initial video segments"];
            }
            return;
        }
    }
    
    self.firstStart = NO;
    [self static_downloadSegmentsForStart];
}

- (void)static_downloadSegmentsForStart {
    // download first video/audio segment to start playback
    if (![self downloadFirstVideoSegment:[self static_nextVideoSegmentURL]
                       firstAudioSegment:[self static_nextAudioSegmentURL]]){
        NSLog(@"DASH - Cannot download media segments");
        if (_delegateRespondsToManagerDidFailWithMessage){
            [self.delegate dashMultimediaManger:self
                             didFailWithMessage:@"DASH - Cannot download media segments"];
        }
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                    didDownloadFirstVideoSegment:
                                                    firstAudioSegment:)])
    {
        [self.delegate dashMultimediaManger:self
               didDownloadFirstVideoSegment:_firstVideoData
                          firstAudioSegment:_firstAudioData];
    }
    
    [self static_downloadNextAudioSegment];
    [self static_downloadNextVideoSegment];
}

- (void)static_downloadNextVideoSegment {
    __weak ANDashMultimediaManager *theWeakSelf = self;
    if ((_currentVideoSegmentIndex - 1) >= statMaxSegmentNumber){
        return;
    }
    [self.segmentManager downloadVideoSegment:[self static_nextVideoSegmentURL]
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              DLog(@"DASH - downloaded next VIDEO segment with success - %@", success ? @"YES" : @"NO");
                              if (success && theStrongSelf && !theStrongSelf.stopped){
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadVideoData:)])
                                  {
                                      ANVideoData *videoData = [[ANVideoData alloc] init];
                                      videoData.mediaData = theStrongSelf.segmentManager.lastVideoSegmentData;
                                      videoData.mediaDuration = [theStrongSelf videoSegmentDuration];
                                      videoData.timescale = theStrongSelf->_videoTimeScale;
                                      videoData.initialData = [theStrongSelf initialVideoDataForRepIndex:theStrongSelf.currentVideoRepIndex];
                                      videoData.segmentNumber = theStrongSelf.currentVideoSegmentIndex - 1;
                                      videoData.isLastSegmentNumber = (_currentVideoSegmentIndex - 1) >= statMaxSegmentNumber;
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadVideoData:videoData];
                                  }
                              } else if (!success) {
                                  NSLog(@"DASH - Video segment download error: %@", error);
                                  if (_delegateRespondsToManagerDidFailWithMessage){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:@"DASH - Video segment download error"];
                                  }
                              }
                          }];
}

- (void)static_downloadNextAudioSegment {
    __weak ANDashMultimediaManager *theWeakSelf = self;
    if ((_currentAudioSegmentIndex - 1) >= statMaxSegmentNumber){
        return;
    }
    [self.segmentManager downloadAudioSegment:[self static_nextAudioSegmentURL]
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              DLog(@"DASH - downloaded next AUDIO segment with success - %@", success ? @"YES" : @"NO");
                              if (success && theStrongSelf && !theStrongSelf.stopped){
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadAudioData:)])
                                  {
                                      ANAudioData *audioData = [[ANAudioData alloc] init];
                                      audioData.mediaData = theStrongSelf.segmentManager.lastAudioSegmentData;
                                      audioData.mediaDuration = [theStrongSelf audioSegmentDuration];;
                                      audioData.timescale = theStrongSelf->_audioTimeScale;
                                      audioData.isLastSegmentNumber = (_currentAudioSegmentIndex - 1) >= statMaxSegmentNumber;
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadAudioData:audioData];
                                  }
                              } else if (!success) {
                                  if (_delegateRespondsToManagerDidFailWithMessage){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:@"DASH - Audio segment download error"];
                                  }
                              }
                          }];
}

- (void)shiftVideoToPosition:(NSTimeInterval)pos {
    NSInteger desiredIndex = (int) pos / (self.videoSegmentDuration / _videoTimeScale);
    if (desiredIndex < self.videoSegmentTemplate.startNumber) {
        desiredIndex = self.videoSegmentTemplate.startNumber;
    }
    if (desiredIndex > statMaxSegmentNumber){
        desiredIndex = statMaxSegmentNumber;
    }
    self.currentAudioSegmentIndex = desiredIndex;
    self.currentVideoSegmentIndex = desiredIndex;
    [self static_downloadSegmentsForStart];
}

#pragma mark - next video segments
- (Representation *)static_currentVideoRep {
    // TODO: return proper video rep
    if (_firstStart){
        return self.videoRepArray[0];
    } else {
        return [self selectVideoRepresentation];
    }
    return nil;
}

- (Representation *)selectVideoRepresentation {
    assert(_videoSegmentDuration);
    assert(_videoTimeScale);

    if (_videoRepArray.count == 0) {
        return _videoRepArray[0];
    }
    
    Representation *audioRep = self.audioRepArray[0];// defauld audio rep
    Representation *retRep = nil;
    double downloadingSpeed = 0.0;
    if ([self.client lastBytesDownloaded] > 1024){
        downloadingSpeed = [self.client lastNetworkSpeed];
    } else {
        downloadingSpeed = [self.client averageNetworkSpeed];
    }
    
    double scaledDuration = _videoSegmentDuration / _videoTimeScale;
    for (Representation *rep in self.videoRepArray){
        double downloadingTime = (([rep bandwidth] + [audioRep bandwidth]) * scaledDuration) / (downloadingSpeed * 8);
        
        if(downloadingTime > scaledDuration - 1.0){
            if (retRep == nil){
                retRep = rep;
            }
            break;
        }
        
        retRep = rep;
    }
    
    _currentVideoRepIndex = [self.videoRepArray indexOfObject:retRep];
    // forbid switching to full hd
    if (retRep.width > 1280 && _currentVideoRepIndex > 0){
        _currentVideoRepIndex--;
        retRep = self.videoRepArray[_currentVideoRepIndex];
    }
    
    return retRep;
}

- (Representation *)static_currentAudioRep {
    // TODO: return proper audio rep
    return self.audioAdaptionSet.representationArray[0];
}


- (NSURL *)static_nextAudioSegmentURL {
    
    NSString *template = [self.audioSegmentTemplate media];
    NSURL *url = nil;
    
    if ([template rangeOfString:ANTemplateRepresentationID].location != NSNotFound){
        template = [template stringByReplacingOccurrencesOfString:ANTemplateRepresentationID
                                                       withString:[self static_currentAudioRep].id];
    }
    
    if ([template rangeOfString:ANTemplateNumber].location != NSNotFound){
        template = [template stringByReplacingOccurrencesOfString:ANTemplateNumber
                                                       withString:[NSString stringWithFormat:@"%lu", (unsigned long)_currentAudioSegmentIndex]];
    }
    _currentAudioSegmentIndex++;
    url = [self.baseUrl URLByAppendingPathComponent:template];
    return url;
}

- (NSURL *)static_nextVideoSegmentURL {
   
    NSString *template = [self.videoSegmentTemplate media];
    NSRange firstRange = [template rangeOfString:@"$"];
    if (firstRange.location != NSNotFound){
        if ([template rangeOfString:ANTemplateRepresentationID].location != NSNotFound){
            template = [template stringByReplacingOccurrencesOfString:ANTemplateRepresentationID
                                                           withString:[self static_currentVideoRep].id];
        }
        if ([template rangeOfString:ANTemplateNumber].location != NSNotFound){
            template = [template stringByReplacingOccurrencesOfString:ANTemplateNumber
                                                           withString:[NSString stringWithFormat:@"%lu",(unsigned long)_currentVideoSegmentIndex]];
        }
    }
    _currentVideoSegmentIndex ++;
    return [self.baseUrl URLByAppendingPathComponent:template];
}


#pragma mark - common dyn and stat methods

#pragma mark - download methods
- (NSURL *)initialVideoSegmentUrlForRep:(Representation *)rep {
    NSString *initSegUrl = [_videoSegmentTemplate initialization];
    NSRange range = [initSegUrl rangeOfString:ANTemplateRepresentationID];
    
    if (range.location != NSNotFound){
        NSString *link = [initSegUrl stringByReplacingOccurrencesOfString:ANTemplateRepresentationID
                                                               withString:rep.id];
        return [self.baseUrl URLByAppendingPathComponent:link];
    } else {
        return [self.baseUrl URLByAppendingPathComponent:initSegUrl];
    }
    // is never reached
    return nil;
}

- (NSURL *)initialAudioSegmentUrl {
    NSString *initSegUrl = self.audioSegmentTemplate.initialization;
    NSRange range = [initSegUrl rangeOfString:ANTemplateRepresentationID];
    
    if (range.location != NSNotFound){
        Representation *rep = [self static_currentAudioRep];
        NSString *link = [initSegUrl stringByReplacingOccurrencesOfString:ANTemplateRepresentationID
                                                               withString:[rep id]];
        return [self.baseUrl URLByAppendingPathComponent:link];
    } else {
        return [self.baseUrl URLByAppendingPathComponent:initSegUrl];
    }
    // is never reached
    return nil;
}

- (BOOL)downloadAllInitialVideoSegmentForRep:(Representation *)rep {
    _downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManager *theWeakSelf = self;
        NSURL *url = [self initialVideoSegmentUrlForRep:rep];
        [self.initialSegmentsURLArray addObject:[url absoluteString]];
        
        [self.segmentManager downloadInitialVideoSegment:url
                                     withCompletionBlock:^(BOOL success, NSError *error, id response){
                                         [theWeakSelf.downloadsCondition lock];
                                         if (success){
                                             [theWeakSelf.initialSegmentsArray addObject:response];
                                             theWeakSelf.downloadsConditionPredecate += 1;
                                         } else {
                                             DLog(@"DASH - Failure");
                                         }
                                         [theWeakSelf.downloadsCondition signal];
                                         [theWeakSelf.downloadsCondition unlock];
                                     }];
    
    return [self downloadConditionPredecateResultForValue:1];
}

- (BOOL)downloadInitialVideoSegment:(NSURL *)videoSegmentUrl audioSegment:(NSURL *)audioSegmentUrl {
    _downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManager *theWeakSelf = self;
    
    [self.segmentManager downloadInitialVideoSegment:videoSegmentUrl
                                 withCompletionBlock:^(BOOL success, NSError *error, id response){
                                     if (success){
                                         [theWeakSelf.downloadsCondition lock];
                                         theWeakSelf.downloadsConditionPredecate += 1;
                                         [theWeakSelf.downloadsCondition signal];
                                         [theWeakSelf.downloadsCondition unlock];
                                     }
                                     
                                 }];
    
    [self.segmentManager downloadInitialAudioSegment:audioSegmentUrl
                                 withCompletionBlock:^(BOOL success, NSError *error){
                                     if (success){
                                         [theWeakSelf.downloadsCondition lock];
                                         theWeakSelf.downloadsConditionPredecate += 1;
                                         [theWeakSelf.downloadsCondition signal];
                                         [theWeakSelf.downloadsCondition unlock];
                                     }
                                 }];
    
    
    return  [self downloadConditionPredecateResultForValue:2];
}

- (BOOL)downloadFirstVideoSegment:(NSURL *)videoSegmentUrl
                firstAudioSegment:(NSURL *)audioSegmentUrl
{
    __weak ANDashMultimediaManager *theWeakSelf = self;
    _downloadsConditionPredecate = 0;
    
    [self.segmentManager downloadVideoSegment:videoSegmentUrl
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              [theWeakSelf.downloadsCondition lock];
                              if (success && theStrongSelf){
                                  ANVideoData *videoData = [[ANVideoData alloc] init];
                                  videoData.mediaData = theStrongSelf.segmentManager.lastVideoSegmentData;
                                  videoData.mediaDuration = [theStrongSelf videoSegmentDuration];
                                  videoData.timescale = theStrongSelf->_videoTimeScale;
                                  
                                  videoData.initialData = [theStrongSelf initialVideoDataForRepIndex:theStrongSelf.currentVideoRepIndex];
                                  
                                  videoData.timeSinceMediaBeginning = (theStrongSelf.videoSegmentDuration *
                                                                       (theStrongSelf.currentVideoSegmentIndex - 2)
                                                                       ) / theStrongSelf->_videoTimeScale;
                                  
                                  videoData.segmentNumber = theStrongSelf.currentVideoSegmentIndex - 1;
                                  theStrongSelf->_firstVideoData = videoData;

                                  theWeakSelf.downloadsConditionPredecate += 1;
                              } else {
                                  DLog(@"DASH - download failure");
                              }
                              
                              [theWeakSelf.downloadsCondition signal];
                              [theWeakSelf.downloadsCondition unlock];
                          }];
    
    [self.segmentManager downloadAudioSegment:audioSegmentUrl
                          withCompletionBlock:^(BOOL success, NSError *error){
                              __strong ANDashMultimediaManager *theStrongSelf = theWeakSelf;
                              [theWeakSelf.downloadsCondition lock];
                              if (success && theStrongSelf){
                                  ANAudioData *audioData = [[ANAudioData alloc] init];
                                  audioData.mediaData = theStrongSelf.segmentManager.lastAudioSegmentData;
                                  audioData.mediaDuration = [theStrongSelf audioSegmentDuration];;
                                  audioData.timescale = theStrongSelf->_audioTimeScale;
                                  
                                  theStrongSelf->_firstAudioData = audioData;
                                  
                                  theWeakSelf.downloadsConditionPredecate += 1;
                              } else {
                                  DLog(@"DASH - download failure");
                              }
                              [theWeakSelf.downloadsCondition signal];
                              [theWeakSelf.downloadsCondition unlock];
                          }];
    
    return [self downloadConditionPredecateResultForValue:2];
}

- (NSData *)initialVideoDataForRepIndex:(NSInteger)index {
    assert(index <= self.videoRepArray.count - 1);
    
    NSData *data = self.initialSegmentsArray [index];
    return data;
}

- (BOOL)downloadConditionPredecateResultForValue:(int)value {
    [self.downloadsCondition lock];
    int i = 0;
    while (i < value) {
        [self.downloadsCondition wait];
        i++;
    }
    [self.downloadsCondition unlock];
    
    return (_downloadsConditionPredecate == value);
}

- (void)dealloc {
    if (self.mpdUpdateTimer){
        [self.mpdUpdateTimer invalidate];
    }
}
@end
