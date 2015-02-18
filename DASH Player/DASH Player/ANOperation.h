//
//  ANOperation.h
//  DASH Player
//
//  Created by DataArt Apps on 07.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ANOperation : NSOperation {
    BOOL finished;
    BOOL executing;
}

- (void)completeOperation;

@end
