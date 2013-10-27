//
//  ViewController.m
//  HyseteriaSamples
//
//  Created by saiday on 13/1/16.
//  Copyright (c) 2013年 saiday. All rights reserved.
//

#import "ViewController.h"
#import "HysteriaPlayer.h"
#import "AFJSONRequestOperation.h"

@interface ViewController ()
{
    HysteriaPlayer *hysteriaPlayer;
    
    NSArray *mp3Array;
    
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
    mp3Array = [NSArray arrayWithObjects:
                @"http://dl.dropbox.com/u/49227701/pain%20is%20temporary.mp3",
                @"http://www.musiclikedirt.com/wp-content/MP3/feb/01%20New%20Noise%201.mp3", nil];
    
    hysteriaPlayer = [[HysteriaPlayer sharedInstance]
                      initWithHandlerPlayerReadyToPlay:^{
                          if (![hysteriaPlayer isPlaying]) {
                              // It will be called when Player is ready to play the PlayerItem, so play it.
                              // If you have play/pause buttons, should update their status after you starting play.
                              
                              [self syncPlayPauseButtons];
                          }
                      }
                      PlayerRateChanged:^{
                          // It will be called when player's rate changed, probely 1.0 to 0.0 or 0.0 to 1.0.
                          // Anyways you should update your interface to notice the user what's happening. HysteriaPlayer have HysteriaPlayerStatus state helping you find out the informations.
                          
                          [self syncPlayPauseButtons];
                      }
                      CurrentItemChanged:^(AVPlayerItem *newItem) {
                          // It will be called when player's currentItem changed.
                          // If you have UI elements related to Playing item, should update them when called.(i.e. title, artist, artwork ..)
                          [self syncPlayPauseButtons];
                      }
                      ItemReadyToPlay:^{
                          // It will be called when current PlayerItem is ready to play.
                      }
                      PlayerPreLoaded:^(CMTime bufferedTime) {
                          // It will be called when receive new buffer data.
                          NSLog(@"item buffered time: %f",CMTimeGetSeconds(bufferedTime));
                      }
                      PlayerFailed:nil
                      PlayerDidReachEnd:^{
                          // It will be called when player stops, reaching the end of playing queue and repeat is disabled.
                          
                          UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Player did reach end." message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                          [alert show];
                      }];
}

- (IBAction)playStaticArray:(id)sender
{
    [hysteriaPlayer removeAllItems];
    [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
        return [mp3Array objectAtIndex:index];
        
    } ItemsCount:[mp3Array count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
//    [hysteriaPlayer setPLAYMODE_Repeat:YES];
}

- (IBAction)playJackJohnsonFromItunes:(id)sender
{
    [hysteriaPlayer removeAllItems];
    NSString *urlString = @"https://itunes.apple.com/lookup?amgArtistId=468749&entity=song&limit=5&sort=recent";
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
        
        [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
            return [itunesPreviewUrls objectAtIndex:index];
        } ItemsCount:[itunesPreviewUrls count]];
        
        [hysteriaPlayer fetchAndPlayPlayerItem:0];
        [hysteriaPlayer setPlayerRepeatMode:RepeatMode_off];
        
    }failure:nil];
    
    [operation start];
}

- (IBAction)playU2FromItunes:(id)sender
{
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
        
        [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
            return [itunesPreviewUrls objectAtIndex:index];
        } ItemsCount:[itunesPreviewUrls count]];
        
        [hysteriaPlayer fetchAndPlayPlayerItem:0];
        [hysteriaPlayer setPlayerRepeatMode:RepeatMode_on];
        
    }failure:nil];
    
    [operation start];
}

- (IBAction)play_pause:(id)sender
{
    if ([hysteriaPlayer isPlaying])
    {
        [hysteriaPlayer setPAUSE_REASON_ForcePause:YES];
        [hysteriaPlayer pause];
    }else{
        [hysteriaPlayer setPAUSE_REASON_ForcePause:NO];
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
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolbar items]];
    switch ([hysteriaPlayer pauseReason]) {
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
