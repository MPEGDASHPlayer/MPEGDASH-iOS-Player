//
//  ANHistoryViewController.m
//  DASH Player
//
//  Created by DataArt Apps on 20.10.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANHistoryViewController.h"
#import "ANHistoryTableViewCell.h"

@interface ANHistoryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *histroyTableView;
@property (nonatomic, strong) NSMutableArray *dataSourceArray;
@end

@implementation ANHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.histroyTableView registerNib:[UINib nibWithNibName:@"ANHistoryTableViewCell"
                                               bundle:[NSBundle mainBundle]]
        forCellReuseIdentifier:[ANHistoryTableViewCell reuseIdentifier]];
    
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:ANUserDefaultsHistoryKey];
    self.dataSourceArray = [NSMutableArray arrayWithArray:arr];
    [self.histroyTableView reloadData];
}

- (IBAction)cancelButtonAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(historyViewControllerDidCancel:)]){
        [self.delegate historyViewControllerDidCancel:self];
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // TODO: change this
    return [self.dataSourceArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = indexPath.row;
    ANHistoryTableViewCell *theCell = [self.histroyTableView dequeueReusableCellWithIdentifier:[ANHistoryTableViewCell reuseIdentifier]];
    theCell.urlLabel.text = self.dataSourceArray[index];
    return theCell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.delegate respondsToSelector:@selector(historyViewController:didSelectUrlString:)]){
        NSString *str = self.dataSourceArray[indexPath.row];
        [self.delegate historyViewController:self didSelectUrlString:str];
    }
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.dataSourceArray removeObjectAtIndex:indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:self.dataSourceArray forKey:ANUserDefaultsHistoryKey];
        
        if (![[NSUserDefaults standardUserDefaults] synchronize]){
            NSLog(@"Data wasn't saved");
        }
        [tableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:YES];
    }
}

@end
