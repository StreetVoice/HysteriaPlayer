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

#import <AvailabilityMacros.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, HysteriaPlayerReadyToPlay) {
    HysteriaPlayerReadyToPlayPlayer = 3000,
    HysteriaPlayerReadyToPlayCurrentItem = 3001,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerFailed) {
    HysteriaPlayerFailedPlayer = 4000,
    HysteriaPlayerFailedCurrentItem = 4001,
};

// Delegate
@protocol HysteriaPlayerDelegate <NSObject>

@optional
- (void)hysteriaPlayerWillChangedAtIndex:(NSInteger)index;
- (void)hysteriaPlayerCurrentItemChanged:(AVPlayerItem *)item;
- (void)hysteriaPlayerRateChanged:(BOOL)isPlaying;
- (void)hysteriaPlayerDidReachEnd;
- (void)hysteriaPlayerCurrentItemPreloaded:(CMTime)time;
- (void)hysteriaPlayerDidFailed:(HysteriaPlayerFailed)identifier error:(NSError *)error;
- (void)hysteriaPlayerReadyToPlay:(HysteriaPlayerReadyToPlay)identifier;

@end

@protocol HysteriaPlayerDataSource <NSObject>

@optional
- (NSInteger)hysteriaPlayerNumberOfItems;
/*!
 Recommend you use this method to handle your source getter, setupSourceAsyncGetter:ItemsCount: is for advanced usage.
 hysteriaPlayerURLForItemAtIndex:(NSInteger)index and hysteriaPlayerAsyncSetUrlForItemAtIndex:(NSInteger)index provides for the use of alternatives.
 @method HysteriaPlayerURLForItemAtIndex:(NSInteger)index
 */
- (NSURL *)hysteriaPlayerURLForItemAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer;
/*!
 If you are using asynchronously handle your items use this method to tell HysteriaPlayer which URL you would use for index, will excute until you call setupPlayerItemWithUrl:index:
 hysteriaPlayerURLForItemAtIndex:(NSInteger)index and hysteriaPlayerAsyncSetUrlForItemAtIndex:(NSInteger)index provides for the use of alternatives.
 @method HysteriaPlayerAsyncSetUrlForItemAtIndex:(NSInteger)index
 */
- (void)hysteriaPlayerAsyncSetUrlForItemAtIndex:(NSInteger)index preBuffer:(BOOL)preBuffer;

@end

typedef void (^ Failed)(HysteriaPlayerFailed identifier, NSError *error) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef void (^ ReadyToPlay)(HysteriaPlayerReadyToPlay identifier) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef void (^ SourceAsyncGetter)(NSInteger index) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");
typedef NSURL * (^ SourceSyncGetter)(NSInteger index) DEPRECATED_MSG_ATTRIBUTE("deprecated since 2.5 version");

typedef NS_ENUM(NSInteger, HysteriaPlayerStatus) {
    HysteriaPlayerStatusPlaying = 0,
    HysteriaPlayerStatusForcePause,
    HysteriaPlayerStatusBuffering,
    HysteriaPlayerStatusUnknown,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerRepeatMode) {
    HysteriaPlayerRepeatModeOn = 0,
    HysteriaPlayerRepeatModeOnce,
    HysteriaPlayerRepeatModeOff,
};

typedef NS_ENUM(NSInteger, HysteriaPlayerShuffleMode) {
    HysteriaPlayerShuffleModeOn = 0,
    HysteriaPlayerShuffleModeOff,
};

@interface HysteriaPlayer : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, weak) id<HysteriaPlayerDelegate> delegate;
@property (nonatomic, weak) id<HysteriaPlayerDataSource> datasource;
@property (nonatomic) NSInteger itemsCount;
@property (nonatomic) BOOL disableLogs;
@property (nonatomic, strong, readonly) NSArray *playerItems;
@property (nonatomic, readonly) BOOL isInEmptySound;
@property (nonatomic) BOOL popAlertWhenError;

+ (HysteriaPlayer *)sharedInstance;

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDelegate instead");
- (void)registerHandlerFailed:(Failed)failed DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDelegate instead");


- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSInteger) count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");
- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSInteger)count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");
- (void)setItemsCount:(NSInteger)count DEPRECATED_MSG_ATTRIBUTE("use HysteriaPlayerDataSource instead.");

/*!
 This method is necessary if you setting up AsyncGetter.
 After you your AVPlayerItem initialized should call this method on your asyncBlock.
 Should not call this method directly if you using setupSourceGetter:ItemsCount.
 @method setupPlayerItemWithUrl:index:
 */
- (void)setupPlayerItemWithUrl:(NSURL *)url index:(NSInteger)index;
- (void)fetchAndPlayPlayerItem: (NSInteger )startAt;
- (void)removeAllItems;
- (void)removeQueuesAtPlayer;
/*!
 Be sure you update hysteriaPlayerNumberOfItems or itemsCount when you remove items
 */
- (void)removeItemAtIndex:(NSInteger)index;
- (void)moveItemFromIndex:(NSInteger)from toIndex:(NSInteger)to;
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

- (void)addDelegate:(id<HysteriaPlayerDelegate>)delegate DEPRECATED_MSG_ATTRIBUTE("set delegate property instead");
- (void)removeDelegate:(id<HysteriaPlayerDelegate>)delegate DEPRECATED_MSG_ATTRIBUTE("Use delegate property instead");;

- (float)getPlayingItemCurrentTime;
- (float)getPlayingItemDurationTime;
- (id)addBoundaryTimeObserverForTimes:(NSArray *)times queue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))block;
- (void)removeTimeObserver:(id)observer;

/*
 * Disable memory cache, player will run SourceItemGetter everytime even the media has been played.
 * Default is YES
 */
- (void)enableMemoryCached:(BOOL) isMemoryCached;
- (BOOL)isMemoryCached;

/*
 * Indicating Playeritem's play index
 */
- (NSNumber *)getHysteriaIndex:(AVPlayerItem *)item;

- (void)deprecatePlayer;

@end

