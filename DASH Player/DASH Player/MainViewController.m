//
//  MainViewController.m
//  RawAudioDataPlayer
//
//  Created by SamYou on 12-8-18.
//  Copyright (c) 2012 SamYou. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

#pragma mark -
#pragma mark life cycle

- (id)init
{
    self = [super init];
    if (self) {
        
        synlock = [[NSLock alloc] init];
    }
    return self;
}

- (void)loadAudioFile {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"raw"];
    NSLog(@"filepath = %@",filepath);
    NSFileManager *manager = [NSFileManager defaultManager];
    NSLog(@"file exist = %d",[manager fileExistsAtPath:filepath]);
    NSLog(@"file size = %lld",[[manager attributesOfItemAtPath:filepath error:nil] fileSize]) ;
    file  = fopen([filepath UTF8String], "r");
    if(file)
    {
        fseek(file, 0, SEEK_SET);
        pcmDataBuffer = malloc(EVERY_READ_LENGTH);
    }
    else{
        NSLog(@"!!!!!!!!!!!!!!!!");
    }
}

-(void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor grayColor];
    
    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button1.frame = CGRectMake(10, 10, 300, 50);
    [button1 setTitle:@"button1" forState:UIControlStateNormal];
    [button1 setTitle:@"button1" forState:UIControlStateHighlighted];
    [button1 addTarget:self action:@selector(onbutton1clicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
    
    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button2.frame = CGRectMake(10, 70, 300, 50);
    [button2 setTitle:@"button2" forState:UIControlStateNormal];
    [button2 setTitle:@"button2" forState:UIControlStateHighlighted];
    [button2 addTarget:self action:@selector(onbutton2clicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    [self loadAudioFile];
    
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)onbutton1clicked
{
    [self initAudio];
    NSLog(@"onbutton1clicked");
    
    for(int i=0; i < QUEUE_BUFFER_SIZE;i++)
    {
        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[i]];
    }
    AudioQueueStart(audioQueue, NULL);
}

-(void)onbutton2clicked
{
    NSLog(@"onbutton2clicked");
}

#pragma mark -
#pragma mark player call back
/*
 ?c[self ***]?void *input
 buffer?AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);queue?
 ?AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    NSLog(@"AudioPlayerAQInputCallback");
    MainViewController *mainviewcontroller = (__bridge MainViewController *)input;
    [mainviewcontroller checkUsedQueueBuffer:outQB];
    [mainviewcontroller readPCMAndPlay:outQ buffer:outQB];
}



-(void)initAudio
{
    ///
    audioDescription.mSampleRate = 22050;//
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///
    audioDescription.mFramesPerPacket = 1;//packet
    audioDescription.mBitsPerChannel = 16;//16bit
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
    ///audioqueue
    //  AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void *)(self), nil, nil, 0, &audioQueue);//player
    ////buffer
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        OSStatus result =  AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d", i, (int)result);
    }
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    [synlock lock];
    int readLength = fread(pcmDataBuffer, 1, EVERY_READ_LENGTH, file);//
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<readLength;i++)
    {
        audiodata[i] = pcmDataBuffer[i];
    }
    /*
     bufferaudioqueue
     AudioQueueBufferRef?AudioQueueBufferRef?AudioQueueBufferRef->mAudioDataByteSize?AudioQueueBufferRef->mAudioData
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    [synlock unlock];
}

-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
}






@end