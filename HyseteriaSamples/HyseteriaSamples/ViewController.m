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
    NSArray *mp3Array;
    
    UIBarButtonItem *mRefresh;
}
@property (nonatomic, weak) IBOutlet UIBarButtonItem *playButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *pauseButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *previousButton;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;
@property (nonatomic, weak) IBOutlet UIButton *firstButton;
@property (nonatomic, weak) IBOutlet UIButton *secondButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *refreshIndicator;

- (IBAction)play_pause:(id)sender;
- (IBAction)playNext:(id)sender;
- (IBAction)playPreviouse:(id)sender;
- (IBAction)playStaticArray:(id)sender;
- (IBAction)playSelected:(id)sender;

@end

@implementation ViewController
@synthesize playButton, pauseButton, nextButton, previousButton, toolbar, firstButton, secondButton, refreshIndicator;

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initView];
     mp3Array = [NSArray arrayWithObjects:
                         @"http://dc394.4shared.com/img/243065174/bec1a18a/dlink__2Fdownload_2FGlObVQyO_3Fdsid_3D48kq5a.654a9e37903de1dcc657fe31569bf5d7/preview.mp3",
                         @"http://www.musiclikedirt.com/wp-content/MP3/feb/01%20New%20Noise%201.mp3", nil];
    
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
    

}

- (void)initView
{
    mRefresh = [[UIBarButtonItem alloc] initWithCustomView:refreshIndicator];
    [mRefresh setWidth:30];

}

- (void)syncPlayPauseButtons
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolbar items]];

    switch ([hysteriaPlayer pauseReason]) {
        case HysteriaPauseReasonUnknown:
            [toolbarItems replaceObjectAtIndex:3 withObject:mRefresh];
            break;
        case HysteriaPauseReasonManul:
            [toolbarItems replaceObjectAtIndex:3 withObject:playButton];
            break;
        case HysteriaPauseReasonPlaying:
            [toolbarItems replaceObjectAtIndex:3 withObject:pauseButton];
        default:
            break;
    }
    toolbar.items = toolbarItems;
}

- (IBAction)playStaticArray:(id)sender
{
    [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
        return [mp3Array objectAtIndex:index];
        
    } ItemsCount:[mp3Array count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
    [hysteriaPlayer setPLAYMODE_isRepeat:YES];
}

- (IBAction)playSelected:(id)sender
{
    
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
