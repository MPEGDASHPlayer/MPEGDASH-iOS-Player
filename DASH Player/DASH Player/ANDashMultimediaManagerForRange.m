//
//  ANDashMultimediaManagerForRange.m
//  DASH Player
//
//  Created by DataArt Apps on 04.11.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANDashMultimediaManagerForRange.h"
#import "ANHttpClient.h"
#import "MPD.h"
#import "ANMpdManager.h"
#import "ANSegmentsManager.h"
#import "Sidx.h"
#import "ANVideoData.h"
#import "ANAudioData.h"

@interface ANDashMultimediaManagerForRange () <ANMpdManagerDelegate> {
    NSTimeInterval      _totalMediaDuration;
}

@property (nonatomic, strong) ANHttpClient *client;

@property (nonatomic, strong) MPD               *mpd;
@property (nonatomic, strong) NSURL             *baseUrl;
@property (nonatomic, strong) ANMpdManager      *mpdManager;
@property (nonatomic, strong) ANSegmentsManager *segmentManager;

@property (nonatomic, strong) NSArray           *videoRepArray;
@property (nonatomic, strong) NSArray           *audioRepArray;
@property (nonatomic, strong) NSMutableArray    *initialSegmentsURLArray;
@property (nonatomic, strong) AdaptationSet     *videoAdaptionSet;
@property (nonatomic, strong) AdaptationSet     *audioAdaptionSet;
@property (nonatomic, strong) NSCondition       *downloadsCondition;

@property (nonatomic, strong) NSMutableArray    *initialVideoSegmentsArray;
@property (nonatomic, strong) NSMutableArray    *initialAudioSegmentsArray;

@property (nonatomic, assign) NSInteger         downloadsConditionPredecate;

@property (nonatomic, assign) BOOL firstStart;
@property (nonatomic, strong) NSMutableDictionary   *sidxVideoDictionary;
@property (nonatomic, strong) NSMutableDictionary   *sidxAudioDictionary;

@property (nonatomic, strong) NSMutableDictionary   *initialVideoSegmentsDictionary;
@property (nonatomic, strong) NSMutableDictionary   *initialAudioSegmentsDictionary;

@property (nonatomic, assign) NSUInteger            currentVideoSidxIndex;
@property (nonatomic, assign) NSUInteger            currentAudioSidxIndex;

@property (nonatomic, strong) ANVideoData           *firstVideoData;
@property (nonatomic, strong) ANAudioData           *firstAudioData;

@property (nonatomic, assign) NSInteger             currentVideoRepIndex;
@property (nonatomic, assign) NSInteger             sidxVideoRefCount;
@property (nonatomic, assign) NSInteger             sidxAudioRefCount;

@property (nonatomic, assign) double                audioVideoDiffForTimeShift;
@end

@implementation ANDashMultimediaManagerForRange

- (id)init {
    self = [super init];
    if (self){
        self.client = [ANHttpClient sharedHttpClient];
        
        self.segmentManager                 = [[ANSegmentsManager alloc] init];
        self.firstStart                     = YES;
        
        self.downloadsCondition             = [[NSCondition alloc] init];
        
        self.initialVideoSegmentsArray      = [NSMutableArray array];
        self.initialAudioSegmentsArray      = [NSMutableArray array];
        
        self.initialSegmentsURLArray        = [NSMutableArray array];
        self.sidxVideoDictionary            = [NSMutableDictionary dictionary];
        self.sidxAudioDictionary            = [NSMutableDictionary dictionary];
        self.initialVideoSegmentsDictionary = [NSMutableDictionary dictionary];
        self.initialAudioSegmentsDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithMpdUrl:(NSURL *)mpdUrl {
    self = [self init];
    if (self){
        NSAssert(mpdUrl, @"MPD URL cannot be nil");
        self.mpdUrl = mpdUrl;
    }
    
    return self;
}

- (void)setMpdUrl:(NSURL *)mpdUrl {
    _mpdUrl = mpdUrl;
    self.baseUrl = [mpdUrl URLByDeletingLastPathComponent];
    self.mpdManager = [[ANMpdManager alloc] initWithMpdUrl:mpdUrl];
    self.mpdManager.delegate = self;
}

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

#pragma mark - ANMpdManagerDelegate
- (void)mpdManager:(ANMpdManager *)manager didFinishParsingMpdFile:(MPD *)mpd {
    self.mpd = mpd;
    
    self.videoAdaptionSet = [_mpd videoAdaptionSet];
    self.audioAdaptionSet = [_mpd audioAdaptionSet];
    
    self.videoRepArray = self.videoAdaptionSet.representationArray;
    self.audioRepArray = self.audioAdaptionSet.representationArray;
    self.currentVideoSidxIndex = 0;
    self.currentAudioSidxIndex = 0;
    
    if (_firstStart){
        [self processStart];
    }
}

- (void)processStart {
    DLog(@"DASH - static_processMPD");
    _totalMediaDuration = [_mpd mediaPresentationDuration];
    BOOL result = NO;
    
    // download initial segments for video
    for (Representation *rep in self.videoRepArray){
        result = [self downloadInitialSegmentForRep:rep saveToDictionary:self.initialVideoSegmentsDictionary];
        if (!result){
            NSLog(@"DASH - Cannot download all initial video segments");
            if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download some of initial video segments"];
            }
            return;
        }
        
        result = [self downloadSidxForRep:rep saveToDictinary:self.sidxVideoDictionary];
        
        if (!result){
            NSLog(@"DASH - Cannot download all segment index boxes");
            if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download all segment index boxes"];
            }
            return;
        }
    }
    Representation *rep = self.videoRepArray[0];
    Sidx *currentSidx = self.sidxVideoDictionary[rep.baseUrlString];
    self.sidxVideoRefCount = currentSidx.referenceCount;

    
    for (Representation *rep in self.audioRepArray){
        result = [self downloadInitialSegmentForRep:rep saveToDictionary:self.initialAudioSegmentsDictionary];
        if (!result){
            NSLog(@"DASH - Cannot download all initial audio segments");
            if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download some of initial audio segments"];
            }
            return;
        }
        
        result = [self downloadSidxForRep:rep saveToDictinary:self.sidxAudioDictionary];
        if (!result){
            NSLog(@"DASH - Cannot download all video segment index boxes");
            if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
                [self.delegate dashMultimediaManger:self
                                 didFailWithMessage:@"DASH - Cannot download all video segment index boxes"];
            }
            return;
        }
    }
    
    rep = self.audioRepArray[0];
    currentSidx = self.sidxAudioDictionary[rep.baseUrlString];
    self.sidxAudioRefCount = currentSidx.referenceCount;
    
    
    [self downloadSegmentsForStart];
    self.firstStart = NO;
}

- (BOOL)downloadInitialSegmentForRep:(Representation *)rep saveToDictionary:(NSMutableDictionary *)dictionary {
    NSURL *baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    _downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManagerForRange *theWeakSelf = self;
    
    [self.segmentManager downloadData:baseUrl
                             atRange:rep.segmentBase.initialization.range
                  withCompletionBlock:^(BOOL success, NSError *error, id response){
        [theWeakSelf.downloadsCondition lock];
        if (success){
            if (dictionary){
                [dictionary setObject:response forKey:rep.baseUrlString];
            }
            theWeakSelf.downloadsConditionPredecate += 1;
        } else {
            DLog(@"DASH - Failure");
        }
        [theWeakSelf.downloadsCondition signal];
        [theWeakSelf.downloadsCondition unlock];
    }];
    return [self downloadConditionPredecateResultForValue:1];
    
}

- (BOOL)downloadSidxForRep:(Representation *)rep saveToDictinary:(NSMutableDictionary *)dictionary {
    NSURL *baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    _downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManagerForRange *theWeakSelf = self;
    uint32_t firstOffset = (uint32_t)NSRangeFromString(rep.segmentBase.indexRange).location;
    [self.segmentManager downloadInitialVideoSegment:baseUrl
                                            witRange:rep.segmentBase.indexRange
                                  andCompletionBlock:^(BOOL success, NSError *error, id response){
                                      [theWeakSelf.downloadsCondition lock];
                                      if (success){
                                          Sidx *sidx = [[Sidx alloc] init];
                                          [sidx parseSidx:response withFirstByteOffset:firstOffset];
                                          if (sidx.error){
                                              NSLog(@"%@", sidx.error);
                                              [theWeakSelf.downloadsCondition signal];
                                              [theWeakSelf.downloadsCondition unlock];
                                              return;
                                          } else if (dictionary){
                                              [dictionary setObject:sidx forKey:rep.baseUrlString];
                                          }
                                          theWeakSelf.downloadsConditionPredecate += 1;
                                      } else {
                                          DLog(@"DASH - Failure");
                                      }
                                      [theWeakSelf.downloadsCondition signal];
                                      [theWeakSelf.downloadsCondition unlock];
                                  }];
    
    return [self downloadConditionPredecateResultForValue:1];
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

#pragma mark - start downloading media segments
- (void)downloadSegmentsForStart {
    // download first video/audio segment to start playback
    if (![self downloadFirstMediaSegments]){
        NSLog(@"DASH - Cannot download media segments");
        if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
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
    
    [self downloadNextAudioSegmentWithThreadBlocking:NO];
    [self downloadNextVideoSegmentWithThreadBlocking:NO];
    
   
}

- (BOOL)downloadFirstMediaSegments {
    __weak ANDashMultimediaManagerForRange *theWeakSelf = self;
    _downloadsConditionPredecate = 0;
    Representation *rep = [self currentVideoRep];
    Sidx *currentSidx = self.sidxVideoDictionary[rep.baseUrlString];
    self.sidxVideoRefCount = currentSidx.referenceCount;

    NSDictionary *currentSegmentReference = currentSidx.references[_currentVideoSidxIndex];
    
    NSURL *baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    NSUInteger offset_v     = [currentSegmentReference[ANSidxConstantOffset] unsignedIntegerValue];
    NSUInteger size_v       = [currentSegmentReference[ANSidxConstantSize] unsignedIntegerValue];
    NSUInteger timescale_v  = [currentSegmentReference[ANSidxConstantTimescale] unsignedIntegerValue];
    NSUInteger duration_v   = [currentSegmentReference[ANSidxConstantDuration] unsignedIntegerValue];
    NSUInteger time_v       = [currentSegmentReference[ANSidxConstantTime] unsignedIntegerValue];
    
    NSString *range_v = [NSString stringWithFormat:@"%lu-%lu", offset_v, offset_v + size_v - 1];
    
    [self.segmentManager downloadData:baseUrl
                              atRange:range_v
                  withCompletionBlock:^(BOOL success, NSError *error, id response){
                              __strong ANDashMultimediaManagerForRange *theStrongSelf = theWeakSelf;
                      
                              [theWeakSelf.downloadsCondition lock];
                      
                              if (success && theStrongSelf){
                                  ANVideoData *videoData = [[ANVideoData alloc] init];
                                  videoData.mediaData = response;
                                  videoData.mediaDuration = duration_v;
                                  videoData.timescale = timescale_v;
                                  
                                  videoData.initialData = [theStrongSelf initialVideoDataForRepIndex:theStrongSelf.currentVideoRepIndex];
                                  
                                  videoData.timeSinceMediaBeginning = time_v / ((double)timescale_v);
                                  
                                  videoData.segmentNumber = theStrongSelf.currentVideoSidxIndex;
                                  
                                  theStrongSelf->_firstVideoData = videoData;
                                  
                                  theWeakSelf.downloadsConditionPredecate += 1;
                              } else {
                                  DLog(@"DASH - download failure");
                              }
                              
                              [theWeakSelf.downloadsCondition signal];
                              [theWeakSelf.downloadsCondition unlock];
                          }];
    
     // download audio segment
    rep = [self currentAudioRep];
    currentSidx = self.sidxAudioDictionary[rep.baseUrlString];

    
    currentSegmentReference = currentSidx.references[_currentAudioSidxIndex];
    
    baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    NSUInteger offset_a     = [currentSegmentReference[ANSidxConstantOffset] unsignedIntegerValue];
    NSUInteger size_a       = [currentSegmentReference[ANSidxConstantSize] unsignedIntegerValue];
    NSUInteger timescale_a  = [currentSegmentReference[ANSidxConstantTimescale] unsignedIntegerValue];
    NSUInteger duration_a   = [currentSegmentReference[ANSidxConstantDuration] unsignedIntegerValue];
    
    NSString *range_a = [NSString stringWithFormat:@"%lu-%lu", offset_a, offset_a + size_a];
    
   
    [self.segmentManager downloadData:baseUrl
                              atRange:range_a
                  withCompletionBlock:^(BOOL success, NSError *error, id response){
                      __strong ANDashMultimediaManagerForRange *theStrongSelf = theWeakSelf;
                      
                      [theWeakSelf.downloadsCondition lock];
                      
                      if (success && theStrongSelf){
                          ANAudioData *audioData = [[ANAudioData alloc] init];
                          audioData.mediaData = response;
                          audioData.mediaDuration = duration_a;
                          audioData.timescale = timescale_a;
                          
                          audioData.initialData = [theStrongSelf initialAudioDataForRepIndex:0];
                          
                          audioData.segmentNumber = theStrongSelf.currentAudioSidxIndex;
                          audioData.diffFromVideo = self.audioVideoDiffForTimeShift;
                          
                          theStrongSelf->_firstAudioData = audioData;
                          
                          theWeakSelf.downloadsConditionPredecate += 1;
                      } else {
                          DLog(@"DASH - download failure");
                      }
                      self.audioVideoDiffForTimeShift = 0;
                      [theWeakSelf.downloadsCondition signal];
                      [theWeakSelf.downloadsCondition unlock];
                  }];
    
    return [self downloadConditionPredecateResultForValue:2];
}

- (Representation *)currentVideoRep {
    // TODO: return proper video rep
    return self.videoRepArray[2];
    
    if (_firstStart){
        return self.videoRepArray[0];
    } else {
        return [self selectVideoRepresentation];
    }
    return nil;
}

- (Representation *)currentAudioRep {
    return self.audioRepArray[0];
}

- (Representation *)selectVideoRepresentation {
    
    if (_videoRepArray.count == 0) {
        return nil;
    }
    
    Representation *audioRep = self.audioRepArray[0];// defauld audio rep
    Representation *firstVideoRep = self.videoRepArray[0];
    Sidx *sidx = [self.sidxVideoDictionary objectForKey:firstVideoRep.baseUrlString];
    NSDictionary *sidxInfo = sidx.references[_currentVideoSidxIndex];
    
    Representation *retRep = nil;
    double downloadingSpeed = 0.0;
    if ([self.client lastBytesDownloaded] > 1024){
        downloadingSpeed = [self.client lastNetworkSpeed];
    } else {
        downloadingSpeed = [self.client averageNetworkSpeed];
    }
    
    NSUInteger duration = [sidxInfo[ANSidxConstantDuration] integerValue];
    double timescale = (double)[sidxInfo[ANSidxConstantTimescale] integerValue]; //
    double scaledDuration = duration / timescale; //_videoSegmentDuration / _videoTimeScale;
    for (Representation *rep in self.videoRepArray){
        double downloadingTime = (([rep bandwidth] + [audioRep bandwidth]) * scaledDuration) / (downloadingSpeed * 8.0);
        
        if(downloadingTime > scaledDuration - 1.0){
            if (retRep == nil){
                retRep = rep;
            }
            break;
        }
        
        retRep = rep;
    }
    
    _currentVideoRepIndex = [self.videoRepArray indexOfObject:retRep];
    // prevent from switching to full hd
    if (retRep.width > 1280 && _currentVideoRepIndex > 0){
        _currentVideoRepIndex--;
        retRep = self.videoRepArray[_currentVideoRepIndex] ;
    }
    return retRep;
}

- (NSData *)initialVideoDataForRepIndex:(NSInteger)index {
    assert(index <= self.videoRepArray.count - 1);
    Representation *rep = self.videoRepArray[index];
    NSData *data = self.initialVideoSegmentsDictionary[rep.baseUrlString];
    return data;
}

- (NSData *)initialAudioDataForRepIndex:(NSInteger)index {
    assert(index <= self.audioRepArray.count - 1);
    Representation *rep = self.audioRepArray[index];
    NSData *data = self.initialAudioSegmentsDictionary[rep.baseUrlString];
    return data;
}

- (BOOL)downloadNextVideoSegmentWithThreadBlocking:(BOOL)block {
    _downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManagerForRange *theWeakSelf = self;
    if (self.currentVideoSidxIndex >= self.sidxVideoRefCount - 1){
        return NO;
    }
    self.currentVideoSidxIndex += 1;
    
    Representation *rep = [self currentVideoRep];
    Sidx *currentSidx = self.sidxVideoDictionary[rep.baseUrlString];
    
    NSDictionary *currentSegmentReference = currentSidx.references[_currentVideoSidxIndex];
    
    NSURL *baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    NSUInteger offset_v     = [currentSegmentReference[ANSidxConstantOffset] unsignedIntegerValue];
    NSUInteger size_v       = [currentSegmentReference[ANSidxConstantSize] unsignedIntegerValue];
    NSUInteger timescale_v  = [currentSegmentReference[ANSidxConstantTimescale] unsignedIntegerValue];
    NSUInteger duration_v   = [currentSegmentReference[ANSidxConstantDuration] unsignedIntegerValue];
    
    NSString *range_v = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)offset_v, (unsigned long)(offset_v + size_v)];
    
    [self.segmentManager downloadData:baseUrl
                              atRange:range_v
                  withCompletionBlock:^(BOOL success, NSError *error, id response)
    {
                              __strong ANDashMultimediaManagerForRange *theStrongSelf = theWeakSelf;
        
                              if (success && theStrongSelf && !theStrongSelf.stopped){
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadVideoData:)])
                                  {
                                      ANVideoData *videoData = [[ANVideoData alloc] init];
                                      videoData.mediaData = response;
                                      videoData.mediaDuration = duration_v;
                                      videoData.timescale = timescale_v;
                                      videoData.initialData = [theStrongSelf initialVideoDataForRepIndex:theStrongSelf.currentVideoRepIndex];
                                      videoData.segmentNumber = theStrongSelf.currentVideoSidxIndex;
                                      videoData.isLastSegmentNumber = (theStrongSelf.currentVideoSidxIndex == (theStrongSelf.sidxVideoRefCount - 1));
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadVideoData:videoData];
                                      theWeakSelf.downloadsConditionPredecate += 1;
                                  }
                              } else if (!success) {
                                  NSLog(@"DASH - Video segment download error: %@", error);
                                  if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:didFailWithMessage:)]){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:@"DASH - Video segment download error"];
                                  }
                              }
                        if (block){
                            [theWeakSelf.downloadsCondition signal];
                        }
                          }];
    if (block){
        return [self downloadConditionPredecateResultForValue:1];
    } else {
        return YES;
    }
}

- (BOOL)downloadNextAudioSegmentWithThreadBlocking:(BOOL)block {
    self.downloadsConditionPredecate = 0;
    __weak ANDashMultimediaManagerForRange *theWeakSelf = self;
    if (self.currentAudioSidxIndex >= self.sidxAudioRefCount - 1){
        return NO;
    }
    self.currentAudioSidxIndex += 1;
    Representation *rep = [self currentAudioRep];
    Sidx *currentSidx = self.sidxAudioDictionary[rep.baseUrlString];
    
    NSDictionary *currentSegmentReference = currentSidx.references[_currentAudioSidxIndex];
    
    NSURL *baseUrl = [self.baseUrl URLByAppendingPathComponent:rep.baseUrlString];
    
    NSUInteger offset_a     = [currentSegmentReference[ANSidxConstantOffset] unsignedIntegerValue];
    NSUInteger size_a       = [currentSegmentReference[ANSidxConstantSize] unsignedIntegerValue];
    NSUInteger timescale_a  = [currentSegmentReference[ANSidxConstantTimescale] unsignedIntegerValue];
    NSUInteger duration_a   = [currentSegmentReference[ANSidxConstantDuration] unsignedIntegerValue];
    
    NSString *range_a = [NSString stringWithFormat:@"%lu-%lu", offset_a, offset_a + size_a];
    DLog(@"DASH - Sent request for next audio segment with number %lu", self.currentAudioSidxIndex);
    [self.segmentManager downloadData:baseUrl
                              atRange:range_a
                  withCompletionBlock:^(BOOL success, NSError *error, id response)
     {
                              __strong ANDashMultimediaManagerForRange *theStrongSelf = theWeakSelf;
                                DLog(@"DASH - Downloaded next audio segment with number %lu", theWeakSelf.currentAudioSidxIndex);
                              if (success && theStrongSelf && !theStrongSelf.stopped){
                                  
                                  if ([theStrongSelf.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                           didDownloadAudioData:)])
                                  {
                                      ANAudioData *audioData = [[ANAudioData alloc] init];
                                      audioData.mediaData = response;
                                      audioData.mediaDuration = duration_a;
                                      audioData.timescale = timescale_a;
                                      audioData.initialData = [theStrongSelf initialAudioDataForRepIndex:0];
                                      audioData.isLastSegmentNumber = (theStrongSelf.currentAudioSidxIndex == (theStrongSelf.sidxAudioRefCount - 1));
                                      
                                      [theStrongSelf.delegate dashMultimediaManger:theStrongSelf
                                                              didDownloadAudioData:audioData];
                                      theWeakSelf.downloadsConditionPredecate += 1;
                                  }
                              } else if (!success) {
                                  if ([self.delegate respondsToSelector:@selector(dashMultimediaManger:
                                                                                  didFailWithMessage:)]){
                                      [self.delegate dashMultimediaManger:self
                                                       didFailWithMessage:@"DASH - Audio segment download error"];
                                  }
                              }
                        if (block){
                             [theWeakSelf.downloadsCondition signal];
                        }
                          }];
    if (block){
        return [self downloadConditionPredecateResultForValue:1];
    } else {
        return YES;
    }
}

#pragma mark - public
- (void)static_downloadNextVideoSegment {
    [self downloadNextVideoSegmentWithThreadBlocking:NO];
}

- (void)static_downloadNextAudioSegment {
    [self downloadNextAudioSegmentWithThreadBlocking:NO];
}

- (void)shiftVideoToPosition:(NSTimeInterval)pos {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        double actualVideoPos = 0;
        [self calculateVideoSidxForPos:pos andActualVideoPos:&actualVideoPos];
        [self calculateAudioSidxForPos:actualVideoPos];
        
        [self downloadSegmentsForStart];
    });
}

- (void)shiftVideoToPositionOnDashThread:(NSNumber *)pos {
    
}

- (void)calculateVideoSidxForPos:(NSTimeInterval)pos andActualVideoPos:(double *)actualPos {
    DLog(@"DASH - calculateVideoSidxForPos %f", pos);
    Representation *rep = [self currentVideoRep];
    Sidx *sidx = self.sidxVideoDictionary[rep.baseUrlString];
    NSArray *references = sidx.references;
    double timescale = (double)sidx.timescale;
    

    int index = 0;
    for (NSDictionary *dic in references){
        double time = [dic[ANSidxConstantTime] unsignedIntegerValue] / timescale;
        if (time >= pos){
            break;
        }
        index ++;
    }
    self.currentVideoSidxIndex = index - 1;
    
    NSDictionary *targetDic = references[self.currentVideoSidxIndex];
    *actualPos = [targetDic[ANSidxConstantTime] unsignedIntegerValue] / timescale;
}

- (void)calculateAudioSidxForPos:(NSTimeInterval)pos {
    DLog(@"DASH - calculateAudioSidxForPos %f", pos);
    Representation *rep = self.audioRepArray[0];
    Sidx *sidx = self.sidxAudioDictionary[rep.baseUrlString];
    NSArray *references = sidx.references;
    NSUInteger timescale = sidx.timescale;
    int index = 0;
    
    for (NSDictionary *dic in references){
        double time = [dic[ANSidxConstantTime] unsignedIntegerValue] / (double)timescale;
        if (time >= pos){
            self.audioVideoDiffForTimeShift = time - pos;
            break;
        }
        index ++;
    }
    self.currentAudioSidxIndex = index - 1;
}

@end
