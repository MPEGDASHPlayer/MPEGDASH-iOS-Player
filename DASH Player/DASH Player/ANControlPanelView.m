//
//  ANControlPanelView.m
//  DASH Player
//
//  Created by DataArt Apps on 29.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANControlPanelView.h"


@implementation ANControlPanelView
@synthesize playButtonEnabled = _playButtonEnabled;

- (void)awakeFromNib {
    [super awakeFromNib];
    self.timeSliderEnabled = NO;
    self.playButtonEnabled = NO;
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.sourceInputView = [[[UINib nibWithNibName:@"ANSourceInputView"
                                            bundle:[NSBundle mainBundle]]
                             instantiateWithOwner:self options:nil] lastObject];
    self.sourceInputView.delegate = self;
    
    [self.timeSlider addTarget:self
                        action:@selector(sliderDidEndSliding:)
              forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
    
    [self.timeSlider addTarget:self
                        action:@selector(sliderDidStartSliding:)
              forControlEvents:(UIControlEventTouchDown)];
}

#pragma mark - IBActions
- (IBAction)controlPanelAddSourceButtonAction:(id)sender {
    [self enableButtons:NO];
    
    [self addSubview:self.sourceInputView];
    self.sourceInputView.translatesAutoresizingMaskIntoConstraints = NO;

    NSDictionary *viewsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:self.sourceInputView, @"sourceInputView",
                                     self.addSourceButton, @"button", nil];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[sourceInputView]-(0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:viewsDictionary]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[button]-(8)-[sourceInputView]-(0)-|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:viewsDictionary]];
}
- (IBAction)showHistoryListButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(controlPanelViewShowHistoryListButtonAction:)]){
        [self.delegate controlPanelViewShowHistoryListButtonAction:self];
    }
}

- (IBAction)playButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(controlPanelViewPlayButtonActioin:)]){
        [self.delegate controlPanelViewPlayButtonActioin:self];
    }
}

- (IBAction)stopButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(controlPanelViewStopAction:)]){
        [self.delegate controlPanelViewStopAction:self];
    }
}

#pragma mark source input view delegate
- (void)sourceInputView:(ANSourceInputView *)view didGetUrlString:(NSString *)urlString {
    [self enableButtons:YES];
    self.urlString = urlString;
    [self.sourceInputView removeFromSuperview];
    if ([self.delegate respondsToSelector:@selector(controlPanelView:didGetUrlString:)]){
        [self.delegate controlPanelView:self didGetUrlString:urlString];
    }
}

- (void)sourceInputViewDidCancel:(ANSourceInputView *)view {
    [self enableButtons:YES];
    [self.sourceInputView removeFromSuperview];
}
- (void)enableButtons:(BOOL)enable {
    self.addSourceButton.enabled = enable;
    self.historyListButton.enabled = enable;
}
#pragma mark - play button
- (void)setPlayButtonEnabled:(BOOL)enabled {
    _playButtonEnabled = enabled;
    self.playButton.enabled = enabled;
}

- (BOOL)playButtonEnabled {
    return self.playButton.enabled;
}

- (void)setPlayButtonTitle:(NSString *)playButtonTitle {
    _playButtonTitle = [playButtonTitle uppercaseString];
    if ([_playButtonTitle isEqualToString:@"PAUSE"]){
        UIImage *pauseImage = [UIImage imageNamed:@"Pause"];
        [self.playButton setImage:pauseImage forState:UIControlStateNormal];
        
    } else if ([_playButtonTitle isEqualToString:@"PLAY"] ||
               [_playButtonTitle isEqualToString:@"RESUME"])
    {
        UIImage *playImage = [UIImage imageNamed:@"Play"];
        [self.playButton setImage:playImage forState:UIControlStateNormal];
    }
}

#pragma mark - time slider
- (void)setTimeSliderEnabled:(BOOL)timeSliderEnabled {
    _timeSliderEnabled = timeSliderEnabled;
    self.timeSlider.enabled = timeSliderEnabled;
    
    if (!timeSliderEnabled){
        self.timeSlider.value = 0.0;
    }
}

- (void)setTimeSliderValue:(double)value {
    _timeSliderValue = value;
    
    if (!self.sliderIsSliding){
        self.timeSlider.value = value;
    }
    
    if (self.totalMediaDuration){
        double currentPos = (self.totalMediaDuration * value) / 100.0;
        int hours = (int)currentPos / 3600.0;
        currentPos = currentPos - hours * 3600;
        
        int min = (int)currentPos / 60.0;
        currentPos = currentPos - min * 60;
        
        int sec = (int)currentPos;
        
        NSMutableString *time = [NSMutableString string];
        if (hours){
            [time appendFormat:@"%d:", hours];
        }
        
        if (min){
            if (min < 10){
                [time appendFormat:@"0%d:", min];
            } else{
                [time appendFormat:@"%d:", min];
            }
        } else {
            [time appendString:@"00:"];
        }
        
        if (sec){
            if (sec < 10) {
                [time appendFormat:@"0%d", sec];
            } else {
                [time appendFormat:@"%d", sec];
            }
        } else {
            [time appendString:@"00"];
        }
        self.timeLabel.text = time;
    }
}

- (void)sliderDidEndSliding:(NSNotification *)notification {
    self.sliderIsSliding = NO;
    if ([self.delegate respondsToSelector:@selector(controlPanelView:sliderDidSlideToPosition:)]){
        [self.delegate controlPanelView:self sliderDidSlideToPosition:self.timeSlider.value];
    }
}

-(void)sliderDidStartSliding:(NSNotification *)notification {
    self.sliderIsSliding = YES;
    if ([self.delegate respondsToSelector:@selector(controlPanelView:sliderDidStartSliding:)]) {
        [self.delegate controlPanelView:self sliderDidStartSliding:self.timeSlider];
    }
}

- (void)reset {
    [self enableButtons:YES];
    self.timeSlider.enabled = NO;
    self.timeSlider.value = 0;
    self.timeLabel.text = @"00:00";
    self.stopButton.enabled = NO;
}

@end
