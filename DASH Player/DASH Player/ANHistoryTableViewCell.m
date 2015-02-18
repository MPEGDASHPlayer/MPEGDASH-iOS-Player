//
//  ANHistoryTableViewCell.m
//  DASH Player
//
//  Created by DataArt Apps on 20.10.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANHistoryTableViewCell.h"

@implementation ANHistoryTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.urlLabel.textColor = [UIColor colorWithRed:0
                                              green:102.0/255.0
                                               blue:204.0/255.0
                                              alpha:1.0];
    
    self.backgroundColor = [UIColor colorWithRed:239.0/255.0
                                           green:239.0/255.0
                                            blue:244.0/255.0
                                           alpha:1.0];
}

- (NSString *)reuseIdentifier {
    return [[self class] reuseIdentifier];
}

+ (NSString *)reuseIdentifier {
    return NSStringFromClass([self class]);
}

@end
