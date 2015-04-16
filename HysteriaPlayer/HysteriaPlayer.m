//
//  HysteriaPlayer.m
//
//  Created by saiday on 13/1/8.
//
//

#import "HysteriaPlayer.h"
#import <AudioToolbox/AudioSession.h>
#import <objc/runtime.h>

static const void *Hysteriatag = &Hysteriatag;

@interface HysteriaPlayer ()
{
    BOOL routeChangedWhilePlaying;
    BOOL interruptedWhilePlaying;
    BOOL pauseReasonForced;
    BOOL pauseReasonBuffering;
    BOOL isPreBuffered;
    BOOL tookAudioFocus;
    
    NSUInteger prepareingItemHash;
    
    UIBackgroundTaskIdentifier bgTaskId;
    UIBackgroundTaskIdentifier removedId;
    
    dispatch_queue_t HBGQueue;
}


@property (nonatomic, strong, readwrite) NSArray *playerItems;
@property (nonatomic, readwrite) BOOL isInEmptySound;
@property (nonatomic) NSUInteger lastItemIndex;

@property (nonatomic, strong) AVQueuePlayer *audioPlayer;
@property (nonatomic) HysteriaPlayerRepeatMode repeatMode;
@property (nonatomic) HysteriaPlayerShuffleMode shuffleMode;
@property (nonatomic) HysteriaPlayerStatus hysteriaPlayerStatus;
@property (nonatomic, strong) NSMutableSet *playedItems;

- (void)longTimeBufferBackground;
- (void)longTimeBufferBackgroundCompleted;
- (void)setHysteriaIndex:(AVPlayerItem *)item Key:(NSNumber *)order;

@end

@implementation HysteriaPlayer


static HysteriaPlayer *sharedInstance = nil;
static dispatch_once_t onceToken;

#pragma mark -
#pragma mark ===========  Initialization, Setup  =========
#pragma mark -

+ (HysteriaPlayer *)sharedInstance {
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

+ (void)showAlertWithError:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Player errors"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
    [alert show];
}

- (id)init {
    self = [super init];
    if (self) {
        HBGQueue = dispatch_queue_create("com.hysteria.queue", NULL);
        _playerItems = [NSArray array];
        
        _repeatMode = HysteriaPlayerRepeatModeOff;
        _shuffleMode = HysteriaPlayerShuffleModeOff;
        _hysteriaPlayerStatus = HysteriaPlayerStatusUnknown;
    }
    
    return self;
}

- (void)preAction
{
    tookAudioFocus = YES;
    
    [self backgroundPlayable];
    [self playEmptySound];
    [self AVAudioSessionNotification];
}

- (void)registerHandlerReadyToPlay:(ReadyToPlay)readyToPlay{}

-(void)registerHandlerFailed:(Failed)failed {}

- (void)setupSourceGetter:(SourceSyncGetter)itemBlock ItemsCount:(NSUInteger)count {}

- (void)asyncSetupSourceGetter:(SourceAsyncGetter)asyncBlock ItemsCount:(NSUInteger)count{}

- (void)setItemsCount:(NSUInteger)count {}

- (void)playEmptySound
{
    //play .1 sec empty sound
    NSString *filepath = [[NSBundle mainBundle]pathForResource:@"point1sec" ofType:@"mp3"];
    if ([[NSFileManager defaultManager]fileExistsAtPath:filepath]) {
        self.isInEmptySound = YES;
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filepath]];
        self.audioPlayer = [AVQueuePlayer queuePlayerWithItems:[NSArray arrayWithObject:playerItem]];
    }
}

- (void)backgroundPlayable
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    if (audioSession.category != AVAudioSessionCategoryPlayback) {
        UIDevice *device = [UIDevice currentDevice];
        if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
            if (device.multitaskingSupported) {
                
                NSError *aError = nil;
                [audioSession setCategory:AVAudioSessionCategoryPlayback error:&aError];
                if (aError) {
                    if (!self.disableLogs) {
                        NSLog(@"set category error:%@",[aError description]);
                    }
                }
                aError = nil;
                [audioSession setActive:YES error:&aError];
                if (aError) {
                    if (!self.disableLogs) {
                        NSLog(@"set active error:%@",[aError description]);
                    }
                }
                //audioSession.delegate = self;
            }
        }
    }else {
        if (!self.disableLogs) {
            NSLog(@"unable to register background playback");
        }
    }
    
    [self longTimeBufferBackground];
}

/*
 * Tells OS this application starts one or more long-running tasks, should end background task when completed.
 */
-(void)longTimeBufferBackground
{
    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:removedId];
        bgTaskId = UIBackgroundTaskInvalid;
    }];
    
    if (bgTaskId != UIBackgroundTaskInvalid && removedId == 0 ? YES : (removedId != UIBackgroundTaskInvalid)) {
        [[UIApplication sharedApplication] endBackgroundTask: removedId];
    }
    removedId = bgTaskId;
}

-(void)longTimeBufferBackgroundCompleted
{
    if (bgTaskId != UIBackgroundTaskInvalid && removedId != bgTaskId) {
        [[UIApplication sharedApplication] endBackgroundTask: bgTaskId];
        removedId = bgTaskId;
    }
    
}

#pragma mark -
#pragma mark ===========  Runtime AssociatedObject  =========
#pragma mark -

- (void)setHysteriaIndex:(AVPlayerItem *)item Key:(NSNumber *)order {
    objc_setAssociatedObject(item, Hysteriatag, order, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)getHysteriaIndex:(AVPlayerItem *)item {
    return objc_getAssociatedObject(item, Hysteriatag);
}

#pragma mark -
#pragma mark ===========  AVAudioSession Notifications  =========
#pragma mark -

- (void)AVAudioSessionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interruption:)
                                                 name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    [self.audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

#pragma mark -
#pragma mark ===========  Player Methods  =========
#pragma mark -

- (void)willPlayPlayerItemAtIndex:(NSUInteger)index
{
    if (!tookAudioFocus) {
        [self preAction];
    }
    self.lastItemIndex = index;
    [self.playedItems addObject:@(index)];

    if ([self.delegate respondsToSelector:@selector(hysteriaPlayerWillChangedAtIndex:)]) {
        [self.delegate hysteriaPlayerWillChangedAtIndex:self.lastItemIndex];
    }
}

- (void)fetchAndPlayPlayerItem:(NSUInteger)startAt
{
    [self willPlayPlayerItemAtIndex:startAt];
    [self.audioPlayer pause];
    [self.audioPlayer removeAllItems];
    BOOL findInPlayerItems = NO;
    findInPlayerItems = [self findSourceInPlayerItems:startAt];
    if (!findInPlayerItems) {
        [self getSourceURLAtIndex:startAt preBuffer:NO];
    } else if (self.audioPlayer.currentItem.status == AVPlayerStatusReadyToPlay) {
        [self.audioPlayer play];
    }
}

- (NSUInteger)hysteriaPlayerItemsCount
{
    if ([self.datasource respondsToSelector:@selector(hysteriaPlayerNumberOfItems)]) {
        return [self.datasource hysteriaPlayerNumberOfItems];
    }
    return self.itemsCount;
}

- (void)getSourceURLAtIndex:(NSUInteger)index preBuffer:(BOOL)preBuffer
{
    NSAssert([self.datasource respondsToSelector:@selector(hysteriaPlayerURLForItemAtIndex:preBuffer:)] || [self.datasource respondsToSelector:@selector(hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer:)], @"You don't implement URL getter delegate from HysteriaPlayerDelegate, hysteriaPlayerURLForItemAtIndex:preBuffer: and hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer: provides for the use of alternatives.");
    NSAssert([self hysteriaPlayerItemsCount] > index, ([NSString stringWithFormat:@"You are about to access index: %li URL when your HysteriaPlayer items count value is %li, please check hysteriaPlayerNumberOfItems or set itemsCount directly.", index, [self hysteriaPlayerItemsCount]]));
    if ([self.datasource respondsToSelector:@selector(hysteriaPlayerURLForItemAtIndex:preBuffer:)] && [self.datasource hysteriaPlayerURLForItemAtIndex:index preBuffer:preBuffer]) {
        dispatch_async(HBGQueue, ^{
            [self setupPlayerItemWithUrl:[self.datasource hysteriaPlayerURLForItemAtIndex:index preBuffer:preBuffer] index:index];
        });
    } else if ([self.datasource respondsToSelector:@selector(hysteriaPlayerAsyncSetUrlForItemAtIndex:preBuffer:)]) {
        [self.datasource hysteriaPlayerAsyncSetUrlForItemAtIndex:index preBuffer:preBuffer];
    } else {
        NSException *exception = [[NSException alloc] initWithName:@"HysteriaPlayer Error" reason:[NSString stringWithFormat:@"Cannot find item URL at index %li", (unsigned long)index] userInfo:nil];
        @throw exception;
    }
}

- (void)setupPlayerItemWithUrl:(NSURL *)url index:(NSUInteger)index
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    if (!item)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setHysteriaIndex:item Key:[NSNumber numberWithInteger:index]];
        NSMutableArray *playerItems = [NSMutableArray arrayWithArray:self.playerItems];
        [playerItems addObject:item];
        self.playerItems = playerItems;
        [self insertPlayerItem:item];
    });
}


- (BOOL)findSourceInPlayerItems:(NSUInteger)index
{
    for (AVPlayerItem *item in self.playerItems) {
        NSInteger checkIndex = [[self getHysteriaIndex:item] integerValue];
        if (checkIndex == index) {
            [item seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                [self insertPlayerItem:item];
            }];
            return YES;
        }
    }
    return NO;
}

- (void)prepareNextPlayerItem
{
    // check before added, prevent add the same songItem
    NSNumber *currentIndexNumber = [self getHysteriaIndex:self.audioPlayer.currentItem];
    NSUInteger nowIndex = [currentIndexNumber integerValue];
    BOOL findInPlayerItems = NO;
    NSUInteger itemsCount = [self hysteriaPlayerItemsCount];
    
    if (currentIndexNumber) {
        if (_shuffleMode == HysteriaPlayerShuffleModeOn || _repeatMode == HysteriaPlayerRepeatModeOnce) {
            return;
        }
        if (nowIndex + 1 < itemsCount) {
            findInPlayerItems = [self findSourceInPlayerItems:nowIndex + 1];
            
            if (!findInPlayerItems) {
                [self getSourceURLAtIndex:nowIndex + 1 preBuffer:YES];
            }
        }
    }
}

- (void)insertPlayerItem:(AVPlayerItem *)item
{
    if ([self.audioPlayer.items count] > 1) {
        for (int i = 1 ; i < [self.audioPlayer.items count] ; i ++) {
            [self.audioPlayer removeItem:[self.audioPlayer.items objectAtIndex:i]];
        }
    }
    if ([self.audioPlayer canInsertItem:item afterItem:nil]) {
        [self.audioPlayer insertItem:item afterItem:nil];
    }
}

- (void)removeAllItems
{
    for (AVPlayerItem *obj in self.audioPlayer.items) {
        [obj seekToTime:kCMTimeZero];
        @try{
            [obj removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
            [obj removeObserver:self forKeyPath:@"status" context:nil];
        }@catch(id anException){
            //do nothing, obviously it wasn't attached because an exception was thrown
        }
    }
    
    self.playerItems = nil;
    [self.audioPlayer removeAllItems];
}

- (void)removeQueuesAtPlayer
{
    while (self.audioPlayer.items.count > 1) {
        [self.audioPlayer removeItem:[self.audioPlayer.items objectAtIndex:1]];
    }
}

- (void)removeItemAtIndex:(NSUInteger)order
{
    for (AVPlayerItem *item in [NSArray arrayWithArray:self.playerItems]) {
        NSUInteger CHECK_order = [[self getHysteriaIndex:item] integerValue];
        if (CHECK_order == order) {
            NSMutableArray *playerItems = [NSMutableArray arrayWithArray:self.playerItems];
            [playerItems removeObject:item];
            self.playerItems = playerItems;
            
            if ([self.audioPlayer.items indexOfObject:item] != NSNotFound) {
                [self.audioPlayer removeItem:item];
            }
        }else if (CHECK_order > order){
            [self setHysteriaIndex:item Key:[NSNumber numberWithInteger:CHECK_order -1]];
        }
    }
}

- (void)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to
{
    for (AVPlayerItem *item in self.playerItems) {
        NSUInteger CHECK_index = [[self getHysteriaIndex:item] integerValue];
        if (CHECK_index == from || CHECK_index == to) {
            NSNumber *replaceOrder = CHECK_index == from ? [NSNumber numberWithInteger:to] : [NSNumber numberWithInteger:from];
            [self setHysteriaIndex:item Key:replaceOrder];
        }
    }
}

- (void)seekToTime:(double)seconds
{
    [self.audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
}

- (void)seekToTime:(double)seconds withCompletionBlock:(void (^)(BOOL))completionBlock
{
    [self.audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        if (completionBlock) {
            completionBlock(finished);
        }
    }];
}

- (AVPlayerItem *)getCurrentItem
{
    return [self.audioPlayer currentItem];
}

- (void)play
{
    [self.audioPlayer play];
}

- (void)pause
{
    [self.audioPlayer pause];
}

- (void)playNext
{
    if (_shuffleMode == HysteriaPlayerShuffleModeOn) {
        NSInteger nextIndex = [self randomIndex];
        if (nextIndex != NSNotFound) {
            [self fetchAndPlayPlayerItem:nextIndex];
        } else {
            [self pausePlayerForcibly:YES];
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd)]) {
                [self.delegate hysteriaPlayerDidReachEnd];
            }
        }
    } else {
        NSNumber *nowIndexNumber = [self getHysteriaIndex:self.audioPlayer.currentItem];
        NSUInteger nowIndex = nowIndexNumber ? [nowIndexNumber integerValue] : self.lastItemIndex;
        if (nowIndex + 1 < [self hysteriaPlayerItemsCount]) {
            if (self.audioPlayer.items.count > 1) {
                [self willPlayPlayerItemAtIndex:nowIndex + 1];
                [self.audioPlayer advanceToNextItem];
            } else {
                [self fetchAndPlayPlayerItem:(nowIndex + 1)];
            }
        } else {
            if (_repeatMode == HysteriaPlayerRepeatModeOff) {
                [self pausePlayerForcibly:YES];
                if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd)]) {
                    [self.delegate hysteriaPlayerDidReachEnd];
                }
            }
            [self fetchAndPlayPlayerItem:0];
        }
    }
}

- (void)playPrevious
{
    NSInteger nowIndex = [[self getHysteriaIndex:self.audioPlayer.currentItem] integerValue];
    if (nowIndex == 0)
    {
        if (_repeatMode == HysteriaPlayerRepeatModeOn) {
            [self fetchAndPlayPlayerItem:[self hysteriaPlayerItemsCount] - 1];
        } else {
            [self.audioPlayer.currentItem seekToTime:kCMTimeZero];
        }
    } else {
        [self fetchAndPlayPlayerItem:(nowIndex - 1)];
    }
}

- (CMTime)playerItemDuration
{
    NSError *err = nil;
    if ([self.audioPlayer.currentItem.asset statusOfValueForKey:@"duration" error:&err] == AVKeyValueStatusLoaded) {
        AVPlayerItem *playerItem = [self.audioPlayer currentItem];
        NSArray *loadedRanges = playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0)
        {
            CMTimeRange range = [[loadedRanges objectAtIndex:0] CMTimeRangeValue];
            //Float64 duration = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
            return (range.duration);
        }else {
            return (kCMTimeInvalid);
        }
    } else {
        return (kCMTimeInvalid);
    }
}

- (void)setPlayerRepeatMode:(HysteriaPlayerRepeatMode)mode
{
    _repeatMode = mode;
}

- (HysteriaPlayerRepeatMode)getPlayerRepeatMode
{
    return _repeatMode;
}

- (void)setPlayerShuffleMode:(HysteriaPlayerShuffleMode)mode
{
    switch (mode) {
        case HysteriaPlayerShuffleModeOff:
            _shuffleMode = HysteriaPlayerShuffleModeOff;
            [_playedItems removeAllObjects];
            _playedItems = nil;
            break;
        case HysteriaPlayerShuffleModeOn:
            _shuffleMode = HysteriaPlayerShuffleModeOn;
            _playedItems = [NSMutableSet set];
            if (self.audioPlayer.currentItem) {
                [self.playedItems addObject:[self getHysteriaIndex:self.audioPlayer.currentItem]];
            }
            break;
        default:
            break;
    }
}

- (HysteriaPlayerShuffleMode)getPlayerShuffleMode
{
    return _shuffleMode;
}

- (void)pausePlayerForcibly:(BOOL)forcibly
{
    pauseReasonForced = forcibly;
}

#pragma mark -
#pragma mark ===========  Player info  =========
#pragma mark -

- (BOOL)isPlaying
{
    if (!self.isInEmptySound)
        return [self.audioPlayer rate] != 0.f;
    else
        return NO;
}

- (HysteriaPlayerStatus)getHysteriaPlayerStatus
{
    if ([self isPlaying])
        return HysteriaPlayerStatusPlaying;
    else if (pauseReasonForced)
        return HysteriaPlayerStatusForcePause;
    else if (pauseReasonBuffering)
        return HysteriaPlayerStatusBuffering;
    else
        return HysteriaPlayerStatusUnknown;
}

- (float)getPlayingItemCurrentTime
{
    CMTime itemCurrentTime = [[self.audioPlayer currentItem] currentTime];
    float current = CMTimeGetSeconds(itemCurrentTime);
    if (CMTIME_IS_INVALID(itemCurrentTime) || !isfinite(current))
        return 0.0f;
    else
        return current;
}

- (float)getPlayingItemDurationTime
{
    CMTime itemDurationTime = [self playerItemDuration];
    float duration = CMTimeGetSeconds(itemDurationTime);
    if (CMTIME_IS_INVALID(itemDurationTime) || !isfinite(duration))
        return 0.0f;
    else
        return duration;
}

- (id)addPeriodicTimeObserverForInterval:(CMTime)interval
                                   queue:(dispatch_queue_t)queue
                              usingBlock:(void (^)(CMTime time))block
{
    id mTimeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:interval queue:queue usingBlock:block];
    return mTimeObserver;
}

#pragma mark -
#pragma mark ===========  Interruption, Route changed  =========
#pragma mark -

- (void)interruption:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSUInteger interuptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (interuptionType == AVAudioSessionInterruptionTypeBegan && !pauseReasonForced) {
        interruptedWhilePlaying = YES;
        [self pausePlayerForcibly:YES];
        [self pause];
    } else if (interuptionType == AVAudioSessionInterruptionTypeEnded && interruptedWhilePlaying) {
        interruptedWhilePlaying = NO;
        [self pausePlayerForcibly:NO];
        [self play];
    }
    if (!self.disableLogs) {
        NSLog(@"HysteriaPlayer interruption: %@", interuptionType == AVAudioSessionInterruptionTypeBegan ? @"began" : @"end");
    }
}

- (void)routeChange:(NSNotification *)notification
{
    NSDictionary *routeChangeDict = notification.userInfo;
    NSUInteger routeChangeType = [[routeChangeDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    if (routeChangeType == AVAudioSessionRouteChangeReasonOldDeviceUnavailable && !pauseReasonForced) {
        routeChangedWhilePlaying = YES;
        [self pausePlayerForcibly:YES];
    } else if (routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable && routeChangedWhilePlaying) {
        routeChangedWhilePlaying = NO;
        [self pausePlayerForcibly:NO];
        [self play];
    }
    if (!self.disableLogs) {
        NSLog(@"HysteriaPlayer routeChanged: %@", routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable ? @"New Device Available" : @"Old Device Unavailable");
    }
}

#pragma mark -
#pragma mark ===========  KVO  =========
#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == self.audioPlayer && [keyPath isEqualToString:@"status"]) {
        if (self.audioPlayer.status == AVPlayerStatusReadyToPlay) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerReadyToPlay:)]) {
                [self.delegate hysteriaPlayerReadyToPlay:HysteriaPlayerReadyToPlayPlayer];
            }
            if (![self isPlaying]) {
                [self.audioPlayer play];
            }
        } else if (self.audioPlayer.status == AVPlayerStatusFailed) {
            if (!self.disableLogs) {
                NSLog(@"%@", self.audioPlayer.error);
            }
            
            if (self.popAlertWhenError) {
                [HysteriaPlayer showAlertWithError:self.audioPlayer.error];
            }
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidFailed:error:)]) {
                [self.delegate hysteriaPlayerDidFailed:HysteriaPlayerFailedPlayer error:self.audioPlayer.error];
            }
        }
    }
    
    if(object == self.audioPlayer && [keyPath isEqualToString:@"rate"]){
        if (!self.isInEmptySound) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerRateChanged:)]) {
                [self.delegate hysteriaPlayerRateChanged:[self isPlaying]];
            }
        }
    }
    
    if(object == self.audioPlayer && [keyPath isEqualToString:@"currentItem"]){
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        AVPlayerItem *lastPlayerItem = [change objectForKey:NSKeyValueChangeOldKey];
        if (lastPlayerItem != (id)[NSNull null]) {
            self.isInEmptySound = NO;
            @try {
                [lastPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
                [lastPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
            } @catch(id anException) {
                //do nothing, obviously it wasn't attached because an exception was thrown
            }
        }
        if (newPlayerItem != (id)[NSNull null]) {
            [newPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [newPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerCurrentItemChanged:)]) {
                [self.delegate hysteriaPlayerCurrentItemChanged:newPlayerItem];
            }
        }
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        isPreBuffered = NO;
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusFailed) {
            if (self.popAlertWhenError) {
                [HysteriaPlayer showAlertWithError:self.audioPlayer.currentItem.error];
            }
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidFailed:error:)]) {
                [self.delegate hysteriaPlayerDidFailed:HysteriaPlayerFailedCurrentItem error:self.audioPlayer.currentItem.error];
            }
        }else if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerReadyToPlay:)]) {
                [self.delegate hysteriaPlayerReadyToPlay:HysteriaPlayerReadyToPlayCurrentItem];
            }
            if (![self isPlaying] && !pauseReasonForced) {
                [self.audioPlayer play];
            }
        }
    }
    
    if (self.audioPlayer.items.count > 1 && object == [self.audioPlayer.items objectAtIndex:1] && [keyPath isEqualToString:@"loadedTimeRanges"]) {
        isPreBuffered = YES;
    }
    
    if(object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"loadedTimeRanges"]){
        if (self.audioPlayer.currentItem.hash != prepareingItemHash) {
            [self prepareNextPlayerItem];
            prepareingItemHash = self.audioPlayer.currentItem.hash;
        }
        
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange=[[timeRanges objectAtIndex:0]CMTimeRangeValue];
            
            if ([self.delegate respondsToSelector:@selector(hysteriaPlayerCurrentItemPreloaded:)]) {
                [self.delegate hysteriaPlayerCurrentItemPreloaded:CMTimeAdd(timerange.start, timerange.duration)];
            }
            
            if (self.audioPlayer.rate == 0 && !pauseReasonForced) {
                pauseReasonBuffering = YES;
                
                [self longTimeBufferBackground];
                
                CMTime bufferdTime = CMTimeAdd(timerange.start, timerange.duration);
                CMTime milestone = CMTimeAdd(self.audioPlayer.currentTime, CMTimeMakeWithSeconds(5.0f, timerange.duration.timescale));
                
                if (CMTIME_COMPARE_INLINE(bufferdTime , >, milestone) && self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay && !interruptedWhilePlaying && !routeChangedWhilePlaying) {
                    if (![self isPlaying]) {
                        if (!self.disableLogs) {
                            NSLog(@"resume from buffering..");
                        }
                        pauseReasonBuffering = NO;
                        
                        [self.audioPlayer play];
                        [self longTimeBufferBackgroundCompleted];
                    }
                }
            }
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    AVPlayerItem *item = [notification object];
    if(![item isEqual:self.audioPlayer.currentItem]){
        return;
    }

    NSNumber *CHECK_Order = [self getHysteriaIndex:self.audioPlayer.currentItem];
    if (CHECK_Order) {
        if (_repeatMode == HysteriaPlayerRepeatModeOnce) {
            NSInteger currentIndex = [CHECK_Order integerValue];
            [self fetchAndPlayPlayerItem:currentIndex];
        } else if (_shuffleMode == HysteriaPlayerShuffleModeOn) {
            NSInteger nextIndex = [self randomIndex];
            if (nextIndex != NSNotFound) {
                [self fetchAndPlayPlayerItem:[self randomIndex]];
            } else {
                [self pausePlayerForcibly:YES];
                if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd)]) {
                    [self.delegate hysteriaPlayerDidReachEnd];
                }
            }
        } else {
            if (self.audioPlayer.items.count == 1 || !isPreBuffered) {
                NSInteger nowIndex = [CHECK_Order integerValue];
                if (nowIndex + 1 < [self hysteriaPlayerItemsCount]) {
                    [self playNext];
                } else {
                    if (_repeatMode == HysteriaPlayerRepeatModeOff) {
                        [self pausePlayerForcibly:YES];
                        if ([self.delegate respondsToSelector:@selector(hysteriaPlayerDidReachEnd)]) {
                            [self.delegate hysteriaPlayerDidReachEnd];
                        }
                    }
                    [self fetchAndPlayPlayerItem:0];
                }
            }
        }
    }
}

- (NSUInteger)randomIndex
{
    NSUInteger itemsCount = [self hysteriaPlayerItemsCount];
    if ([self.playedItems count] == itemsCount) {
        self.playedItems = [NSMutableSet set];
        if (_repeatMode == HysteriaPlayerRepeatModeOff) {
            return NSNotFound;
        }
    }

    NSUInteger index;
    do {
        index = arc4random() % itemsCount;
    } while ([_playedItems containsObject:[NSNumber numberWithInteger:index]]);
    
    return index;
}

#pragma mark -
#pragma mark ===========   Deprecation  =========
#pragma mark -

- (void)deprecatePlayer
{
    NSError *error;
    tookAudioFocus = NO;
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [self.audioPlayer removeObserver:self forKeyPath:@"status" context:nil];
    [self.audioPlayer removeObserver:self forKeyPath:@"rate" context:nil];
    [self.audioPlayer removeObserver:self forKeyPath:@"currentItem" context:nil];
    
    [self removeAllItems];
    
    [self.audioPlayer pause];
    self.delegate = nil;
    self.datasource = nil;
    self.audioPlayer = nil;
    
    onceToken = 0;
}

#pragma mark -
#pragma mark ===========   Memory cached  =========
#pragma mark -

- (BOOL) isMemoryCached
{
    return (self.playerItems == nil);
}

- (void) enableMemoryCached:(BOOL)isMemoryCached
{
    if (self.playerItems == nil && isMemoryCached) {
        self.playerItems = [NSArray array];
    }else if (self.playerItems != nil && !isMemoryCached){
        self.playerItems = nil;
    }
}

#pragma mark -
#pragma mark ===========   Delegation  =========
#pragma mark -

- (void)addDelegate:(id<HysteriaPlayerDelegate>)delegate{}

- (void)removeDelegate:(id<HysteriaPlayerDelegate>)delegate{}

@end