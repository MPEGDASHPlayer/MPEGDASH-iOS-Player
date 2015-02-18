//
//  ANSourceInputView.m
//  DASH Player
//
//  Created by DataArt Apps on 29.09.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANSourceInputView.h"

@implementation ANSourceInputView

- (void)awakeFromNib {
    [super awakeFromNib];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self saveUrlToDefaults:@"http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"];
        [self saveUrlToDefaults:@"http://rdmedia.bbc.co.uk/dash/ondemand/bbb/avc1/1/client_manifest.mpd"];
    });
    
    self.sourceInputViewTextField.delegate = self;
}

- (IBAction)doneButtonAction:(id)sender {
    NSString *urlString = self.sourceInputViewTextField.text;
    if (urlString.length){
        [self saveUrlToDefaults:urlString];
        
        if ([self.delegate respondsToSelector:@selector(sourceInputView:didGetUrlString:)]){
            [self.delegate sourceInputView:self didGetUrlString:urlString];
        }
        [self.sourceInputViewTextField resignFirstResponder];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Enter link"
                                    message:@""
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];
    }
}

- (void)saveUrlToDefaults:(NSString *)urlString {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *arr = [userDefaults objectForKey:ANUserDefaultsHistoryKey];
    
    NSMutableArray *array;
    if ([arr count]){
        array = [NSMutableArray arrayWithArray:arr];
        BOOL found = NO;
        for (NSString *str in arr) {
            if ([urlString isEqualToString:str]){
                found = YES;
                break;
            }
        }
        if (!found){
            [array addObject:urlString];
        }
    } else {
        array = [NSMutableArray arrayWithObject:urlString];
    }
    
    [userDefaults setObject:array forKey:ANUserDefaultsHistoryKey];
    [userDefaults synchronize];
}

- (IBAction)cancelButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(sourceInputViewDidCancel:)]){
        [self.delegate sourceInputViewDidCancel:self];
    }
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length){
        [textField resignFirstResponder];
        return YES;
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Enter link"
                                    message:@""
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];
        return NO;
    }
}

@end
