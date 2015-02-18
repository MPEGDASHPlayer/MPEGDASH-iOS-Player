//
//  AudioChannelConfiguration.h
//  DASH Player
//
//  Created by DataArt Apps on 28.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioChannelConfiguration : NSObject
@property (nonatomic, strong) NSString *schemeIdUri;
@property (nonatomic, assign) NSUInteger value;

- (void)setValueFromString:(NSString *)valueString;

@end
