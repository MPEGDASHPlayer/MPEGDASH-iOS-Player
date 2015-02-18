//
//  ANDownloadOperation.m
//  DASH Player
//
//  Created by DataArt Apps on 07.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANDownloadOperation.h"
@interface ANDownloadOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *urlConnection;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableData *receivedData;

@property (nonatomic, strong) NSLock *cancelLock;

@property (nonatomic, assign) NSTimeInterval startTime;

@property (nonatomic, assign) BOOL shoulCancelDownloading;

@end

@implementation ANDownloadOperation
@synthesize shoulCancelDownloading = _shoulCancelDownloading;
+ (void) __attribute__((noreturn)) networkRequestThreadEntryPoint:(id)__unused object {
    do {
        @autoreleasepool {
            [[NSThread currentThread] setName:@"ANDownloadOperationThread"];
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(networkRequestThreadEntryPoint:)
                                                          object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}

-(id)initWithUrl:(NSURL *)url {
    self = [super init];
    if(self){
        self.url = url;
        self.cancelLock = [[NSLock alloc] init];
    }
    return self;
}

#pragma mark - download
- (void)startDownload {
    _shoulCancelDownloading = NO;
    NSAssert(self.urlRequest, @"URL request should be set befor downloading");
    
    self.receivedData = [NSMutableData data];
  

    self.urlConnection = [[NSURLConnection alloc] initWithRequest:self.urlRequest
                                                         delegate:self];
    
    if (self.urlConnection){
        self.startTime = [NSDate timeIntervalSinceReferenceDate];
        [self.urlConnection start];
    } else {
        if (self.failure) {
            NSError *error = [NSError errorWithDomain:@"Download Operation Error" code:0 userInfo:nil];
            self.failure(error);
        }
    }
}

- (void)lauchDownloading {
    [self performSelector:@selector(startDownload)
                 onThread:[[self class] networkRequestThread]
               withObject:nil
            waitUntilDone:NO
                    modes:@[NSDefaultRunLoopMode]];
    
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (_shoulCancelDownloading){
        return;
    }
//    NSLog(@"RESPONSE = %@", response);
    // receivedData is an instance variable declared elsewhere.
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (_shoulCancelDownloading){
        return;
    }
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    if (_shoulCancelDownloading){
        return;
    }
    self.urlConnection = nil;
    self.receivedData = nil;
    
    // inform the user
    DLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    if (self.failure){
        self.failure(error);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_shoulCancelDownloading){
        return;
    }
    self.timeForDownload = [NSDate timeIntervalSinceReferenceDate] - self.startTime;
    self.bytesDownloaded = [self.receivedData length];
    
    if (self.success){
        self.success(self.receivedData);
    }
    if (self.statisticBlock){
        self.statisticBlock();
    }
    self.urlConnection = nil;
    self.receivedData = nil;
}

- (void)cancelDownloading {
    [self.urlConnection cancel];
    self.shoulCancelDownloading = YES;
}
- (void)setShoulCancelDownloading:(BOOL)shoulCancelDownloading {
    [_cancelLock lock];
    _shoulCancelDownloading = shoulCancelDownloading;
    [_cancelLock unlock];
}
- (BOOL)shoulCancelDownloading {
    [_cancelLock lock];
    BOOL ret = _shoulCancelDownloading;
    [_cancelLock unlock];
    
    return ret;
}
@end
