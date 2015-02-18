//
//  ANHttpClient.m
//  DASH Player
//
//  Created by DataArt Apps on 06.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANHttpClient.h"
#import "ANDownloadOperation.h"

@interface ANHttpClient()
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, strong) NSMutableArray *downloadingOperationsArray;
@end

@implementation ANHttpClient
- (id)init {
    self = [super init];
    if (self){
        self.downloadQueue = [[NSOperationQueue alloc] init];
        self.timeForDownload = 0.0;
        self.bytesDownloaded = 0;
        _downloadingOperationsArray = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)sharedHttpClient {
    static ANHttpClient *sharedHttpClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHttpClient = [[self alloc] init];
    });
    return sharedHttpClient;
}

- (NSUInteger)lastDownloadSpeed {
    @synchronized(self){
        return (unsigned int)((_lastBytesDownloaded / _lastTimeForDownload) / 1024.0);
    }
}

#pragma mark - download methods
- (void)downloadFile:(NSURL *)fileUrl
            withSuccess:(ANSuccessWithResponseCompletionBlock)success
                failure:(ANFailureCompletionBlock)failure
{
//    DLog(@"Request to URL: %@", fileUrl);
    ANDownloadOperation *operation = [[ANDownloadOperation alloc] initWithUrl:fileUrl];
    operation.success = success;
    operation.failure = failure;
    
    __weak ANDownloadOperation *weakOperation = operation;

    operation.statisticBlock = ^{
        self.timeForDownload += weakOperation.timeForDownload;
        self.bytesDownloaded += weakOperation.bytesDownloaded;
        
        self.lastBytesDownloaded = weakOperation.bytesDownloaded;
        self.lastTimeForDownload = weakOperation.timeForDownload;
        [self.downloadingOperationsArray removeObject:weakOperation];
    };
    
    [_downloadingOperationsArray addObject:operation];
    NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:fileUrl
                                                              cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                          timeoutInterval:60];
    operation.urlRequest = theRequest;
    
    [operation lauchDownloading];
}
- (void)downloadFile:(NSURL *)fileUrl
             atRange:(NSString *)rangeString
         withSuccess:(ANSuccessWithResponseCompletionBlock)success
             failure:(ANFailureCompletionBlock)failure
{
    ANDownloadOperation *operation = [[ANDownloadOperation alloc] initWithUrl:fileUrl];
    operation.success = success;
    operation.failure = failure;
    
    __weak ANDownloadOperation *weakOperation = operation;
    
    operation.statisticBlock = ^{
        self.timeForDownload += weakOperation.timeForDownload;
        self.bytesDownloaded += weakOperation.bytesDownloaded;
        
        self.lastBytesDownloaded = weakOperation.bytesDownloaded;
        self.lastTimeForDownload = weakOperation.timeForDownload;
        [self.downloadingOperationsArray removeObject:weakOperation];
    };
    
    [_downloadingOperationsArray addObject:operation];
    
    NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:fileUrl
                                                              cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                          timeoutInterval:60];
    NSString *range = @"bytes=";
    range = [range stringByAppendingString:rangeString];
    [theRequest setValue:range forHTTPHeaderField:@"Range"];
    
    operation.urlRequest = theRequest;
    [operation lauchDownloading];
}

- (double)averageNetworkSpeed {
    double speed = 0.0;
    if (_bytesDownloaded && _timeForDownload){
        speed = _bytesDownloaded / _timeForDownload;
    }
    return speed;
}

- (double)lastNetworkSpeed {
    double speed = 0.0;
    if (_lastBytesDownloaded && _lastTimeForDownload){
        speed = _lastBytesDownloaded / _lastTimeForDownload;
    }
    return  speed;
}
- (void)cancelDownloading {
    for (ANDownloadOperation *op in self.downloadingOperationsArray) {
        [op cancelDownloading];
    }
}
@end
