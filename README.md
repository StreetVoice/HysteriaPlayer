![](https://raw.github.com/StreetVoice/HysteriaPlayer/master/docs/Hysteria.jpg)
Hysteria Player
=========

HysteriaPlayer provides useful basic player functionalities.

It provides:

- PlayerItem cache management.
- Pre-buffer next PlayerItem. 

Features:

- Supporting both local and remote media.
- Setting up HysteriaPlayer with few blocks, implementing delegation in your `UIView` and `UIViewController` subclasses to update UI when player event changed.
- Ability to advance next/previous item.
- If player suspended bacause of buffering issue, auto-resume the playback when buffered size reached 5 secs. 
- Background playable. (check the background audio mode then everything works)
- Using getHysteriaOrder: to get the index of your PlayerItems.
- Extends long time buffering in background.
- Player modes support: Repeat, RepeatOne, Shuffle.

Tutorials
---------------
In [part 0](http://imnotyourson.com/streaming-remote-audio-on-ios-with-hysteriaplayer-tutorial-0/), what we want? why HysteriaPlayer?

In [part 1](http://imnotyourson.com/streaming-remote-audio-on-ios-with-hysteriaplayer-tutorial-1/), demonstrating how to play remote audios with HysteriaPlayer.

In [part 2](http://imnotyourson.com/streaming-remote-audio-on-ios-with-hysteriaplayer-tutorial-2/), making a simple player user interface. 

In [part 3](http://imnotyourson.com/streaming-remote-audio-on-ios-with-hysteriaplayer-tutorial-3/), registering lock screen details and remote controls. 


You can download tutorial source code [here](https://github.com/saiday/HysteriaPlayerTutorial)

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

### Manually install ###
#### Import library to your project ####

Drag `HysteriaPlayer.m`, `HysteriaPlayer.h` to your project.

#### Add Frameworks ####

Add CoreMedia.framework, AudioToolbox.framework and AVFoundation.framework to your Link Binary With Libraries.

#### Copy provided point1sec.mp3 file to your Supporting Files ####

Ability to play the __first__ PlayerItem when your application is resigned active but __first__ PlayerItem is still buffering. 

Register your app's background modes
----------

Click your project and select your target app, going to the info tab find __Required background modes__ , if not exist create new one. In __Required background modes's item 0__ copy this string `App plays audio` into it.

![](https://raw.github.com/StreetVoice/HysteriaPlayer/master/docs/SC_RegisterBG.png)

How to use - Setup
---------------
    
Register Handlers of HysteriaPlayer, all Handlers are optional.
 

```objective-c
#import "HysteriaPlayer.h"

...

- (void)setupHyseteriaPlayer
{
    HysteriaPlayer *hysteriaPlayer = [HysteriaPlayer sharedInstance];
    
    [hysteriaPlayer registerHandlerPlayerRateChanged:^{
        
    } CurrentItemChanged:^(AVPlayerItem *item) {
        
    } PlayerDidReachEnd:^{
        
    }];
    
    [hysteriaPlayer registerHandlerCurrentItemPreLoaded:^(CMTime time) {
        NSLog(@"%f", CMTimeGetSeconds(time));
    }];
    
    [hysteriaPlayer registerHandlerReadyToPlay:^(HysteriaPlayerReadyToPlay identifier) {
        switch (identifier) {
            case HysteriaPlayerReadyToPlayCurrentItem:
                if ([hysteriaPlayer getHysteriaPlayerStatus] != HysteriaPlayerStatusForcePause) {
                    [hysteriaPlayer play];
                }
                break;
            case HysteriaPlayerReadyToPlayPlayer:
                [hysteriaPlayer play];
                break;
                
            default:
                break;
        }
    }];
    
    [hysteriaPlayer registerHandlerFailed:^(HysteriaPlayerFailed identifier, NSError *error) {
        switch (identifier) {
            case HysteriaPlayerFailedCurrentItem:
                break;
                
            default:
                break;
        }
    }];
    
    [hysteriaPlayer setPlayerRepeatMode:RepeatMode_off];
    [hysteriaPlayer enableMemoryCached:NO];
}
```

### Handlers: ###

Specified event would trigger related callback blocks.

#### __RateChanged:CurrentItemChanged:PlayerDidReachEnd:__ : ####

**PlayerRateChanged**'s callback block will be called when player's rate changed, probely 1.0 to 0.0 or 0.0 to 1.0. You should update your UI to notice the user what's happening. HysteriaPlayer have __getHysteriaPlayerStatus:__ method helping you find out the informations. 
- HysteriaPlayerStatusPlaying : Player is playing
- HysteriaPlayerStatusForcePause : Player paused when Player's property `PAUSE_REASON_ForcePause = YES`.
- HysteriaPlayerStatusBuffering : Player suspended because of no buffered.
- HysteriaPlayerStatusUnknown : Player status unknown.

**CurrentItemChanged**'s callback block will be called when player's currentItem changed. If you have UI elements related to Playing item, should update them.(i.e. title, artist, artwork ..)

**PlayerDidReachEnd**'s callback block will be called when player stops, reaching the end of playing queue and repeat is disabled.

#### __ReadyToPlay__ : ####
It will be called when **Player** or **PlayerItem** ready to play.

#### __CurrentItemPreLoaded__ : ####
It will be called when receive new buffer data.

#### __Failed__ : ####
It will be called when **Player** or **PlayerItem** failed.


## Setting up Source Getter ##

Before you starting play anything, you have to set up your data source for HysteriaPlayer.
When Player gonna use (instantly play or pre-buffer) items, the source getter block will telling which index of your playing list is needed.

There are two methods to set up Source Getter.

1. __setupSourceGetter:ItemsCount:__
2. __asyncSetupSourceGetter:ItemsCount:__

__ItemsCount__ tells HysteriaPlayer the counts of your data source, you have to update it using `setItemsCount:(NSUInteger)count` if your datasource's count is changed.

#### 1. setupSourceGetter:ItemsCount: ####
The simplest way.  
When player ask for an index that it would liked to use, return your source link as NSURL type inside the index given block.

example:

```objective-c
    [hysteriaPlayer setupSourceGetter:^NSURL *(NSUInteger index) {
        return [urlArray objectAtIndex:index];
    } ItemsCount:[mp3Array count]];
```

#### 2. asyncSetupSourceGetter:ItemsCount: ####
For advanced usage, if you could use `setupSourceGetter:ItemsCount:` as well then no needs to use this method to setting up.

If you have to access your media link when player actually gonna play that item. 
You probability take that media link by an asynchronous connection and HysteriaPlayer also needs an asynchronous block to transform the media link your provided to AVPlayerItem. There are no ways you can return values from an async block to another.

So, you have to call `setupPlayerItem:Order:` by yourself when your async connection that getting media link is completion. And the Order parameter is what player asked for.

example:
```objective-c
NSUInteger count = [listItems count];
[hysteriaPlayer asyncSetupSourceGetter:^(NSUInteger index) {
    asyncOperation^{
        ..
        operation
        ..
        NSString *mediaLink = source;
        NSURL *url = [NSURL URLWithString:mediaLink];
        [hysteriaPlayer setupPlayerItem:url Order:index];
    }
} ItemsCount:count];
```

Snippets
--------------
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

[![Analytics](https://ga-beacon.appspot.com/UA-36710053-5/hysteriaplayer/readme)](https://github.com/igrigorik/ga-beacon)
[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/StreetVoice/hysteriaplayer/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
