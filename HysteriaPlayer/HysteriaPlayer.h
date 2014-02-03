//
//  HysteriaPlayer.h
//
//  Version 1.0
//
//  Created by Saiday on 01/14/2013.
//  Copyright 2013 StreetVoice
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <AVFoundation/AVFoundation.h>

#define HYSTERIAPLAYER_CURRENT_TIME @"CurrentTime"
#define HYSTERIAPLAYER_DURATION_TIME @"DurationTime"

typedef NS_ENUM(NSUInteger, HysteriaPlayerReadyToPlay) {
    HysteriaPlayerReadyToPlayPlayer = 3000,
    HysteriaPlayerReadyToPlayCurrentItem = 3001,
};

typedef NS_ENUM(NSUInteger, HysteriaPlayerFailed) {
    HysteriaPlayerFailedPlayer = 4000,
    HysteriaPlayerFailedCurrentItem = 4001,
    
};

typedef void (^ Failed)(HysteriaPlayerFailed identifier, NSError *error);
typedef void (^ ReadyToPlay)(HysteriaPlayerReadyToPlay identifier);
typedef void (^ SourceAsyncGetter)(NSUInteger index);
typedef NSString * (^ SourceSyncGetter)(NSUInteger index);
typedef void (^ PlayerRateChanged)();
typedef void (^ CurrentItemChanged)(AVPlayerItem *item);
typedef void (^ PlayerDidReachEnd)();
typedef void (^ CurrentItemPreLoaded)(CMTime time);

// deprecated typedef
typedef void (^PlayerPreLoaded)() __deprecated;
typedef void (^ PlayerFailed)() __deprecated;
typedef NSString *(^ SourceItemGetter) (NSUInteger) __deprecated;
typedef void (^ PlayerReadyToPlay)() __deprecated;
typedef void (^ ItemReadyToPlay)() __deprecated;

typedef enum
{
    HysteriaPlayerStatusPlaying = 0,
    HysteriaPlayerStatusForcePause,
    HysteriaPlayerStatusBuffering,
    HysteriaPlayerStatusUnknown
}
HysteriaPlayerStatus;

typedef enum
{
    RepeatMode_on = 0,
    RepeatMode_one,
    RepeatMode_off
}
PlayerRepeatMode;

typedef enum
{
    ShuffleMode_on = 0,
    ShuffleMode_off
}
PlayerShuffleMode;


@interface HysteriaPlayer : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, strong, readonly) NSMutableArray *playerItems;
@property (nonatomic, readonly) BOOL isInEmptySound;
@property (nonatomic) BOOL showErrorMessages;

+ (HysteriaPlayer *)sharedInstance;

- (void)registerHandlerPlayerRateChanged:(PlayerRateChanged)playerRateChanged CurrentItemChanged:(CurrentItemChanged)currentItemChanged PlayerDidReachEnd:(PlayerDidReachEnd)playerDidReachEnd;
- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay;
- (void)registerHandlerCurrentItemPreLoaded:(CurrentItemPreLoaded)currentItemPreLoaded;
- (void)registerHandlerFailed:(Failed)failed;


/*!
 Recommend you use this method to handle your source getter, setupSourceAsyncGetter:ItemsCount: is for advanced usage.
 @method setupSourceGetter:ItemsCount:
 */
- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSUInteger) count;
/*!
 If you are using Async block handle your item, make sure you call setupPlayerItem: at last
 @method asyncSetupSourceGetter:ItemsCount
 */
- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSUInteger)count;
- (void)setItemsCount:(NSUInteger)count;

/*!
 This method is necessary if you setting up AsyncGetter.
 After you your AVPlayerItem initialized should call this method on your asyncBlock.
 Should not call this method directly if you using setupSourceGetter:ItemsCount.
 @method setupPlayerItem:
 */
- (void)setupPlayerItem:(NSString *)url Order:(NSUInteger)index;
- (void)fetchAndPlayPlayerItem: (NSUInteger )startAt;
- (void)removeAllItems;
- (void)removeQueuesAtPlayer;
- (void)removeItemAtIndex:(NSUInteger)index;
- (void)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (void)play;
- (void)pause;
- (void)playPrevious;
- (void)playNext;
- (void)seekToTime:(double) CMTime;
- (void)seekToTime:(double) CMTime withCompletionBlock:(void (^)(BOOL finished))completionBlock;

- (void)setPlayerRepeatMode:(PlayerRepeatMode)mode;
- (PlayerRepeatMode)getPlayerRepeatMode;
- (void)setPlayerShuffleMode:(PlayerShuffleMode)mode;
- (void)pausePlayerForcibly:(BOOL)forcibly;

- (PlayerShuffleMode)getPlayerShuffleMode;
- (NSDictionary *)getPlayerTime;
- (float)getPlayerRate;
- (BOOL)isPlaying;
- (AVPlayerItem *)getCurrentItem;
- (HysteriaPlayerStatus)getHysteriaPlayerStatus;

/*!
 DEPRECATED: Use getHysteriaPlayerStatus instead
 @method pauseReason
 */
- (HysteriaPlayerStatus)pauseReason __deprecated;
/*!
 DEPRECATED: Use setupSourceGetter:ItemsCount: instead
 @method setupWithGetterBlock:ItemsCount:
 */
- (void)setupWithGetterBlock:(SourceItemGetter) itemBlock ItemsCount:(NSUInteger) count __deprecated;

/*!
 DEPRECATED: Use registerHandler... instead
 @method initWithHandlerPlayerReadyToPlay:PlayerRateChanged:CurrentItemChanged:ItemReadyToPlay:PlayerPreLoaded:PlayerFailed:PlayerDidReachEnd:
 */
- (instancetype)initWithHandlerPlayerReadyToPlay:(PlayerReadyToPlay)playerReadyToPlay PlayerRateChanged:(PlayerRateChanged)playerRateChanged CurrentItemChanged:(CurrentItemChanged)currentItemChanged ItemReadyToPlay:(ItemReadyToPlay)itemReadyToPlay PlayerPreLoaded:(PlayerPreLoaded)playerPreLoaded PlayerFailed:(PlayerFailed)playerFailed PlayerDidReachEnd:(PlayerDidReachEnd)playerDidReachEnd __deprecated;

/*
 * Disable memory cache, player will run SourceItemGetter everytime even the media has been played.
 * Default is YES
 */
- (void)enableMemoryCached:(BOOL) isMemoryCached;
- (BOOL)isMemoryCached;

/*
 * Indicating Playeritem's play order
 */
- (NSNumber *)getHysteriaOrder:(AVPlayerItem *)item;

- (void)deprecatePlayer;

@end
