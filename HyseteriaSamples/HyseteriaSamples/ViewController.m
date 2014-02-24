//
//  ViewController.m
//  HyseteriaSamples
//
//  Created by saiday on 13/1/16.
//  Copyright (c) 2013年 saiday. All rights reserved.
//

#import "ViewController.h"
#import "AFJSONRequestOperation.h"

@interface ViewController ()
{
    NSArray *localMedias;
    
    UIBarButtonItem *mRefresh;
    
    __block NSMutableArray *itunesPreviewUrls;
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
- (IBAction)playJackJohnsonFromItunes:(id)sender;
- (IBAction)playU2FromItunes:(id)sender;
@end

@implementation ViewController
@synthesize playButton, pauseButton, nextButton, previousButton, toolbar, firstButton, secondButton, refreshIndicator;


#pragma mark -
#pragma mark ===========   Hysteria Players  =========
#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initDefaults];
    localMedias = [NSArray arrayWithObjects:
                [[NSBundle mainBundle] pathForResource:@"pain_is_temporary" ofType:@"mp3"],
                [[NSBundle mainBundle] pathForResource:@"new_noise" ofType:@"mp3"],
                nil];
    
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    [hysteriaPlayer addDelegate:self];
    
    /*
     Register Handlers of HysteriaPlayer
     All Handlers are optional
     */
    [hysteriaPlayer registerHandlerReadyToPlay:^(HysteriaPlayerReadyToPlay identifier) {
        switch (identifier) {
            case HysteriaPlayerReadyToPlayPlayer:
                // It will be called when Player is ready to play at the first time.
                
                // If you have any UI changes related to Player, should update here.
                break;
            
            case HysteriaPlayerReadyToPlayCurrentItem:
                // It will be called when current PlayerItem is ready to play.
                
                // HysteriaPlayer will automatic play it, if you don't like this behavior,
                // You can pausePlayerForcibly:YES to stop it.
                break;
            default:
                break;
        }
    }];
    
    [hysteriaPlayer registerHandlerFailed:^(HysteriaPlayerFailed identifier, NSError *error) {
        switch (identifier) {
            case HysteriaPlayerFailedPlayer:
                break;
                
            case HysteriaPlayerFailedCurrentItem:
                // Current Item failed, advanced to next.
                [hysteriaPlayer playNext];
                break;
            default:
                break;
        }
        NSLog(@"%@", [error localizedDescription]);
    }];
}

- (void)hysteriaPlayerCurrentItemChanged:(AVPlayerItem *)item
{
    NSLog(@"current item changed");
}

- (void)hysteriaPlayerCurrentItemPreloaded:(CMTime)time
{
    NSLog(@"current item pre-loaded time: %f", CMTimeGetSeconds(time));
}

- (void)hysteriaPlayerDidReachEnd
{
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Player did reach end."
                                                   message:nil
                                                  delegate:self
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil, nil];
    [alert show];
}

- (void)hysteriaPlayerRateChanged:(BOOL)isPlaying
{
    [self syncPlayPauseButtons];
    NSLog(@"player rate changed");
}

- (IBAction)playStaticArray:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer removeAllItems];
    
    [hysteriaPlayer setupSourceGetter:^NSURL *(NSUInteger index) {
        return [[NSURL alloc] initFileURLWithPath:[localMedias objectAtIndex:index]];
    } ItemsCount:[localMedias count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
}


#pragma mark - Normal usage example, recommended.

- (IBAction)playU2FromItunes:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer removeAllItems];
    NSString *urlString = @"https://itunes.apple.com/lookup?amgArtistId=5723&entity=song&limit=5&sort=recent";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    itunesPreviewUrls = [NSMutableArray array];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON){
        NSArray *JSONArray = [JSON objectForKey:@"results"];
        for (NSDictionary *obj in JSONArray) {
            if ([obj objectForKey:@"previewUrl"] != nil) {
                [itunesPreviewUrls addObject:[obj objectForKey:@"previewUrl"]];
            }
        }
        
        [hysteriaPlayer setupSourceGetter:^NSURL *(NSUInteger index) {
            return [NSURL URLWithString:[itunesPreviewUrls objectAtIndex:index]];
        } ItemsCount:[itunesPreviewUrls count]];
        
        [hysteriaPlayer fetchAndPlayPlayerItem:0];
        [hysteriaPlayer setPlayerRepeatMode:HysteriaPlayerRepeatModeOn];
        
    }failure:nil];
    
    [operation start];
}

#pragma mark - Async source getter example, advanced usage.
/*
 You need to know counts of items that you playing.
 
 Useful when you have a list of songs but you don't have media links,
 this way could help you access the link (ex. with song.id) and setup your PlayerItem with your async connection.
 
 This example shows how to use asyncSetupSourceGetter:ItemsCount:, 
 but in this situation that we had media links already, highly recommend you use setupSourceGetter:ItemsCount: instead.
 */

- (IBAction)playJackJohnsonFromItunes:(id)sender
{
    NSUInteger limit = 5;
    
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer removeAllItems];
    NSString *urlString = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?amgArtistId=468749&entity=song&limit=%i&sort=recent", limit];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    itunesPreviewUrls = [NSMutableArray array];
    
    
    
    [hysteriaPlayer asyncSetupSourceGetter:^(NSUInteger index) {
        AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON){
            NSArray *JSONArray = [JSON objectForKey:@"results"];
            for (NSDictionary *obj in JSONArray) {
                if ([obj objectForKey:@"previewUrl"] != nil) {
                    [itunesPreviewUrls addObject:[obj objectForKey:@"previewUrl"]];
                }
            }

            // using async source getter, should call this method after you get the source.
            NSURL *url = [NSURL URLWithString:[itunesPreviewUrls objectAtIndex:index]];
            [hysteriaPlayer setupPlayerItemWithUrl:url Order:index];
        }failure:nil];
        
        [operation start];
    } ItemsCount:limit];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
    [hysteriaPlayer setPlayerRepeatMode:HysteriaPlayerShuffleModeOff];
}

- (IBAction)play_pause:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    if ([hysteriaPlayer isPlaying])
    {
        [hysteriaPlayer pausePlayerForcibly:YES];
        [hysteriaPlayer pause];
    }else{
        [hysteriaPlayer pausePlayerForcibly:NO];
        [hysteriaPlayer play];
    }
}

- (IBAction)playNext:(id)sender
{
    [[HysteriaPlayer sharedInstance] playNext];
}

- (IBAction)playPreviouse:(id)sender
{
    [[HysteriaPlayer sharedInstance] playPrevious];
}

#pragma mark -
#pragma mark ===========   Additions  =========
#pragma mark -

- (void)initDefaults
{
    mRefresh = [[UIBarButtonItem alloc] initWithCustomView:refreshIndicator];
    [mRefresh setWidth:30];
}

- (void)syncPlayPauseButtons
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolbar items]];
    switch ([hysteriaPlayer getHysteriaPlayerStatus]) {
        case HysteriaPlayerStatusUnknown:
            [toolbarItems replaceObjectAtIndex:3 withObject:mRefresh];
            break;
        case HysteriaPlayerStatusForcePause:
            [toolbarItems replaceObjectAtIndex:3 withObject:playButton];
            break;
        case HysteriaPlayerStatusBuffering:
            [toolbarItems replaceObjectAtIndex:3 withObject:playButton];
            break;
        case HysteriaPlayerStatusPlaying:
            [toolbarItems replaceObjectAtIndex:3 withObject:pauseButton];
        default:
            break;
    }
    toolbar.items = toolbarItems;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
