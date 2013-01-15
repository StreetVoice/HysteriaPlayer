//
//  ViewController.m
//  HyseteriaSamples
//
//  Created by saiday on 13/1/16.
//  Copyright (c) 2013年 saiday. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    
}
@property (nonatomic, weak) IBOutlet UIButton *playPauseButton;
@property (nonatomic, weak) IBOutlet UIButton *nextButton;
@property (nonatomic, weak) IBOutlet UIButton *previousButton;

- (IBAction)play_pause:(id)sender;
- (IBAction)playNext:(id)sender;
- (IBAction)playPreviouse:(id)sender;

@end

@implementation ViewController
@synthesize playPauseButton,nextButton,previousButton;

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSArray *mp3Array = [NSArray arrayWithObjects:@"http://dc394.4shared.com/img/243065174/bec1a18a/dlink__2Fdownload_2FGlObVQyO_3Fdsid_3D48kq5a.654a9e37903de1dcc657fe31569bf5d7/preview.mp3", @"http://www.musiclikedirt.com/wp-content/MP3/feb/01%20New%20Noise%201.mp3", nil];
	hysteriaPlayer = [[HysteriaPlayer alloc]
                      initWithHandlerPlayerReadyToPlay:^{
                          if (![hysteriaPlayer isPlaying]) {
                              [hysteriaPlayer play];
                              [self syncPlayPauseButtons];
                          }
                      }
                      PlayerRateChanged:^{
                          [self syncPlayPauseButtons];
                      }
                      CurrentItemChanged:^(AVPlayerItem * newItem) {
                          if (newItem != (id)[NSNull null]) {
                              [self syncPlayPauseButtons];
                              NSLog(@"current order is %@",[hysteriaPlayer getHysteriaOrder:newItem]);
                          }
                      }
                      ItemReadyToPlay:^{
                          if ([hysteriaPlayer pauseReason] == HysteriaPauseReasonUnknown) {
                              [hysteriaPlayer play];
                          }
                      }];
    
    [hysteriaPlayer setupWithGetterBlock:^AVPlayerItem *(NSUInteger index) {
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:[mp3Array objectAtIndex:index]]];
        return playerItem;
        NSLog(@"wtf");
        
    } ItemsCount:[mp3Array count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
    [hysteriaPlayer setPLAYMODE_isRepeat:YES];
}

- (void)syncPlayPauseButtons
{
    switch ([hysteriaPlayer pauseReason]) {
        case HysteriaPauseReasonUnknown:
            [playPauseButton setTitle:@"fetching" forState:UIControlStateNormal];
            break;
        case HysteriaPauseReasonManul:
            [playPauseButton setTitle:@"pause" forState:UIControlStateNormal];
            break;
        case HysteriaPauseReasonPlaying:
            [playPauseButton setTitle:@"playing" forState:UIControlStateNormal];
        default:
            break;
    }
    
}

- (IBAction)play_pause:(id)sender
{
    if ([hysteriaPlayer isPlaying])
    {
        [hysteriaPlayer setPAUSE_REASON_manul:YES];
        [hysteriaPlayer pause];
    }else{
        [hysteriaPlayer setPAUSE_REASON_manul:NO];
        [hysteriaPlayer play];
    }
}

- (IBAction)playNext:(id)sender
{
    [hysteriaPlayer playNext];
}

- (IBAction)playPreviouse:(id)sender
{
    [hysteriaPlayer playPrevious];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
