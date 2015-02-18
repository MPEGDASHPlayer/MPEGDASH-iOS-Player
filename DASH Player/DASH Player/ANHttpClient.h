//
//  ANHttpClient.h
//  DASH Player
//
//  Created by DataArt Apps on 06.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ANHttpClient : NSObject

@property (nonatomic, assign) NSUInteger bytesDownloaded;
@property (nonatomic, assign) double timeForDownload;

@property (nonatomic, assign) NSUInteger lastBytesDownloaded;
@property (nonatomic, assign) double lastTimeForDownload;


@property (nonatomic, assign) double averageNetworkSpeed;
@property (nonatomic, assign) double lastNetworkSpeed;

+ (instancetype)sharedHttpClient;

- (void)downloadFile:(NSURL *)fileUrl
         withSuccess:(ANSuccessWithResponseCompletionBlock)success
             failure:(ANFailureCompletionBlock)failure;

- (void)downloadFile:(NSURL *)fileUrl
             atRange:(NSString *)rangeString
         withSuccess:(ANSuccessWithResponseCompletionBlock)success
             failure:(ANFailureCompletionBlock)failure;

- (NSUInteger)lastDownloadSpeed;
- (void)cancelDownloading;
@end

