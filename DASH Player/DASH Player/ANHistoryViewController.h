//
//  ANHistoryViewController.h
//  DASH Player
//
//  Created by DataArt Apps on 20.10.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol ANHistoryViewControllerDelegate;
@interface ANHistoryViewController : UIViewController
@property (nonatomic, weak) id <ANHistoryViewControllerDelegate> delegate;
@end

@protocol ANHistoryViewControllerDelegate <NSObject>
@optional
- (void)historyViewControllerDidCancel:(ANHistoryViewController *)controller;

- (void)historyViewController:(ANHistoryViewController *)controller didSelectUrlString:(NSString *)urlString;

@end