//
//  ANSourceInputView.h
//  DASH Player
//
//  Created by DataArt Apps on 29.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

// http://rdmedia.bbc.co.uk/dash/ondemand/bbb/avc1/1/client_manifest.mpd

// http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd
// http://yt-dash-mse-test.commondatastorage.googleapis.com/media/feelings_vp9-20130806-manifest.mpd

#import <UIKit/UIKit.h>
@protocol ANSourceInputViewDelegate;

@interface ANSourceInputView : UIView <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *sourceInputViewDoneButton;
@property (weak, nonatomic) IBOutlet UITextField *sourceInputViewTextField;

@property (nonatomic, weak) id <ANSourceInputViewDelegate> delegate;

@end

@protocol ANSourceInputViewDelegate <NSObject>
@optional
- (void)sourceInputView:(ANSourceInputView *)view didGetUrlString:(NSString *)urlString;
- (void)sourceInputViewDidCancel:(ANSourceInputView *)view;
@end