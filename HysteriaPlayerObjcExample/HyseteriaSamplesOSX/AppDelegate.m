//
//  AppDelegate.m
//  HyseteriaSamplesOSX
//
//  Created by Manik Kalra on 10/22/15.
//  Copyright © 2015 saiday. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *playPauseWebURLButton;

@property (nonatomic) NSMutableArray *media;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    self.media = [[NSMutableArray alloc] init];
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    hysteriaPlayer.delegate = self;
    hysteriaPlayer.datasource = self;
}

- (IBAction)playPauseFromWebURL:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer removeAllItems];
    NSString *urlString = @"https://archive.org/download/gd83-08-27.aud.hinko.16439.sbeok.shnf/gd1983-08-27d1t01_vbr.mp3";
    NSString *urlString2 = @"https://ia902606.us.archive.org/27/items/bk2011-02-27/bk_2011-02-27t10.mp3";
    NSString *urlString3 = @"https://archive.org/download/bkweller2002-06-08/bkweller2002-06-08t06.mp3";
    [self.media removeAllObjects];
    [self.media addObjectsFromArray:@[urlString, urlString2, urlString3]];
    [hysteriaPlayer fetchAndPlayPlayerItem:0];

}

- (IBAction)playPause:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    if ([hysteriaPlayer isPlaying])
    {
        [hysteriaPlayer pausePlayerForcibly:YES];
        [hysteriaPlayer pause];
    }
    else
    {
        [hysteriaPlayer pausePlayerForcibly:NO];
        [hysteriaPlayer play];
    }
}

- (IBAction)playNextTrack:(id)sender
{
    [[HysteriaPlayer sharedInstance] playNext];
}

- (IBAction)playPreviousTrack:(id)sender
{
    [[HysteriaPlayer sharedInstance] playPrevious];
}

#pragma mark - HysteriaPlayerDataSource

- (NSInteger)hysteriaPlayerNumberOfItems
{
    return [self.media count];
}

// Adopt one of
// hysteriaPlayerURLForItemAtIndex:(NSInteger)index
// or
// hysteriaPlayerAsyncSetUrlForItemAtIndex:(NSInteger)index
// which meets your requirements.

- (NSURL *)hysteriaPlayerURLForItemAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer
{
    NSURL *url = [NSURL URLWithString:[self.media objectAtIndex:index]];
    
    return url;
}


#pragma mark - HysteriaPlayerDelegate

- (void)hysteriaPlayerDidFailed:(HysteriaPlayerFailed)identifier error:(NSError *)error
{
    switch (identifier) {
        case HysteriaPlayerFailedPlayer:
            break;
            
        case HysteriaPlayerFailedCurrentItem:
            // Current Item failed, advanced to next.
            [[HysteriaPlayer sharedInstance] playNext];
            break;
        default:
            break;
    }
    NSLog(@"%@", [error localizedDescription]);
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
    NSLog(@"End reached!");
}

- (void)hysteriaPlayerRateChanged:(BOOL)isPlaying
{
    NSLog(@"player rate changed");
}

- (void)hysteriaPlayerWillChangedAtIndex:(NSInteger)index
{
    NSLog(@"index: %li is about to play", index);
}


@end
