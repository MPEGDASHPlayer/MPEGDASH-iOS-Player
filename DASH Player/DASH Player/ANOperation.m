//
//  ANOperation.m
//  DASH Player
//
//  Created by DataArt Apps on 07.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANOperation.h"

@implementation ANOperation
#pragma mark - operation lifecycle related methods
- (BOOL)isExecuting {
//    NSLog(@"NSOperation %@: - Someone asks wether I am executing. I say %@", self, executing ? @"YES" : @"NO");
    return executing;
}

- (BOOL)isFinished {
//    NSLog(@"NSOperation %@: - Someone asks wether I am finised. I say %@", self, finished ? @"YES" : @"NO");
    return finished;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    executing = NO;
    finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}
@end
