//
//  MainViewController.h
//  RawAudioDataPlayer
//
//  Created by SamYou on 12-8-18.
//  Copyright (c) 2012 SamYou. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 4 //
#define EVERY_READ_LENGTH 10000 //
#define MIN_SIZE_PER_FRAME 20000 //

@interface MainViewController : UIViewController
{
    AudioStreamBasicDescription audioDescription;///
    AudioQueueRef audioQueue;//
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];//
    NSLock *synlock ;///
    Byte *pcmDataBuffer;//pcm
    FILE *file;//pcm
}

static void AudioPlayerAQInputCallback(void *input, AudioQueueRef inQ, AudioQueueBufferRef outQB);

-(void)onbutton1clicked;
-(void)onbutton2clicked;
-(void)initAudio;
-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB;
-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf;

@end