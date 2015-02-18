//
//  AudioFrameExtractor.m
//  DASH Player
//
//  Created by DataArt Apps on 22.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANAudioDecoder.h"
#import "ANRingBuffer.h"
#import "ANAudioData.h"

#define CODEC_MAX_AUDIO_FRAME_SIZE 192000
#define AUDIO_BUF_SIZE ((CODEC_MAX_AUDIO_FRAME_SIZE * 3) / 2)
#define MAX_AUDIO_BUF_SIZE (CODEC_MAX_AUDIO_FRAME_SIZE * 4)

#define OUTPUT_BUFFER_DEFAULT_SIZE 2048

static NSUInteger const ANReadBufferSize = 4096;

@interface ANAudioDecoder () {
    
    double audio_clock;
    BOOL quit;
    
    Byte *readBuffer;
    
    Byte *audioDataPtr;
    int audioDataSize;
    int desiredBufferSize;
    int outputBufferSize;
    int16_t *outputBuffer;
}

@property (nonatomic, strong) ANAudioData *audioData;
@property (nonatomic, assign, readwrite) BOOL audioIsFinished;
@end

@implementation ANAudioDecoder

#pragma mark - demux thread
+ (void) __attribute__((noreturn)) audioDemuxThreadEntryPoint:(id)__unused object {
    do {
        @autoreleasepool {
            [[NSThread currentThread] setName:@"ANAudioDemuxThread"];
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}

+ (NSThread *)audioDemuxThread {
    static NSThread *_audioDemuxThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _audioDemuxThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(audioDemuxThreadEntryPoint:)
                                                          object:nil];
        [_audioDemuxThread start];
    });
    
    return _audioDemuxThread;
}

#pragma mark - init
static int readFunction(void* opaque, uint8_t* buf, int buf_size) {
    ANAudioDecoder *afe = (__bridge ANAudioDecoder *)(opaque);
    if (afe->bytesLeft == 0) {
        return -1;
    }
    if (buf_size > afe->bytesLeft) {
        memcpy(buf, afe->audioDataPtr + afe->bytesRead, afe->bytesLeft);
        
        int left = afe->bytesLeft;
        afe->bytesRead += afe->bytesLeft;
        afe->bytesLeft = 0;
        
        return left;
    } else {
        memcpy(buf, afe->audioDataPtr + afe->bytesRead, buf_size);
        afe->bytesLeft -= buf_size;
        afe->bytesRead += buf_size;
    }
    return buf_size;
}

- (id)initWithAudioData:(ANAudioData *)audioData {
    if (!(self = [super init])) {
        return nil;
    }
    
    self.ringBuffer = [[ANRingBuffer alloc] initWitSize:AUDIO_BUF_SIZE
                                                maxSize:MAX_AUDIO_BUF_SIZE];
    
    avcodec_register_all();
    av_register_all();
    
    self.audioData = audioData;
    if (audioData.initialData){
        NSMutableData *mutableData = [NSMutableData dataWithData:audioData.initialData];
        [mutableData appendData:audioData.mediaData];
        self.audioData.mediaData = mutableData;
    }
    
    self->audioDataPtr = (Byte *)[audioData.mediaData bytes];
    bytesLeft = (int)[audioData.mediaData length];
    bytesRead = 0;
    
    Byte *buffer = av_malloc(ANReadBufferSize);
    AVIOContext *avioContext = avio_alloc_context(buffer,
                                                  ANReadBufferSize,
                                                  0,
                                                  (__bridge void *)(self),
                                                  &readFunction,
                                                  NULL,
                                                  NULL);
    
    formatContext = avformat_alloc_context();
    
    formatContext->pb = avioContext;
    
    // Open audio file
    if (avformat_open_input(&formatContext, "dummyFilename", NULL, NULL) != 0){
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        return nil;
    }
    
    // Retrieve stream information
    if(avformat_find_stream_info(formatContext, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "ffmpeg: Couldn't find stream information\n");
        return nil;
    }
    
    self->audioStream = [self openAudioStream];
	
    if (!audioStream){
        av_log(NULL, AV_LOG_ERROR, "ffmpeg: Could not open audio stream\n");
        return nil;
    }
    frame = av_frame_alloc();
    
    
    outputBufferSize = OUTPUT_BUFFER_DEFAULT_SIZE;
    outputBuffer = malloc(outputBufferSize * sizeof(int16_t));
    desiredBufferSize = 0;
    
    if (self.audioData.diffFromVideo > 0){
        [self seekTime:self.audioData.diffFromVideo];
    }
    
    return self;
}

-(AVStream *) openAudioStream {
	int index;
	AVStream* stream = NULL;
	// Find stream index
	for (index = 0; index < formatContext->nb_streams; ++index) {
		if (formatContext->streams[index]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
			stream = formatContext->streams[index];
            self->audioStreamIndex = index;
			break;
		}
	}
	if (stream == NULL) {
		// Stream index not found
		return NULL;
	}
	
    self->codecContext = stream->codec;
	
	// Find suitable codec
	AVCodec* codec = avcodec_find_decoder(codecContext->codec_id);
	if (codec == NULL) {
		// Codec not found
		return NULL;
	}
	if (avcodec_open2(codecContext, codec, NULL) < 0) {
		// Failed to open codec
		return NULL;
	}
	
	return stream;
}

-(double)duration {
	return (double)formatContext->duration / AV_TIME_BASE;
}

- (void)dealloc {
    av_free_packet(&packet);

    av_free(frame);
	
    if (codecContext){
        avcodec_close(codecContext);
    }
	
    if (formatContext){
        avformat_close_input(&formatContext);
    }
    
    if (outputBuffer){
        free(outputBuffer);
    }
}

-(void)seekTime:(double)seconds {
    AVRational timeBase = audioStream->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(formatContext, audioStreamIndex, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(codecContext);
}

#pragma mark - demux_thread method
- (void)audioDemuxThread {
	DLog(@"audio_demux_thread STARTED");
	AVPacket thePacket;
    int gotFrame;
    
	while ((av_read_frame(formatContext, &thePacket) >= 0) && !self->quit) {
		if (thePacket.stream_index == audioStreamIndex) {
            av_frame_unref(frame);
            
            int len = avcodec_decode_audio4(codecContext, frame, &gotFrame, &thePacket);
            if (len < 0) {
                av_free_packet(&thePacket);
                fprintf(stderr, "Failed to decode audio frame\n");
                break;
            }
            
            if (gotFrame) {
                // Convert from AV_SAMPLE_FMT_FLTP to AV_SAMPLE_FMT_S16
                // Get decoded buffer size
                int data_size = av_samples_get_buffer_size(NULL,
                                                           codecContext->channels,
                                                           frame->nb_samples,
                                                           AV_SAMPLE_FMT_S16,
                                                           1);
                
                
                int in_samples = frame->nb_samples;
                int i = 0;
                float *inputChannel0 = (float *)frame->extended_data[0];
                desiredBufferSize = in_samples << 1; // * 2
                
                //reallocate output buffer
                if (outputBufferSize < desiredBufferSize){
                    if (outputBuffer){
                        free(outputBuffer);
                    }
                    
                    outputBuffer = malloc(desiredBufferSize * sizeof(int16_t));
                    outputBufferSize = desiredBufferSize;
                }
                
                // Mono
                if (frame->channels == 1) {
                    for (i = 0 ; i < in_samples; i++) {
                        float sample = *inputChannel0++;
                        if (sample < -1.0f) {
                            sample = -1.0f;
                        } else if (sample > 1.0f) {
                            sample = 1.0f;
                        }
                        
                        outputBuffer[i] = (int16_t) (sample * 32767.0f);
                    }
                } else {
                    // Stereo
                    float *inputChannel1 = (float *)frame->extended_data[1];
                    for (i = 0 ; i < in_samples ; i++) {
                        outputBuffer[i * 2] = (int16_t) ((*inputChannel0++) * 32767.0f);
                        outputBuffer[i * 2 + 1] = (int16_t) ((*inputChannel1++) * 32767.0f);
                    }
                }
                
                [self.ringBuffer write:outputBuffer
                            withLength:data_size
                                 block:1];
                
                
            }
            av_free_packet(&thePacket);
            
		} else {
      		av_free_packet(&thePacket);
    	}
	}
    self.audioIsFinished = YES;
    [self.ringBuffer eof];
    DLog(@"AUDIO DECODER - audio_demux_thread FINISHED");
    [self.delegate audioDidEnd:self];
}

#pragma mark - public
- (void)startWork {
    [self performSelector:@selector(audioDemuxThread)
                 onThread:[[self class] audioDemuxThread]
               withObject:nil
            waitUntilDone:NO];
}

- (int)sampleRate {
    return codecContext->sample_rate;
}

- (int)channels {
    return codecContext->channels;
}
- (void)quit {
    quit = YES;
    [self.ringBuffer eof];
}
- (BOOL)isQuit {
    return quit;
}
@end
