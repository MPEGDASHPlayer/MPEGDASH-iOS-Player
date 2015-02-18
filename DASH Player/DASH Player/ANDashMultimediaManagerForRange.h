//
//  ANDashMultimediaManagerForRange.h
//  DASH Player
//
//  Created by DataArt Apps on 04.11.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANDashMultimediaManager.h"

@interface ANDashMultimediaManagerForRange : ANDashMultimediaManager
@property (nonatomic, weak) id <ANDashMultimediaMangerDelegate> delegate;
@property (nonatomic, strong) NSURL *mpdUrl;
@property (nonatomic, assign) NSTimeInterval totalMediaDuration;

- (id)initWithMpdUrl:(NSURL *)mpdUrl;

- (void)launchManager;

- (void)static_downloadNextVideoSegment;
- (void)static_downloadNextAudioSegment;

@end
