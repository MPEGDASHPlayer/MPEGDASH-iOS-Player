//
//  ANPlayerView.h
//  DASH Player
//
//  Created by DataArt Apps on 24.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
@class VideoFrameExtractor;
@class MPD;

@interface ANPlayerView : UIView {
    UIImageView *playerImageView;
    UIButton *playButton;
    UILabel *fpsLabel;
}

@property (nonatomic) IBOutlet UIImageView *playerImageView;
@property (nonatomic) IBOutlet UIButton *playButton;
@property (nonatomic) IBOutlet UILabel *fpsLabel;
@property (nonatomic) IBOutlet UILabel *downloadSpeedLabel;

@property (nonatomic) UIImage *image;
@property (nonatomic, assign) BOOL enablePlayButton;

@property (nonatomic, strong) NSString *fpsValueString;
@property (nonatomic, strong) CALayer *imageLayer;

- (void)displayCurrentFrame:(UIImage *)image;

@end
