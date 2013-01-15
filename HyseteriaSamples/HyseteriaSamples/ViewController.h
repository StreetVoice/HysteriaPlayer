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

@interface ViewController : UIViewController <AVAudioSessionDelegate>
{
    HysteriaPlayer *hysteriaPlayer;
}
@end
