//
//  HysteriaPlayer.m
//
//  Created by saiday on 13/1/8.
//
//

#import "HysteriaPlayer.h"
#import <objc/runtime.h>

static const void *Hysteriatag = &Hysteriatag;

@interface HysteriaPlayer ()
{
    BOOL routeChangedWhilePlaying;
    BOOL interruptedWhilePlaying;
    
    NSUInteger CHECK_AvoidPreparingSameItem;
    NSUInteger items_count;
    
    UIBackgroundTaskIdentifier bgTaskId;
    UIBackgroundTaskIdentifier removedId;
    
    dispatch_queue_t HBGQueue;
    
    BlockItemGetter blockItemGetter;
    PlayerReadyToPlay playerReadyToPlay;
    PlayerRateChanged playerRateChanged;
    CurrentItemChanged currentItemChanged;
    ItemReadyToPlay itemReadyToPlay;
}
@property (nonatomic, strong, readwrite) NSMutableArray *playerItems;

@property (nonatomic, readwrite) BOOL isInEmptySound;
@end

@implementation HysteriaPlayer
@synthesize audioPlayer,playerItems,PAUSE_REASON_ForcePause,PLAYMODE_Repeat,PLAYMODE_RepeatOne,PLAYMODE_Shuffle,NETWORK_ERROR_getNextItem,isInEmptySound;

#pragma mark -
#pragma mark ===========  Initialization, Setup  =========
#pragma mark -

- (id)initWithHandlerPlayerReadyToPlay:(PlayerReadyToPlay)_playerReadyToPlay PlayerRateChanged:(PlayerRateChanged)_playerRateChanged CurrentItemChanged:(CurrentItemChanged)_currentItemChanged ItemReadyToPlay:(ItemReadyToPlay)_itemReadyToPlay
{
    if ((self = [super init])) {
        HBGQueue = dispatch_queue_create("com.hysteria.queue", NULL);
        playerItems = [NSMutableArray array];
        PLAYMODE_Repeat = YES;
        PLAYMODE_RepeatOne = NO;
        PLAYMODE_Shuffle = NO;
        
        playerReadyToPlay = _playerReadyToPlay;
        playerRateChanged = _playerRateChanged;
        currentItemChanged = _currentItemChanged;
        itemReadyToPlay = _itemReadyToPlay;
        
        [self backgroundPlayable];
        [self playEmptySound];
        [self AVAudioSessionNotification];
    }
    return self;
}

- (id)initWithHandlerPlayerReadyToPlay:(PlayerReadyToPlay)_playerReadyToPlay PlayerRateChanged:(PlayerRateChanged)_playerRateChanged CurrentItemChanged:(CurrentItemChanged)_currentItemChanged
{
    if ((self = [super init])) {
        HBGQueue = dispatch_queue_create("com.hysteria.queue", NULL);
        playerItems = [NSMutableArray array];
        PLAYMODE_Repeat = YES;
        PLAYMODE_RepeatOne = NO;
        PLAYMODE_Shuffle = NO;
        
        playerReadyToPlay = _playerReadyToPlay;
        playerRateChanged = _playerRateChanged;
        currentItemChanged = _currentItemChanged;
        itemReadyToPlay = nil;
        
        [self backgroundPlayable];
        [self playEmptySound];
        [self AVAudioSessionNotification];
    }
    return self;
}

- (void)setupWithGetterBlock:(BlockItemGetter)itemBlock ItemsCount:(NSUInteger)count
{ 
    blockItemGetter = itemBlock;
    items_count = count;
}

- (void)setItemsCount:(NSUInteger)count
{
    items_count = count;
}


- (void)playEmptySound
{
    //play  2 sec empty sound
    NSString *filepath = [[NSBundle mainBundle]pathForResource:@"point1sec" ofType:@"mp3"];
    if ([[NSFileManager defaultManager]fileExistsAtPath:filepath]) {
        isInEmptySound = YES;
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filepath]];
        audioPlayer = [AVQueuePlayer queuePlayerWithItems:[NSArray arrayWithObject:playerItem]];
        NSLog(@"empty sound played");
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
                    NSLog(@"set category error:%@",[aError description]);
                }
                aError = nil;
                [audioSession setActive:YES error:&aError];
                if (aError) {
                    NSLog(@"set active error:%@",[aError description]);
                }
                //audioSession.delegate = self;
            }
        }
        NSLog(@"register background playable");
    }else {
        NSLog(@"do not register background playable");
    }
    
    [self longTimeBufferBackground];
}

/*
 * Tells OS this application starts one or more long-running tasks, should end background task when completed.
 */
-(void)longTimeBufferBackground
{
    bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    if (bgTaskId != UIBackgroundTaskInvalid && removedId != UIBackgroundTaskInvalid) {
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

- (void)setHysteriaOrder:(AVPlayerItem *)item Key:(NSNumber *)order {
    objc_setAssociatedObject(item, Hysteriatag, order, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)getHysteriaOrder:(AVPlayerItem *)item {
    return objc_getAssociatedObject(item, Hysteriatag);
}

#pragma mark -
#pragma mark ===========  AVAudioSession Notifications  =========
#pragma mark -

- (void)AVAudioSessionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
    [audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
}

#pragma mark -
#pragma mark ===========  Player Methods  =========
#pragma mark -

- (void) fetchAndPlayPlayerItem: (NSUInteger )startAt
{
    [audioPlayer pause];
    [audioPlayer removeAllItems];
    for (AVPlayerItem *item in playerItems) {
        NSInteger checkIndex = [[self getHysteriaOrder:item] integerValue];
        if (checkIndex == startAt) {
            [item seekToTime:kCMTimeZero];
            [self insertPlayerItem:item];
            return;
        }
    }
    
    dispatch_async(HBGQueue, ^{
        AVPlayerItem *item;
        if (blockItemGetter) {
            item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:blockItemGetter(startAt)]];
        }else{
            NSLog(@"please using setupWithGetterBlock: to setup your datasource");
            return ;
        }
        if (item == nil) {
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:startAt]];
            [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            [playerItems addObject:item];
            if (isInEmptySound) {
                isInEmptySound = NO;
                [self insertPlayerItem:item];
            }else{
                [self insertPlayerItem:item];
            }
        });
    });
}

- (void) prepareNextPlayerItem
{
    // check before added, prevent add the same songItem
    NSNumber *CHECK_Order = [self getHysteriaOrder:audioPlayer.currentItem];
    NSUInteger nowIndex = [CHECK_Order integerValue];
    BOOL findInPlayerItems = NO;
    
    if (CHECK_Order) {
        if (PLAYMODE_Shuffle || PLAYMODE_RepeatOne) {
            return;
        }
        if (nowIndex + 1 < items_count) {
            for (AVPlayerItem *item in playerItems) {
                NSInteger checkIndex = [[self getHysteriaOrder:item] integerValue];
                if (checkIndex == nowIndex +1) {
                    [item seekToTime:kCMTimeZero];
                    findInPlayerItems = YES;
                    [self insertPlayerItem:item];
                }
            }
            if (!findInPlayerItems) {
                dispatch_async(HBGQueue, ^{
                    AVPlayerItem *item;
                    if (blockItemGetter) {
                        item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:blockItemGetter(nowIndex + 1)]];
                    }else{
                        NSLog(@"please using setupWithGetterBlock: to setup your datasource");
                        return ;
                    }
                    if (item == nil) {
                        return ;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:nowIndex + 1]];
                        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
                        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
                        [playerItems addObject:item];
                        [self insertPlayerItem:item];
                    });
                });
            }
        }else if (items_count > 1){
            if (PLAYMODE_Repeat) {
                for (AVPlayerItem *item in playerItems) {
                    NSInteger checkIndex = [[self getHysteriaOrder:item] integerValue];
                    if (checkIndex == 0) {
                        findInPlayerItems = YES;
                        [self insertPlayerItem:item];
                    }
                }
                if (!findInPlayerItems) {
                    dispatch_async(HBGQueue, ^{
                        AVPlayerItem *item;
                        if (blockItemGetter) {
                            item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:blockItemGetter(0)]];
                        }else{
                            NSLog(@"please using setupWithGetterBlock: to setup your datasource");
                            return ;
                        }
                        if (item == nil) {
                            return ;
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:0]];
                            [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
                            [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
                            [playerItems addObject:item];
                            [self insertPlayerItem:item];
                        });
                    });
                }
            }
        }
    }
}

- (void)insertPlayerItem:(AVPlayerItem *)item
{
    if ([audioPlayer.items count] > 1) {
        for (int i = 1 ; i < [audioPlayer.items count] ; i ++) {
            [audioPlayer removeItem:[audioPlayer.items objectAtIndex:i]];
        }
    }
    if ([audioPlayer canInsertItem:item afterItem:nil]) {
        [audioPlayer insertItem:item afterItem:nil];
    }
}

- (void)removeAllItems
{
    for (AVPlayerItem *obj in playerItems) {
        [obj seekToTime:kCMTimeZero];
        [obj removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
        [obj removeObserver:self forKeyPath:@"status" context:nil];
    }
    
    [playerItems removeAllObjects];
    [audioPlayer removeAllItems];
}

- (void)removeQueuesAtPlayer
{
    while (audioPlayer.items.count > 1) {
        [audioPlayer removeItem:[audioPlayer.items objectAtIndex:1]];
    }
}

- (void)removeItemAtIndex:(NSUInteger)order
{
    for (AVPlayerItem *item in [NSArray arrayWithArray:playerItems]) {
        NSUInteger CHECK_order = [[self getHysteriaOrder:item] integerValue];
        if (CHECK_order == order) {
            [playerItems removeObject:item];
            
            if ([audioPlayer.items indexOfObject:item] != NSNotFound) {
                [audioPlayer removeItem:item];
            }
        }else if (CHECK_order > order){
            [self setHysteriaOrder:item Key:[NSNumber numberWithInteger:CHECK_order -1]];
        }
    }

    items_count --;
}

- (void)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to
{
    for (AVPlayerItem *item in playerItems) {
        NSUInteger CHECK_index = [[self getHysteriaOrder:item] integerValue];
        if (CHECK_index == from || CHECK_index == to) {
            NSNumber *replaceOrder = CHECK_index == from ? [NSNumber numberWithInteger:to] : [NSNumber numberWithInteger:from];
            [self setHysteriaOrder:item Key:replaceOrder];
        }
    }
}

- (void)seekToTime:(double)seconds
{
    [audioPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
}
- (AVPlayerItem *)getCurrentItem
{
    return [audioPlayer currentItem];
}

- (void)play
{
    [audioPlayer play];
}

- (void)pause
{
    [audioPlayer pause];
}

- (void)playNext
{
    if (PLAYMODE_Shuffle) {
        NSUInteger index;
        [audioPlayer removeAllItems];
        do {
            index = arc4random() % items_count;
        } while (index == [[self getHysteriaOrder:audioPlayer.currentItem] integerValue]);
        [self fetchAndPlayPlayerItem:index];
    }else{
        if ([audioPlayer.items count] == 2) {
            [audioPlayer advanceToNextItem];
        }else{
            NSInteger nowIndex = [[self getHysteriaOrder:audioPlayer.currentItem] integerValue];
            if (nowIndex + 1 < items_count) {
                [self fetchAndPlayPlayerItem:(nowIndex + 1)];
            }else{
                if (PLAYMODE_Repeat) {
                    [self fetchAndPlayPlayerItem:0];
                }
            }
        }
    }
}

- (void)playPrevious
{
    NSInteger nowIndex = [[self getHysteriaOrder:audioPlayer.currentItem] integerValue];
    if (nowIndex == 0)
    {
        if (PLAYMODE_Repeat) {
            [self fetchAndPlayPlayerItem:items_count - 1];
        }else{
            [audioPlayer.currentItem seekToTime:kCMTimeZero];
        }
    }else{
        [self fetchAndPlayPlayerItem:(nowIndex - 1)];
    }
}

- (CMTime)playerItemDuration
{
    NSError *err = nil;
    if ([audioPlayer.currentItem.asset statusOfValueForKey:@"duration" error:&err] == AVKeyValueStatusLoaded) {
        AVPlayerItem *playerItem = [audioPlayer currentItem];
        NSArray *loadedRanges = playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0)
        {
            CMTimeRange range = [[loadedRanges objectAtIndex:0] CMTimeRangeValue];
            //Float64 duration = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
            return (range.duration);
        }else {
            return (kCMTimeInvalid);
        }
    }else{
        return (kCMTimeInvalid);
    }
}

- (void)setPLAYMODE_Repeat:(BOOL)_PLAYMODE_Repeat
{
    if (_PLAYMODE_Repeat) {
        if (PLAYMODE_RepeatOne) {
            PLAYMODE_RepeatOne = NO;
        }
    }
}

- (void)setPLAYMODE_RepeatOne:(BOOL)_PLAYMODE_RepeatOne
{
    if (_PLAYMODE_RepeatOne) {
        if (PLAYMODE_Repeat) {
            PLAYMODE_Repeat = NO;
        }
    }
}
#pragma mark -
#pragma mark ===========  Player info  =========
#pragma mark -

- (BOOL)isPlaying
{
	return [audioPlayer rate] != 0.f;
}

- (HysteriaPauseReason)pauseReason
{
    if ([self isPlaying]) {
        return HysteriaPauseReasonPlaying;
    }else if (PAUSE_REASON_ForcePause){
        return HysteriaPauseReasonForce;
    }else{
        return HysteriaPauseReasonUnknown;
    }
}

- (NSDictionary *)getPlayerTime
{
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:0.0], @"CurrentTime", [NSNumber numberWithDouble:0.0], @"DurationTime", nil];
    }
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		double time = CMTimeGetSeconds([audioPlayer currentTime]);
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:time], @"CurrentTime", [NSNumber numberWithDouble:duration], @"DurationTime", nil];
	}else{
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:0.0], @"CurrentTime", [NSNumber numberWithDouble:0.0], @"DurationTime", nil];
    }
}

#pragma mark -
#pragma mark ===========  Interruption, Route changed  =========
#pragma mark -

- (void)interruption:(NSNotification *)notification
{
    
    //ios 6.0 bug
    //search avaudiosessioninterruptionnotification at
    //http://developer.apple.com/library/ios/#documentation/AVFoundation/Reference/AVAudioSession_ClassReference/Reference/Reference.html#//apple_ref/c/data/AVAudioSessionInterruptionTypeKey
    
    NSDictionary *userInfo = [notification userInfo];
    NSUInteger reason = [[userInfo objectForKey:@"AVAudioSessionInterruptionType"] integerValue];
    
    if (reason == AVAudioSessionInterruptionTypeEnded && interruptedWhilePlaying) {
        interruptedWhilePlaying = NO;
        PAUSE_REASON_ForcePause = NO;
        [audioPlayer play];
    }else if (reason == AVAudioSessionInterruptionTypeBegan){
        interruptedWhilePlaying = YES;
        PAUSE_REASON_ForcePause = YES;
        [audioPlayer pause];
    }
    
    
    NSLog(@"resume playback from interruption");
}

- (void)routeChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSUInteger reason = [[userInfo objectForKey:@"AVAudioSessionRouteChangeReasonKey"] integerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        routeChangedWhilePlaying = YES;
        PAUSE_REASON_ForcePause = YES;
        NSLog(@"route changed while playng, pause player");
    }else if (reason == AVAudioSessionRouteChangeReasonNewDeviceAvailable && routeChangedWhilePlaying){
        routeChangedWhilePlaying = NO;
        PAUSE_REASON_ForcePause = NO;
        [audioPlayer play];
        NSLog(@"resume playback from route changed");
    }
}

#pragma mark -
#pragma mark ===========  KVO  =========
#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == audioPlayer && [keyPath isEqualToString:@"status"]) {
        if (audioPlayer.status == AVPlayerStatusReadyToPlay) {
            if (playerReadyToPlay != nil) {
                playerReadyToPlay();
            }
            if (![self isPlaying]) {
                [audioPlayer play];
            }
        } else if (audioPlayer.status == AVPlayerStatusFailed) {
            NSLog(@"player error!!!:%@",audioPlayer.error);
        }
    }
    
    if(object == audioPlayer && [keyPath isEqualToString:@"rate"]){
        if (playerRateChanged != nil) {
            playerRateChanged();
        }
    }
    
    if(object == audioPlayer && [keyPath isEqualToString:@"currentItem"]){
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        NSLog(@"current item changed");
        if (currentItemChanged != nil) {
            currentItemChanged(newPlayerItem);
        }
    }
    
    if (object == audioPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        if (audioPlayer.currentItem.status == AVPlayerItemStatusFailed) {
            NSLog(@"------player item failed:%@",audioPlayer.currentItem.error);
            [self playNext];
        }else if (audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            if (itemReadyToPlay != nil) {
                itemReadyToPlay();
            }
        }
    }
    
    if(object == audioPlayer.currentItem && [keyPath isEqualToString:@"loadedTimeRanges"]){
        if (audioPlayer.currentItem.hash != CHECK_AvoidPreparingSameItem) {
            [self prepareNextPlayerItem];
            CHECK_AvoidPreparingSameItem = audioPlayer.currentItem.hash;
        }
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange=[[timeRanges objectAtIndex:0]CMTimeRangeValue];
            
            NSLog(@". . . %.5f  -> %.5f",CMTimeGetSeconds(timerange.start),CMTimeGetSeconds(timerange.duration));
            
            if (audioPlayer.rate == 0 && !PAUSE_REASON_ForcePause) {
                //buffer for 5 secs, then play
                if (CMTIME_COMPARE_INLINE(timerange.duration, >, CMTimeMakeWithSeconds(5, timerange.duration.timescale)) && audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay && !interruptedWhilePlaying) {
                    NSLog(@"-----------3G delay------------");
                    if (![self isPlaying]) {
                        NSLog(@"3g delay play");
                        [audioPlayer play];
                    }
                }
            }
        }
    }

}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    NSNumber *CHECK_Order = [self getHysteriaOrder:audioPlayer.currentItem];
    if (CHECK_Order) {
        if (PLAYMODE_RepeatOne) {
            NSInteger currentIndex = [CHECK_Order integerValue];
            [self fetchAndPlayPlayerItem:currentIndex];
        }else if (PLAYMODE_Shuffle){
            NSUInteger index;
            do {
                index = arc4random() % items_count;
            } while (index == [CHECK_Order integerValue]);
            [self fetchAndPlayPlayerItem:index];
        }else{
            if (NETWORK_ERROR_getNextItem || audioPlayer.items.count == 1) {
                NETWORK_ERROR_getNextItem = NO;
                NSInteger nowIndex = [CHECK_Order integerValue];
                if (nowIndex + 1 < items_count) {
                    [self fetchAndPlayPlayerItem:(nowIndex + 1)];
                }else if (PLAYMODE_Repeat){
                    [self fetchAndPlayPlayerItem:0];
                }else if (!PLAYMODE_Repeat){
                    NSInteger nowIndex = [CHECK_Order integerValue];
                    if (nowIndex + 1 == items_count) {
                        [audioPlayer removeAllItems];
                        PAUSE_REASON_ForcePause = YES;
                        [audioPlayer pause];
                        [self fetchAndPlayPlayerItem:0];
                    }
                }
            }
        }
    }
    NSLog(@"item end.");
}

#pragma mark -
#pragma mark ===========   Deprecation  =========
#pragma mark -

- (void)deprecatePlayer
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [audioPlayer removeObserver:self forKeyPath:@"status" context:nil];
    [audioPlayer removeObserver:self forKeyPath:@"rate" context:nil];
    [audioPlayer removeObserver:self forKeyPath:@"currentItem" context:nil];
    
    [self removeAllItems];
    
    [audioPlayer pause];
    audioPlayer = nil;
}

#pragma mark -
#pragma mark ===========   iOS 5 under Interruption  =========
#pragma mark -

//   iOS6 deprecated!
//- (void)beginInterruption
//{
//    if ([self isPlaying]) {
//        manul_pause = YES;
//        [player pause];
//        interruptedWhilePlaying = YES;
//        NSLog(@"begin interrupting");
//    }
//}

//- (void)endInterruption
//{
//    NSLog(@"end interrupitng");
//
//    if (interruptedWhilePlaying) {
//        double delayInSeconds = 2.0;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds  *NSEC_PER_SEC);
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//            NSError *activationError = nil;
//            [[AVAudioSession sharedInstance]setActive:YES error:&activationError];
//            if (activationError != nil) {
//                NSLog(@"unable to resume playback after interruption");
//                NSLog(@"%@",activationError.description);
//
//                interruptedWhilePlaying = NO;
//                manul_pause = NO;
//                [player play];
//
//            }else {
//                NSLog(@"resume from interrtuption");
//                interruptedWhilePlaying = NO;
//                manul_pause = NO;
//                [player play];
//            }
//        });
//
//    }
//
//}
@end
