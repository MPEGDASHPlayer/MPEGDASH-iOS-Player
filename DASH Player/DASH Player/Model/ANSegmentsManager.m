//
//  ANSegmentsManager.m
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANSegmentsManager.h"
#import "MPD.h"
#import "ANHttpClient.h"

typedef enum {
    ANSegmentTypeVideo = 0,
    ANSegmentTypeAudio = 1
} ANSegmentType;

@interface ANSegmentsManager ()
@property (nonatomic, strong) ANHttpClient *client;

@property (nonatomic, strong) NSData *initialVideoSegmentData;

@property (nonatomic, strong) NSURL *videoSegmentUrl;
@property (nonatomic, strong) NSString *prelastVideoSegmentPath;

@property (nonatomic, strong) NSData *initialAudioSegmentData;

@property (nonatomic, strong) NSURL *audioSegmentUrl;
@property (nonatomic, strong) NSString *prelastAudioSegmentPath;

@end

@implementation ANSegmentsManager

- (id)init {
    self = [super init];
    if (self){
        self.client = [ANHttpClient sharedHttpClient];
    }
    return self;
}

#pragma mark
#pragma mark - initial segments

- (void)downloadInitialVideoSegment:(NSURL *)segmentUrl
                withCompletionBlock:(ANCompletionBlockWithData)completion
{
    [self.client downloadFile:segmentUrl
                  withSuccess:^(id response){
                      self.initialVideoSegmentData = response;
                      if (completion){
                         
                          completion(YES, nil, response);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error, nil);
                          }
                      }];
}

- (void)downloadInitialVideoSegment:(NSURL *)segmentUrl
                           witRange:(NSString *)range
                andCompletionBlock:(ANCompletionBlockWithData)completion
{
    [self.client downloadFile:segmentUrl
                      atRange:range
                  withSuccess:^(id response){
                      self.initialVideoSegmentData = response;
                      if (completion){
                          
                          completion(YES, nil, response);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error, nil);
                          }
                      }];
}

- (void)downloadData:(NSURL *)segmentUrl
            atRange:(NSString *)range
  withCompletionBlock:(ANCompletionBlockWithData)completion
{
    [self.client downloadFile:segmentUrl
                      atRange:range
                  withSuccess:^(id response){
                      if (completion){
                          
                          completion(YES, nil, response);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error, nil);
                          }
                      }];
}

- (void)downloadInitialAudioSegment:(NSURL *)segmentUrl
                           witRange:(NSString *)range
                 andCompletionBlock:(ANCompletionBlockWithData)completion
{
    [self.client downloadFile:segmentUrl
                      atRange:range
                  withSuccess:^(id response){
                      self.initialAudioSegmentData = response;
                      if (completion){
                          
                          completion(YES, nil, response);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error, nil);
                          }
                      }];
}

- (void)downloadInitialAudioSegment:(NSURL *)segmentUrl
                withCompletionBlock:(ANCompletionBlock)completion
{
    [self.client downloadFile:segmentUrl
                  withSuccess:^(id response){
                      self.initialAudioSegmentData = response;
                      if (completion){
                          completion(YES, nil);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error);
                          }
                      }];
}

#pragma mark - media segments
- (void)downloadVideoSegment:(NSURL *)segmentUrl
         withCompletionBlock:(ANCompletionBlock)completion
{
    self.videoSegmentUrl = segmentUrl;
    __weak ANSegmentsManager *theWeakSelf = self;
     DLog(@"SEGMENT_MANAGER - Start downloading video segment: %@", segmentUrl);
    [self.client downloadFile:segmentUrl
                  withSuccess:^(id response){
                      __strong ANSegmentsManager * theStrongSelf = theWeakSelf;
                      theStrongSelf.lastVideoSegmentData = response;
                      
                      DLog(@"SEGMENT_MANAGER - Downloaded videoSegment: %@", segmentUrl);
                      if (completion){
                          completion(YES, nil);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error);
                          }
                      }];
}

- (void)downloadAudioSegment:(NSURL *)segmentUrl
         withCompletionBlock:(ANCompletionBlock)completion
{
    self.audioSegmentUrl = segmentUrl;
    __weak ANSegmentsManager *theWeakSelf = self;
    DLog(@"SEGMENT_MANAGER - Start downloading audio segment: %@", segmentUrl);
    [self.client downloadFile:segmentUrl
                  withSuccess:^(id response){
                       DLog(@"SEGMENT_MANAGER - Downloaded audio segment: %@", segmentUrl);
                      __strong ANSegmentsManager * theStrongSelf = theWeakSelf;
                      NSMutableData *newData = [NSMutableData dataWithData:theStrongSelf.initialAudioSegmentData];
                      [newData appendData:response];
                      theStrongSelf.lastAudioSegmentData = newData;
                      
                      if (completion){
                          completion(YES, nil);
                      }
                  }
                      failure:^(NSError *error){
                          if (completion){
                              completion(NO, error);
                          }
                      }];
}

@end
