//
//  ANXsdDurationParser.m
//  DASH Player
//
//  Created by DataArt Apps on 29.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import "ANXsdDurationParser.h"
@interface ANXsdDurationParser ()
@property (nonatomic, strong) NSNumber * years;
@property (nonatomic, strong) NSNumber * months;
@property (nonatomic, strong) NSNumber * days;
@property (nonatomic, strong) NSNumber * hours;
@property (nonatomic, strong) NSNumber * minutes;
@property (nonatomic, strong) NSNumber * seconds;

@end

/*
 * Parser doesn't check input string to be valid. 
 * It assumes that string represents duration in correct format.
 */

@implementation ANXsdDurationParser

#pragma mark - public
- (void)parseDurationFromString:(NSString *)durationString {
    NSString *upperCaseString = [durationString uppercaseString];
    if ([upperCaseString characterAtIndex:0] != 'P'){
        return;
    }
    
    int i = 0;
    
    unichar ch = 0;
    ANXsdState prevState = 0;
    ANXsdState prevNotDigitState = 0;
    ANXsdState state = 0;
    
    NSMutableArray *digitsArray;
    
    while (i < upperCaseString.length) {
        ch = [upperCaseString characterAtIndex:i++];
        state = [self stateForChar:ch];
        
        switch (state) {
            case ANXsdStateBegin:{
                prevNotDigitState = ANXsdStateBegin;
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateYear:{
                prevNotDigitState = ANXsdStateYear;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.years = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateMonth:{
                prevNotDigitState = ANXsdStateMonth;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.months = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateDay:{
                prevNotDigitState = ANXsdStateDay;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.days = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateT:{
                prevNotDigitState = ANXsdStateT;
            }
                break;
            case ANXsdStateHours:{
                prevNotDigitState = ANXsdStateHours;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.hours = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateMinutes:{
                prevNotDigitState = ANXsdStateMinutes;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.minutes = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateSeconds:{
                prevNotDigitState = ANXsdStateSeconds;
                NSAssert(digitsArray.count, @"digitsArray cannot be empty.");
                self.seconds = [self numberFromArray:digitsArray];
                digitsArray = [NSMutableArray array];
            }
                break;
            case ANXsdStateDot:{
                [digitsArray addObject:@((short)ch)];
            }
                break;
            case ANXsdStateDigit:{
                [digitsArray addObject:@((short)ch)];
            }
                break;
                
            default:
                break;
        }
        prevState = state;
    }
}

- (NSTimeInterval)timeIntervalFromString:(NSString *)string {
    [self parseDurationFromString:string];
    NSTimeInterval duration = 0.0;
    duration += [self.hours   floatValue] * 3600.0f;
    duration += [self.minutes floatValue] * 60.0f;
    duration += [self.seconds floatValue];
    return duration;
}

#pragma mark - private
- (ANXsdState)stateForChar:(unichar)ch {
    static BOOL tOccured = NO;
    if( ch >= (unichar)'0' && ch <= (unichar)'9'){
        return ANXsdStateDigit;
    } else {
        ANXsdState s = 0;
        switch (ch) {
            case 'T':
                s = ANXsdStateT;
                tOccured = YES;
                break;
                
            case 'P':
                s = ANXsdStateBegin;
                break;
                
            case 'Y':
                s = ANXsdStateYear;
                break;
                
            case 'M':
                s = tOccured ? ANXsdStateMinutes : ANXsdStateMonth;
                break;
                
            case 'D':
                s = ANXsdStateDay;
                break;
                
            case 'H':
                s = ANXsdStateHours;
                break;
                
            case 'S':
                s = ANXsdStateSeconds;
                break;
                
            case '.':
                s = ANXsdStateDot;
                break;
                
            default:
                s = 0;
                break;
        }
        return s;
    }
    return 0;
}

- (NSNumber *)numberFromArray:(NSArray *)array {
    unichar *chars = calloc(array.count, sizeof(unichar));
    for (int i = 0; i < array.count; ++i){
        NSNumber *num = array[i];
        chars[i] = [num shortValue];
    }
    NSString *str = [NSString stringWithCharacters:chars length:array.count];
    free(chars);
    return @([str floatValue]);
}

@end
