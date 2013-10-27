Hysteria Player
=========

HysteriaPlayer provides useful basic player functionalities.

It provides:

- PlayerItem cache management.
- Pre-buffer next PlayerItem. 

Features:

- You don't need to write KVO again, setting up few blocks then you can handle player status.
- Ability to play previous PlayerItem.
- If player suspended bacause of high network latency in bad network, auto-resume the playback of your PlayerItem when buffered ready. 
- Background playable enabled. (need to register your App supports background modes as "App plays audio")
- Using getHysteriaOrder: to get the index of your PlayerItems.
- Extends long time buffering in background.
- Returns playing item's current and duration timescale.
- PlayModes: Repeat, RepeatOne, Shuffle.

Installation
---------------

### CocoaPods ###

If you using [CocoaPods](http://cocoapods.org/), it's easy to install HysteriaPlayer.

Podfile:

```
platform :ios, 'x.0'

pod 'HysteriaPlayer',			        '~> x.x.x'
    
end
```

---------------

### Manually import library to your project ###

#### Add Frameworks ####

Add CoreMedia.framework, AudioToolbox.framework and AVFoundation.framework to your Link Binary With Libraries.

### Copy provided point1sec.mp3 file to your Supporting Files ###

Ability to play the __first__ PlayerItem when your application is resigned active but __first__ PlayerItem is still buffering. 

### Register your app's background modes ###
Click your project and select your target app, going to the info tab find __Required background modes__ , if not exist create new one. In __Required background modes's item 0__ copy this string `App plays audio` into it.

![](http://imnotyourson.com/images/HysteriaPlayer/SC_RegisterBG.png)

How to use - Setup
---------------


```objective-c
#import "HysteriaPlayer.h"

...

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    hysteriaPlayer = [hysteriaPlayer initWithHandlerPlayerReadyToPlay:^{
                      }
                      PlayerRateChanged:^{
                          [self syncPlayPauseButtons];
                      }
                      CurrentItemChanged:^(AVPlayerItem *newItem) {
                          [self syncPlayPauseButtons];
                      }
                      ItemReadyToPlay:^{
                      }
                      PlayerPreLoaded:^(CMTime bufferedTime) {
                          NSLog(@"item buffered time: %f",CMTimeGetSeconds(bufferedTime));
                      }
                      PlayerFailed:nil
                      PlayerDidReachEnd:^{
                          UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Player did reach end."
                                                                         message:nil
                                                                        delegate:self
                                                               cancelButtonTitle:@"OK"
                                                               otherButtonTitles:nil, nil];
                          [alert show];
                      }];
}

- (IBAction)playStaticArray:(id)sender
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer removeAllItems];
    [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
        return [mp3Array objectAtIndex:index];
        
    } ItemsCount:[mp3Array count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
}
```

### Using initWithHandlers: ###

With callback blocks, handling the Player when status changed.
All blocks are optional, set `nil` if you won't do anything on that callback block.

- __PlayerReadyToPlay__ :
It will be called when Player is ready to play the PlayerItem, so play it. If you have play/pause buttons, should update their status after you starting play.

- __PlayerRateChanged__ :
It will be called when player's rate changed, probely 1.0 to 0.0 or 0.0 to 1.0. Anyways you should update your interface to notice the user what's happening. HysteriaPlayer have __HysteriaPlayerStatus__ state helping you find out the informations. 
	- HysteriaPlayerStatusPlaying : Player is playing
	- HysteriaPlayerStatusForcePause : Player paused when Player's property `PAUSE_REASON_ForcePause = YES`.
	- HysteriaPlayerStatusBuffering : Player suspended because of no buffered.
    - HysteriaPlayerStatusUnknown : Player status unknown.
- __CurrentItem Changed__ :
It will be called when player's currentItem changed. If you have UI elements related to Playing item, should update them when called.(i.e. title, artist, artwork ..)

- __ItemReadyToPlay__ :
It will be called when current __PlayerItem__ is ready to play.

- __PlayerPreLoaded__ :
It will be called when receive new buffer data.

- __PlayerFailed__ :
It will be called when player just failed.

- __PlayerDidReachEnd__ :
It will be called when player stops, reaching the end of playing queue and repeat is disabled.

 
### Using setupWithGetterBlock: ###

Before you starting play anything, set your datasource to Hysteria Player. This block will gives you the index that will be using (instantly play or pre-buffer). Returning a NSString format url is all you need to do.

__ItemsCount__ tells HysteriaPlayer the count of your datasource, you have to update it using `setItemsCount:(NSUInteger)count` if your datasource's count is changed.

```objective-c
[hysteriaPlayer removeAllItems];
[hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
    return [mp3Array objectAtIndex:index];
} ItemsCount:[mp3Array count]];
```

Snippets
---------------
### Get item's index of my working items: ###
```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
NSNumber *order = [hysteriaPlayer getHysteriaOrder:[hysteriaPlayer getCurrentItem]];
```

### Get playing item's timescale ###

```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
NSDictionary *dict = [hysteriaPlayer getPlayerTime];
double durationTime = [[dict objectForKey:@"DurationTime"] doubleValue];
double currentTime = [[dict objectForKey:@"CurrentTime"] doubleValue];
```

### How to pause my playback forcibly? ###
`pausePlayerForcibly:(BOOL)` method telling HysteriaPlayer to/not to force pause the playback(mostly when user tapped play/pause button)
```objective-c
- (IBAction)play_pauseButton:(id)sender
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
```

### Get Player status ###
```objective-c
switch ([hysteriaPlayer getHysteriaPlayerStatus]) {
    case HysteriaPlayerStatusUnknown:
        
        break;
    case HysteriaPlayerStatusForcePause:
        
        break;
    case HysteriaPlayerStatusBuffering:
        
        break;
    case HysteriaPlayerStatusPlaying:
        
    default:
        break;
}
```

### Disable played item caching ###
Default is cache enabled
```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
[hysteriaPlayer enableMemoryCached:NO];
```

### What if I don't need player instance anymore? ###
```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
[hysteriaPlayer deprecatePlayer];
hysteriaPlayer = nil;
```

## Licenses ##

All source code is licensed under the MIT License.

## Author ##

Created by Saiday
 
* [GitHub](https://github.com/saiday/)
* [Twitter](https://twitter.com/saiday)
* Skype: imnotyourson


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/StreetVoice/hysteriaplayer/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

