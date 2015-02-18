
#import <Foundation/Foundation.h>

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libavutil/time.h"

@class ANVideoPicturesList;
@class ANVideoData;
@protocol ANVideoDecoderDelegate;

static NSString *const ANRuleAskNext    = @"ANRuleAskNext";
static NSString *const ANRuleEndDecode  = @"ANRuleEndDecode";

typedef enum {
    ANMovieFrameTypeAudio = 0,
    ANMovieFrameTypeVideo,
    ANMovieFrameTypeArtwork,
    ANMovieFrameTypeSubtitle,
} ANMovieFrameType;

typedef enum {
    ANVideoFrameFormatRGB,
    ANVideoFrameFormatYUV,
} ANVideoFrameFormat;


#pragma mark - ANVideoFrameYUV
@interface ANVideoFrameYUV : NSObject
@property (nonatomic) float pts;

@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;

@property (nonatomic, assign) Byte *luma;
@property (nonatomic, assign) Byte *chromaB;
@property (nonatomic, assign) Byte *chromaR;

@property (nonatomic, assign) NSUInteger lumaLength;
@property (nonatomic, assign) NSUInteger chromaBLength;
@property (nonatomic, assign) NSUInteger chromaRLength;

@end


#pragma mark - VideoFrameExtractor

@interface ANVideoDecoder : NSObject {
	AVFormatContext *formatContex;
	AVCodecContext *codecContext;

    AVFrame *pFrame;
    AVPacket packet;
	AVPicture picture;

    BOOL quit;
    
    int bytesRead;
    int bytesLeft;
}

@property (nonatomic, strong, readonly) ANVideoData *videoData;

@property (nonatomic, assign, readonly) NSInteger framesCount;

@property (nonatomic, assign, getter = isVideoFinished) BOOL videoIsFinished;

@property (nonatomic, strong) ANVideoPicturesList *videoPicturesList;

@property (nonatomic, weak) id <ANVideoDecoderDelegate> delegate;

@property (nonatomic, readonly) int sourceWidth, sourceHeight;

@property (nonatomic, readonly) double duration;

- (id)initWithVideoData:(ANVideoData *)videoData;

- (AVRational)movieFramerate;

- (void)startWork;

- (void)quit;
@end

@protocol ANVideoDecoderDelegate <NSObject>

- (void)decoderDidFinishDecoding:(ANVideoDecoder *)video;

@end