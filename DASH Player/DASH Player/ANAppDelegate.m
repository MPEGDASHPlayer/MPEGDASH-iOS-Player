//
//  ANAppDelegate.m
//  DASH Player
//
//  Created by DataArt Apps on 24.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANAppDelegate.h"
#import "ANPlayerViewController.h"

@implementation ANAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    ANPlayerViewController *vc = (ANPlayerViewController *)self.window.rootViewController;
    [vc pause];
    DLog(@"APP DELEGATE - player paused");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    ANPlayerViewController *vc = (ANPlayerViewController *)self.window.rootViewController;
    [vc stop];
    DLog(@"APP DELEGATE - player paused");
}

@end
