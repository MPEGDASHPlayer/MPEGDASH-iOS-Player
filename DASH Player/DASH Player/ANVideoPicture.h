//
//  ANVideoPicture.h
//  DASH Player
//
//  Created by DataArt Apps on 24.07.14.
//  Copyright (c) 2014 DataArt Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ANVideoPicture : NSObject {
//    SDL_Surface* screen;
//	SDL_Overlay* bmp;
	double pts;
	int ready;
    NSCondition *cond;
    NSLock *mutexLock;
    
//	SDL_mutex* mutex;
//	SDL_cond* cond;
}
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) int ready;
//@property (nonatomic, strong) NSCondition *cond;
//@property (nonatomic, strong) NSLock *mutexLock;
@property (nonatomic, strong) UIImage *image;

@end
