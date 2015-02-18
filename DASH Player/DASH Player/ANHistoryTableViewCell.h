//
//  ANHistoryTableViewCell.h
//  DASH Player
//
//  Created by DataArt Apps on 20.10.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ANHistoryTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *urlLabel;
- (NSString *)reuseIdentifier;
+ (NSString *)reuseIdentifier;

@end
