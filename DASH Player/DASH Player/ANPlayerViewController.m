//
//  ANPlayer.m
//  DASH Player
//
//  Created by DataArt Apps on 05.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANPlayerViewController.h"
#import "ANVideoDecoder.h"
#import "MPD.h"
#import "ANPlayerView.h"
#import "ANHttpClient.h"
#import "ANVideoPicture.h"
#import "ANVideoPicturesList.h"
#import "ANAudioDecoder.h"
#import "ANRingBuffer.h"
#import "ANDrawingPlayerView.h"
#import "ANAudioData.h"
#import "ANVideoData.h"
#import "ANControlPanelView.h"
#import "ANMpdManager.h"
#import "ANHistoryViewController.h"
#import "ANDashMultimediaManagerForRange.h"

#include "libavutil/time.h"

static NSUInteger const ANQueueBufferCount = 4;

static NSUInteger const ANAudioBufferSize = 4096;

static double const ANSyncThreshold = 0.02;

static double const ANControlPanelDefaultDismissTime = 4.0;


@interface ANPlayerViewController ()<ANVideoDecoderDelegate,
                                     ANAudioDecoderDelegate,
                                     ANControlPanelViewDelegate, ANHistoryViewControllerDelegate>
{
    ANVideoDecoder *            _video;
    ANVideoDecoder *            _nextVideo;
    
    ANAudioDecoder *            _audio;
    ANAudioDecoder *            _nextAudio;
    
    
    NSLock *                    _audioLock;
    NSLock *                    _audioClockLock;
    NSLock *                    _accessorsLock;
    NSLock *                    _waitingForMediaLock;
    
    
    NSCondition *               _currentVideoFinishCond;
    NSCondition *               _currentAudioFinishCond;
    NSCondition *               _firstVideoSegmentReadyCond;
    NSCondition *               _firstAudioSegmentReadyCond;
    NSCondition *               _nextVideoReadyCond;
    NSCondition *               _nextAudioReadyCond;
    
    NSDate *                    _playbackStartDate;
    
    AudioStreamBasicDescription _audioDescription;
    AudioQueueRef               _audioQueue;
    AudioQueueBufferRef         _audioQueueBuffers[ANQueueBufferCount];
    
    
    double                      _previousVideosDuration;
    double                      _audioClock;
    
    
    NSTimeInterval              _totalMediaDuration;
    NSTimeInterval              _startDateTimeInterval;
    NSTimeInterval              _startTimeSinceMediaBeginning;
    
    
    NSUInteger                         _audioChannels;
    NSUInteger                         _audioSampleRate;
    NSUInteger                         _bytesPerSample;
    NSUInteger                  _totalAudioBytesRead;
    

    BOOL                        _allowNextVideoInitialization;
    BOOL                        _allowNextAudioInitialization;
    
    BOOL                        _firstVideoSegmentIsDownloaded;
    BOOL                        _firstAudioSegmentIsDownloaded;
    
    BOOL                        _playbackIsStarted;
    BOOL                        _playbackIsInitialized;
    BOOL                        _isStaticStream;
    
    BOOL                        _nextVideoIsReady;
    BOOL                        _nextAudioIsReady;
    
    BOOL                        _pausedForTimeShift;
    BOOL                        _waitingForMediaContent;
    
    
    dispatch_queue_t            _audioSegmentQueue;
    dispatch_queue_t            _videoSegmentQueue;
    
    
    NSTimer *                   _displayUpdateTimer;
    NSTimer *                   _sliderUpdateTimer;
    NSDate *                    _nextTimerFireDate;
    

    ANPicturesListElement *     _currentPictureListElement;
    

    ANVideoData *               _firstVideoData;
    
    ANAudioData *               _firstAudioData;
 
    
    AVRational                  _frameRate;
    AVRational                  _normalFramerate;
}

@property (nonatomic, assign) double audioClock;

@property (nonatomic, assign) BOOL stopped;

@property (nonatomic, assign) BOOL paused;

@property (nonatomic, assign) BOOL controlPanelIsVisible;

@property (nonatomic, assign, getter = isPausedForTimeShift) BOOL pausedForTimeShift;

@property (nonatomic, assign, getter = isWaitingForMediaContent) BOOL waitingForMediaContent;

@property (nonatomic, assign, getter = isNextVideoReady) BOOL nextVideoIsReady;
@property (nonatomic, assign, getter = isNextAudioReady) BOOL nextAudioIsReady;

@property (nonatomic, strong) ANMpdManager *mpdm;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) ANHttpClient *client;

@property (nonatomic, strong) NSURL *mpdUrl;

@property (nonatomic, strong) UITapGestureRecognizer *controlPanelTapGesture;
@property (nonatomic, strong) NSTimer *controlPanelAppereanceTimer;

@property (nonatomic, strong) ANDashMultimediaManager *dashMultimediaManager;

@property (nonatomic, strong) ANHistoryViewController *historyViewController;

@property (nonatomic, assign, getter=isVideoRanged) BOOL videoIsRanged;

static void AudioPlayerAQInputCallback(void *input, AudioQueueRef inQueue, AudioQueueBufferRef outQueueBuffer);

@end

@implementation ANPlayerViewController

@synthesize playerView = playerView;

@synthesize audioClock = _audioClock;

@synthesize waitingForMediaContent = _waitingForMediaContent;
@synthesize nextAudioIsReady = _nextAudioIsReady;
@synthesize nextVideoIsReady = _nextVideoIsReady;
@synthesize stopped = _stopped;

#pragma mark - UIViewController lifecycle methods
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initPlayer];
    
    [self configDrawingView];
    
    [self configControlPanel];
    
    [self configActivityIndicator];
    
    [self configControlPanelAppereance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initPlayer {
    self.client = [ANHttpClient sharedHttpClient];
    
    _currentVideoFinishCond     = [[NSCondition alloc] init];
    _currentAudioFinishCond            = [[NSCondition alloc] init];
    
    _firstVideoSegmentReadyCond      = [[NSCondition alloc] init];
    _firstAudioSegmentReadyCond      = [[NSCondition alloc] init];
    
    _nextVideoReadyCond         = [[NSCondition alloc] init];
    _nextAudioReadyCond         = [[NSCondition alloc] init];
    
    
    _audioSegmentQueue          = dispatch_queue_create("audioSegmetnQueue", DISPATCH_QUEUE_CONCURRENT);
    _videoSegmentQueue          = dispatch_queue_create("videoSegmentQueue", DISPATCH_QUEUE_CONCURRENT);
    
    _audioClockLock             = [[NSLock alloc] init];
    _audioLock                  = [[NSLock alloc] init];
    _accessorsLock              = [[NSLock alloc] init];
    _waitingForMediaLock        = [[NSLock alloc] init];
    
    self.controlPanelIsVisible  = YES;
    self.stopped                = YES;
}

- (void)configDrawingView {
    self.playerView = [[[UINib nibWithNibName:@"ANDrawingPlayerView"
                                       bundle:[NSBundle mainBundle]]
                        instantiateWithOwner:self options:nil] lastObject];
    
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.playerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.playerView];
    NSDictionary *viewsDictionary = [NSDictionary dictionaryWithObject:self.playerView forKey:@"playerView"];
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[playerView]-(0)-|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:viewsDictionary]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[playerView]-(0)-|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:viewsDictionary]];
}

- (void)configControlPanel {
    self.controlPanelContainer.layer.cornerRadius = 5.0;
    self.controlPanelView = [[[UINib nibWithNibName:@"ANControlPanelView"
                                             bundle:[NSBundle mainBundle]]
                              instantiateWithOwner:self options:nil] lastObject];
    
    self.controlPanelContainerHeigthConstraint.constant = self.controlPanelView.frame.size.height;
    
    self.controlPanelView.delegate = self;
    
    [self.controlPanelContainer addSubview:self.controlPanelView];
    self.controlPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary * viewsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:self.controlPanelView, @"panel", nil];
    
    [self.controlPanelContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[panel]-(0)-|"
                                                                                       options:0
                                                                                       metrics:nil
                                                                                         views:viewsDictionary]];
    
    [self.controlPanelContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[panel]-(0)-|"
                                                                                       options:0
                                                                                       metrics:nil
                                                                                         views:viewsDictionary]];
    self.controlPanelView.stopButton.enabled = NO;
}

- (void)configActivityIndicator {
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.containerView addSubview:self.activityIndicator];
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.containerView
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0
                                                                constant:0];
    
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.containerView
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1.0
                                                                constant:0];
    [self.containerView addConstraints:@[centerX, centerY]];
    self.activityIndicator.hidesWhenStopped = YES;
}

#pragma mark - control panel appearance methods
- (void)configControlPanelAppereance {
    // setup controlPanelAppereanceTimer
    self.controlPanelAppereanceTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture]
                                                                interval:ANTimerIntervalLagreValue
                                                                  target:self
                                                                selector:@selector(controlPanelAppearanceTimerMethod:)
                                                                userInfo:nil
                                                                 repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.controlPanelAppereanceTimer
                                 forMode:NSDefaultRunLoopMode];
    self.controlPanelTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(showControlPanelTapGesture:)];
    [self.containerView addGestureRecognizer:self.controlPanelTapGesture];
}

- (void)showControlPanelTapGesture:(UITapGestureRecognizer *)theGesture {
    if (_playbackIsStarted){
        if (theGesture.state == UIGestureRecognizerStateEnded){
            if (!self.controlPanelIsVisible){
                self.controlPanelIsVisible = YES;
                if (!self.stopped){
                    [self scheduleControlPanelTimerOnTime:ANControlPanelDefaultDismissTime];
                }
            } else {
                self.controlPanelIsVisible = NO;
            }
        }
    }
}

- (void)scheduleControlPanelTimerOnTime:(NSTimeInterval)sec {
    NSDate *tfd = [NSDate date];
    tfd = [tfd dateByAddingTimeInterval:sec];
    [self.controlPanelAppereanceTimer setFireDate:tfd];
}

- (void)controlPanelAppearanceTimerMethod:(NSTimer *)timer {
    if (!_paused && _playbackIsStarted){
        self.controlPanelIsVisible = NO;
    }
    [timer setFireDate:[NSDate distantFuture]];
}

- (void)showControlPanel:(BOOL)show {
    __weak ANPlayerViewController *theWeekSelf = self;
    if (show){
        self.controlPanelContainer.hidden = NO;
    }
    [UIView animateWithDuration:0.5 animations:^{
        theWeekSelf.controlPanelBottomSpaceConstraint.constant = (show) ? 0.0f : self.controlPanelContainer.frame.size.height;;
        [theWeekSelf.view layoutIfNeeded];
    } completion:^(BOOL finished){
        if (!show){
            theWeekSelf.controlPanelContainer.hidden = YES;
        }
        DLog(@"Control panel animation finished");
    }];
}

- (void)setControlPanelIsVisible:(BOOL)controlPanelIsVisible {
    _controlPanelIsVisible = controlPanelIsVisible;
    [self showControlPanel:controlPanelIsVisible];
}

#pragma mark - ANControlPanelViewDelegate
- (void)controlPanelView:(ANControlPanelView *)theView didGetUrlString:(NSString *)urlString {
    [self processObtainedUrlString:urlString];
}

- (void)controlPanelView:(ANControlPanelView *)theView sliderDidSlideToPosition:(CGFloat)pos {
    
    [self pauseForTimeShift];
    
    float desiredTime = (_totalMediaDuration * pos) / 100.0; // in seconds
    DLog(@"ANPlayer : controlPanelView - slide timer to pos %f sec", pos);
    
    [self.dashMultimediaManager shiftVideoToPosition:desiredTime];
    self.dashMultimediaManager.stopped = NO;
}

- (void)controlPanelViewPlayButtonActioin:(ANControlPanelView *)theView {
    if (!_playbackIsStarted && !_paused){ // if is not started yet and is not paused
        _playbackIsInitialized = YES;
        self.controlPanelView.stopButton.enabled = YES;
        [self.controlPanelView enableButtons:NO];
        [self.activityIndicator startAnimating];
        [self enablePlayButton:NO];
        [self configPlayerButtonTitle:@"Pause"];
        if (self.mpdm.isVideoRanged){
            self.dashMultimediaManager = [[ANDashMultimediaManagerForRange alloc] initWithMpdUrl:self.mpdUrl];
        } else {
            self.dashMultimediaManager = [[ANDashMultimediaManager alloc] initWithMpdUrl:self.mpdUrl];
        }
        self.dashMultimediaManager.delegate = self;
        [self.dashMultimediaManager launchManager];
    } else {
        if (_paused){
            [self resume];
        } else {
            [self pause];
        }
    }
}
- (void)controlPanelView:(ANControlPanelView *)theView sliderDidStartSliding:(UISlider *)slider {
    [self.controlPanelAppereanceTimer setFireDate:[NSDate distantFuture]];
}

- (void)controlPanelViewStopAction:(ANControlPanelView *)theView {
    [self stop];
}

- (void)controlPanelViewShowHistoryListButtonAction:(ANControlPanelView *)theView {
    [self presentViewController:self.historyViewController
                       animated:YES
                     completion:^{
        
    }];
}

- (ANHistoryViewController *)historyViewController {
    if (!_historyViewController){
        _historyViewController = [[ANHistoryViewController alloc] initWithNibName:@"ANHistoryViewController"
                                                                               bundle:[NSBundle mainBundle]];
        _historyViewController.delegate = self;
    }
    return _historyViewController;
}
#pragma mark - ANHistoryViewControllerDelegate
- (void)historyViewControllerDidCancel:(ANHistoryViewController *)controller {
    [self.historyViewController dismissViewControllerAnimated:YES
                                                   completion:^{
        
    }];
}
- (void)historyViewController:(ANHistoryViewController *)controller didSelectUrlString:(NSString *)urlString {
    [self.historyViewController dismissViewControllerAnimated:YES
                                                   completion:^{
                                                       
                                                   }];
    
    [self processObtainedUrlString:urlString];
}

#pragma mark - control panel supporting methods
- (void)enablePlayButton:(BOOL)enable {
    self.controlPanelView.playButtonEnabled = enable;
}

- (void)enableStopButton:(BOOL)disable {
    self.controlPanelView.stopButton.enabled = disable;
}

- (void)configPlayerButtonTitle:(NSString *)title {
    self.controlPanelView.playButtonTitle = title;
}

- (void)processObtainedUrlString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    self.mpdUrl = url;
    if (url){
        [self.activityIndicator startAnimating];
        [self.controlPanelView enableButtons:NO];
        __weak ANPlayerViewController *theWeakSelf = self;
        self.mpdm = [[ANMpdManager alloc] initWithMpdUrl:url
                                            parserThread:[NSThread mainThread]];
        [self.mpdm checkMpdWithCompletionBlock:^(BOOL success, NSError *error){
            if (success){
                [theWeakSelf enablePlayButton:YES];
            } else {
                NSString *message = [NSString stringWithFormat:@"%@", [error userInfo]];
                [ANSupport showInfoAlertWithMessage:message];
                [theWeakSelf enablePlayButton:NO];
            }
            [theWeakSelf.activityIndicator stopAnimating];
            [theWeakSelf.controlPanelView enableButtons:YES];
        }];
    } else {
        [ANSupport showInfoAlertWithMessage:@"URL is not valid"];
        [self enablePlayButton:NO];
    }
}
#pragma mark - Keyboard handling
- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue* aValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardRect = [aValue CGRectValue];
    
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)){
        [self moveControlsPanelWithKeyBoardHeight:keyboardRect.size.width
                                     withDuration:animationDuration];
    } else {
        [self moveControlsPanelWithKeyBoardHeight:keyboardRect.size.height
                                     withDuration:animationDuration];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    [self moveControlsPanelWithKeyBoardHeight:0
                                 withDuration:animationDuration];
}

- (void)moveControlsPanelWithKeyBoardHeight:(CGFloat)kHeigh withDuration:(NSTimeInterval)duration {
    __weak ANPlayerViewController *theWeekSelf = self;
    [UIView animateWithDuration:duration animations:^{
        theWeekSelf.controlPanelBottomSpaceConstraint.constant = -kHeigh;
        [theWeekSelf.view layoutIfNeeded];
    } completion:^(BOOL finished){
        DLog(@"Control panel animation finished");
    }];
}

#pragma mark - pause\play
- (void)pause {
    if (_playbackIsStarted){
        [self.controlPanelAppereanceTimer setFireDate:[NSDate distantFuture]];
        
        [self configPlayerButtonTitle:@"Resume"];
        [self pauseForStatic];
        self.controlPanelIsVisible = YES;
        _paused = YES;
        
        if (!_isStaticStream){
            [self stop];
        }
    }
}

- (void)pauseForStatic {
    AudioQueuePause(_audioQueue);
    [_displayUpdateTimer setFireDate:[NSDate distantFuture]];
    [_sliderUpdateTimer invalidate];
}

- (void)pauseForTimeShift {
    self.pausedForTimeShift = YES;
    AudioQueuePause(_audioQueue);
    
    [self.activityIndicator startAnimating];
    [self enablePlayButton:NO];
    
    [_displayUpdateTimer setFireDate:[NSDate distantFuture]];
    [_sliderUpdateTimer invalidate];
    
    self.dashMultimediaManager.stopped = YES;
    
    _firstAudioSegmentIsDownloaded = NO;
    _firstVideoSegmentIsDownloaded = NO;
    
    [self stopMediaDecoding];
    
    [self releaseAllConditions];
    dispatch_async(dispatch_get_main_queue(), ^{
        AudioQueueStop(_audioQueue, YES);
    });
}

- (void)stopMediaDecoding {
    [_nextVideo quit];
    [_nextAudio quit];
    [_video quit];
    [_audio quit];
    
    _video = nil;
    _audio = nil;
    _nextAudio = nil;
    _nextVideo = nil;
}

- (void)releaseAllConditions {
    _allowNextVideoInitialization = YES;
    [_currentVideoFinishCond broadcast];
    
    _allowNextAudioInitialization = YES;
    [_currentAudioFinishCond broadcast];
    
    self.nextVideoIsReady = YES;
    [_nextVideoReadyCond broadcast];
    
    self.nextAudioIsReady = YES;
    [_nextAudioReadyCond broadcast];
}

- (void)resume {
    _paused = NO;
    [self configPlayerButtonTitle:@"Pause"];
    [self scheduleControlPanelTimerOnTime:ANControlPanelDefaultDismissTime];
    if (_isStaticStream){
        
        [self resumeForStatic];
    } else {
        // it will be enabled when playback starts
        [self enablePlayButton:NO];
        
        self.dashMultimediaManager.stopped = NO;
        [self.dashMultimediaManager launchManager];
    }
}

- (void)resumeForStatic {
    [self setupPlaybackStartDateWithCurrentDate];
    
    _sliderUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(sliderTimerMethod:)
                                                        userInfo:nil
                                                         repeats:YES];
    
    _nextTimerFireDate = [NSDate dateWithTimeInterval:0.0
                                            sinceDate:_playbackStartDate];
    AudioQueueStart(_audioQueue, NULL);
    [_displayUpdateTimer setFireDate:_nextTimerFireDate];
}

- (void)waitForContent {
    if (!self.stopped){
        DLog(@"ANPlayer : waitForContent");
        self.waitingForMediaContent = YES;
        DLog(@"ANPlayer : waitForContent set to YES");
        
        AudioQueuePause(_audioQueue);
        [_displayUpdateTimer setFireDate:[NSDate distantFuture]];
        [_sliderUpdateTimer invalidate];
        [self.activityIndicator startAnimating];
    }
}

- (void)resumeFromContentWaiting {
    DLog(@"ANPlayer : resumeFromContentWaiting");
    [self.activityIndicator stopAnimating];
    self.waitingForMediaContent = NO;
    
    [self resumeForStatic];
}

- (void)stop {
    DLog(@"ANPlayer : stop");
    if (_playbackIsStarted || _playbackIsInitialized){
        self.stopped = YES;
        _firstVideoSegmentIsDownloaded = NO;
        _firstAudioSegmentIsDownloaded = NO;
        
        _playbackIsStarted = NO;
        _playbackIsInitialized = NO;
        _paused = NO;
        
        self.dashMultimediaManager.stopped = YES;
        
        [self.playerView clear];
        
        [self configPlayerButtonTitle:@"Play"];
        [self pauseForStatic];
        
        [self stopMediaDecoding];
        [self releaseAllConditions];
        
        [self.controlPanelView reset];
        self.dashMultimediaManager = nil;
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.controlPanelAppereanceTimer setFireDate:[NSDate distantFuture]];
        
        self.waitingForMediaContent = NO;
        self.controlPanelIsVisible = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            AudioQueueStop(_audioQueue, YES);
        });
    }
    [self.activityIndicator stopAnimating];
}

#pragma mark - displaying logic
- (void)startPlayback {
    DLog(@"ANPlayer : startPlayback");
    _previousVideosDuration = 0;
    _totalAudioBytesRead = 0;
    self.audioClock = 0;
    
    self.dashMultimediaManager.stopped = NO;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    if (_displayUpdateTimer){
        [_displayUpdateTimer invalidate];
    }
    _displayUpdateTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture]
                                                   interval:ANTimerIntervalLagreValue // any lagre value
                                                     target:self
                                                   selector:@selector(displayNextFrame:)
                                                   userInfo:nil
                                                    repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:_displayUpdateTimer
                                 forMode:NSDefaultRunLoopMode];
    
    
    [self setupPlaybackStartDateWithCurrentDate];
    _nextTimerFireDate = [NSDate dateWithTimeInterval:0.0
                                            sinceDate:_playbackStartDate];
    
    self.controlPanelView.timeSliderEnabled = _isStaticStream ? YES : NO;
    
    [self initAudioQueues];
    for(int i = 0; i < ANQueueBufferCount; i++) {
        [self readPCMAndPlay:_audioQueue buffer:_audioQueueBuffers[i]];
    }
    
    _sliderUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(sliderTimerMethod:)
                                                        userInfo:nil
                                                         repeats:YES];
    
    [self.activityIndicator stopAnimating];
    AudioQueueStart(_audioQueue, NULL);
    _currentPictureListElement = [self nextPictureListElement];
    [self displayNextFrame:nil];
    
    _playbackIsStarted = YES;
    _playbackIsInitialized = NO;
    
    [self signalFirstSegmentsDownloaded];
    [self enablePlayButton:YES];
    DLog(@"ANPlayer : startPlayback - _firstVideoSegmentCond signal");
    
    [self scheduleControlPanelTimerOnTime:ANControlPanelDefaultDismissTime];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_paused){
            [self pause];
        }
    });
}

- (void)signalFirstSegmentsDownloaded {
    _firstVideoSegmentIsDownloaded = YES;
    _firstAudioSegmentIsDownloaded = YES;
    
    [_firstVideoSegmentReadyCond signal];
    [_firstAudioSegmentReadyCond signal];
}

-(void)displayNextFrame:(NSTimer *)timer {
    [self scheduleVideoRefreshTimer];
    _currentPictureListElement = [self nextPictureListElement];
    if (_currentPictureListElement){
        [self.playerView render:_currentPictureListElement.yuvFrame];
        _currentPictureListElement = nil;
    }
}

- (void)scheduleVideoRefreshTimer {
    double diff = 0;
    do {
        double timeInterval = (double) _frameRate.den / _frameRate.num;
        _nextTimerFireDate = [NSDate dateWithTimeInterval:timeInterval
                                                sinceDate:_nextTimerFireDate];

        diff = [_nextTimerFireDate timeIntervalSinceReferenceDate] - [NSDate timeIntervalSinceReferenceDate];
        if (diff > 0){
            [_displayUpdateTimer setFireDate:_nextTimerFireDate];
            break;
        } else {
            DLog(@"ANPlayer : scheduleVideoRefreshTime - fireDate is in the past");
        }
    } while (diff < 0);
}

- (ANPicturesListElement *)nextPictureListElement {
    ANPicturesListElement *element = [_video.videoPicturesList getPictureElement];
    if ((_video.videoPicturesList.count == 0
        && [_video isVideoFinished]))
    {
        DLog(@"ANPlayer : nextPictureListElement - video ended");
        if (_video.videoData.isLastSegmentNumber){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stop];
            });
            return element;
        }
        
        if (!self.isNextVideoReady) {
            DLog(@"ANPlayer : nextPictureListElement - video - waitForContent");
            [self waitForContent];
            return element;
        }
        
        [self calculateNextFramerate];
        // TODO: write correct waiting algorithm for next video segment in case when internet connection is too slow
        
        if (_nextVideo == nil) {
            DLog(@"ANPlayer : nextPictureListElement - next video == NIL");
        }
        
        [self switchToNextVideoSegment];

        if (!element){ // element might be nil in case if app was waiting for content
            element = [_video.videoPicturesList getPictureElement];
        }
    }
    
    return element;
}
- (void)switchToNextVideoSegment {
     DLog(@"ANPlayer : switchToNextVideoSegment - next video segment number = %lu", (unsigned long)_nextVideo.videoData.segmentNumber);
    
    _video = _nextVideo;
    
//    _nextVideoDuration = 0;
    _nextVideo = nil;
    
    self.nextVideoIsReady = NO;
}

- (void)calculateNextFramerate {
    _previousVideosDuration += _video.videoData.mediaDurationScaled;
    double audioClock = self.audioClock;
    
    // if diff > 0, video is speeding up
    double diff = _previousVideosDuration - audioClock;
    double diffAbs = fabs(diff);
    
    if (diffAbs > ANSyncThreshold){
        if (!_nextVideo.videoData.isLastSegmentNumber){
            double currentFrameDuration = (double)_normalFramerate.den / _normalFramerate.num;
            double scaledDuration = _nextVideo.videoData.mediaDurationScaled;
            double framesInNextVideo = (scaledDuration * (double)_normalFramerate.num) / (double)_normalFramerate.den;
            double value = (diff - diff / 10.0) / framesInNextVideo;
            
            _frameRate = av_d2q(currentFrameDuration + value, 65536);
            _frameRate = av_inv_q(_frameRate);
            
        } else {
            _frameRate = [_nextVideo movieFramerate];
        }
        
        DLog(@"ANPlayer : calculateNextFramerate - framerate changed.\nNew framerate is %f",
             (double)_frameRate.num / _frameRate.den);
    }
    
    DLog(@"ANPlayer : calculateNextFramerate - diff = %f", diff);
}

- (void)sliderTimerMethod:(NSTimer *)timer {
    if (!self.stopped){
        float time = self.audioClock + _startTimeSinceMediaBeginning;
        self.controlPanelView.timeSliderValue = (time / _totalMediaDuration) * 100;
    }
}

- (void)setupPlaybackStartDateWithCurrentDate {
    _playbackStartDate = [NSDate date];
    _startDateTimeInterval = [_playbackStartDate timeIntervalSinceReferenceDate];
}

#pragma mark - preparing for playback
- (BOOL)prepareForPlayback {
    self.pausedForTimeShift = NO;
    self.stopped = NO;
    
    _allowNextVideoInitialization = NO;
    _allowNextAudioInitialization = NO;
    self.nextVideoIsReady = NO;
    self.nextAudioIsReady = NO;
    
    _isStaticStream = (_dashMultimediaManager.streamType == ANStreamTypeStatic);
    _totalMediaDuration = _dashMultimediaManager.totalMediaDuration;
    self.controlPanelView.totalMediaDuration = _totalMediaDuration;
    BOOL result = [self prepareVideo] && [self prepareAudio];
    return result;
}

- (BOOL)prepareVideo {
    _startTimeSinceMediaBeginning = _firstVideoData.timeSinceMediaBeginning;
    if (!(_video = [[ANVideoDecoder alloc] initWithVideoData:_firstVideoData])){
        NSLog(@"ANPlayer : prepareVideo - cannot read video data");
        [self failureStopWithMessage:@"ANPlayer : prepareVideo - cannot read video data"];
        return NO;
    }
    _video.delegate = self;
    [_video startWork];
    DLog(@"ANPlayer : prepareVideo - Created first video object %@", _video);
    
    _frameRate = [_video movieFramerate];
    _firstVideoData.framerate = _frameRate;
    
    self.playerView.videoSize = CGSizeMake(_video.sourceWidth, _video.sourceHeight);
    return YES;
}

- (BOOL)prepareAudio {
    if (!(_audio = [[ANAudioDecoder alloc] initWithAudioData:_firstAudioData])){
        NSLog(@"ANPlayer : prepareAudio - cannot read audio data");
        [self failureStopWithMessage:@"ANPlayer : prepareAudio - cannot read audio data"];
        return NO;
    }
    _audio.delegate = self;
    [_audio startWork];
    return YES;
}

#pragma mark - processing downloaded segments
- (void)processNextVideoSegmentData:(ANVideoData *)videoData {
    assert(videoData.mediaData);
    DLog(@"ANPlayer : processNextVideoSegmentData - process Next Video Segment");
    
    [_currentVideoFinishCond lock];
    while (!_allowNextVideoInitialization) {
        DLog(@"ANPlayer : processNextVideoSegmentData - waiting for current video decoding END");
        [_currentVideoFinishCond wait];
        DLog(@"ANPlayer : processNextVideoSegmentData - current video decoding ENDED");
    }
    _allowNextVideoInitialization = NO;
    [_currentVideoFinishCond unlock];
    
    _nextVideo = [[ANVideoDecoder alloc] initWithVideoData:videoData];
    self.nextVideoIsReady = YES;
    DLog(@"ANPlayer : processNextVideoSegmentData - Created next video object %@ with segment number %lu", _nextVideo, (unsigned long)videoData.segmentNumber);
    _nextVideo.delegate = self;
    
    if (!self.pausedForTimeShift && !self.stopped){
        [_nextVideo startWork];
    }
    [_nextVideoReadyCond signal];
    BOOL isWaiting = self.isWaitingForMediaContent;
    DLog(@"ANPlayer : processNextVideoSegmentData - isWaitingForMediaContent == %@", isWaiting ? @"YES" : @"NO");
    
    if (isWaiting){
        DLog(@"ANPlayer : processNextVideoSegmentData - resume");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resumeFromContentWaiting];
        });
    }
}

- (void)processNextAudioSegmentData:(ANAudioData *)audioData {
    assert(audioData.mediaData);
    DLog(@"ANPlayer : processNextAudioSegmentData - process Next Audio Segment");

    [_currentAudioFinishCond lock];
    
    _nextAudio = [[ANAudioDecoder alloc] initWithAudioData:audioData];
    assert(_nextAudio);
    DLog(@"ANPlayer : processNextAudioSegmentData - crated next audio object %@ with segment number %lu",
         _nextAudio, audioData.segmentNumber);
    
    _nextAudio.delegate = self;
    self.nextAudioIsReady = YES;
    
    DLog(@"ANPlayer : processNextAudioSegmentData - Audio duration: %f", audioData.mediaDurationScaled);
    while (!_allowNextAudioInitialization) {
        DLog(@"ANPlayer : processNextAudioSegmentData - waiting for current audio decoding END");
        [_currentAudioFinishCond wait];
        DLog(@"ANPlayer : processNextAudioSegmentData - current audio decoding ENDED");
    }
    _allowNextAudioInitialization = NO;
    [_currentAudioFinishCond unlock];
    
    if (!self.pausedForTimeShift){
        [_nextAudio startWork];
    }
    
    DLog(@"ANPlayer : processNextAudioSegmentData - _nextAudioReadyCond signal");
    [_nextAudioReadyCond signal];
    BOOL isWaiting = self.isWaitingForMediaContent;
    if (isWaiting){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resumeFromContentWaiting];
        });
    }
}

#pragma mark - ANDashMultimediaManagerDelegate
- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager
didDownloadFirstVideoSegment:(ANVideoData *)videoData
           firstAudioSegment:(ANAudioData *)audioData
{
    DLog(@"ANPlayer : dashMultimediaManger:didDownloadFirstVideoSegment - process first media segments");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _firstVideoData = videoData;
        _firstAudioData = audioData;
        
        if ([self prepareForPlayback]){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self startPlayback];
            });
        }
        
    });
}

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager
        didDownloadVideoData:(ANVideoData *)videoData
{
    dispatch_async(_videoSegmentQueue, ^{
        
        [_firstVideoSegmentReadyCond lock];
        while (!_firstVideoSegmentIsDownloaded) {
            DLog(@"ANPlayer : dashMultimediaManger:didDownloadVideoData - next VIDEO waiting for firstVideoSegmentDownloaded");
            [_firstVideoSegmentReadyCond wait];
        }
        [_firstVideoSegmentReadyCond unlock];
        [self processNextVideoSegmentData:videoData];
    });
}

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager
        didDownloadAudioData:(ANAudioData *)audioData
{
    dispatch_async(_audioSegmentQueue, ^{
        [_firstAudioSegmentReadyCond lock];
        while (!_firstAudioSegmentIsDownloaded) {
            DLog(@"ANPlayer : dashMultimediaManger:didDownloadAudioData - next AUDIO waiting for firstAudioSegmentDownloaded");
            [_firstAudioSegmentReadyCond wait];
        }
        [_firstAudioSegmentReadyCond unlock];
        [self processNextAudioSegmentData:audioData];
    });
}

- (void)dashMultimediaManger:(ANDashMultimediaManager *)manager didFailWithMessage:(NSString *)failMessage {
    [self failureStopWithMessage:failMessage];
}

- (void)failureStopWithMessage:(NSString *)failMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[UIAlertView alloc] initWithTitle:failMessage
                                    message:@""
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];
        [self stop];
    });
}

#pragma mark - ANVideoDecoderDelegate protocol

- (void)decoderDidFinishDecoding:(ANVideoDecoder *)video {
     DLog(@"ANPlayer : decoderDidFinishDecoding - video did finish");
    if (!self.pausedForTimeShift){
        ANVideoData *videoData = [video videoData];
        NSInteger expectedFramesNumber = [videoData expectedFramesNumber];
        DLog(@"ANPlayer : decoderDidFinishDecoding - frames in video = %lu", video.framesCount);
        AVRational requiredFps = av_make_q((int)(video.framesCount * videoData.timescale), (int)videoData.mediaDuration);
        av_reduce(&requiredFps.num, &requiredFps.den, requiredFps.num, requiredFps.den, requiredFps.num);
        
        if (expectedFramesNumber > video.framesCount){
            _normalFramerate = requiredFps;
        } else {
            _normalFramerate = video.movieFramerate;
        }

        DLog(@"ANPlayer : decoderDidFinishDecoding - New framerate = %d / %d", _frameRate.num, _frameRate.den);
       
        _allowNextVideoInitialization = YES;
        DLog(@"ANPlayer : decoderDidFinishDecoding - _currentVideoFinishCond signal");
        [_currentVideoFinishCond signal];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [_nextVideoReadyCond lock];
            while (!self.nextVideoIsReady) {
                [_nextVideoReadyCond wait];
            }
            DLog(@"ANPlayer : decoderDidFinishDecoding - Send request for video segment downloading");
            if (_isStaticStream){
                [self.dashMultimediaManager static_downloadNextVideoSegment];
            } else {
                [self.dashMultimediaManager dynamic_downloadNextVideoSegment];
            }
            [_nextVideoReadyCond unlock];
           
        });
    }
}

#pragma mark - ANAudioFrameExtractorDelegate protocol
- (void)audioDidEnd:(ANAudioDecoder *)audio {
    DLog(@"ANPlayer : audioDidEnd -_audioFinishCond signal");
    _allowNextAudioInitialization = YES;
    [_currentAudioFinishCond signal];
}

#pragma mark - audio
#pragma mark - audio call back
static double ANBytesForOneSec = 0.0;
-(void)initAudioQueues
{
    _audioDescription.mSampleRate = [_audio sampleRate];
    _audioDescription.mFormatID = kAudioFormatLinearPCM;
    _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    _audioDescription.mChannelsPerFrame = [_audio channels];
    _audioDescription.mFramesPerPacket = 1;
    _audioDescription.mBitsPerChannel = sizeof(int16_t) * 8;//sizeof (AudioSampleType);//16bit
    _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
    _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame ;

    self->_audioSampleRate = _audioDescription.mSampleRate;
    self->_audioChannels = _audioDescription.mChannelsPerFrame;
    self->_bytesPerSample = 2;
    
    ANBytesForOneSec = (double)(_audioChannels * _audioSampleRate * _bytesPerSample);
    AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void *)(self), nil, nil, 0, &_audioQueue);

    for(int i = 0; i < ANQueueBufferCount; i++) {
        AudioQueueAllocateBuffer(_audioQueue, ANAudioBufferSize, &_audioQueueBuffers[i]);
    }
}

static void AudioPlayerAQInputCallback(void *input, AudioQueueRef inQueue, AudioQueueBufferRef outQueueBuffer)
{
    
    ANPlayerViewController *player = (__bridge ANPlayerViewController *)input;
    [player readPCMAndPlay:inQueue buffer:outQueueBuffer];
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    static int bufferedSize = (ANAudioBufferSize * ANQueueBufferCount) ;//+ 17640 ; // 17640 == 1/10 sec
    
    if (self.pausedForTimeShift || self.isWaitingForMediaContent){
        return;
    }
    
    [_audioLock lock];
    
    Byte *audiodata = (Byte *)outQB->mAudioData;
    
    int bytesRead = [_audio.ringBuffer read:audiodata
                                 withLength:ANAudioBufferSize
                                      block:1];

    if ( (bytesRead > 0) && (bytesRead < ANAudioBufferSize)){
        if (!self.isNextAudioReady){
            if (_video.videoData.isLastSegmentNumber){
                AudioQueueStop(_audioQueue, NO);
            } else {
                DLog(@"ANPlayer : readPCMAndPlay - Next audio isn't ready");
                int64_t delta =  (int64_t)((ANAudioBufferSize / 2.0) / ANBytesForOneSec) * NSEC_PER_SEC; // convert to nanosec
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, delta);
                
                self.waitingForMediaContent = YES;
                dispatch_after(time, dispatch_get_main_queue(), ^{
                    DLog(@"ANPlayer : readPCMAndPlay  -  audio - waitForContent");
                    [self waitForContent];
                });
            }
        } else {
            self.nextAudioIsReady = NO;
            
            _audio = [self nextAudioDecoder];
            bytesRead += [_audio.ringBuffer read:audiodata + bytesRead
                                      withLength:ANAudioBufferSize - bytesRead
                                           block:1];
            DLog(@"ANPlayer : readPCMAndPlay  - switch audio");
        }
    } else if (bytesRead == 0 || bytesRead == -1){
        if (!self.isNextAudioReady){
            if (_video.videoData.isLastSegmentNumber){
                AudioQueueStop(_audioQueue, NO);
                [_audioLock unlock];
                return;
            } else {
                DLog(@"ANPlayer : readPCMAndPlay  - Next audio isn't ready");
                int64_t delta =  (int64_t)((ANAudioBufferSize / 2.0) / ANBytesForOneSec) * NSEC_PER_SEC; // convert to nanosec
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, delta);
                
                self.waitingForMediaContent = YES;
                dispatch_after(time, dispatch_get_main_queue(), ^{
                    DLog(@"ANPlayer : readPCMAndPlay  -  audio - waitForContent");
                    [self waitForContent];
                });
                [_audioLock unlock];
                return;
            }
        }
        
        self.nextAudioIsReady = NO;
        if (_nextAudio == nil){
            DLog(@"ANPlayer : readPCMAndPlay - NEXT AUDIO == NIL!!!!!!");
            [_audioLock unlock];
            return;
        }
        _audio = [self nextAudioDecoder];
        bytesRead = [_audio.ringBuffer read:audiodata
                                 withLength:ANAudioBufferSize
                                      block:1];
        DLog(@"ANPlayer : readPCMAndPlay  - switch audio 2, Bytes read: %d", bytesRead);
    }
    
    if (bytesRead > 0){
        outQB->mAudioDataByteSize = bytesRead;
        AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
        _totalAudioBytesRead += bytesRead;
        self.audioClock = (double) (_totalAudioBytesRead - bufferedSize) / ANBytesForOneSec;
    }
    [_audioLock unlock];
}

- (ANAudioDecoder *)nextAudioDecoder {
    __weak ANPlayerViewController *theWeakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_isStaticStream){
            DLog(@"ANPlayer - Download next Audio segment");
            [theWeakSelf.dashMultimediaManager static_downloadNextAudioSegment];
        } else {
            [theWeakSelf.dashMultimediaManager dynamic_downloadNextAudioSegment];
        }
    });
    
    return _nextAudio;
}

#pragma mark - atomic
- (void)setAudioClock:(double)anAudioClock {
    [_audioClockLock lock];
    _audioClock = anAudioClock;
    [_audioClockLock unlock];
}

- (double)audioClock {
    [_audioClockLock lock];
    double ret = _audioClock;
    [_audioClockLock unlock];
    
    return ret;
}

- (void)setPausedForTimeShift:(BOOL)pausedForTimeShift {
    [_accessorsLock lock];
    _pausedForTimeShift = pausedForTimeShift;
    [_accessorsLock unlock];
}

- (BOOL)isPausedForTimeShift {
    [_accessorsLock lock];
    BOOL ret = _pausedForTimeShift;
    [_accessorsLock unlock];
    
    return ret;
}

- (void)setWaitingForMediaContent:(BOOL)waitingForMediaContent {
    [_waitingForMediaLock lock];
    if (waitingForMediaContent){
        DLog(@"ANPlayer : setWaitingForMediaContent == YES");
    }
    _waitingForMediaContent = waitingForMediaContent;
    [_waitingForMediaLock unlock];
}

- (BOOL)isWaitingForMediaContent {
    [_waitingForMediaLock lock];
    BOOL ret = _waitingForMediaContent;
    [_waitingForMediaLock unlock];
    
    return ret;
}

- (void)setNextAudioIsReady:(BOOL)nextAudioIsReady {
    [_accessorsLock lock];
    _nextAudioIsReady = nextAudioIsReady;
    [_accessorsLock unlock];
}

- (BOOL)isNextAudioReady {
    [_accessorsLock lock];
    BOOL ret = _nextAudioIsReady;
    [_accessorsLock unlock];
    
    return ret;
}

- (void)setNextVideoIsReady:(BOOL)nextVideoIsReady {
     [_accessorsLock lock];
    _nextVideoIsReady = nextVideoIsReady;
     [_accessorsLock unlock];
}

- (BOOL)isNextVideoReady {
    [_accessorsLock lock];
    BOOL ret = _nextVideoIsReady;
    [_accessorsLock unlock];
    
    return ret;
}
- (void)setStopped:(BOOL)stopped {
    [_accessorsLock lock];
    _stopped = stopped;
    [_accessorsLock unlock];
}

- (BOOL)stopped {
    [_accessorsLock lock];
    BOOL ret = _stopped;
    [_accessorsLock unlock];
    
    return ret;
}

@end
