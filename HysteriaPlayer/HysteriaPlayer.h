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

typedef NSString * (^ SourceItemGetter)(NSUInteger);
typedef void (^ PlayerReadyToPlay)();
typedef void (^ PlayerRateChanged)();
typedef void (^ CurrentItemChanged)(AVPlayerItem *);
typedef void (^ ItemReadyToPlay)();
typedef void (^ PlayerFailed)();
typedef void (^ PlayerDidReachEnd)();
typedef void (^ PlayerPreLoaded)(CMTime);


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
Player_RepeatMode;

typedef enum
{
    ShuffleMode_on = 0,
    ShuffleMode_off
}
Player_ShuffleMode;


@interface HysteriaPlayer : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, strong) AVQueuePlayer *audioPlayer;
@property (nonatomic, strong, readonly) NSMutableArray *playerItems;
@property (nonatomic) BOOL PAUSE_REASON_ForcePause;
@property (nonatomic) BOOL PAUSE_REASON_Buffering;
@property (nonatomic) BOOL NETWORK_ERROR_getNextItem;
@property (nonatomic, readonly) BOOL isInEmptySound;
@property (nonatomic) Player_RepeatMode _repeatMode;
@property (nonatomic) Player_ShuffleMode _shuffleMode;
@property (nonatomic) HysteriaPlayerStatus hysteriaPlayerStatus;

+ (HysteriaPlayer *)sharedInstance;
- (instancetype)initWithHandlerPlayerReadyToPlay:(PlayerReadyToPlay)playerReadyToPlay PlayerRateChanged:(PlayerRateChanged)playerRateChanged CurrentItemChanged:(CurrentItemChanged)currentItemChanged ItemReadyToPlay:(ItemReadyToPlay)itemReadyToPlay PlayerPreLoaded:(PlayerPreLoaded)playerPreLoaded PlayerFailed:(PlayerFailed)playerFailed PlayerDidReachEnd:(PlayerDidReachEnd)playerDidReachEnd;
- (void)setupWithGetterBlock:(SourceItemGetter) itemBlock ItemsCount:(NSUInteger) count;
- (void)setItemsCount:(NSUInteger)count;

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

- (void)setPlayerRepeatMode:(Player_RepeatMode) mode;
- (Player_RepeatMode) getPlayerRepeatMode;
- (void)setPlayerShuffleMode:(Player_ShuffleMode) mode;
- (Player_ShuffleMode)getPlayerShuffleMode;



- (NSDictionary *)getPlayerTime;
- (float)getPlayerRate;
- (BOOL)isPlaying;
- (AVPlayerItem *)getCurrentItem;
- (HysteriaPlayerStatus)pauseReason;

- (void)deprecatePlayer;

/*
 * Disable memory cache, player will run SourceItemGetter everytime even the media has been played.
 * Default is YES
 */
- (void) enableMemoryCached:(BOOL) isMemoryCached;
- (BOOL) isMemoryCached;

/*
 * Tells OS this application starts one or more long-running tasks, should end background task when completed.
 */
- (void)longTimeBufferBackground;
- (void)longTimeBufferBackgroundCompleted;

/*
 * Indicating Playeritem's play order
 */
- (void)setHysteriaOrder:(AVPlayerItem *)item Key:(NSNumber *)order;
- (NSNumber *)getHysteriaOrder:(AVPlayerItem *)item;

@end
