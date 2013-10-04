Hysteria Player
=========

This class provides useful basic player functionality.

Features:

- You don't need to write KVO again, setting up few blocks then you can handle player status.
- Ability to play previous PlayerItem.
- If player paused bacause buffering problems, auto-resume the playback of your PlayerItem when enough buffered. 
- Background playable enabled. (need to register your App supports background modes as "App plays audio")
- Using getHysteriaOrder: to get the index of your PlayerItems.
- Long buffer/load time for PlayerItems in background.
- Returns playing item's current and duration timescale.
- PlayModes: Repeat, RepeatOne, Shuffle.

It provides:

- PlayerItem cache management.
- Pre-buffer next PlayerItem. 

Installation
---------------

### CocoaPods ###

If you using [CocoaPods](http://cocoapods.org/), it's easy to install HysteriaPlayer.

Podfile:
```
platform :ios, '6.0'

pod 'HysteriaPlayer',			        '~> 1.0.0'
    
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

    hysteriaPlayer = [[HysteriaPlayer sharedInstance]
                      initWithHandlerPlayerReadyToPlay:^{
                          if (![hysteriaPlayer isPlaying]) {
                              //Tells user your player is starting, update views or something here.
                              //[self syncPlayPauseButtons];
                          }
                      }
                      PlayerRateChanged:^{
                          //[self syncPlayPauseButtons];
                      }
                      CurrentItemChanged:^(AVPlayerItem *newItem) {
                          if (newItem != (id)[NSNull null]) {
                              //Adjustment your PlayerItem here
                          }
                          [self syncPlayPauseButtons];
                      }
                      ItemReadyToPlay:^{
                          if ([hysteriaPlayer pauseReason] == HysteriaPauseReasonUnknown) {
                              [hysteriaPlayer play];
                          }
                      }
                      PlayerFailed:^{}
                      PlayerDidReachEnd:^{
                      	  //When your player's PLAYMODE_Repeat property isn't @YES, this block get called at Player's endpoint.
                      }];
}

- (IBAction)playStaticArray:(id)sender
{
    [hysteriaPlayer removeAllItems];
    [hysteriaPlayer setupWithGetterBlock:^NSString *(NSUInteger index) {
        return [mp3Array objectAtIndex:index];
        
    } ItemsCount:[mp3Array count]];
    
    [hysteriaPlayer fetchAndPlayPlayerItem:0];
    [hysteriaPlayer setPlayerRepeatMode:RepeatMode_on];
}
```

### Using initWithHandlers: ###

With these four blocks, you can handle about the Player's status changed, including __status changed__, __rate changed__, __currentItem changed__.

- __Status Changed__ :
It will be called when Player is ready to play the PlayerItem, so play it. If you have play/pause buttons, should update their status after you starting play.

- __CurrentItem Changed__ :
It will be called when player's currentItem changed. If you have artworks, playeritem's infos or play/pause buttons to display, you should update them when this be called.

- __ItemReadyToPlay__ :
It will be called when __PlayerItem__ is ready to play, this is optional.

- __Rate Changed__ :
It will be called when player's rate changed, probely 1.0 to 0.0 or 0.0 to 1.0. Anyways you should update your interface to notice the user what's happening. Hysteria Player have __HysteriaPauseReason__ to help you. 
	- HysteriaPauseReasonPlaying : Player is playing
	- HysteriaPauseReasonForce : Player paused when Player's property `PAUSE_REASON_ForcePause = YES`.
    - HysteriaPauseReasonUnknown : Player paused for unknown reason, usually it because Player is paused for buffering.
 
### Using setupWithGetterBlock: ###

Before you starting play anything, set your datasource to Hysteria Player. This block will gives you a index that will be used (instantly play or pre-buffer). Returning a NSString format url is all you need to do.

__ItemsCount__ tells Hysteria Player the count of your datasource, you have to update it using `setItemsCount:(NSUInteger)count` if your datasource's count is modified.


### Getting playing item's timescale ###

```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];

NSDictionary *dict = [hysteriaPlayer getPlayerTime];
double durationTime = [[dict objectForKey:@"DurationTime"] doubleValue];
double currentTime = [[dict objectForKey:@"CurrentTime"] doubleValue];
```

FAQ
---------------
### Get item's index of my working items: ###
```objective-c
HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
NSNumber *order = [hysteriaPlayer getHysteriaOrder:[hysteriaPlayer getCurrentItem]];
```


## Licenses ##

All source code is licensed under the MIT License.

## Author ##

Created by Saiday
 
* [GitHub](https://github.com/saiday/)
* [Twitter](https://twitter.com/saiday)
* Skype: imnotyourson
