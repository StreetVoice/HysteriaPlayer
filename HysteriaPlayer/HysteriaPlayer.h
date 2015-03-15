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

@class MPMediaItem;

// Delegate
@protocol HysteriaPlayerDelegate <NSObject>

@optional
- (void)hysteriaPlayerCurrentItemChanged:(AVPlayerItem *)item;
- (void)hysteriaPlayerRateChanged:(BOOL)isPlaying;
- (void)hysteriaPlayerDidReachEnd;
- (void)hysteriaPlayerCurrentItemPreloaded:(CMTime)time;

@end

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
typedef NSURL * (^ SourceSyncGetter)(NSUInteger index);

typedef NS_ENUM(NSUInteger, HysteriaPlayerStatus) {
    HysteriaPlayerStatusPlaying = 0,
    HysteriaPlayerStatusForcePause,
    HysteriaPlayerStatusBuffering,
    HysteriaPlayerStatusUnknown,
};

typedef NS_ENUM(NSUInteger, HysteriaPlayerRepeatMode) {
    HysteriaPlayerRepeatModeOn = 0,
    HysteriaPlayerRepeatModeOnce,
    HysteriaPlayerRepeatModeOff,
};

typedef NS_ENUM(NSUInteger, HysteriaPlayerShuffleMode) {
    HysteriaPlayerShuffleModeOn = 0,
    HysteriaPlayerShuffleModeOff,
};

@interface HysteriaPlayer : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, strong, readonly) NSMutableArray *playerItems;
@property (nonatomic, readonly) BOOL isInEmptySound;
@property (nonatomic) BOOL showErrorMessages;

+ (HysteriaPlayer *)sharedInstance;

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay;
- (void)registerHandlerFailed:(Failed)failed;


/*!
 Recommend you use this method to handle your source getter, setupSourceAsyncGetter:ItemsCount: is for advanced usage.
 @method setupSourceGetter:ItemsCount:
 */
- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSUInteger) count;
/*!
 If you are using Async block handle your item, make sure you call setupPlayerItemWithUrl:Order: at last
 @method asyncSetupSourceGetter:ItemsCount
 */
- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSUInteger)count;
- (void)setItemsCount:(NSUInteger)count;

/*!
 This method is necessary if you setting up AsyncGetter.
 After you your AVPlayerItem initialized should call this method on your asyncBlock.
 Should not call this method directly if you using setupSourceGetter:ItemsCount.
 @method setupPlayerItemWithUrl:Order:
 */
- (void)setupPlayerItemWithUrl:(NSURL *)url Order:(NSUInteger)index;
- (void)fetchAndPlayPlayerItem: (NSUInteger )startAt;
- (void)removeAllItems;
- (void)removeQueuesAtPlayer;
- (void)removeItemAtIndex:(NSUInteger)index;
- (void)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (void)play;
- (void)pause;
- (void)pausePlayerForcibly:(BOOL)forcibly;
- (void)playPrevious;
- (void)playNext;
- (void)seekToTime:(double) CMTime;
- (void)seekToTime:(double) CMTime withCompletionBlock:(void (^)(BOOL finished))completionBlock;

- (void)setPlayerRepeatMode:(HysteriaPlayerRepeatMode)mode;
- (HysteriaPlayerRepeatMode)getPlayerRepeatMode;
- (void)setPlayerShuffleMode:(HysteriaPlayerShuffleMode)mode;
- (HysteriaPlayerShuffleMode)getPlayerShuffleMode;

- (BOOL)isPlaying;
- (AVPlayerItem *)getCurrentItem;
- (HysteriaPlayerStatus)getHysteriaPlayerStatus;

- (void)addDelegate:(id<HysteriaPlayerDelegate>)delegate;
- (void)removeDelegate:(id<HysteriaPlayerDelegate>)delegate;

- (float)getPlayingItemCurrentTime;
- (float)getPlayingItemDurationTime;
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval
                                   queue:(dispatch_queue_t)queue
                              usingBlock:(void (^)(CMTime time))block;

- (void)configureNowPlayingInfo:(NSDictionary *)properties;

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

