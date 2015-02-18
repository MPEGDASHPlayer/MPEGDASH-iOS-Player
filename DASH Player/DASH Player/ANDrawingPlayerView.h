//
//  ANGLKPlayerView.h
//  DASH Player
//
//  Created by DataArt Apps on 03.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "ANVideoDecoder.h"

#pragma mark - renderer protocol
@protocol ANMovieGLRenderer
- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (void) setFrame: (id) frame;
- (BOOL) prepareRender;

@end

enum {
	ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};


@interface ANDrawingPlayerView : UIView

@property (nonatomic, assign) CGSize videoSize;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

- (void) render: (ANVideoFrameYUV *) frame;
- (void) clear;

@end

@interface ANMovieGLRenderer_YUV : NSObject <ANMovieGLRenderer> {
    
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}

@end