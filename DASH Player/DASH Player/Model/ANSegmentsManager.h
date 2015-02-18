//
//  ANSegmentsManager.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ANHttpClient;

@interface ANSegmentsManager :NSObject
@property (nonatomic, strong) NSString *lastVideoSegmentPath;
@property (nonatomic, strong) NSString *lastAudioSegmentPath;

@property (nonatomic, strong) NSData *lastVideoSegmentData;
@property (nonatomic, strong) NSData *lastAudioSegmentData;

- (void)downloadInitialVideoSegment:(NSURL *)segmentUrl withCompletionBlock:(ANCompletionBlockWithData)completion;
- (void)downloadVideoSegment:(NSURL *)segmentUrl withCompletionBlock:(ANCompletionBlock)completion;

- (void)downloadInitialAudioSegment:(NSURL *)segmentUrl withCompletionBlock:(ANCompletionBlock)completion;
- (void)downloadAudioSegment:(NSURL *)segmentUrl withCompletionBlock:(ANCompletionBlock)completion;

- (void)downloadInitialVideoSegment:(NSURL *)segmentUrl
                           witRange:(NSString *)range
                 andCompletionBlock:(ANCompletionBlockWithData)completion;

- (void)downloadData:(NSURL *)segmentUrl
             atRange:(NSString *)range
 withCompletionBlock:(ANCompletionBlockWithData)completion;
@end
