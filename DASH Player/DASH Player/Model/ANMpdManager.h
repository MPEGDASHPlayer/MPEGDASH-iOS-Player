//
//  ANSegmentLoader.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MPD;
@class ANHttpClient;

@protocol  ANMpdManagerDelegate;

@interface ANMpdManager : NSObject

@property (nonatomic, weak) id<ANMpdManagerDelegate> delegate;

@property (nonatomic, strong) NSThread *currentThread;

- (id)initWithMpdUrl:(NSURL *)mpdUrl;
- (id)initWithMpdUrl:(NSURL *)mpdUrl parserThread:(NSThread *)thread;

- (void)checkMpdWithCompletionBlock:(ANCompletionBlock)completion;
- (void)updateMpd;
- (BOOL)isVideoRanged;
@end

@protocol  ANMpdManagerDelegate <NSObject>
@optional
-(void)mpdManager:(ANMpdManager *)manager didFinishParsingMpdFile:(MPD *)mpd;

@end