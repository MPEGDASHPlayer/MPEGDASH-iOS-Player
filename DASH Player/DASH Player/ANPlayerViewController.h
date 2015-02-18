//
//  ANPlayer.h
//  DASH Player
//
//  Created by DataArt Apps on 05.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ANDashMultimediaManager.h"
#import "ANControlPanelView.h"

@class ANDrawingPlayerView;
@class ANVideoDecoder;
@class MPD;

@interface ANPlayerViewController : UIViewController  <ANDashMultimediaMangerDelegate>

@property (nonatomic, strong) ANDrawingPlayerView *playerView;

@property (strong, nonatomic) ANControlPanelView *controlPanelView;

@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (weak, nonatomic) IBOutlet UIView *controlPanelContainer;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *controlPanelBottomSpaceConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *controlPanelContainerHeigthConstraint;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

- (void)pause;
- (void)stop;

@end
