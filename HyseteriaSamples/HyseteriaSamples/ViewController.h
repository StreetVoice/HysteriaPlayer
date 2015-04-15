//
//  ViewController.h
//  HyseteriaSamples
//
//  Created by saiday on 13/1/16.
//  Copyright (c) 2013年 saiday. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "HysteriaPlayer.h"

typedef NS_ENUM(NSUInteger, PlayingType) {
    PlayingTypeStaticItems,
    PlayingTypeSync,
    PlayingTypeAsync,
};

@interface ViewController : UIViewController <AVAudioSessionDelegate, HysteriaPlayerDelegate, HysteriaPlayerDataSource>

@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;

@end
