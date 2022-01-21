//
//  ViewController.h
//  HyseteriaSamples
//
//  Created by saiday on 13/1/16.
//  Copyright (c) 2013年 saiday. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, PlayingType) {
    PlayingTypeStaticItems,
    PlayingTypeSync,
    PlayingTypeAsync,
};

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;

@end
