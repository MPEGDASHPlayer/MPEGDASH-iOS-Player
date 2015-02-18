//
//  Video.m
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
//  Copyright 2010 www.codza.com. All rights reserved.
//

#import "ANVideoDecoder.h"
#import "ANRingBuffer.h"
#import "ANVideoPicturesList.h"
#import "ANVideoData.h"

static NSUInteger const ANReadBufferSize = 8192;


@implementation ANVideoFrameYUV

- (void)dealloc {
    if (_luma){
        free(_luma);
    }
    if (_chromaB){
        free(_chromaB);
    }
    if (_chromaR){
        free(_chromaR);
    }
}

@end

@interface ANVideoDecoder () {
    int videoStream;
    
    Byte *readBuffer;
    
    Byte *videoDataPtr;
    int videoDataSize;
    
    BOOL _allowVideoDataConditionPredicate;
    
    BOOL _skipFrame;
    NSMutableArray *_videoDataArray;
    
}

@property (nonatomic, strong) ANVideoData *videoData;
@end

@implementation ANVideoDecoder


#pragma mark - demux thread
+ (void) __attribute__((noreturn)) demuxThreadEntryPoint:(id)__unused object {
    do {
        @autoreleasepool {
            [[NSThread currentThread] setName:@"ANVideoDemuxThread"];
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}

+ (NSThread *)demuxThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(demuxThreadEntryPoint:)
                                                          object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}

#pragma mark - init

static int ANReadFunction(void* opaque, uint8_t* buf, int buf_size) {
    ANVideoDecoder *vd = (__bridge ANVideoDecoder *)(opaque);
    if (vd->bytesLeft == 0) {
        DLog(@"VIDEO DECODER %@ - End of video video data", vd);
        return -1;
    }
    if (buf_size > vd->bytesLeft) {
        memcpy(buf, vd->videoDataPtr + vd->bytesRead, vd->bytesLeft);
        int left = vd->bytesLeft;
        vd->bytesRead += vd->bytesLeft;
        vd->bytesLeft = 0;
        return left;
    } else {
        memcpy(buf, vd->videoDataPtr + vd->bytesRead, buf_size);
        vd->bytesLeft -= buf_size;
        vd->bytesRead += buf_size;
    }
    return buf_size;
}

- (void)configSupportingObjects {
    _videoDataArray         = [NSMutableArray array];
    self.videoPicturesList  = [[ANVideoPicturesList alloc] init];
}

- (id)initWithVideoData:(ANVideoData *)videoData {
	if (!(self = [super init])) {
        return nil;
    }
    self.videoData = videoData;
    
    NSMutableData *mutableData = [NSMutableData dataWithData:videoData.initialData];
    [mutableData appendData:videoData.mediaData];
    self.videoData.mediaData = mutableData;
    [self configSupportingObjects];
    [self configVideoData];
    if (![self openVideo]){
        return nil;
    }
	return self;
}

- (void)configVideoData {
    self->videoDataPtr = (Byte *)[self.videoData.mediaData bytes];
    bytesLeft = (int)[self.videoData.mediaData length];
    if (bytesLeft == 0){
        DLog(@"VIDEO DECODER - Bytes left == 0");
    }
    bytesRead = 0;
}

- (BOOL)openVideo {
    // Register all formats and codecs
    avcodec_register_all();
    av_register_all();
    
    // Open video file
    Byte *buffer = av_malloc(ANReadBufferSize);
    self->readBuffer = buffer;
    AVIOContext *avioContext = avio_alloc_context(buffer,
                                                  ANReadBufferSize,
                                                  0,
                                                  (__bridge void *)(self),
                                                  &ANReadFunction,
                                                  NULL,
                                                  NULL);
    
    formatContex = avformat_alloc_context();
    
    formatContex->pb = avioContext;
    
    if (avformat_open_input(&formatContex, "dummyFilename", NULL, NULL) != 0){
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        return NO;
    }
    
    // Retrieve stream information
    if(avformat_find_stream_info(formatContex, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        return NO;
    }
    
    AVCodec         *pCodec;
    // Find the first video stream
    if ((videoStream =  av_find_best_stream(formatContex, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        return NO;
    }
	
    // Get a pointer to the codec context for the video stream
    codecContext = formatContex->streams[videoStream]->codec;
    
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(codecContext->codec_id);
    if(pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        return NO;
    }
	
    // Open codec
    if(avcodec_open2(codecContext, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        return NO;
    }
	
    // Allocate video frame
    pFrame = av_frame_alloc();
    return YES;
}

- (ANVideoData *)nextVideoData {
    ANVideoData *object = [_videoDataArray firstObject];
    
    if (object){
        [_videoDataArray removeObjectAtIndex:0];
    } else {
        DLog(@"DECODER - object == nil;");
    }
    return object;
}

- (void)startWork {
    [self performSelector:@selector(demux_thread)
                 onThread:[[self class] demuxThread]
               withObject:nil
            waitUntilDone:NO];
}
#pragma mark - setters
- (void)addNextVideoData:(ANVideoData *)videoData {
    [_videoDataArray addObject:videoData];
}

#pragma mark - getters
-(double)duration {
	return (double)formatContex->duration / AV_TIME_BASE;
}

- (AVRational)movieFramerate {
    return  av_stream_get_r_frame_rate(formatContex->streams[videoStream]);
}

-(int)sourceWidth {
	return codecContext->width;
}

-(int)sourceHeight {
	return codecContext->height;
}

-(void)dealloc {

	avpicture_free(&picture);

    av_free_packet(&packet);
	
    av_free(pFrame);
	
    if (codecContext){
        avcodec_close(codecContext);
    }
	
    if (formatContex) {
        avformat_close_input(&formatContex);
    }
}

#pragma mark - demux_thread method



- (void)demux_thread {
    self.videoData.framerate = [self movieFramerate];
	DLog(@"VIDEO DECODER - video_demux_thread STARTED");
    AVPacket thePacket;
    int gotFrame = 0;
    _framesCount = 0;
    
    while(av_read_frame(formatContex, &thePacket) >= 0 && !self->quit) {
        if(thePacket.stream_index == videoStream) {
            // Decode video frame
            avcodec_decode_video2(codecContext, pFrame, &gotFrame, &thePacket);
            if (gotFrame){
                if (self->quit) {
                    break;
                }
                
                ANVideoFrameYUV *frame = [self handleVideoFrame:pFrame];
                ANPicturesListElement *element = [[ANPicturesListElement alloc] init];
                element.yuvFrame = frame;
                
                [self.videoPicturesList putPictureElement:element];
                
                _framesCount += 1;
            }
        }
        av_free_packet(&thePacket);
    }
    
    [self.videoPicturesList endOfList];
    self.videoIsFinished = YES;
    DLog(@"VIDEO DECODER - videoSegment № %lu, video_demux_thread FINISHED", (unsigned long)self.videoData.segmentNumber);
    [self.delegate decoderDidFinishDecoding:self];
}

static Byte * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    Byte *data = malloc(width * height * sizeof(Byte));
    Byte *dst = data;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return data;
}

- (ANVideoFrameYUV *) handleVideoFrame:(AVFrame *)frame {
    if (!frame->data[0]){
        return nil;
    }
    ANVideoFrameYUV *yuvFrame = [[ANVideoFrameYUV alloc] init];
    yuvFrame.luma = copyFrameData(frame->data[0],
                                  frame->linesize[0],
                                  codecContext->width,
                                  codecContext->height);
    
    yuvFrame.chromaB = copyFrameData(frame->data[1],
                                     frame->linesize[1],
                                     codecContext->width / 2,
                                     codecContext->height / 2);
    
    yuvFrame.chromaR = copyFrameData(frame->data[2],
                                     frame->linesize[2],
                                     codecContext->width / 2,
                                     codecContext->height / 2);
    
    yuvFrame.width = codecContext->width;
    yuvFrame.height = codecContext->height;
    
    return yuvFrame;
}

- (void)quit {
    self->quit = YES;
    [self.videoPicturesList endOfList];
}

@end
