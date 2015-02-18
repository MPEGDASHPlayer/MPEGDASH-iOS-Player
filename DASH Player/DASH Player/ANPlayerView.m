//
//  ANPlayerView.m
//  DASH Player
//
//  Created by DataArt Apps on 24.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANPlayerView.h"
#import "VideoFrameExtractor.h"
#import "Utilities.h"

@implementation ANPlayerView
@synthesize playerImageView = playerImageView;
@synthesize playButton = playButton;
@synthesize fpsLabel = fpsLabel;


- (void)awakeFromNib {
    [super awakeFromNib];
//     [self.playerImageView setTransform:CGAffineTransformMakeRotation(M_PI/2)];
    [self bringSubviewToFront:self.playButton];
//    self.imageLayer = [CALayer layer];
//    self.imageLayer.contentsGravity = kCAGravityResizeAspect;
//    self.imageLayer.bounds = [self bounds];
//    [self.playerImageView.layer addSublayer:self.imageLayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageLayer.frame = self.bounds;
}
- (void)displayCurrentFrame:(UIImage *)image {
//    self.imageLayer.contents = (__bridge id)(image.CGImage);
    
    playerImageView.image = image;
//    [playerImageView setNeedsDisplay];
//    [self layoutIfNeeded];
}

- (void)setEnablePlayButton:(BOOL)enablePlayButton {
    _enablePlayButton = enablePlayButton;
    self.playButton.enabled = enablePlayButton;
}

-(void)setFpsValueString:(NSString *)fpsValueString {
    fpsLabel.text = fpsValueString;
}

@end
