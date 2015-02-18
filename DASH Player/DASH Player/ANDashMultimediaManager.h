//
//  ANDashMultimediaManager.h
//  DASH Player
//
//  Created by DataArt Apps on 07.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "ANOperation.h"
typedef NS_ENUM(NSUInteger, ANStreamType) {
    ANStreamTypeStatic,
    ANStreamTypeDynamic,
    ANStreamTypeNone
};

@class ANAudioData;
@class ANVideoData;
@protocol ANDashMultimediaMangerDelegate;

@interface ANDashMultimediaManager : NSObject

@property (nonatomic, weak) id <ANDashMultimediaMangerDelegate> delegate;

@property (nonatomic, assign) ANStreamType streamType;

@property (nonatomic, assign) BOOL stopped;

- (id)initWithMpdUrl:(NSURL *)mpdUrl;

- (void)launchManager;

- (void)dynamic_downloadNextVideoSegment;
- (void)dynamic_downloadNextAudioSegment;

- (void)static_downloadNextVideoSegment;
- (void)static_downloadNextAudioSegment;

- (NSTimeInterval)totalMediaDuration;
- (void)shiftVideoToPosition:(NSTimeInterval)pos;

+ (NSThread *)dashMultimediaThread;
@end

@protocol ANDashMultimediaMangerDelegate <NSObject>
@optional

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager didDownloadFirstVideoSegment:(ANVideoData *)videData firstAudioSegment:(ANAudioData *)audioData;

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager didDownloadVideoData:(ANVideoData *)videoData;

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager didDownloadAudioData:(ANAudioData *)audioData;

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager didFailWithMessage:(NSString *)failMessage;


@end