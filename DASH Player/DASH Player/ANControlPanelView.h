//
//  ANControlPanelView.h
//  DASH Player
//
//  Created by DataArt Apps on 29.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ANSourceInputView.h"

@protocol ANControlPanelViewDelegate;

@interface ANControlPanelView : UIView <ANSourceInputViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *addSourceButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *historyListButton;


@property (nonatomic, strong) ANSourceInputView *sourceInputView;
@property (nonatomic, strong) NSString *urlString;

@property (nonatomic, weak) id <ANControlPanelViewDelegate> delegate;

@property (nonatomic, assign) BOOL playButtonEnabled;

@property (nonatomic, assign) BOOL timeSliderEnabled;

@property (nonatomic, assign) double timeSliderValue;

@property (nonatomic, assign) double totalMediaDuration;

@property (nonatomic, strong) NSString *playButtonTitle;

@property (nonatomic, assign) BOOL sliderIsSliding;

- (void)reset;
- (void)enableButtons:(BOOL)enable;
@end

@protocol ANControlPanelViewDelegate <NSObject>

@optional
- (void)controlPanelView:(ANControlPanelView *)theView didGetUrlString:(NSString *)urlString;
- (void)controlPanelViewPlayButtonActioin:(ANControlPanelView *)theView;
- (void)controlPanelView:(ANControlPanelView *)theView sliderDidSlideToPosition:(CGFloat)pos;
- (void)controlPanelViewStopAction:(ANControlPanelView *)theView;
- (void)controlPanelView:(ANControlPanelView *)theView sliderDidStartSliding:(UISlider *)slider;
- (void)controlPanelViewShowHistoryListButtonAction:(ANControlPanelView *)theView;
@end
