//
//  SegmentBase.h
//  DASH Player
//
//  Created by DataArt Apps on 04.11.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Initialization.h"

@interface SegmentBase : NSObject
@property (nonatomic, strong) NSString *indexRange;
@property (nonatomic, strong) Initialization *initialization;
@end
