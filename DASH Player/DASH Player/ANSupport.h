//
//  ANSupport.h
//  DASH Player
//
//  Created by DataArt Apps on 06.08.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^ANSuccessWithResponseCompletionBlock)(id response);
typedef void (^ANCompletionBlockWithData)(BOOL success, NSError* error, id data);
typedef void (^ANCompletionBlock)(BOOL success, NSError* error);
typedef void (^ANFailureCompletionBlock)(NSError *error);

typedef unsigned long long int ANTimeInterval;

void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout);

GLuint compileShader(GLenum type, NSString *shaderString);
BOOL validateProgram(GLuint prog);

static double const ANTimerIntervalLagreValue = 1024.0;

static NSString * const ANUserDefaultsHistoryKey = @"ANUsegDefaultsHistoryKey";


@interface ANSupport : NSObject

+ (void)showInfoAlertWithMessage:(NSString *)message;

@end
